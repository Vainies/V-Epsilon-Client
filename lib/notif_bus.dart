import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';
import 'models.dart';
import 'push_service.dart';
import 'theme.dart';
import 'extension_runtime.dart';

/// Global notification bus. The app shell opens a WebSocket to the server on
/// every app-resume and pipes server events here. Screens (Activity, AppShell
/// for the dot) subscribe to the streams they care about.
///
/// Lifecycle:
///   NotifBus.I.start(api)   - opens WS, listens
///   NotifBus.I.stop()       - closes WS
///   NotifBus.I.newNotifs.listen((_) => refresh)
class NotifBus extends ChangeNotifier {
  NotifBus._();
  static final NotifBus I = NotifBus._();

  WebSocketChannel? _ch;
  Api? _api;
  Timer? _reconnectTimer;
  StreamSubscription? _sub;
  bool _wantOpen = false;
  int _reconnectAttempt = 0;
  static const int _maxRetries = 10;

  /// Latest incoming event. Widgets can listen with `addListener` + read
  /// [lastEvent] to react. Alternatively subscribe to [events].
  final StreamController<WsEvent> _events = StreamController.broadcast();
  Stream<WsEvent> get events => _events.stream;

  /// Counter that bumps every time a new notification arrives. Screens can
  /// watch this with a ValueListenableBuilder to trigger refresh.
  final ValueNotifier<int> unreadBump = ValueNotifier<int>(0);

  WsEvent? lastEvent;

  /// Start or restart the connection.
  void start(Api api) {
    _api = api;
    _wantOpen = true;
    _reconnectAttempt = 0;
    _openNow();
  }

  void stop() {
    _wantOpen = false;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }

  void _openNow() {
    if (!_wantOpen || _api == null || !_api!.isAuthed) return;
    try {
      final ch = _api!.openWebSocket();
      if (ch == null) {
        _scheduleReconnect();
        return;
      }
      _ch = ch;
      _sub = ch.stream.listen(
        _onMessage,
        onError: (e) {
          if (kDebugMode) debugPrint('[notifbus] ws error: $e');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      // Subscribe to our personal notification topic. Server auto-subs
      // `user:<uid>` when a token was provided in the URL, but we also send
      // an explicit `sub` message for belt & suspenders.
      final uid = _api!.userId;
      if (uid != null) {
        ch.sink.add(jsonEncode({'type': 'sub', 'topic': 'user:$uid'}));
      }
      ch.sink.add(jsonEncode({'type': 'sub', 'topic': 'feed'}));
      if (kDebugMode) debugPrint('[notifbus] ws open');
    } catch (e) {
      if (kDebugMode) debugPrint('[notifbus] open failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _sub?.cancel();
    _sub = null;
    _ch = null;
    _reconnectTimer?.cancel();
    if (!_wantOpen) return;
    _reconnectAttempt++;
    if (_reconnectAttempt > _maxRetries) {
      if (kDebugMode) debugPrint('[notifbus] max retries reached, giving up');
      return;
    }
    final delays = [1, 2, 4, 8, 15, 30, 60];
    final secs = _reconnectAttempt - 1 < delays.length ? delays[_reconnectAttempt - 1] : 60;
    final delay = Duration(seconds: secs);
    if (kDebugMode) debugPrint('[notifbus] reconnect #$_reconnectAttempt in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, _openNow);
  }

  void _onMessage(dynamic raw) {
    try {
      final Map<String, dynamic> j =
          raw is String ? jsonDecode(raw) : jsonDecode(utf8.decode(raw as List<int>));
      final ev = WsEvent(
        topic: (j['topic'] ?? '') as String,
        kind: (j['kind'] ?? '') as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ??  {},
      );
      lastEvent = ev;
      _events.add(ev);
      notifyListeners();
      if (ev.kind == 'notification.new') {
        unreadBump.value++;
        _raiseLocalPush(ev);
      } else if (ev.kind == 'update.available') {
        _raiseLocalPush(ev);
      } else if (ev.kind == 'theme.updated') {
        _applyGlobalTheme(ev.payload);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[notifbus] bad msg: $e / $raw');
    }
  }

  /// Translates a server WS event into an Android notification.
  void _raiseLocalPush(WsEvent ev) {
    try {
      if (ev.kind == 'notification.new') {
        final kind = (ev.payload['kind'] ?? '') as String;
        final actor = ev.actor;
        if (actor == null) return;
        final body = (ev.payload['body'] ?? '') as String;
        final text = PushService.I.formatBody(kind, actor, body);
        final nid = (ev.payload['id'] as num?)?.toInt() ?? 0;
        PushService.I.showNotification(
          title: 'Epsilon',
          body: text,
          category: kind,
          id: nid,
          payload: '$nid:notification',
        );
      } else if (ev.kind == 'update.available') {
        final v = (ev.payload['version'] ?? '') as String;
        PushService.I.showNotification(
          title: 'Epsilon update',
          body: v.isEmpty ? 'A new version is available.' : 'Version $v is available. Tap to install.',
          category: 'updates',
          id: 100001,
          payload: '100001:update',
        );
      }
    } catch (_) {}
  }

  void _applyGlobalTheme(Map<String, dynamic> payload) {
    final theme = payload['theme'] as Map<String, dynamic>?;
    if (theme == null) return;
    if (theme.isEmpty) {
      ExtensionRuntime.I.uninstall('global_theme');
    } else {
      ExtensionRuntime.I.install('global_theme', {'type': 'theme', 'theme': theme});
    }
    VETheme.I.loadOverrides();
    VETheme.I.refresh();
  }
}

class WsEvent {
  final String topic;
  final String kind;
  final Map<String, dynamic> payload;
   WsEvent({required this.topic, required this.kind, required this.payload});

  /// Parse payload's actor field as AppUser if present.
  AppUser? get actor {
    final a = payload['actor'];
    if (a is Map) return AppUser.fromJson(a.cast<String, dynamic>());
    return null;
  }

  @override
  String toString() => 'WsEvent($topic, $kind, $payload)';
}
