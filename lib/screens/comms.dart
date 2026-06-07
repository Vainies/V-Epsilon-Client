import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile.dart';

class CommsScreen extends StatefulWidget {
   const CommsScreen({super.key});
  @override
  State<CommsScreen> createState() => _CommsScreenState();
}

class _CommsScreenState extends State<CommsScreen> {
  Future<List<Thread>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<Api>();
    if (!api.isAuthed) return;
    setState(() => _future = api.threads());
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<Api>();
    if (!api.isAuthed) return _loginPrompt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:  const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            children: [
               const Icon(Icons.forum_rounded, color: VE.emerald, size: 28),
               const SizedBox(width: 10),
              Text('Comms', style: Theme.of(context).textTheme.displayMedium),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            color: VE.text,
            backgroundColor: VE.bgCard,
            child: FutureBuilder<List<Thread>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return  const Center(child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2));
                }
                final threads = snap.data ?? [];
                if (threads.isEmpty) {
                  return ListView(children: [
                     const SizedBox(height: 80),
                     const Icon(Icons.chat_outlined, size: 64, color: VE.textFaint),
                     const SizedBox(height: 16),
                    Text('No messages yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  ]);
                }
                return ListView.separated(
                  padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: threads.length,
                  separatorBuilder: (_, __) =>  const SizedBox(height: 12),
                  itemBuilder: (_, i) => _threadTile(threads[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _threadTile(Thread t) {
    return VECard(
      padding:  const EdgeInsets.all(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProfileScreen(user: t.user),
      )),
      child: Row(
        children: [
          VEAvatar(url: t.user.avatarUrl, seed: t.user.name, size: 52, radius: 20, showOnline: true),
           const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      t.user.name,
                      style:  const TextStyle(fontWeight: FontWeight.w700, color: VE.text, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    relativeTime(t.time),
                    style:  const TextStyle(fontFamily: VE.fontMono, fontSize: 10, color: VE.textMuted),
                  ),
                ]),
                 const SizedBox(height: 4),
                if (t.kind == 'voice')
                  Row(children: [
                    Container(
                      padding:  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VE.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: VE.blue.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                         const Icon(Icons.mic, size: 12, color: VE.blue),
                         const SizedBox(width: 4),
                        Text(t.duration,
                            style:  const TextStyle(fontFamily: VE.fontMono, fontSize: 10, color: VE.blue, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                     const SizedBox(width: 8),
                     const Text('Voice Message', style: TextStyle(color: VE.textMuted, fontSize: 13)),
                  ])
                else
                  Text(
                    t.lastMessage,
                    style: TextStyle(color: t.read ? VE.textMuted : VE.text, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginPrompt() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.lock_outline, size: 48, color: VE.textFaint),
             const SizedBox(height: 12),
            Text('Sign in to view messages', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}
