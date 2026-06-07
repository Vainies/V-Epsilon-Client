import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api.dart';
import 'notif_bus.dart';
import 'push_service.dart';
import 'theme.dart';
import 'models.dart';
import 'updater.dart';
import 'crash_reporter.dart';
import 'extension_runtime.dart';
import 'feature_config.dart';
import 'screens/home.dart';
import 'screens/reposts.dart';
import 'screens/comms.dart';
import 'screens/versions.dart';
import 'screens/activity.dart';
import 'screens/admin_dashboard.dart';
import 'screens/auth.dart';
import 'screens/extensions.dart';
import 'screens/profile.dart';
import 'screens/qr_screen.dart';
import 'screens/settings.dart';
import 'screens/composer.dart';
import 'screens/search.dart';
import 'widgets/common.dart';
import 'widgets/update_dialog.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: VE.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final api = Api();
  await api.load();
  await ExtensionRuntime.I.init();         // Load persisted extensions
  await VETheme.I.init();                  // Load theme mode from prefs
  // Stale profile themes should never persist between sessions
  await ExtensionRuntime.I.uninstall('_profile_theme');
  VETheme.I.loadOverrides();               // Apply any persisted global/customizer themes
  await FeatureConfig.I.init();
  Updater(api.baseUrl).cleanup();

  // Install crash reporter BEFORE runApp so initial-frame errors are caught.
  final reporter = CrashReporter(api.baseUrl);
  await reporter.init();

  // Fire up local notifications. Permission prompt happens on first use.
  unawaited(PushService.I.init());
  PushService.I.onTap = (id, category) {
    Future.microtask(() {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      switch (category) {
        case 'update':
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const VersionsScreen()));
          break;
        default:
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ActivityScreen()));
          break;
      }
    });
  };

  // Probe network in background (don't block startup).
  // Picks the fastest reachable server URL among public / LAN candidates.
  unawaited(api.probeAndPickFastest());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: api),
        ChangeNotifierProvider.value(value: VETheme.I),
        ChangeNotifierProvider.value(value: FeatureConfig.I),
      ],
      child: const EpsilonApp(),
    ),
  );
}

class EpsilonApp extends StatelessWidget {
  const EpsilonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VETheme>(
      builder: (context, theme, _) => MaterialApp(
        title: 'Epsilon',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: theme.themeData,
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
   const _RootGate();
  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = context.read<Api>();
      if (!api.isAuthed) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) =>  const AuthScreen(firstRun: true)),
        );
      }
      _checkForUpdate(api);
      _fetchGlobalTheme(api);
    });
  }

  Future<void> _fetchGlobalTheme(Api api) async {
    if (!api.isAuthed) return;
    try {
      final theme = await api.getGlobalTheme();
      if (theme.isNotEmpty) {
        await ExtensionRuntime.I.install('global_theme', {'type': 'theme', 'theme': theme});
        VETheme.I.loadOverrides();
        VETheme.I.refresh();
      }
    } catch (_) {}
  }

  Future<void> _checkForUpdate(Api api) async {
    if (!api.allowUpdates) return;
    await Future<void>.delayed( const Duration(seconds: 2));
    if (!mounted) return;
    final updater = Updater(api.baseUrl);
    final info = await updater.check(api.betaMode);
    if (!mounted || info == null) return;
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version;
    // If update is required (current version below required_version), block the app.
    final isRequired = info.requiredVersion.isNotEmpty && compareVersions(current, info.requiredVersion) < 0;
    final isEmergency = info.isEmergency;
    if (isRequired || isEmergency) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: UpdateDialog(updater: updater, info: info, isRequired: true, isEmergency: isEmergency),
        ),
      );
    } else {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateDialog(updater: updater, info: info),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>  const AppShell();
}

