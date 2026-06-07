import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'models.dart';

/// Global API client. Holds base URL + JWT token.
class Api extends ChangeNotifier {
  // Built-in candidate URLs - add your own server URL(s) here.
  // The app will probe these on startup to find a reachable server.
  static const builtinUrls = <String>[];
  List<String> _knownUrls = [];
  List<String> get _candidateUrls => [...builtinUrls, ..._knownUrls];

  // Default base URL. Users should set this to their own server address.
  static const defaultBaseUrl = '';

  String _baseUrl = defaultBaseUrl;
  String? _token;
  int? _userId;
  String? _handle;
  bool _probedOnce = false;
  bool _betaMode = false;
  bool _allowUpdates = true;
  bool _online = true;
  Timer? _healthTimer;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  int? get userId => _userId;
  String get handle => _handle ?? '';
  bool get isAuthed => _token != null;
  bool get betaMode => _betaMode;
  bool get allowUpdates => _allowUpdates;
  bool get online => _online;

  Future<void> setBetaMode(bool v) async {
    _betaMode = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('beta_mode', v);
    notifyListeners();
  }

  Future<void> setAllowUpdates(bool v) async {
    _allowUpdates = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('allow_updates', v);
    notifyListeners();
  }

  /// Startup health check + periodic ping to track online/offline.
  void startHealthPings() {
    _pingHealth();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pingHealth());
  }

  void stopHealthPings() {
    _healthTimer?.cancel();
  }

  Future<void> _pingHealth() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 5));
      final was = _online;
      _online = res.statusCode == 200;
      if (was != _online) notifyListeners();
    } catch (_) {
      if (_online) {
        _online = false;
        notifyListeners();
      }
    }
  }

  /// URL to share a profile. ALWAYS uses the canonical public URL, never the
  /// LAN address the local probe picked - otherwise shared links won't
  /// resolve for anyone outside your network.
  String webUrlFor(String handle) =>
      '${_canonicalPublicUrl()}/redirect/app/u/$handle';

  /// URL to share a post.
  String postUrlFor(int id) =>
      '${_canonicalPublicUrl()}/redirect/app/p/$id';

  /// The public-facing base URL used for share links. Defaults to the well-known
  /// public IP of the Epsilon server. If a dev overrides `public_url` in prefs
  /// that wins.
  String _canonicalPublicUrl() {
    // Override this with your server's public URL for share links.
    return _publicUrlOverride ?? defaultBaseUrl;
  }

  String? _publicUrlOverride;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _baseUrl = sp.getString('server_url') ?? defaultBaseUrl;
    _token = sp.getString('token');
    _userId = sp.getInt('user_id');
    _handle = sp.getString('handle');
    _betaMode = sp.getBool('beta_mode') ?? false;
    _allowUpdates = sp.getBool('allow_updates') ?? true;
    _knownUrls = sp.getStringList('known_server_urls') ?? [];
    notifyListeners();
  }

  /// Races candidate URLs in parallel. First one to respond to /health wins.
  /// Saved as the current base URL for this session.
  Future<void> probeAndPickFastest({Duration timeout =  const Duration(seconds: 3)}) async {
    _probedOnce = true;
    final completer = Completer<String?>();
    for (final url in _candidateUrls) {
      http.get(Uri.parse('$url/health')).timeout(timeout).then((r) {
        if (r.statusCode == 200 && !completer.isCompleted) {
          completer.complete(url);
        }
      }).catchError((_) {});
    }
    // Finish after timeout even if none respond.
    Future<void>.delayed(timeout).then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    final winner = await completer.future;
    if (winner != null && winner != _baseUrl) {
      _baseUrl = winner;
      final sp = await SharedPreferences.getInstance();
      await sp.setString('server_url', _baseUrl);
      if (kDebugMode) debugPrint('[api] picked $_baseUrl');
      notifyListeners();
    }
  }

  bool get hasProbed => _probedOnce;

  /// Resolve a relative URL to absolute using the current server URL.
  /// Pass through absolute URLs unchanged.
  String resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$_baseUrl$url';
    return url;
  }

  Future<void> setServer(String url) async {
    _baseUrl = url.trim();
    final sp = await SharedPreferences.getInstance();
    await sp.setString('server_url', _baseUrl);
    notifyListeners();
  }

  List<String> get knownUrls => List.unmodifiable(_knownUrls);

  Future<void> addKnownUrl(String url) async {
    url = url.trim();
    if (_knownUrls.contains(url) || builtinUrls.contains(url)) return;
    _knownUrls.add(url);
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('known_server_urls', _knownUrls);
    notifyListeners();
  }

  Future<void> removeKnownUrl(String url) async {
    _knownUrls.remove(url);
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('known_server_urls', _knownUrls);
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> auth) async {
    _token = auth['token'] as String?;
    _userId = (auth['user_id'] as num?)?.toInt();
    _handle = auth['handle'] as String?;
    final sp = await SharedPreferences.getInstance();
    if (_token != null) await sp.setString('token', _token!);
    if (_userId != null) await sp.setInt('user_id', _userId!);
    if (_handle != null) await sp.setString('handle', _handle!);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _handle = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
    await sp.remove('user_id');
    await sp.remove('handle');
    notifyListeners();
  }

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _u(String path, [Map<String, String>? qp]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: qp);

  // ---- Auth ----
  Future<void> register(String handle, String name, String password, {String? email}) async {
    final res = await http.post(_u('/api/v1/auth/register'),
        headers: _headers(),
        body: jsonEncode({'handle': handle, 'name': name, 'password': password, if (email != null && email.isNotEmpty) 'email': email}));
    _assertOk(res);
    await _saveSession(jsonDecode(res.body));
  }

  Future<void> login(String handle, String password) async {
    final res = await http.post(_u('/api/v1/auth/login'),
        headers: _headers(),
        body: jsonEncode({'handle': handle, 'password': password}));
    _assertOk(res);
    await _saveSession(jsonDecode(res.body));
  }

  // ---- Feed / Posts ----
  Future<List<Post>> feed({String? kind, int limit = 30, int offset = 0}) async {
    final qp = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (kind != null && kind != 'all') qp['kind'] = kind;
    final res = await http.get(_u('/api/v1/feed', qp), headers: _headers(json: false));
    _assertOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['posts'] as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Post> getPost(int id) async {
    final res = await http.get(_u('/api/v1/posts/$id'), headers: _headers(json: false));
    _assertOk(res);
    return Post.fromJson(jsonDecode(res.body));
  }

  Future<int> createPost(Map<String, dynamic> body) async {
    final res = await http.post(_u('/api/v1/posts'), headers: _headers(), body: jsonEncode(body));
    _assertOk(res);
    return (jsonDecode(res.body)['id'] as num).toInt();
  }

  Future<void> likePost(int id) async {
    final res = await http.post(_u('/api/v1/posts/$id/like'), headers: _headers());
    _assertOk(res);
  }

  Future<void> unlikePost(int id) async {
    final res = await http.delete(_u('/api/v1/posts/$id/like'), headers: _headers());
    _assertOk(res);
  }

  // ---- Comments ----
  Future<List<Comment>> comments(int postId) async {
    final res = await http.get(_u('/api/v1/posts/$postId/comments'), headers: _headers(json: false));
    _assertOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['comments'] as List).map((e) => Comment.fromJson(e)).toList();
  }

  Future<int> comment(int postId, String body) async {
    final res = await http.post(_u('/api/v1/posts/$postId/comments'),
        headers: _headers(), body: jsonEncode({'body': body}));
    _assertOk(res);
    return (jsonDecode(res.body)['id'] as num).toInt();
  }

  // ---- Users / Me ----
  Future<AppUser> getUser(String handle) async {
    final res = await http.get(_u('/api/v1/users/$handle'), headers: _headers(json: false));
    _assertOk(res);
    return AppUser.fromJson(jsonDecode(res.body));
  }

  Future<AppUser> me() async {
    final res = await http.get(_u('/api/v1/me'), headers: _headers(json: false));
    _assertOk(res);
    return AppUser.fromJson(jsonDecode(res.body));
  }

  Future<void> updateMe(Map<String, dynamic> patch) async {
    final res = await http.patch(_u('/api/v1/me'), headers: _headers(), body: jsonEncode(patch));
    _assertOk(res);
  }

  Future<void> changePassword(String current, String newPass) async {
    final res = await http.post(_u('/api/v1/me/password'), headers: _headers(),
        body: jsonEncode({'current': current, 'new': newPass}));
    _assertOk(res);
  }

  Future<void> deleteMe() async {
    final res = await http.delete(_u('/api/v1/me'), headers: _headers(json: false));
    _assertOk(res);
    await logout();
  }

  Future<String> exportMe() async {
    final res = await http.get(_u('/api/v1/me/export'), headers: _headers(json: false));
    _assertOk(res);
    return res.body;
  }

  // ---- Uploads ----
  /// Upload a file. Returns absolute URL (baseUrl + returned path).
  Future<String> uploadFile(File file) async {
    final req = http.MultipartRequest('POST', _u('/api/v1/uploads'));
    req.headers.addAll(_headers(json: false));
    final ext = file.path.toLowerCase().split('.').last;
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
    };
    final mt = mimeTypes[ext] ?? 'application/octet-stream';
    final parts = mt.split('/');
    req.files.add(await http.MultipartFile.fromPath('file', file.path,
        contentType: MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream')));
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    _assertOk(resp);
    final j = jsonDecode(resp.body);
    final url = j['url'] as String;
    return url.startsWith('http') ? url : '$_baseUrl$url';
  }

  // ---- Notifications / Messages ----
  Future<List<AppNotification>> notifications() async {
    final res = await http.get(_u('/api/v1/notifications'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['notifications'] as List)
        .map((e) => AppNotification.fromJson(e))
        .toList();
  }

  Future<List<Thread>> threads() async {
    final res = await http.get(_u('/api/v1/messages'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['threads'] as List)
        .map((e) => Thread.fromJson(e))
        .toList();
  }

  // ---- Version history ----
  Future<List<Map<String, dynamic>>> getVersions() async {
    final qp = <String, String>{};
    if (_betaMode) qp['include_beta'] = 'true';
    final res = await http.get(_u('/api/v1/versions', qp), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['versions'] as List).cast<Map<String, dynamic>>();
  }

  // ---- Search ----
  Future<Map<String, dynamic>> search(String query) async {
    final res = await http.get(_u('/api/v1/search', {'q': query}), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---- Extensions ----
  Future<List<Map<String, dynamic>>> getExtensions() async {
    final res = await http.get(_u('/api/v1/extensions'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['extensions'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> extensionReviews(String id) async {
    final res = await http.get(_u('/api/v1/extensions/$id/reviews'), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> extensionData(String id) async {
    final res = await http.get(_u('/api/v1/extensions/$id/data'), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> extensionSubmitReview(String id, int rating, String text) async {
    final res = await http.post(_u('/api/v1/extensions/$id/review'), headers: _headers(), body: jsonEncode({'rating': rating, 'text': text}));
    _assertOk(res);
  }

  Future<void> adminCreateAd(Map<String, dynamic> data) async {
    final res = await http.post(_u('/api/v1/admin/ads'), headers: _headers(), body: jsonEncode(data));
    _assertOk(res);
  }

  Future<void> adminDeleteAd(int id) async {
    final res = await http.delete(_u('/api/v1/admin/ads/$id'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<void> adminCreateAnnouncement(Map<String, dynamic> data) async {
    final res = await http.post(_u('/api/v1/admin/announcements'), headers: _headers(), body: jsonEncode(data));
    _assertOk(res);
  }

  Future<void> adminDeleteAnnouncement(int id) async {
    final res = await http.delete(_u('/api/v1/admin/announcements/$id'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final res = await http.get(_u('/api/v1/announcements'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['announcements'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAds() async {
    final res = await http.get(_u('/api/v1/ads'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['ads'] as List).cast<Map<String, dynamic>>();
  }

  // ---- Reposts ----
  Future<void> repost(int id) async {
    final res = await http.post(_u('/api/v1/posts/$id/repost'), headers: _headers());
    _assertOk(res);
  }

  Future<void> unrepost(int id) async {
    final res = await http.delete(_u('/api/v1/posts/$id/repost'), headers: _headers());
    _assertOk(res);
  }

  /// Fetch a user's reposts as a chronological feed.
  Future<List<Post>> userReposts(String handle, {int limit = 30}) async {
    final res = await http.get(
        _u('/api/v1/feed', {'scope': 'reposts', 'user': handle, 'limit': '$limit'}),
        headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['posts'] as List)
        .map((e) => Post.fromJson(e))
        .toList();
  }

  /// Fetch a user's own posts (server-side filter).
  Future<List<Post>> userPosts(String handle, {int limit = 30}) async {
    final res = await http.get(
        _u('/api/v1/feed', {'scope': 'user', 'user': handle, 'limit': '$limit'}),
        headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['posts'] as List)
        .map((e) => Post.fromJson(e))
        .toList();
  }

  // ---- Social graph ----
  Future<void> follow(String handle) async {
    final res = await http.post(_u('/api/v1/users/$handle/follow'), headers: _headers());
    _assertOk(res);
  }

  Future<void> unfollow(String handle) async {
    final res = await http.delete(_u('/api/v1/users/$handle/follow'), headers: _headers());
    _assertOk(res);
  }

  Future<void> mute(String handle) async {
    final res = await http.post(_u('/api/v1/users/$handle/mute'), headers: _headers());
    _assertOk(res);
  }

  Future<void> unmute(String handle) async {
    final res = await http.delete(_u('/api/v1/users/$handle/mute'), headers: _headers());
    _assertOk(res);
  }

  Future<void> block(String handle) async {
    final res = await http.post(_u('/api/v1/users/$handle/block'), headers: _headers());
    _assertOk(res);
  }

  Future<void> unblock(String handle) async {
    final res = await http.delete(_u('/api/v1/users/$handle/block'), headers: _headers());
    _assertOk(res);
  }

  // ---- Moderation (admin/mod only) ----
  Future<void> flagPost(int id, String reason) async {
    final res = await http.post(_u('/api/v1/posts/$id/flag'),
        headers: _headers(), body: jsonEncode({'reason': reason}));
    _assertOk(res);
  }

  Future<List<dynamic>> getPostLikes(int postId, {int offset = 0}) async {
    final res = await http.get(_u('/api/v1/posts/$postId/likes?offset=$offset'),
        headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['users'] as List);
  }

  Future<void> deleteComment(int id) async {
    final res = await http.delete(_u('/api/v1/comments/$id'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<void> adminDeletePost(int id) async {
    final res = await http.delete(_u('/api/v1/admin/posts/$id'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<void> deletePost(int id) async {
    final res = await http.delete(_u('/api/v1/posts/$id'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<List<Map<String, dynamic>>> adminUsers() async {
    final res = await http.get(_u('/api/v1/admin/users'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['users'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> adminBanUser(String handle, String reason) async {
    final res = await http.post(_u('/api/v1/admin/users/$handle/ban'),
        headers: _headers(), body: jsonEncode({'reason': reason}));
    _assertOk(res);
  }

  Future<void> adminUnbanUser(String handle) async {
    final res = await http.delete(_u('/api/v1/admin/users/$handle/ban'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<void> adminToggleVerify(String handle) async {
    final res = await http.post(_u('/api/v1/admin/users/$handle/verify'), headers: _headers(json: false));
    _assertOk(res);
  }

  Future<void> adminDeleteUser(String handle) async {
    final res = await http.delete(_u('/api/v1/admin/users/$handle'), headers: _headers(json: false));
    _assertOk(res);
  }

  // ---- Admin: System Stats ----
  Future<Map<String, dynamic>> adminSystemStats() async {
    final res = await http.get(_u('/api/v1/admin/system'), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---- Admin: Sessions ----
  Future<List<Map<String, dynamic>>> adminSessions() async {
    final res = await http.get(_u('/api/v1/admin/sessions'), headers: _headers(json: false));
    _assertOk(res);
    return ((jsonDecode(res.body) as Map)['sessions'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> adminKickSession(int id) async {
    final res = await http.delete(_u('/api/v1/admin/sessions/$id'), headers: _headers(json: false));
    _assertOk(res);
  }

  // ---- Admin: Uploads ----
  Future<Map<String, dynamic>> adminUploads({String? query}) async {
    final qp = <String, String>{};
    if (query != null && query.isNotEmpty) qp['q'] = query;
    final res = await http.get(_u('/api/v1/admin/uploads', qp), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Full admin dashboard payload - single request, cheap on the server.
  /// Returns the raw map so the dashboard screen can pluck panels it needs.
  Future<Map<String, dynamic>> adminDashboard() async {
    final res = await http.get(_u('/api/v1/admin/dashboard'), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> adminArchivedPosts() async {
    final res = await http.get(_u('/api/v1/admin/archived-posts'), headers: _headers());
    _assertOk(res);
    return (jsonDecode(res.body)['posts'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> adminRestoreArchivedPost(int id) async {
    final res = await http.post(_u('/api/v1/admin/archived-posts/$id/restore'), headers: _headers());
    _assertOk(res);
  }

  // ---- Notifications: mark-read ----
  Future<void> markNotificationsRead() async {
    final res = await http.post(_u('/api/v1/notifications/read'), headers: _headers());
    _assertOk(res);
  }

  // ---- Voice comments ----
  Future<int> voiceComment(int postId, String mediaUrl, String duration) async {
    final res = await http.post(_u('/api/v1/posts/$postId/voice_comment'),
        headers: _headers(),
        body: jsonEncode({
          'kind': 'voice',
          'media_url': mediaUrl,
          'duration': duration,
        }));
    _assertOk(res);
    return (jsonDecode(res.body)['id'] as num).toInt();
  }

  // ---- DM reactions ----
  Future<void> likeMessage(int id) async {
    final res = await http.post(_u('/api/v1/messages/$id/like'), headers: _headers());
    _assertOk(res);
  }

  Future<void> unlikeMessage(int id) async {
    final res = await http.delete(_u('/api/v1/messages/$id/like'), headers: _headers());
    _assertOk(res);
  }

  // ---- Epsilon Dev Program ----
  Future<Map<String, dynamic>> devProgramStatus() async {
    final res = await http.get(_u('/api/v1/dev/status'), headers: _headers(json: false));
    _assertOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> joinDevProgram({required String github, required List<String> interests}) async {
    final res = await http.post(_u('/api/v1/dev/signup'),
        headers: _headers(),
        body: jsonEncode({'github': github, 'interests': interests}));
    _assertOk(res);
  }

  Future<void> leaveDevProgram() async {
    final res = await http.delete(_u('/api/v1/dev/signup'), headers: _headers(json: false));
    _assertOk(res);
  }
  // ---- Global theme (Customizer Publish) ----
  Future<Map<String, String>> getGlobalTheme() async {
    final res = await http.get(_u('/api/v1/app/theme'), headers: _headers(json: false));
    _assertOk(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final theme = (j['theme'] as Map?)?.cast<String, String>() ?? {};
    return theme;
  }

  /// Publish global theme (mod+ only).
  Future<void> publishGlobalTheme(Map<String, String> theme, {String name = ''}) async {
    final res = await http.post(_u('/api/v1/admin/theme/publish'),
        headers: _headers(), body: jsonEncode({'theme': theme, 'name': name}));
    _assertOk(res);
  }

  /// Returns the WS URI string or null if not configured.
  Uri? wsUri() {
    try {
      final httpUrl = Uri.parse(_baseUrl);
      final wsScheme = httpUrl.scheme == 'https' ? 'wss' : 'ws';
      final qp = _token != null ? '?token=$_token' : '';
      return Uri.parse('$wsScheme://${httpUrl.host}:${httpUrl.port}/api/v1/ws$qp');
    } catch (_) {
      return null;
    }
  }

  /// Opens a WS connection. Returns a stream of events.
  /// Caller is responsible for closing the returned channel.
  WebSocketChannel? openWebSocket() {
    try {
      final uri = wsUri();
      if (uri == null) return null;
      return WebSocketChannel.connect(uri);
    } catch (e) {
      if (kDebugMode) debugPrint('[ws] connect failed: $e');
      return null;
    }
  }

  // ---- helpers ----
  void _assertOk(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      String msg = 'HTTP ${r.statusCode}';
      try {
        final j = jsonDecode(r.body);
        if (j is Map && j['error'] != null) msg = j['error'].toString();
      } catch (_) {}
      if (r.statusCode == 401 && _token != null) {
        logout();
      }
      throw ApiException(msg, r.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

/// Close helper so callers don't have to import ws_status.
void closeWs(WebSocketChannel? ch) {
  try {
    ch?.sink.close(ws_status.normalClosure);
  } catch (_) {}
}
