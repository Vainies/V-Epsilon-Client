import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/post_card.dart';
import 'post_detail.dart';
import 'profile.dart';

/// Reposts tab — shows posts the current user has reposted.
/// When user taps a card it opens the post detail. Original author is shown
/// in the card; a subtle header line "<you> reposted" is rendered above.
class RepostsScreen extends StatefulWidget {
   const RepostsScreen({super.key});
  @override
  State<RepostsScreen> createState() => _RepostsScreenState();
}

class _RepostsScreenState extends State<RepostsScreen> {
  Future<List<Post>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<Api>();
    if (!api.isAuthed) return;
    setState(() => _future = api.userReposts(api.handle));
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<Api>();
    if (!api.isAuthed) {
      return _loginPrompt();
    }
    return Scaffold(
      backgroundColor: VE.bg,
      body: RefreshIndicator(
        color: VE.text,
        backgroundColor: VE.bgCard,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
             const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 18, color: VE.text),
                    SizedBox(width: 8),
                    Text('Your reposts',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: VE.text)),
                  ],
                ),
              ),
            ),
             const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Posts you rebroadcast. They also show up in your followers\' feeds.',
                  style: TextStyle(color: VE.textDim, fontSize: 13, height: 1.5),
                ),
              ),
            ),
            FutureBuilder<List<Post>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2),
                    ),
                  );
                }
                final posts = snap.data ?? [];
                if (posts.isEmpty) {
                  return  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat_rounded, size: 40, color: VE.textFaint),
                            SizedBox(height: 12),
                            Text('You haven\'t reposted anything yet',
                                style: TextStyle(color: VE.textMuted, fontSize: 14)),
                            SizedBox(height: 6),
                            Text('Tap the repeat icon on any post to share it here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: VE.textFaint, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding:  const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (_, i) => PostCard(
                      post: posts[i],
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: posts[i]))),
                      onProfileTap: (u) => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => ProfileScreen(user: u))),
                    ),
                  ),
                );
              },
            ),
             const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _loginPrompt() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.lock_outline_rounded, size: 40, color: VE.textFaint),
             const SizedBox(height: 12),
            Text('Sign in to see your reposts',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}