class AppShell extends StatefulWidget {
   const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _appVersion;
  bool _hasUnreadNotifs = false;
  Timer? _notifCheckTimer;
  AppUser? _meCache;
  /// Reentry guard: rapid bell taps were pushing multiple ActivityScreen
  /// routes which looked like a crash (stack builds up, back takes forever).
  bool _navigatingToActivity = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _startNotifCheck();
    _loadMe();
    // Live notification bus. Auto-bumps _hasUnreadNotifs via NotifBus.unreadBump.
    NotifBus.I.unreadBump.addListener(_onNotifBump);
    // Start WS after first frame so context has Api. Also re-sync me cache
    // whenever auth state changes (login/logout/profile edit).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = context.read<Api>();
      if (api.isAuthed) NotifBus.I.start(api);
      api.startHealthPings();
      api.addListener(_onApiChanged);
    });
  }

  void _onApiChanged() {
    final api = context.read<Api>();
    if (api.isAuthed) {
      NotifBus.I.start(api);
      _loadMe();
      _fetchGlobalTheme();
    } else {
      NotifBus.I.stop();
      if (_meCache != null) setState(() => _meCache = null);
    }
  }

  void _onNotifBump() {
    if (mounted && !_hasUnreadNotifs) setState(() => _hasUnreadNotifs = true);
  }

  Future<void> _fetchGlobalTheme() async {
    final api = context.read<Api>();
    if (!api.isAuthed) return;
    try {
      final theme = await api.getGlobalTheme();
      if (theme.isNotEmpty) {
        await ExtensionRuntime.I.install('global_theme', {'type': 'theme', 'theme': theme});
        VETheme.I.loadOverrides();
        VETheme.I.refresh();
      }
    } catch (_) {}
  }

  Future<void> _loadMe() async {
    final api = context.read<Api>();
    if (!api.isAuthed) return;
    try {
      final u = await api.me();
      if (mounted) setState(() => _meCache = u);
    } catch (_) {}
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  void _startNotifCheck() {
    // Poll every 30s for unread notifications. WebSocket will push them later.
    _checkUnread();
    _notifCheckTimer = Timer.periodic( const Duration(seconds: 30), (_) => _checkUnread());
  }

  Future<void> _checkUnread() async {
    final api = context.read<Api>();
    if (!api.isAuthed) {
      if (_hasUnreadNotifs) setState(() => _hasUnreadNotifs = false);
      return;
    }
    try {
      final notifs = await api.notifications();
      final unread = notifs.any((n) => !n.read);
      if (mounted && unread != _hasUnreadNotifs) {
        setState(() => _hasUnreadNotifs = unread);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notifCheckTimer?.cancel();
    NotifBus.I.unreadBump.removeListener(_onNotifBump);
    try {
      context.read<Api>().removeListener(_onApiChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _openActivity(Api api) async {
    if (_navigatingToActivity) return;
    _navigatingToActivity = true;
    // Optimistic clear.
    setState(() => _hasUnreadNotifs = false);
    try {
      await api.markNotificationsRead();
    } catch (_) {}
    if (!mounted) {
      _navigatingToActivity = false;
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) =>  const ActivityScreen()));
    if (mounted) _navigatingToActivity = false;
  }

  int get _visibleTabCount {
    final fc = FeatureConfig.I;
    int count = 0;
    if (fc.showHome) count++;
    if (fc.showReposts) count++;
    if (fc.showComms) count++;
    if (fc.showProfile) count++;
    return count;
  }

  int _visibleIndex(int logical) {
    final fc = FeatureConfig.I;
    int vi = 0;
    if (logical == 0 && fc.showHome) return 0;
    if (fc.showHome) vi++;
    if (logical == 1 && fc.showReposts) return vi;
    if (fc.showReposts) vi++;
    if (logical == 3 && fc.showComms) return vi;
    if (fc.showComms) vi++;
    if (logical == 4 && fc.showProfile) return vi;
    return 0;
  }

  void _jump(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<Api>();
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: VE.bg,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      drawer: _drawer(api),
      appBar: _topBar(api),
      body: IndexedStack(
        index: _tab,
        children: [
           const HomeScreen(),
           const RepostsScreen(),
           const SizedBox.shrink(),
           const CommsScreen(),
          _profileOrLogin(api),
        ],
      ),
      bottomNavigationBar: _bottomNav(),
      floatingActionButton: keyboardOpen || !FeatureConfig.I.showFab ? null : _fab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _profileOrLogin(Api api) {
    if (!api.isAuthed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.person_outline_rounded, size: 48, color: VE.textFaint),
             const SizedBox(height: 12),
            Text('Sign in to view your profile', style: Theme.of(context).textTheme.titleMedium),
             const SizedBox(height: 16),
            VEPrimaryButton(
              label: 'SIGN IN',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>  const AuthScreen())),
            ),
          ],
        ),
      );
    }
    return FutureBuilder<AppUser>(
      future: api.me(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return  const Center(child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2));
        }
        return ProfileScreen(user: snap.data!, showBack: false);
      },
    );
  }

  Widget _drawer(Api api) {
    return Drawer(
      backgroundColor: VE.bg,
      surfaceTintColor: VE.bg,
      shape:  const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topRight: Radius.circular(VE.r24), bottomRight: Radius.circular(VE.r24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:  const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient:  const LinearGradient(colors: [VE.blue, VE.cyan]),
                      borderRadius: BorderRadius.circular(VE.r12),
                    ),
                    child:  const Center(
                      child: Text('ε',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1)),
                    ),
                  ),
                   const SizedBox(width: 12),
                   const Text('Epsilon',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: VE.text)),
                ],
              ),
            ),
            if (api.isAuthed) ...[
              Padding(
                padding:  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    VEAvatar(
                      url: _meCache?.avatarUrl ?? '',
                      seed: _meCache?.name.isNotEmpty == true
                          ? _meCache!.name
                          : (api.handle),
                      size: 40,
                      radius: 14,
                    ),
                     const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_meCache?.name.isNotEmpty == true ? _meCache!.name : api.handle,
                              style:  const TextStyle(
                                  fontWeight: FontWeight.w800, color: VE.text, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                          Text('@${api.handle}',
                              style:  const TextStyle(
                                  color: VE.textMuted, fontSize: 12, fontFamily: VE.fontMono)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
               const SizedBox(height: 8),
            ],
             const Divider(height: 1),
            _drawerItem(Icons.home_rounded, 'Feed', () {
              Navigator.pop(context);
              _jump(0);
            }),
            _drawerItem(Icons.forum_rounded, 'Comms', () {
              Navigator.pop(context);
              _jump(3);
            }),
            _drawerItem(Icons.notifications_rounded, 'Activity', () {
              Navigator.pop(context);
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) =>  const ActivityScreen()));
            }),
            _drawerItem(Icons.extension_rounded, 'Extensions', () {
              Navigator.pop(context);
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ExtensionsScreen()));
            }),
            _drawerItem(Icons.archive_rounded, 'Archive', () {
              Navigator.pop(context);
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const VersionsScreen()));
            }),
            _drawerItem(Icons.person_rounded, 'My profile', () {
              Navigator.pop(context);
              _jump(4);
            }),
            if (api.isAuthed)
            _drawerItem(Icons.qr_code_scanner_rounded, 'Scan QR', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
            }),
            if (api.isAuthed)
              _drawerItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context);
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) =>  const SettingsScreen()));
              }),
            // Admin-only: server dashboard. Shown for the hard-coded 'vain'
            // handle — server still enforces the real admin check on the
            // underlying endpoint, so this is just UX affordance.
            if (api.isAuthed && api.handle == 'vain')
              _drawerItem(Icons.dashboard_rounded, 'Admin dashboard', () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>  const AdminDashboardScreen()));
              }, color: VE.orange),
             const Divider(height: 1),
            _drawerItem(Icons.system_update_rounded, 'Check for updates', () async {
              Navigator.pop(context);
              await _manualUpdateCheck();
            }),
            if (api.isAuthed)
              _drawerItem(Icons.logout_rounded, 'Sign out', () async {
                Navigator.pop(context);
                await api.logout();
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) =>  const AuthScreen(firstRun: true)),
                );
              }, color: VE.pink),
             const Spacer(),
            Padding(
              padding:  const EdgeInsets.all(20),
              child: Text('v${_appVersion ?? "…"}',
                  style:  const TextStyle(
                      fontFamily: VE.fontMono,
                      fontSize: 10,
                      color: VE.textMuted,
                      letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 22, color: color ?? VE.text),
      title: Text(label,
          style: TextStyle(color: color ?? VE.text, fontWeight: FontWeight.w700, fontSize: 14)),
      dense: true,
    );
  }

  Future<void> _manualUpdateCheck() async {
    final api = context.read<Api>();
    final updater = Updater(api.baseUrl);

    // Centered square dialog with a spinner while the check runs. Dismisses
    // itself once we know the result.
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => Dialog(
        backgroundColor: VE.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VE.r24),
          side: BorderSide(color: VE.border),
        ),
        child:  const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                    color: VE.blue, strokeWidth: 3),
              ),
              SizedBox(height: 20),
              Text('Checking for updates',
                  style: TextStyle(
                      color: VE.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              SizedBox(height: 4),
              Text("Talking to the Epsilon server…",
                  style: TextStyle(color: VE.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    final info = await updater.check(api.betaMode);
    if (!mounted) return;

    // Pop the loading dialog.
    Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;

    if (info == null) {
      // No update — show a similar square "up to date" dialog that dismisses
      // on tap/outside.
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (_) => Dialog(
          backgroundColor: VE.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VE.r24),
            side: BorderSide(color: VE.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: VE.emerald.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: VE.emerald.withValues(alpha: 0.35)),
                  ),
                  child:
                       const Icon(Icons.check_rounded, color: VE.emerald, size: 32),
                ),
                 const SizedBox(height: 20),
                 const Text('You are up to date',
                    style: TextStyle(
                        color: VE.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                 const SizedBox(height: 4),
                Text('Running v${_appVersion ?? "…"}',
                    style: const TextStyle(
                        color: VE.textMuted,
                        fontSize: 12,
                        fontFamily: VE.fontMono)),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK',
                      style: TextStyle(
                          color: VE.textDim,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    final isEmergency = info.isEmergency;
    final isRequired = info.requiredVersion.isNotEmpty;
    if (isRequired || isEmergency) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: UpdateDialog(updater: updater, info: info, isRequired: true, isEmergency: isEmergency),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => UpdateDialog(updater: updater, info: info),
      );
    }
  }

  PreferredSizeWidget _topBar(Api api) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: BoxDecoration(
          color: VE.bg,
          border: Border(bottom: BorderSide(color: VE.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                _iconChip(Icons.menu_rounded, onTap: () => _scaffoldKey.currentState?.openDrawer()),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E0E),
                      borderRadius: BorderRadius.circular(VE.r16),
                      border: Border.all(color: VE.border),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      style:  const TextStyle(fontSize: 14, color: VE.text, height: 1.2),
                      cursorColor: VE.blue,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding:  const EdgeInsets.symmetric(vertical: 12),
                        hintText: 'Search Epsilon',
                        hintStyle:  const TextStyle(color: VE.textMuted, fontSize: 14),
                        prefixIcon:  const Padding(
                          padding: EdgeInsets.only(left: 14, right: 10),
                          child: Icon(Icons.search_rounded, size: 18, color: VE.textMuted),
                        ),
                        prefixIconConstraints:  const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon:  const Icon(Icons.close_rounded,
                                    size: 16, color: VE.textMuted),
                                onPressed: () => setState(() => _searchCtrl.clear()),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: v.trim())),
                          );
                        }
                      },
                    ),
                  ),
                ),
                 const SizedBox(width: 10),
                _iconChip(Icons.notifications_rounded,
                    badge: api.isAuthed && _hasUnreadNotifs,
                    onTap: _navigatingToActivity ? null : () => _openActivity(api)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconChip(IconData icon, {bool badge = false, VoidCallback? onTap}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VE.r16),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:  const Color(0xFF0E0E0E),
              borderRadius: BorderRadius.circular(VE.r16),
              border: Border.all(color: VE.border),
            ),
            child: Icon(icon, size: 20, color: VE.textDim),
          ),
        ),
        if (badge)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: VE.emerald,
                shape: BoxShape.circle,
                border: Border.all(color: VE.bg, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bottomNav() {
    final fc = FeatureConfig.I;
    if (fc.navMode == NavMode.hidden) return const SizedBox.shrink();
    final showIcons = fc.navMode == NavMode.iconsLabels && fc.showIcons;
    final tabs = <Widget>[];
    if (fc.showHome) tabs.add(_navBtn(icon: Icons.home_rounded, label: 'HOME', index: 0, hideIcon: !showIcons));
    if (fc.showReposts) tabs.add(_navBtn(icon: Icons.repeat_rounded, label: 'REPOSTS', index: 1, hideIcon: !showIcons));
    tabs.add(const SizedBox(width: 60));
    if (fc.showComms) tabs.add(_navBtn(icon: Icons.forum_rounded, label: 'COMMS', index: 3, hideIcon: !showIcons));
    if (fc.showProfile) tabs.add(_navBtn(icon: Icons.person_rounded, label: 'PROFILE', index: 4, hideIcon: !showIcons));
    final isCompact = !showIcons;
    final h = isCompact ? 52.0 : 72.0;
    return Container(
      decoration:  const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: VE.borderStrong)),
      ),
      height: h,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: tabs,
        ),
      ),
    );
  }

  Widget _navBtn({required IconData icon, required String label, required int index, bool disabled = false, bool hideIcon = false}) {
    final active = _tab == index;
    final color = disabled ? VE.textFaint : (active ? VE.text : VE.textMuted);
    return InkWell(
      onTap: () => _jump(index),
      borderRadius: BorderRadius.circular(VE.r12),
      child: Padding(
        padding:  EdgeInsets.symmetric(horizontal: 14, vertical: hideIcon ? 14 : 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hideIcon) ...[
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
            ],
            Text(label,
                style: TextStyle(
                  fontFamily: VE.fontSans,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }

  Widget _fab() {
    return Material(
      color: VE.text,
      borderRadius: BorderRadius.circular(VE.r16),
      child: InkWell(
        borderRadius: BorderRadius.circular(VE.r16),
        onTap: _onCreate,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: VE.text,
            borderRadius: BorderRadius.circular(VE.r16),
            border: Border.all(color: VE.bg, width: 4),
          ),
          child:  const Icon(Icons.add_rounded, size: 28, color: Colors.black),
        ),
      ),
    );
  }

  void _onCreate() {
    final api = context.read<Api>();
    if (!api.isAuthed) {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>  const AuthScreen()));
      return;
    }
    if (!api.online) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No connection — can\'t post')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) =>  const ComposerScreen(), fullscreenDialog: true),
    );
  }
}
