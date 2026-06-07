import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'profile.dart';
import 'post_detail.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _ctrl;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;
  String _tab = 'All';
  String? _error;
  Timer? _debounce;
  List<String> _recent = [];

  static const _recentKey = 'search_recent';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _loadRecent();
    if (widget.initialQuery.isNotEmpty) {
      _search();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => _recent = sp.getStringList(_recentKey) ?? []);
  }

  Future<void> _saveRecent(String q) async {
    final list = [q, ..._recent.where((e) => e != q)].take(8).toList();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_recentKey, list);
    _recent = list;
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });
    try {
      final api = context.read<Api>();
      final data = await api.search(q);
      if (!mounted) return;
      setState(() {
        _results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
      _saveRecent(q);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_tab == 'All') return _results;
    return _results.where((r) => (r['type'] as String? ?? '') == _tab.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VE.bg,
      appBar: AppBar(
        backgroundColor: VE.bg,
        surfaceTintColor: VE.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VE.text),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E),
            borderRadius: BorderRadius.circular(VE.r16),
            border: Border.all(color: VE.border),
          ),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: VE.text),
            cursorColor: VE.blue,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: 'Search users and posts',
              hintStyle: const TextStyle(color: VE.textMuted, fontSize: 14),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, size: 18, color: VE.textMuted),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: VE.textMuted),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() {
                          _results = [];
                          _searched = false;
                          _error = null;
                        });
                      },
                    ),
            ),
            onChanged: (_) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _search);
            },
            onSubmitted: (_) => _search(),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: VE.textDim),
            const SizedBox(height: 12),
            const Text('Search failed', style: TextStyle(color: VE.textMuted, fontSize: 15)),
            const SizedBox(height: 16),
            TextButton(onPressed: _search, child: const Text('Retry', style: TextStyle(color: VE.blue))),
          ],
        ),
      );
    }
    if (!_searched) {
      return _recent.isNotEmpty
          ? _recentSearchView()
          : _emptyView();
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: VE.textFaint),
            const SizedBox(height: 16),
            Text('No results for "${_ctrl.text.trim()}"',
                style: const TextStyle(color: VE.textMuted, fontSize: 14)),
          ],
        ),
      );
    }
    return Column(
      children: [
        _tabBar(),
        Expanded(child: _resultsList()),
      ],
    );
  }

  Widget _emptyView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: VE.bgCard,
            shape: BoxShape.circle,
            border: Border.all(color: VE.border),
          ),
          child: const Icon(Icons.search_rounded, size: 32, color: VE.textDim),
        ),
        const SizedBox(height: 20),
        const Text('Search Epsilon',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: VE.text)),
        const SizedBox(height: 8),
        const Text('Find users and posts across the network.',
            style: TextStyle(color: VE.textMuted, fontSize: 13)),
      ],
    ),
  );

  Widget _recentSearchView() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Recent', style: TextStyle(color: VE.textMuted, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final sp = await SharedPreferences.getInstance();
                await sp.remove(_recentKey);
                setState(() => _recent = []);
              },
              child: const Text('Clear', style: TextStyle(color: VE.textDim, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _recent.map((q) => InkWell(
            onTap: () {
              _ctrl.text = q;
              _search();
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: VE.bgCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: VE.border),
              ),
              child: Text(q, style: const TextStyle(color: VE.text, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          )).toList(),
        ),
      ],
    ),
  );

  Widget _tabBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'Users', 'Posts'].map((t) {
          final active = _tab == t;
          final count = t == 'All' ? _results.length : _results.where((r) => (r['type'] as String? ?? '') == t.toLowerCase()).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _tab = t),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? VE.text : VE.bgCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? VE.text : VE.border),
                ),
                child: Text('$t ($count)',
                    style: TextStyle(
                        color: active ? Colors.black : VE.textDim,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _resultsList() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
    itemCount: _filtered.length,
    itemBuilder: (_, i) {
      final r = _filtered[i];
      final type = r['type'] as String? ?? '';
      if (type == 'user') {
        final u = AppUser.fromJson(r['user'] as Map<String, dynamic>);
        return _userTile(u);
      } else if (type == 'post') {
        final p = Post.fromJson(r['post'] as Map<String, dynamic>);
        return PostCard(
          post: p,
          onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: p))),
          onProfileTap: (u) => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ProfileScreen(user: u))),
        );
      }
      return const SizedBox.shrink();
    },
  );

  Widget _userTile(AppUser u) {
    return InkWell(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => ProfileScreen(user: u))),
      borderRadius: BorderRadius.circular(VE.r16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            VEAvatar(url: u.avatarUrl, seed: u.name.isEmpty ? u.handle : u.name, size: 44, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(u.name.isEmpty ? '@${u.handle}' : u.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: VE.text, fontSize: 14)),
                      if (u.badges.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ...u.badges.take(2).map((b) => VEBadge(type: b)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('@${u.handle}',
                      style: const TextStyle(color: VE.textDim, fontSize: 12, fontFamily: VE.fontMono)),
                ],
              ),
            ),
            Text('${compactNum(u.followers)} followers',
                style: const TextStyle(color: VE.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
