import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../theme.dart';
import '../updater.dart';
import '../widgets/update_dialog.dart';

/// Version archive. Shows only current + changelog in stable mode;
/// in beta mode shows all versions including unreleased (admin only) and allows downgrades.
class VersionsScreen extends StatefulWidget {
   const VersionsScreen({super.key});
  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _currentVersion = info.version);
    } catch (_) {}
    if (mounted) setState(() => _future = context.read<Api>().getVersions());
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<Api>();
    return Scaffold(
      backgroundColor: VE.bg,
      appBar: AppBar(
        backgroundColor: VE.bg,
        surfaceTintColor: VE.bg,
        leading: IconButton(
          icon:  const Icon(Icons.arrow_back_rounded, color: VE.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(api.betaMode ? 'Version archive' : 'Version info',
            style:  const TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: VE.text,
        backgroundColor: VE.bgCard,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return  const Center(child: CircularProgressIndicator(color: VE.textDim, strokeWidth: 2));
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding:  const EdgeInsets.all(40),
                  child: Text('No version history available',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
              );
            }
            return ListView.builder(
              padding:  const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: items.length,
              itemBuilder: (_, i) => _versionCard(items[i], api.betaMode),
            );
          },
        ),
      ),
    );
  }

  Widget _versionCard(Map<String, dynamic> v, bool betaMode) {
    final version = v['version'] as String;
    final isBeta = (v['is_beta'] ?? false) as bool;
    final isUnreleased = (v['is_unreleased'] ?? false) as bool;
    final isCurrentServer = (v['is_current'] ?? false) as bool;
    final isInstalled = version == _currentVersion;
    final notes = (v['release_notes'] ?? '') as String;
    final publishedAt = (v['published_at'] ?? '') as String;
    final canDownload = betaMode && !isInstalled && (v['apk_url'] as String?)?.isNotEmpty == true;

    final color = isUnreleased
        ? VE.pink
        : (isBeta ? VE.orange : (isCurrentServer ? VE.emerald : VE.textDim));

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding:  const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(VE.r16),
        border: Border.all(
          color: isInstalled ? VE.emerald.withValues(alpha: 0.4) : VE.border,
          width: isInstalled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('v$version',
                  style:  const TextStyle(
                      fontFamily: VE.fontSans,
                      fontWeight: FontWeight.w900,
                      color: VE.text,
                      fontSize: 17)),
               const SizedBox(width: 8),
              if (isInstalled)
                _chip('INSTALLED', VE.emerald)
              else if (isCurrentServer)
                _chip('LATEST', VE.emerald)
              else if (isUnreleased)
                _chip('UNRELEASED', VE.pink)
              else if (isBeta)
                _chip('BETA', VE.orange)
              else
                _chip('ARCHIVE', VE.textMuted, color: color),
               const Spacer(),
              if (canDownload)
                OutlinedButton.icon(
                  onPressed: () => _install(v),
                  icon:  const Icon(Icons.download_rounded, size: 14),
                  label:  const Text('Install'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VE.blue,
                    side: BorderSide(color: VE.blue.withValues(alpha: 0.5)),
                    padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle:  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
            ],
          ),
          if (publishedAt.isNotEmpty) ...[
             const SizedBox(height: 4),
            Text(_formatDate(publishedAt),
                style:  const TextStyle(
                    color: VE.textMuted, fontSize: 11, fontFamily: VE.fontMono)),
          ],
          if (notes.isNotEmpty) ...[
             const SizedBox(height: 10),
            Text(notes,
                style:  const TextStyle(color: VE.textDim, fontSize: 13, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, {Color? color}) {
    return Container(
      padding:  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: VE.fontMono,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 1.5,
          color: color ?? bg,
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _install(Map<String, dynamic> v) async {
    final api = context.read<Api>();
    final updater = Updater(api.baseUrl);
    final info = ReleaseInfo(
      version: v['version'] as String,
      build: (v['build'] as num?)?.toInt() ?? 0,
      apkUrl: (v['apk_url'] ?? '') as String,
      apkSize: 0,
      releaseNotes: (v['release_notes'] ?? '') as String,
    );
    await showDialog(
      context: context,
      builder: (_) => UpdateDialog(updater: updater, info: info),
    );
  }
}
