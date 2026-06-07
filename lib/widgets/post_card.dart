import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';
import 'image_viewer.dart';
import 'voice.dart';
import 'youtube_player.dart';
import '../screens/profile.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onTap;
  final ValueChanged<AppUser>? onProfileTap;
  final bool expanded;
  /// Called when a moderation action modifies the post (e.g. admin delete),
  /// so parent list can remove it.
  final VoidCallback? onRemoved;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onProfileTap,
    this.expanded = false,
    this.onRemoved,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late int _likeCount;
  late bool _reposted;
  late int _repostCount;
  /// When the post has a spoiler warning, content stays hidden until the
  /// viewer taps "reveal". Applies only in feed; expanded detail view skips
  /// the gate since the user actively navigated into the thread.
  bool _spoilerRevealed = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
    _likeCount = widget.post.likes;
    _reposted = widget.post.reposted;
    _repostCount = widget.post.reposts;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent hands us a freshly loaded Post, re-hydrate.
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likes != widget.post.likes ||
        oldWidget.post.reposts != widget.post.reposts ||
        oldWidget.post.liked != widget.post.liked ||
        oldWidget.post.reposted != widget.post.reposted) {
      _liked = widget.post.liked;
      _likeCount = widget.post.likes;
      _reposted = widget.post.reposted;
      _repostCount = widget.post.reposts;
    }
  }

  void _toggleLike() async {
    final api = context.read<Api>();
    if (!api.isAuthed) {
      _requireAuth();
      return;
    }
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      // Persist on the Post itself so other screens that see the same Post
      // reference (e.g. the detail screen opened right after) reflect state.
      widget.post.liked = _liked;
      widget.post.likes = _likeCount;
    });
    try {
      if (_liked) {
        await api.likePost(widget.post.id);
      } else {
        await api.unlikePost(widget.post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
        widget.post.liked = _liked;
        widget.post.likes = _likeCount;
      });
    }
  }

  void _showLikers() async {
    if (!mounted) return;
    final api = context.read<Api>();
    try {
      final users = await api.getPostLikes(widget.post.id);
      if (!mounted || users.isEmpty) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: VE.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Container(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 32, height: 4, decoration: BoxDecoration(color: VE.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Liked by', style: TextStyle(color: VE.text, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: VE.border, indent: 56),
                  itemBuilder: (_, i) {
                    final u = users[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: VEAvatar(url: u['avatar_url'] as String? ?? '', size: 36),
                      title: Text(u['name'] as String? ?? '', style: const TextStyle(color: VE.text, fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text('@${u['handle']}', style: const TextStyle(color: VE.textDim, fontSize: 12)),
                      onTap: () async {
                        Navigator.pop(context);
                        final api = context.read<Api>();
                        try {
                          final user = await api.getUser(u['handle'] as String);
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: user)));
                        } catch (_) {}
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  void _toggleRepost() async {
    final api = context.read<Api>();
    if (!api.isAuthed) {
      _requireAuth();
      return;
    }
    setState(() {
      _reposted = !_reposted;
      _repostCount += _reposted ? 1 : -1;
      widget.post.reposted = _reposted;
      widget.post.reposts = _repostCount;
    });
    try {
      if (_reposted) {
        await api.repost(widget.post.id);
      } else {
        await api.unrepost(widget.post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reposted = !_reposted;
        _repostCount += _reposted ? 1 : -1;
        widget.post.reposted = _reposted;
        widget.post.reposts = _repostCount;
      });
    }
  }

  void _requireAuth() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Sign in to interact with posts'),
      backgroundColor: VE.bgElevated,
    ));
  }

  Future<void> _openMenu() async {
    final api = context.read<Api>();
    final isOwn = api.handle == widget.post.author.handle;
    // Show admin/mod actions if the stored handle equals 'vain' (owner seed).
    // Server enforces the real check - this is just UX affordance.
    final adminHint = api.handle == 'vain';

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VE.bgElevated,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(VE.r24)),
        side: BorderSide(color: VE.border),
      ),
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
              if (!isOwn) ...[
                _menuItem(Icons.flag_outlined, 'Report post', 'report'),
                _menuItem(
                    widget.post.author.isMuted
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    widget.post.author.isMuted ? 'Unmute user' : 'Mute user',
                    'mute'),
                _menuItem(
                    widget.post.author.isBlocked
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                    widget.post.author.isBlocked ? 'Unblock user' : 'Block user',
                    'block',
                    color: VE.pink),
              ],
              if (isOwn)
                _menuItem(Icons.delete_outline_rounded, 'Delete my post',
                    'delete_own',
                    color: VE.pink),
              if (adminHint && !isOwn) ...[
                Divider(height: 1, color: VE.border),
                _menuItem(Icons.shield_rounded, 'Admin: delete post',
                    'admin_delete',
                    color: VE.orange),
                _menuItem(Icons.gavel_rounded, 'Admin: ban user', 'admin_ban',
                    color: VE.orange),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _performMenuAction(action, api);
  }

  Widget _menuItem(IconData icon, String label, String key, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? VE.text, size: 20),
      title: Text(label,
          style: TextStyle(
              color: color ?? VE.text, fontWeight: FontWeight.w700, fontSize: 14)),
      onTap: () => Navigator.of(context).pop(key),
    );
  }

  Future<void> _performMenuAction(String action, Api api) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'report':
          final reason = await _promptReason('Report post', 'Why are you reporting this?');
          if (reason == null) return;
          await api.flagPost(widget.post.id, reason);
          messenger.showSnackBar(const SnackBar(
              content: Text('Reported - a moderator will review'),
              backgroundColor: VE.emerald));
          break;
        case 'mute':
          if (widget.post.author.isMuted) {
            await api.unmute(widget.post.author.handle);
            messenger.showSnackBar(const SnackBar(
                content: Text('User unmuted'), backgroundColor: VE.emerald));
          } else {
            await api.mute(widget.post.author.handle);
            messenger.showSnackBar(const SnackBar(
                content: Text('User muted - you won\'t see their posts'),
                backgroundColor: VE.emerald));
          }
          break;
        case 'block':
          final confirm = widget.post.author.isBlocked
              ? true
              : await veConfirm(context,
                  title: 'Block @${widget.post.author.handle}?',
                  body:
                      "They won't be able to follow you or see your posts.",
                  icon: Icons.block_rounded,
                  confirmLabel: 'Block',
                  confirmColor: VE.pink);
          if (!confirm) return;
          if (widget.post.author.isBlocked) {
            await api.unblock(widget.post.author.handle);
          } else {
            await api.block(widget.post.author.handle);
          }
          messenger.showSnackBar(const SnackBar(
              content: Text('Done'), backgroundColor: VE.emerald));
          break;
        case 'delete_own':
          final ok = await veConfirm(context,
              title: 'Delete this post?',
              body: 'This cannot be undone.',
              icon: Icons.delete_outline_rounded,
              confirmLabel: 'Delete',
              confirmColor: VE.pink);
          if (!ok) return;
          await api.deletePost(widget.post.id);
          widget.onRemoved?.call();
          break;
        case 'admin_delete':
          final ok = await veConfirm(context,
              title: 'Delete post?',
              body: 'Admin action - cannot be undone.',
              icon: Icons.shield_rounded,
              iconColor: VE.orange,
              confirmLabel: 'Delete',
              confirmColor: VE.orange);
          if (!ok) return;
          await api.adminDeletePost(widget.post.id);
          widget.onRemoved?.call();
          messenger.showSnackBar(const SnackBar(
              content: Text('Post deleted'), backgroundColor: VE.orange));
          break;
        case 'admin_ban':
          final reason = await _promptReason(
              'Ban @${widget.post.author.handle}', 'Reason for ban?');
          if (reason == null) return;
          await api.adminBanUser(widget.post.author.handle, reason);
          messenger.showSnackBar(SnackBar(
              content: Text('@${widget.post.author.handle} banned'),
              backgroundColor: VE.orange));
          break;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: VE.pink));
    }
  }

  Future<String?> _promptReason(String title, String hint) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VE.bgCard,
        title: Text(title, style: const TextStyle(color: VE.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
          style: const TextStyle(color: VE.text, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Submit')),
        ],
      ),
    );
    return (result != null && result.isNotEmpty) ? result : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isVideo = p.kind == 'video' || p.kind == 'coop';
    final isAd = p.kind == 'ad';

    return GestureDetector(
      onTap: widget.expanded ? null : widget.onTap,
      child: Container(
        margin: widget.expanded ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isAd ? VE.indigo.withValues(alpha: 0.05) : VE.bgCard,
          border: Border.all(
              color: isAd ? VE.indigo.withValues(alpha: 0.3) : VE.border),
          borderRadius: BorderRadius.circular(widget.expanded ? 0 : VE.r24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.repostedBy != null) _repostedByHeader(p.repostedBy!),
            if (p.kind == 'coop') _coopHeader(),
            if (isVideo) _videoThumb(context, p),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VEAvatar(
                    url: p.author.avatarUrl,
                    seed: p.author.name.isNotEmpty ? p.author.name : p.author.handle,
                    size: 44,
                    radius: 14,
                    onTap: widget.onProfileTap == null ? null : () => widget.onProfileTap!(p.author),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _body(context, p, isAd)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _repostedByHeader(AppUser u) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            const Icon(Icons.repeat_rounded, size: 14, color: VE.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '@${u.handle} reposted',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: VE.fontMono,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: VE.textMuted,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _coopHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF030303),
        child: const Row(
          children: [
            Icon(Icons.groups_rounded, size: 14, color: VE.textMuted),
            SizedBox(width: 6),
            Text(
              'CO-OP STREAM',
              style: TextStyle(
                fontFamily: VE.fontMono,
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 2,
                color: VE.textMuted,
              ),
            ),
          ],
        ),
      );

  Widget _videoThumb(BuildContext context, Post p) {
    final resolvedThumb = p.thumbUrl.isNotEmpty ? context.read<Api>().resolveUrl(p.thumbUrl) : '';
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder gradient as thumbnail - replaced by real media_url later
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [VE.blue, VE.purple],
              ),
            ),
          ),
            if (resolvedThumb.isNotEmpty)
              CachedNetworkImage(
                imageUrl: resolvedThumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
          ),
          if (p.duration.isNotEmpty)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.duration,
                  style: const TextStyle(
                    fontFamily: VE.fontMono,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Post p, bool isAd) {
    final gated = p.spoiler && !_spoilerRevealed && !widget.expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    p.author.name.isEmpty ? '@${p.author.handle}' : p.author.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: VE.text),
                  ),
                  ...p.author.badges.take(2).map((b) => VEBadge(type: b)),
                  if (isAd)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VE.indigo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: VE.indigo.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'PROMOTED',
                        style: TextStyle(
                          fontFamily: VE.fontMono,
                          fontWeight: FontWeight.w900,
                          fontSize: 8,
                          color: VE.indigo,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  if (p.spoiler)
                    _spoilerChip(p.spoilerLabel),
                ],
              ),
            ),
            IconButton(
              onPressed: _openMenu,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.more_horiz, color: VE.textMuted, size: 20),
            ),
          ],
        ),
        if (gated)
          _spoilerGate(p)
        else ...[
          if (p.title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.title,
              style: TextStyle(
                fontFamily: VE.fontSans,
                fontWeight: FontWeight.w900,
                fontSize: p.kind == 'blog' ? 18 : 15,
                color: VE.text,
                height: 1.25,
              ),
              maxLines: widget.expanded ? null : 3,
              overflow: widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ],
          if (p.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              p.body,
              style: const TextStyle(color: VE.textDim, fontSize: 13, height: 1.5),
              maxLines: widget.expanded ? null : 4,
              overflow: widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (!widget.expanded && p.body.length > 200)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: VE.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
          if (p.code.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(VE.r16),
                border: Border.all(color: VE.borderStrong),
              ),
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  p.code,
                  style: const TextStyle(
                    fontFamily: VE.fontMono,
                    fontSize: 11,
                    color: VE.emerald,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
          if (_attachmentsOf(p).isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._attachmentsOf(p).map(_renderAttachment),
          ],
        ],
        if (!isAd) ...[
          const SizedBox(height: 14),
          _actions(p),
        ],
      ],
    );
  }

  Widget _spoilerChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: VE.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VE.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 10, color: VE.orange),
            const SizedBox(width: 3),
            Text(
              (label.isEmpty ? 'SPOILER' : label).toUpperCase(),
              style: const TextStyle(
                fontFamily: VE.fontMono,
                fontWeight: FontWeight.w900,
                fontSize: 8,
                color: VE.orange,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );

  /// Pre-reveal placeholder shown in the feed when post.spoiler=true.
  /// Tap anywhere on it to expand the real content in place.
  Widget _spoilerGate(Post p) {
    final label = p.spoilerLabel.isEmpty ? 'Spoiler warning' : p.spoilerLabel;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => setState(() => _spoilerRevealed = true),
        borderRadius: BorderRadius.circular(VE.r16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VE.orange.withValues(alpha: 0.06),
            border: Border.all(color: VE.orange.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(VE.r16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: VE.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.visibility_off_rounded,
                    color: VE.orange, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: VE.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    const Text('Tap to reveal post contents',
                        style: TextStyle(
                            color: VE.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: VE.textDim, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(Post p) {
    return Row(
      children: [
        GestureDetector(
          onLongPress: () => _showLikers(),
          child: _actionBtn(
            icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _liked ? VE.pink : VE.textMuted,
            label: compactNum(_likeCount),
            onTap: _toggleLike,
          ),
        ),
        const SizedBox(width: 20),
        _actionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          color: VE.textMuted,
          label: compactNum(p.comments),
          onTap: widget.onTap,
        ),
        const SizedBox(width: 20),
        _actionBtn(
          icon: Icons.repeat_rounded,
          color: _reposted ? VE.emerald : VE.textMuted,
          label: compactNum(_repostCount),
          onTap: _toggleRepost,
        ),
        const Spacer(),
        Text(
          relativeTime(p.createdAt).toUpperCase(),
          style: const TextStyle(
            fontFamily: VE.fontMono,
            fontSize: 9,
            color: VE.textMuted,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({required IconData icon, required Color color, String? label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontFamily: VE.fontMono, fontSize: 11, color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Attachments ---
  List<Attachment> _attachmentsOf(Post p) {
    if (p.attachments.isNotEmpty) return p.attachments;
    // Backwards-compat: older posts may have metadata.attachments
    final meta = p.metadata['attachments'];
    if (meta is List) {
      return meta
          .whereType<Map>()
          .map((m) => Attachment.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    return  [];
  }

  Widget _renderAttachment(Attachment a) {
    // Every attachment gets a rounded container; onTap opens the URL.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AttachmentEmbed(attachment: a),
    );
  }
}

/// Rich attachment renderer. Handles:
///   - image URLs (display full image with loading spinner)
///   - YouTube URLs (thumbnail + play overlay)
///   - generic links (preview card with icon + domain)
class _AttachmentEmbed extends StatelessWidget {
  final Attachment attachment;
  const _AttachmentEmbed({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    switch (a.type) {
      case 'image':
        return _imageEmbed(context, a.url);
      case 'youtube':
        return _youtubeEmbed(context, a);
      case 'github':
        return _platformEmbed(
            context, a, 'GitHub', Icons.code_rounded, Colors.white);
      case 'discord':
        return _platformEmbed(
            context, a, 'Discord', Icons.forum_rounded, const Color(0xFF5865F2));
      case 'instagram':
        return _platformEmbed(context, a, 'Instagram', Icons.camera_alt_rounded,
            const Color(0xFFE1306C));
      case 'tiktok':
        return _platformEmbed(context, a, 'TikTok', Icons.music_note_rounded,
            const Color(0xFF00F2EA));
      case 'voice':
        return VoicePlayer(url: a.url, duration: a.title ?? '', accent: VE.pink);
      default:
        return _linkCard(context, a);
    }
  }

  Widget _platformEmbed(BuildContext context, Attachment a, String platform,
      IconData icon, Color color) {
    return GestureDetector(
      onTap: () => platform == 'YouTube'
          ? showDialog(
              context: context,
              builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
                  body: WebYouTubePlayer(youtubeUrl: a.url)))
          : _open(context, a.url),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VE.bgCard,
          borderRadius: BorderRadius.circular(VE.r16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platform.toUpperCase(),
                      style: TextStyle(
                          fontFamily: VE.fontMono,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: color,
                          letterSpacing: 2)),
                  const SizedBox(height: 2),
                  Text(a.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: VE.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: VE.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _youtubeEmbed(BuildContext context, Attachment a) {
    final videoId = _extractYoutubeId(a.url);
    if (videoId.isEmpty) return _linkCard(context, a);
    final thumbUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    return GestureDetector(
      onTap: () => _openYoutube(context, a.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VE.r16),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: thumbUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => _loadingPlaceholder(),
              errorWidget: (_, __, ___) => CachedNetworkImage(
                imageUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => _loadingPlaceholder(),
                errorWidget: (_, __, ___) => _platformEmbed(context, a, 'YouTube', Icons.smart_display_rounded, VE.pink),
              ),
            ),
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45],
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_rounded, size: 64, color: Colors.white70),
            ),
            Positioned(
              left: 12, bottom: 10,
              child: Row(
                children: [
                  const Icon(Icons.smart_display_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text('YouTube', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontMono, letterSpacing: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
    if (uri.pathSegments.contains('shorts')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    return '';
  }

  Future<void> _openYoutube(BuildContext context, String url) async {
    // Try to open in the YouTube app first, fall back to browser.
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Force http: so the OS can route to the YouTube app (intent://).
    final intentUrl = url.replaceFirst('https://', 'http://');
    if (await canLaunchUrl(Uri.parse(intentUrl))) {
      await launchUrl(Uri.parse(intentUrl), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _imageEmbed(BuildContext context, String url) {
    final resolved = context.read<Api>().resolveUrl(url);
    // Tap opens the fullscreen viewer (pinch-zoom, pan, X to close).
    // Constrained to 280px max height in feed for performance.
    return GestureDetector(
      onTap: () => ImageViewer.open(context, url: url, heroTag: 'img:$url'),
      child: Hero(
        tag: 'img:$url',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VE.r16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              placeholder: (_, __) => _loadingPlaceholder(),
              errorWidget: (ctx, __, ___) =>
                  _linkCard(ctx, Attachment(type: 'link', url: resolved)),
            ),
          ),
        ),
      ),
    );
  }

  /// Loading tile with a clear progress spinner, sized to typical image aspect.
  Widget _loadingPlaceholder() => Container(
        height: 200,
        decoration: BoxDecoration(
          color: VE.bgCard,
          borderRadius: BorderRadius.circular(VE.r16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2),
          ),
        ),
      );

  Widget _linkCard(BuildContext context, Attachment a) {
    IconData icon;
    Color color;
    switch (a.type) {
      case 'youtube':
        icon = Icons.smart_display_rounded;
        color = VE.pink;
        break;
      case 'github':
        icon = Icons.code_rounded;
        color = VE.textDim;
        break;
      case 'video':
        icon = Icons.play_circle_rounded;
        color = VE.blue;
        break;
      case 'image':
        icon = Icons.image_rounded;
        color = VE.emerald;
        break;
      default:
        icon = Icons.link_rounded;
        color = VE.blue;
    }
    final host = Uri.tryParse(a.url)?.host ?? a.url;
    return InkWell(
      borderRadius: BorderRadius.circular(VE.r16),
      onTap: () => _open(context, a.url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VE.bgCard,
          border: Border.all(color: VE.border),
          borderRadius: BorderRadius.circular(VE.r16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VE.r12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13, color: VE.text),
                  ),
                  Text(
                    a.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: VE.fontMono,
                        fontSize: 11,
                        color: VE.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded, size: 14, color: VE.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
