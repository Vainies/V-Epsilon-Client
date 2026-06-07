import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Wraps flutter_local_notifications so other code doesn't need to know about
/// the plugin. Also centralizes permission requests and user preferences.
///
/// Designed around Android-only display for now. We don't use FCM - events
/// come via our own WebSocket and we raise a local notification when the app
/// is backgrounded. Notifications show even when the app is foregrounded so
/// the user gets feedback without watching the bell.
typedef NotificationTapCallback = void Function(int id, String? category);

class PushService {
  PushService._();
  static final PushService I = PushService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationTapCallback? onTap;
  // Enabled categories (mirrors server-side columns in users.push_*).
  bool likesOn = true;
  bool commentsOn = true;
  bool followsOn = true;
  bool updatesOn = true;

  static const _channelId = 'epsilon_events';
  static const _channelName = 'Epsilon';
  static const _channelDesc = 'Likes, comments, follows and updates';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Load saved preferences.
    final sp = await SharedPreferences.getInstance();
    likesOn = sp.getBool('push_likes') ?? true;
    commentsOn = sp.getBool('push_comments') ?? true;
    followsOn = sp.getBool('push_follows') ?? true;
    updatesOn = sp.getBool('push_updates') ?? true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && onTap != null) {
          final parts = payload.split(':');
          final id = int.tryParse(parts[0]) ?? 0;
          final cat = parts.length > 1 ? parts[1] : null;
          onTap!(id, cat);
        }
      },
    );

    // Android 13+ requires runtime permission.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      // Older Android versions don't have the API; ignore.
    }
  }

  Future<void> setCategory(String key, bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('push_$key', v);
    switch (key) {
      case 'likes':
        likesOn = v;
        break;
      case 'comments':
        commentsOn = v;
        break;
      case 'follows':
        followsOn = v;
        break;
      case 'updates':
        updatesOn = v;
        break;
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required String category, // likes|comments|follows|updates
    int id = 0,
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (!_allowed(category)) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    );
    try {
      await _plugin.show(id, title, body, const NotificationDetails(android: androidDetails), payload: payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[push] show failed: $e');
    }
  }

  bool _allowed(String category) {
    switch (category) {
      case 'like':
      case 'likes':
        return likesOn;
      case 'comment':
      case 'comments':
        return commentsOn;
      case 'follow':
      case 'follows':
        return followsOn;
      case 'update':
      case 'updates':
        return updatesOn;
    }
    return true;
  }

  /// Convert a server notification payload into a user-facing message.
  String formatBody(String kind, AppUser actor, String body) {
    final name = actor.name.isEmpty ? '@${actor.handle}' : actor.name;
    switch (kind) {
      case 'like':
        return '$name liked your post';
      case 'comment':
        return body.isEmpty ? '$name commented on your post' : '$name: $body';
      case 'follow':
        return '$name started following you';
      case 'repost':
        return '$name reposted you';
      default:
        return body.isEmpty ? '$name sent you an update' : body;
    }
  }
}
