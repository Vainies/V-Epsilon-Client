import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../notif_bus.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import '../widgets/voice.dart';
import 'profile.dart';

/// Post + thread view. Comments are stacked as card-bubbles to match the
/// rest of the app, rather than raw rows. Live-updates via WebSocket when
/// new comments arrive.
class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Future<List<Comment>>? _future;
  final _commentCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  late Post _post;
  StreamSubscription<WsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _load();
    // Subscribe to WS events for this post and reload when a comment/like lands.
    _wsSub = NotifBus.I.events.listen((e) {
      if (!mounted) return;
      if (e.topic == 'post:${_post.id}') {
        if (e.kind == 'comment.added') {
          _load();
        } else if (e.kind == 'post.liked' || e.kind == 'post.unliked') {
          _refreshPost();
        }
      }
    });
  }

  Future<void> _refreshPost() async {
    try {
      final p = await context.read<Api>().getPost(_post.id);
      if (mounted) setState(() => _post = p);
    } catch (_) {}
  }

  void _load() {
    setState(() => _future = context.read<Api>().comments(_post.id));
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _commentCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final api = context.read<Api>();
    if (!api.isAuthed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to reply')));
      return;
    }
    setState(() => _sending = true);
    try {
      await api.comment(_post.id, text);
      _commentCtrl.clear();
      _load();
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoice(String path, int seconds) async {
    final api = context.read<Api>();
    if (!api.isAuthed) return;
    setState(() => _sending = true);
    try {
      final url = await api.uploadFile(File(path));
      final duration =
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      await api.voiceComment(_post.id, url, duration);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Voice reply failed: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VE.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: VE.bg,
        surfaceTintColor: VE.bg,
        elevation: 0,
        title: const Text('Thread',
            style: TextStyle(
                color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: VE.text),
            onPressed: () => Navigator.maybePop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: VE.text,
              backgroundColor: VE.bgCard,
              onRefresh: () async {
                _load();
                await _refreshPost();
              },
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  PostCard(
                    post: _post,
                    expanded: true,
                    onProfileTap: (u) => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ProfileScreen(user: u))),
                  ),
                  const SizedBox(height: 20),
                  _threadHeader(),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Comment>>(
                    future: _future,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: VE.textDim, strokeWidth: 2),
                          ),
                        );
                      }
                      final comments = snap.data ?? [];
                      if (comments.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: VE.bgCard,
                            borderRadius: BorderRadius.circular(VE.r16),
                            border: Border.all(color: VE.border),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 32, color: VE.textFaint),
                              SizedBox(height: 8),
                              Text('No replies yet',
                                  style: TextStyle(
                                      color: VE.textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 4),
                              Text('Be the first to say something.',
                                  style: TextStyle(
                                      color: VE.textFaint, fontSize: 12)),
                            ],
                          ),
                        );
                      }
                      final api = context.read<Api>();
                      final myId = api.userId;
                      return Column(
                        children: [
                          for (int i = 0; i < comments.length; i++)
                            _CommentCard(
                              comment: comments[i],
                              isOwner: comments[i].author.id == myId,
                              onDelete: comments[i].author.id == myId
                                  ? () async {
                                      try {
                                        await api.deleteComment(comments[i].id);
                                        _load();
                                      } catch (_) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Failed to delete'), backgroundColor: VE.red),
                                        );
                                      }
                                    }
                                  : null,
                              onAuthorTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(user: comments[i].author))),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          _replyBar(),
        ],
      ),
    );
  }

  Widget _threadHeader() => Row(
        children: [
          const Icon(Icons.forum_rounded, size: 16, color: VE.textMuted),
          const SizedBox(width: 8),
          Text(
            _post.comments == 0
                ? 'REPLIES'
                : 'REPLIES · ${compactNum(_post.comments)}',
            style: const TextStyle(
                fontFamily: VE.fontMono,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 2,
                color: VE.textMuted),
          ),
        ],
      );

  Widget _replyBar() => Container(
        decoration: BoxDecoration(
          color: VE.bg,
          border: Border(top: BorderSide(color: VE.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: VE.bgElevated,
                    borderRadius: BorderRadius.circular(VE.r24),
                    border: Border.all(color: VE.border),
                  ),
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(color: VE.text, fontSize: 14, height: 1.35),
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Post your reply…',
                      hintStyle: TextStyle(color: VE.textMuted, fontSize: 14),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Show mic-to-record when text is empty, else show send button.
              _commentCtrl.text.trim().isEmpty && !_sending
                  ? VoiceRecordButton(onComplete: _sendVoice)
                  : Material(
                      color: _sending ? VE.textFaint : VE.blue,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sending ? null : _send,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final VoidCallback onAuthorTap;
  final VoidCallback? onDelete;
  final bool isOwner;
  const _CommentCard({required this.comment, required this.onAuthorTap, this.onDelete, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    final c = comment;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(VE.r16),
        border: Border.all(color: VE.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VEAvatar(
            url: c.author.avatarUrl,
            seed: c.author.name.isEmpty ? c.author.handle : c.author.name,
            size: 36,
            radius: 12,
            onTap: onAuthorTap,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.author.name.isEmpty ? '@${c.author.handle}' : c.author.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: VE.text),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ...c.author.badges.take(1).map((b) => VEBadge(type: b)),
                    const Spacer(),
                    if (isOwner && onDelete != null)
                      GestureDetector(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: VE.bgCard,
                              title: const Text('Delete comment?', style: TextStyle(color: VE.text, fontSize: 16)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: VE.textDim))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: VE.red))),
                              ],
                            ),
                          );
                          if (ok == true) onDelete?.call();
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.delete_outline_rounded, size: 16, color: VE.textMuted),
                        ),
                      ),
                    Text(
                      relativeTime(c.createdAt),
                      style: const TextStyle(
                          fontFamily: VE.fontMono,
                          fontSize: 10,
                          color: VE.textMuted),
                    ),
                  ],
                ),
                Text('@${c.author.handle}',
                    style: const TextStyle(
                        fontFamily: VE.fontMono,
                        fontSize: 10,
                        color: VE.textMuted)),
                const SizedBox(height: 6),
                if (c.kind == 'voice' && c.mediaUrl.isNotEmpty)
                  VoicePlayer(url: c.mediaUrl, duration: c.duration)
                else
                  Text(c.body,
                      style: const TextStyle(
                          color: VE.text, fontSize: 13.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
