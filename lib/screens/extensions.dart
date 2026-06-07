import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../extension_runtime.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key});
  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  List<Map<String, dynamic>>? _extensions;
  bool _loading = true;
  String _category = 'All';

  static const categories = ['All', 'Themes', 'Customization'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final exts = await context.read<Api>().getExtensions();
      if (!mounted) return;
      setState(() {
        _extensions = exts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_category == 'All') return _extensions ?? [];
    return (_extensions ?? []).where((e) {
      final cat = (e['category'] as String? ?? '').toLowerCase();
      return cat == _category.toLowerCase();
    }).toList();
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
        title: const Text('Extension Store',
            style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: VE.blue, strokeWidth: 2))
          : _extensions == null || _extensions!.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    _categoryBar(),
                    Expanded(child: _grid()),
                  ],
                ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: VE.bgElevated,
            shape: BoxShape.circle,
            border: Border.all(color: VE.border),
          ),
          child: const Icon(Icons.extension_rounded, size: 36, color: VE.textDim),
        ),
        const SizedBox(height: 24),
        const Text('No Extensions Yet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: VE.text)),
        const SizedBox(height: 8),
        const Text('Check back later for community extensions.',
            style: TextStyle(color: VE.textMuted, fontSize: 14)),
      ],
    ),
  );

  Widget _categoryBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final active = _category == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _category = cat),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? VE.text : VE.bgCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? VE.text : VE.border),
                ),
                child: Text(cat,
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

  Widget _grid() => RefreshIndicator(
    onRefresh: _load,
    color: VE.text,
    backgroundColor: VE.bgCard,
    child: GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _extCard(_filtered[i]),
    ),
  );

  Widget _extCard(Map<String, dynamic> ext) {
    final id = ext['id'] as String? ?? '';
    final name = ext['name'] as String? ?? id;
    final desc = ext['description'] as String? ?? '';
    final version = ext['version'] as String? ?? '';
    final cat = ext['category'] as String? ?? '';
    final installed = ExtensionRuntime.I.isInstalled(id);

    final displayName = name.length > 30 ? '${name.substring(0, 27)}...' : name;
    final displayDesc = desc.length > 80 ? '${desc.substring(0, 77)}...' : desc;

    final colors = [VE.blue, VE.purple, VE.pink, VE.cyan, VE.emerald, VE.orange];
    final color = colors[id.hashCode % colors.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExtDetailScreen(ext: ext))),
        borderRadius: BorderRadius.circular(VE.r24),
        child: Container(
          decoration: BoxDecoration(
            color: VE.bgCard,
            borderRadius: BorderRadius.circular(VE.r24),
            border: Border.all(color: installed ? VE.emerald.withValues(alpha: 0.4) : VE.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VE.r16),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.extension_rounded, size: 24, color: color),
                      if (installed)
                        Positioned(
                          right: -2, bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: VE.emerald, shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(displayName,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: VE.text)),
              const SizedBox(height: 4),
              Text(displayDesc,
                  style: const TextStyle(color: VE.textDim, fontSize: 10, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(
                children: [
                  if (cat.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(cat,
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
                    ),
                  const Spacer(),
                  Text('v$version',
                      style: const TextStyle(color: VE.textMuted, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExtDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ext;
  const ExtDetailScreen({super.key, required this.ext});
  @override
  State<ExtDetailScreen> createState() => _ExtDetailScreenState();
}

class _ExtDetailScreenState extends State<ExtDetailScreen> {
  List<Map<String, dynamic>>? _reviews;
  bool _loadingReviews = true;
  bool _loadingData = false;
  bool _applying = false;
  Map<String, dynamic>? _extData;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = widget.ext['id'] as String? ?? '';
    try {
      final d = await context.read<Api>().extensionData(id);
      if (mounted) setState(() => _extData = d);
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    try {
      final id = widget.ext['id'] as String? ?? '';
      final data = await context.read<Api>().extensionReviews(id);
      if (!mounted) return;
      setState(() {
        _reviews = (data['reviews'] as List).cast<Map<String, dynamic>>();
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _install() async {
    final id = widget.ext['id'] as String? ?? '';
    setState(() => _loadingData = true);
    try {
      final d = await context.read<Api>().extensionData(id);
      await ExtensionRuntime.I.install(id, d);
      VETheme.I.loadOverrides();
      VETheme.I.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.ext['name'] ?? id} installed!'),
        backgroundColor: VE.emerald,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to install extension'),
        backgroundColor: VE.red,
      ));
    }
    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _uninstall() async {
    final id = widget.ext['id'] as String? ?? '';
    await ExtensionRuntime.I.uninstall(id);
    VETheme.I.loadOverrides();
    VETheme.I.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Extension uninstalled.'),
      backgroundColor: VE.textDim,
    ));
  }

  Future<void> _apply() async {
    final id = widget.ext['id'] as String? ?? '';
    setState(() => _applying = true);
    await ExtensionRuntime.I.install(id, _extData ?? {});
    VETheme.I.loadOverrides();
    VETheme.I.refresh();
    setState(() => _applying = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.ext['name'] ?? id} applied!'),
      backgroundColor: VE.emerald,
    ));
  }

  bool get _installed => ExtensionRuntime.I.isInstalled(widget.ext['id'] as String? ?? '');

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final id = ext['id'] as String? ?? '';
    final name = ext['name'] as String? ?? id;
    final desc = ext['description'] as String? ?? '';
    final author = ext['author'] as String? ?? '';
    final version = ext['version'] as String? ?? '';
    final cat = ext['category'] as String? ?? '';
    final isTheme = _extData?['type'] == 'theme' || id == 'pinky';

    final colors = [VE.blue, VE.purple, VE.pink, VE.cyan, VE.emerald, VE.orange];
    final color = colors[id.hashCode % colors.length];

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
        title: Text(name,
            style: const TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VE.bgCard,
              borderRadius: BorderRadius.circular(VE.r24),
              border: Border.all(color: VE.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VE.r16),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.extension_rounded, size: 32, color: color),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: VE.text)),
                if (cat.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(cat,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 1)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VE.textDim, fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (author.isNotEmpty) ...[
                      Text(author,
                          style: const TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                    ],
                    Text('v$version',
                        style: const TextStyle(color: VE.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _installed
                      ? Column(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uninstall,
                              icon: const Icon(Icons.remove_rounded, size: 16),
                              label: const Text('Uninstall'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: VE.pink,
                                side: BorderSide(color: VE.pink.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r12)),
                              ),
                            ),
                            if (isTheme) ...[
                              const SizedBox(height: 8),
                              VEPrimaryButton(
                                label: _applying ? 'APPLYING...' : 'APPLY THEME',
                                onPressed: _applying ? null : _apply,
                              ),
                            ],
                          ],
                        )
                      : VEPrimaryButton(
                          label: _loadingData ? 'INSTALLING...' : 'INSTALL',
                          icon: Icons.download_rounded,
                          onPressed: _loadingData ? null : _install,
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text('REVIEWS',
              style: TextStyle(fontFamily: VE.fontMono, fontSize: 10, letterSpacing: 2, color: VE.textMuted, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _ReviewForm(extId: id, onSubmitted: _loadReviews),
          const SizedBox(height: 12),
          if (_loadingReviews)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: VE.blue, strokeWidth: 2),
            ))
          else if (_reviews == null || _reviews!.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.rate_review_outlined, size: 32, color: VE.textFaint),
                  SizedBox(height: 8),
                  Text('No reviews yet', style: TextStyle(color: VE.textMuted, fontSize: 13)),
                ]),
              ),
            )
          else
            ..._reviews!.map((r) => _reviewTile(r)),
        ],
      ),
    );
  }

  Widget _reviewTile(Map<String, dynamic> r) {
    final rating = r['rating'] as int? ?? 0;
    final body = r['body'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(VE.r12),
        border: Border.all(color: VE.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: star <= rating ? VE.yellow : VE.textFaint,
                  size: 14,
                ),
              );
            }),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: VE.textDim, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final String extId;
  final VoidCallback onSubmitted;
  const _ReviewForm({required this.extId, required this.onSubmitted});
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  int _rating = 5;
  final _textController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final text = _textController.text.trim();
      await context.read<Api>().extensionSubmitReview(widget.extId, _rating, text.length > 500 ? text.substring(0, 500) : text);
      _textController.clear();
      widget.onSubmitted();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!'), backgroundColor: VE.emerald));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit review'), backgroundColor: VE.red));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(VE.r16),
        border: Border.all(color: VE.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: star <= _rating ? VE.yellow : VE.textFaint,
                    size: 24,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLength: 500,
            maxLines: 2,
            style: const TextStyle(color: VE.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Write your review…',
              hintStyle: const TextStyle(color: VE.textFaint, fontSize: 13),
              filled: true,
              fillColor: VE.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VE.r12),
                borderSide: BorderSide(color: VE.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VE.r12),
                borderSide: BorderSide(color: VE.border),
              ),
              contentPadding: const EdgeInsets.all(10),
              counterStyle: const TextStyle(color: VE.textFaint, fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: VEPrimaryButton(
              label: _submitting ? 'SUBMITTING...' : 'SUBMIT',
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
