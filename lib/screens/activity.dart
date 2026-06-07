import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../notif_bus.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Future<List<AppNotification>>? _future;
  StreamSubscription<WsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Live refresh when a notification arrives over the wire.
    _wsSub = NotifBus.I.events.listen((e) {
      if (e.kind == 'notification.new' && mounted) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _load() {
    final api = context.read<Api>();
    if (!api.isAuthed) return;
    setState(() => _future = api.notifications());
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<Api>();
    if (!api.isAuthed) return _loginPrompt();

    return Scaffold(
      backgroundColor: VE.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: VE.bg,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            title: const Text('Activity',
                style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Likes, follows, mentions and comments on your posts.',
                style: TextStyle(color: VE.textMuted, fontSize: 12),
              ),
            ),
          ),
          SliverFillRemaining(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              color: VE.text,
              backgroundColor: VE.bgCard,
              child: FutureBuilder<List<AppNotification>>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2));
                  }
                  final notifs = snap.data ?? [];
                  if (notifs.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.notifications_off_outlined, size: 56, color: VE.textFaint),
                      const SizedBox(height: 16),
                      Text('Nothing yet',
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'When people interact with your posts or profile, it shows up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: VE.textMuted, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (_, i) => _notifRow(notifs[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifRow(AppNotification n) {
    final data = _configFor(n.kind);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: n.actor))),
      borderRadius: BorderRadius.circular(VE.r16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                VEAvatar(url: n.actor.avatarUrl, seed: n.actor.name, size: 42, radius: 14),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: data.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: VE.bg, width: 2.5),
                    ),
                    child: Icon(data.icon, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: VE.textDim, fontSize: 13, height: 1.4),
                  children: [
                    TextSpan(
                      text: n.actor.name.isEmpty ? '@${n.actor.handle}' : n.actor.name,
                      style: const TextStyle(color: VE.text, fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(text: n.body.isEmpty ? _defaultText(n.kind) : n.body),
                    TextSpan(
                      text: '  ·  ${relativeTime(n.createdAt)}',
                      style: const TextStyle(color: VE.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (!n.read)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: VE.blue, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  static ({IconData icon, Color color}) _configFor(String kind) {
    switch (kind) {
      case 'like':
        return (icon: Icons.favorite_rounded, color: VE.pink);
      case 'follow':
        return (icon: Icons.person_add_rounded, color: VE.blue);
      case 'coop':
        return (icon: Icons.groups_rounded, color: VE.purple);
      case 'comment':
        return (icon: Icons.chat_bubble_rounded, color: VE.cyan);
    }
    return (icon: Icons.notifications_rounded, color: VE.textDim);
  }

  static String _defaultText(String kind) {
    switch (kind) {
      case 'like':
        return 'liked your post';
      case 'follow':
        return 'started following you';
      case 'coop':
        return 'invited you to a co-op stream';
      case 'comment':
        return 'commented on your post';
    }
    return '';
  }

  Widget _loginPrompt() => Scaffold(
        backgroundColor: VE.bg,
        appBar: AppBar(backgroundColor: VE.bg),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: VE.textFaint),
              const SizedBox(height: 12),
              Text('Sign in to see activity', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
}
