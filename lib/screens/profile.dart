import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../extension_runtime.dart';
import '../feature_config.dart';
import 'qr_screen.dart';
import 'post_detail.dart';
import 'settings.dart';
import '../widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  /// When shown via bottom nav (user's own tab), there's no meaningful back stack
  /// so hide the back button.
  final bool showBack;
  const ProfileScreen({super.key, required this.user, this.showBack = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfileTab { posts, reposts }

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  Future<List<Post>>? _postsFuture;
  Future<List<Post>>? _repostsFuture;
  _ProfileTab _tab = _ProfileTab.posts;
  bool _following = false;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _following = widget.user.isFollowing;
    _reload();
    _applyProfileTheme();
  }

  @override
  void dispose() {
    ExtensionRuntime.I.uninstall('_profile_theme');
    VETheme.I.loadOverrides();
    VETheme.I.refresh();
    super.dispose();
  }

  void _applyProfileTheme() {
    final theme = widget.user.profileTheme;
    if (theme.isNotEmpty) {
      ExtensionRuntime.I.install('_profile_theme', {'type': 'theme', 'theme': theme}).then((_) {
        VETheme.I.loadOverrides();
        VETheme.I.refresh();
      });
    }
  }

  Future<void> _reload() async {
    final api = context.read<Api>();
    if (widget.user.handle.isEmpty) return;
    // Kick off user fetch for freshest viewer-relative flags.
    () async {
      try {
        final u = await api.getUser(widget.user.handle);
        if (mounted) {
          setState(() {
            _user = u;
            _following = u.isFollowing;
          });
          _reapplyProfileTheme(u);
        }
      } catch (_) {}
    }();
    setState(() {
      _postsFuture = api.userPosts(widget.user.handle);
      _repostsFuture = api.userReposts(widget.user.handle);
    });
  }

  void _reapplyProfileTheme(AppUser u) {
    final theme = u.profileTheme;
    ExtensionRuntime.I.uninstall('_profile_theme');
    if (theme.isNotEmpty) {
      ExtensionRuntime.I.install('_profile_theme', {'type': 'theme', 'theme': theme}).then((_) {
        VETheme.I.loadOverrides();
        VETheme.I.refresh();
      });
    }
  }

  Future<void> _share(AppUser u) async {
    final api = context.read<Api>();
    final url = api.webUrlFor(u.handle);
    final text = 'Check out ${u.name.isEmpty ? "@${u.handle}" : u.name} on Epsilon\n$url';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    try {
      await Share.share(text, subject: 'Epsilon profile');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile link copied to clipboard'),
      ));
    }
  }

  Future<void> _toggleFollow() async {
    final api = context.read<Api>();
    if (!api.isAuthed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in to follow')));
      return;
    }
    final u = _user!;
    setState(() {
      _followBusy = true;
      _following = !_following;
      _user = u.copyWith(
        isFollowing: _following,
        followers: u.followers + (_following ? 1 : -1),
      );
    });
    try {
      if (_following) {
        await api.follow(u.handle);
      } else {
        await api.unfollow(u.handle);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _following = !_following;
        _user = u; // revert
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openMoreMenu() async {
    final api = context.read<Api>();
    final u = _user!;
    final isOwn = api.handle == u.handle;
    final isAdmin = api.handle == 'vain'; // admin hint (server enforces)

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VE.bgElevated,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(VE.r24)),
          side: BorderSide(color: VE.border)),
      builder: (_) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: VE.bgElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(VE.r24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: VE.border, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 8),
              _item(Icons.ios_share_rounded, 'Share profile', 'share'),
              _item(Icons.content_copy_rounded, 'Copy link', 'copy'),
              if (isOwn) ...[
                _item(Icons.edit_rounded, 'Edit profile', 'edit'),
                _item(Icons.qr_code_scanner_rounded, 'Share QR', 'qr'),
              ],
              if (!isOwn) ...[
                Divider(height: 1, color: VE.border),
                _item(u.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    u.isMuted ? 'Unmute user' : 'Mute user', 'mute'),
                _item(u.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    u.isBlocked ? 'Unblock user' : 'Block user', 'block',
                    color: VE.pink),
                _item(Icons.flag_outlined, 'Report user', 'report'),
              ],
            if (isAdmin && !isOwn) ...[
              Divider(height: 1, color: VE.border),
              _item(
                  u.badges.contains('verified')
                      ? Icons.remove_circle_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  u.badges.contains('verified') ? 'Admin: unverify' : 'Admin: verify',
                  'admin_verify',
                  color: VE.blue),
              _item(u.isBanned ? Icons.lock_open_rounded : Icons.gavel_rounded,
                  u.isBanned ? 'Admin: unban' : 'Admin: ban (wipe posts)',
                  u.isBanned ? 'admin_unban' : 'admin_ban',
                  color: VE.orange),
              _item(Icons.delete_forever_rounded,
                  'Admin: DELETE ACCOUNT (irreversible)', 'admin_delete_user',
                  color: VE.pink),
            ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'edit':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          break;
        case 'share':
          await _share(u);
          break;
        case 'qr':
          Navigator.push(context, MaterialPageRoute(builder: (_) => QrShareScreen(handle: u.handle)));
          break;
        case 'copy':
          await Clipboard.setData(ClipboardData(text: api.webUrlFor(u.handle)));
          messenger.showSnackBar(const SnackBar(
              content: Text('Link copied'), backgroundColor: VE.emerald));
          break;
        case 'mute':
          if (u.isMuted) {
            await api.unmute(u.handle);
          } else {
            await api.mute(u.handle);
          }
          _reload();
          break;
        case 'block':
          if (u.isBlocked) {
            await api.unblock(u.handle);
          } else {
            await api.block(u.handle);
          }
          _reload();
          break;
        case 'report':
          // Reporting a user is modeled as flagging one of their posts later.
          messenger.showSnackBar(SnackBar(
              content: const Text('User reports coming soon - report specific posts for now.'),
              backgroundColor: VE.bgElevated));
          break;
        case 'admin_ban':
          final reason = await _promptText('Ban @${u.handle}', 'Reason?');
          if (reason == null) return;
          await api.adminBanUser(u.handle, reason);
          messenger.showSnackBar(SnackBar(
              content: Text('@${u.handle} banned'),
              backgroundColor: VE.orange));
          _reload();
          break;
        case 'admin_unban':
          await api.adminUnbanUser(u.handle);
          messenger.showSnackBar(SnackBar(
              content: Text('@${u.handle} unbanned'),
              backgroundColor: VE.emerald));
          _reload();
          break;
        case 'admin_verify':
          await api.adminToggleVerify(u.handle);
          messenger.showSnackBar(SnackBar(
              content: Text('Verification toggled for @${u.handle}'),
              backgroundColor: VE.blue));
          _reload();
          break;
        case 'admin_delete_user':
          final reason = await _promptText(
              'DELETE @${u.handle}?',
              'This is IRREVERSIBLE. All posts, comments, likes and follows will be removed. Type the handle to confirm:');
          if (reason == null) return;
          if (reason.trim() != u.handle) {
            messenger.showSnackBar(const SnackBar(
                content: Text('Confirmation mismatch - account NOT deleted'),
                backgroundColor: VE.pink));
            return;
          }
          await api.adminDeleteUser(u.handle);
          messenger.showSnackBar(SnackBar(
              content: Text('@${u.handle} deleted'),
              backgroundColor: VE.orange));
          if (!mounted) return;
          // Leave the now-dead profile screen so we don't show a 404 shell.
          Navigator.of(context).maybePop();
          break;
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: VE.pink));
    }
  }

  Widget _item(IconData icon, String label, String key, {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? VE.text, size: 20),
        title: Text(label,
            style: TextStyle(
                color: color ?? VE.text,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        onTap: () => Navigator.of(context).pop(key),
      );

  Future<String?> _promptText(String title, String hint) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VE.bgCard,
        title: Text(title, style: const TextStyle(color: VE.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          style: const TextStyle(color: VE.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    return (r != null && r.isNotEmpty) ? r : null;
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<Api>();
    final u = _user ?? widget.user;
    final isOwn = api.isAuthed && api.handle == u.handle;

    return Scaffold(
      backgroundColor: VE.bg,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        color: VE.text,
        backgroundColor: VE.bgCard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _bannerAndHeader(u)),
            SliverToBoxAdapter(child: _profileBody(u)),
            if (u.locked)
              const SliverToBoxAdapter(child: _LockedNotice())
            else
              _tabContent(),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _bannerAndHeader(AppUser u) {
    const bannerH = 200.0;
    const avatarSize = 88.0;
    const avatarOverlap = 44.0;
    final bannerResolved = u.bannerUrl.isNotEmpty ? context.read<Api>().resolveUrl(u.bannerUrl) : '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: bannerH,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [VE.blue, VE.purple, VE.pink],
                  ),
                ),
              ),
              if (bannerResolved.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: bannerResolved,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        // Dark overlay at bottom of banner for text readability
        if (FeatureConfig.I.showBannerOverlay)
          Positioned(
            left: 0, right: 0,
            bottom: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, VE.bg.withValues(alpha: 0.85)],
                ),
              ),
            ),
          ),
        // Back button (floating)
        if (widget.showBack)
          Positioned(
            left: 12, top: 8,
            child: Container(
              decoration: BoxDecoration(
                color: VE.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: VE.text, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
        // 3-dots menu (floating island)
        Positioned(
          right: 12, top: 8,
          child: Container(
            decoration: BoxDecoration(
              color: VE.bg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: VE.text, size: 20),
              onPressed: _openMoreMenu,
            ),
          ),
        ),
        // Avatar (overlaps banner bottom)
        Positioned(
          left: 20,
          top: bannerH - (avatarSize - avatarOverlap),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: VE.bg,
              borderRadius: BorderRadius.circular(VE.r24),
            ),
            child: VEAvatar(
              url: u.avatarUrl,
              seed: u.name.isEmpty ? u.handle : u.name,
              size: avatarSize,
              radius: VE.r16,
            ),
          ),
        ),
      ],
    );
  }

  // Full-width background section - spans name, handle, status, bio,
  // stats, and action row.
  Widget _profileBody(AppUser u) {
    final hasBg = u.profileBgUrl.isNotEmpty;
    final bgPrefs = ExtensionRuntime.I.data('bg_prefs');
    final bgOpacity = (bgPrefs?['opacity'] as num?)?.toDouble() ?? 0.5;
    final bgBackHex = bgPrefs?['backColor'] as String?;
    final bgBackColor = bgBackHex != null && bgBackHex.startsWith('#')
        ? Color(int.parse('FF${bgBackHex.substring(1)}', radix: 16))
        : const Color(0xFF000000);
    final api = context.watch<Api>();
    final isOwn = api.isAuthed && api.handle == u.handle;

    final bgUrl = hasBg ? api.resolveUrl(u.profileBgUrl) : '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: hasBg ? bgBackColor.withValues(alpha: bgOpacity) : VE.bgCard,
        image: bgUrl.isNotEmpty ? DecorationImage(
          image: CachedNetworkImageProvider(bgUrl),
          fit: BoxFit.cover,
          opacity: 1.0 - bgOpacity,
        ) : null,
        border: Border(top: BorderSide(color: VE.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + handle + status (originally _headerInfo)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(u.name.isEmpty ? '@${u.handle}' : u.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: VE.text,
                            height: 1.1)),
                    ...u.badges.take(3).map((b) => VEBadge(type: b)),
                    if (u.isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VE.pink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('BANNED',
                            style: TextStyle(fontFamily: VE.fontMono, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1, color: VE.pink)),
                      ),
                    if (u.privacyProfile)
                      const Icon(Icons.lock_rounded, size: 12, color: VE.textMuted),
                  ],
                ),
                const SizedBox(height: 2),
                Text('@${u.handle}',
                    style: const TextStyle(color: VE.textDim, fontSize: 12, fontFamily: VE.fontMono)),
                if (u.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(u.status,
                        style: const TextStyle(color: VE.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Bio
          if (u.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(u.bio,
                  style: const TextStyle(color: VE.text, fontSize: 13, height: 1.5)),
            ),
          // Followers / following
          if (!u.privacyFollowers)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _stat(compactNum(u.followers), 'followers'),
                  const SizedBox(width: 24),
                  _stat(compactNum(u.following), 'following'),
                ],
              ),
            ),
          // Action row (follow button for non-own)
          if (!isOwn) _actionRow(u, isOwn),
          const SizedBox(height: 20),
          // Tabs inside the background, with fade to transparent bottom
          if (!u.locked) _tabs(),
          // Bottom gradient fade from background color to transparent
          SizedBox(
            height: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    hasBg ? bgBackColor.withValues(alpha: bgOpacity) : VE.bgCard,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(AppUser u, bool isOwn) {
    if (isOwn) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _following
              ? OutlinedButton.icon(
                  onPressed: _followBusy ? null : _toggleFollow,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Following'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VE.text,
                    side: BorderSide(color: VE.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _followBusy ? null : _toggleFollow,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text(u.isFollowedBy ? 'Follow back' : 'Follow'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VE.text,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: VE.text),
            onPressed: () => _share(u),
            style: IconButton.styleFrom(
              backgroundColor: VE.bgCard,
              side: BorderSide(color: VE.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: VE.text, fontSize: 17)),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontFamily: VE.fontMono,
                  fontSize: 10,
                  color: VE.textMuted,
                  letterSpacing: 1.5)),
        ],
      );

  Widget _tabs() {
    final u = _user ?? widget.user;
    final showReposts = !u.hideReposts;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: VE.bgCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: VE.border),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(child: _tabBtn('Posts', _ProfileTab.posts)),
            if (showReposts)
              Expanded(child: _tabBtn('Reposts', _ProfileTab.reposts)),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, _ProfileTab t) {
    final active = _tab == t;
    return InkWell(
      onTap: () => setState(() => _tab = t),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? VE.text : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: active ? Colors.black : VE.textDim,
              fontWeight: FontWeight.w800,
              fontSize: 13),
        ),
      ),
    );
  }

  Widget _tabContent() {
    final future = _tab == _ProfileTab.posts ? _postsFuture : _repostsFuture;
    return FutureBuilder<List<Post>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(
                      color: VE.textDim, strokeWidth: 2)),
            ),
          );
        }
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                    _tab == _ProfileTab.posts
                        ? 'No posts yet'
                        : 'No reposts yet',
                    style: const TextStyle(
                        color: VE.textMuted, fontSize: 14)),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (_, i) => PostCard(
              post: posts[i],
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: posts[i]))),
              onProfileTap: (u) {
                if (u.handle != _user?.handle) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: u)));
                }
              },
              onRemoved: () => _reload(),
            ),
          ),
        );
      },
    );
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VE.bgCard,
          borderRadius: BorderRadius.circular(VE.r16),
          border: Border.all(color: VE.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 36, color: VE.textMuted),
            SizedBox(height: 12),
            Text('This profile is private',
                style: TextStyle(
                    color: VE.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
            SizedBox(height: 6),
            Text(
              'Follow this user to see their posts, likes and reposts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VE.textDim, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
