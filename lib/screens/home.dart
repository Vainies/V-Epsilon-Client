import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../notif_bus.dart';
import '../theme.dart';
import '../widgets/post_card.dart';
import 'post_detail.dart';

class HomeScreen extends StatefulWidget {
   const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 10;
  static const int _maxCached = 30;

  final List<Post> _posts = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _fillingScreen = false;
  int _offset = 0;
  String? _error;
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<WsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
    _wsSub = NotifBus.I.events.listen((e) {
      if (!mounted) return;
      if (e.topic == 'feed' && e.kind == 'post.created') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients &&
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    try {
      final posts = await context.read<Api>().feed(limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _offset = posts.length;
        _hasMore = posts.length >= _pageSize;
        _initialLoading = false;
        _error = null;
      });
      _fillScreen();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        if (_posts.isEmpty) _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final posts = await context.read<Api>().feed(limit: _pageSize, offset: _offset);
      if (!mounted) return;
      setState(() {
        _posts.addAll(posts);
        _offset += posts.length;
        _hasMore = posts.length >= _pageSize;
        _loadingMore = false;
        if (_posts.length > _maxCached) {
          _posts.removeRange(0, _posts.length - _maxCached);
        }
      });
      _fillScreen();
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _fillScreen() {
    if (_fillingScreen || _loadingMore || !_hasMore) return;
    _fillingScreen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { _fillingScreen = false; return; }
      if (!_scrollCtrl.hasClients) {
        // Scroll controller not attached yet - try again next frame
        WidgetsBinding.instance.addPostFrameCallback((__) {
          if (!mounted) { _fillingScreen = false; return; }
          if (!_scrollCtrl.hasClients) { _fillingScreen = false; return; }
          if (_scrollCtrl.position.maxScrollExtent < _scrollCtrl.position.viewportDimension) {
            _loadMore();
          }
          _fillingScreen = false;
        });
        return;
      }
      if (_scrollCtrl.position.maxScrollExtent < _scrollCtrl.position.viewportDimension) {
        _loadMore();
      }
      _fillingScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<Api>().online;
    if (_initialLoading) {
      return Column(children: [
        if (!online) _offlineBanner(),
        const Expanded(child: Center(child: CircularProgressIndicator(color: VE.blue, strokeWidth: 2))),
      ]);
    }
    if (_error != null) {
      return Column(children: [
        if (!online) _offlineBanner(),
        Expanded(child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: VE.textDim, size: 40),
                const SizedBox(height: 12),
                const Text('Could not load feed', style: TextStyle(color: VE.textMuted, fontSize: 15)),
                const SizedBox(height: 16),
                TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: VE.blue))),
              ],
            ),
          ),
        )),
      ]);
    }
    if (_posts.isEmpty) {
      return Column(children: [
        if (!online) _offlineBanner(),
        const Expanded(child: Center(
          child: Text('Nothing in your feed yet.',
              style: TextStyle(color: VE.textMuted, fontSize: 14, fontWeight: FontWeight.w700)),
        )),
      ]);
    }
    return Column(children: [
      if (!online) _offlineBanner(),
      Expanded(child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _posts.length + (_loadingMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i >= _posts.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2))),
              );
            }
            return PostCard(
              post: _posts[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PostDetailScreen(post: _posts[i]),
              )),
            );
          },
        ),
      )),
    ]);
  }

  Widget _offlineBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    color: VE.orange.withValues(alpha: 0.15),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 14, color: VE.orange),
        SizedBox(width: 8),
        Text('No connection - some features unavailable',
            style: TextStyle(color: VE.orange, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
