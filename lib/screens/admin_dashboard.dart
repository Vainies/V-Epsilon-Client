import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  Timer? _timer;
  bool _loading = true;

  final List<FlSpot> _requestSpots = [];
  final List<FlSpot> _errorSpots = [];
  double _timerCounter = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<Api>().adminDashboard();
      if (!mounted) return;
      
      setState(() {
        _stats = data;
        _loading = false;
        _timerCounter += 1;
        
        // Extract real-time metrics for graphs
        final cache = (data['cache'] as Map?) ?? {};
        final hits = (cache['hits'] as num?)?.toDouble() ?? 0;
        final misses = (cache['misses'] as num?)?.toDouble() ?? 0;
        final total = hits + misses;
        
        _requestSpots.add(FlSpot(_timerCounter, total));
        if (_requestSpots.length > 20) _requestSpots.removeAt(0);

        final evicts = (cache['evicts'] as num?)?.toDouble() ?? 0;
        _errorSpots.add(FlSpot(_timerCounter, evicts));
        if (_errorSpots.length > 20) _errorSpots.removeAt(0);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _chartPanel(String title, List<FlSpot> spots, Color color) {
    return _panel(
      title,
      SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      icon: Icons.show_chart_rounded,
      accent: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: VE.bg,
        appBar: AppBar(
          backgroundColor: VE.bg,
          surfaceTintColor: VE.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: VE.text),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Admin Console',
              style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
          bottom: TabBar(
            dividerColor: VE.border,
            indicatorColor: VE.blue,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: VE.blue,
            unselectedLabelColor: VE.textMuted,
            labelStyle: const TextStyle(fontFamily: VE.fontMono, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
            tabs: const [
              Tab(text: 'SYSTEM'),
              Tab(text: 'USERS'),
              Tab(text: 'MARKETING'),
              Tab(text: 'SERVERS'),
              Tab(text: 'POSTS'),
            ],
          ),
        ),
        body: _loading 
          ? const Center(child: CircularProgressIndicator(color: VE.blue, strokeWidth: 2))
          : TabBarView(
              children: [
                _systemTab(),
                _usersTab(),
                _marketingTab(),
                _serversTab(),
                _postsTab(),
              ],
            ),
      ),
    );
  }

  Widget _systemTab() {
    final d = _stats ?? {};
    final totals = (d['totals'] as Map?) ?? {};
    final cache = (d['cache'] as Map?) ?? {};
    final recentCrashes = (d['recent_crashes'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statsGrid(totals),
        const SizedBox(height: 16),
        _chartPanel('Request Volume (Cache Traffic)', _requestSpots, VE.blue),
        const SizedBox(height: 16),
        _chartPanel('Cache Evictions (Performance)', _errorSpots, VE.pink),
        const SizedBox(height: 16),
        _cachePanel(cache),
        _recentPanel('Recent crashes', recentCrashes, _renderRecentCrash),
      ],
    );
  }

  Widget _usersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _usersPanel(),
      ],
    );
  }

  Widget _marketingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _marketingPanel('Announcements', Icons.campaign_rounded, context.read<Api>().getAnnouncements, _deleteAnnouncement, _addAnnouncement),
        const SizedBox(height: 16),
        _marketingPanel('Ads', Icons.monetization_on_rounded, context.read<Api>().getAds, _deleteAd, _addAd),
      ],
    );
  }

  // --- Components from original dashboard ---

  Widget _statsGrid(Map t) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _statCard('Accounts', t['users']?.toString() ?? '0', VE.blue),
        _statCard('Posts', t['posts']?.toString() ?? '0', VE.emerald),
        _statCard('Messages', t['messages']?.toString() ?? '0', VE.purple),
        _statCard('Reports', t['flags']?.toString() ?? '0', VE.pink),
      ],
    );
  }

  Widget _statCard(String label, String val, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: VE.bgCard,
      borderRadius: BorderRadius.circular(VE.r24),
      border: Border.all(color: VE.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: VE.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const Spacer(),
        Text(val, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: VE.fontMono)),
      ],
    ),
  );

  Widget _cachePanel(Map c) {
    return _panel('Memory Cache', Column(
      children: [
        _cacheRow('Hits', c['hits']?.toString() ?? '0', VE.emerald),
        _cacheRow('Misses', c['misses']?.toString() ?? '0', VE.pink),
        _cacheRow('Evictions', c['evicts']?.toString() ?? '0', VE.orange),
        _cacheRow('Size', '${c['size'] ?? 0} keys', VE.blue),
      ],
    ), icon: Icons.bolt_rounded, accent: VE.blue);
  }

  Widget _cacheRow(String label, String val, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(color: VE.textDim, fontSize: 13)),
      const Spacer(),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontFamily: VE.fontMono, fontSize: 13)),
    ]),
  );

  Widget _panel(String title, Widget child, {IconData? icon, Color? accent}) {
    return Container(
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(VE.r24),
        border: Border.all(color: VE.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 16, color: accent ?? VE.blue), const SizedBox(width: 8)],
            Text(title, style: const TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _recentPanel(String title, List items, Widget Function(Map) renderer) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _panel(title, Column(children: items.map((i) => renderer(i as Map)).toList()), icon: Icons.history_rounded, accent: VE.textDim),
    );
  }

  Widget _renderRecentCrash(Map c) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(c['message'] ?? 'Unknown Error', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VE.pink, fontWeight: FontWeight.w700, fontSize: 12)),
    subtitle: Text('${c['device']} · v${c['app_version']}', style: const TextStyle(color: VE.textMuted, fontSize: 11)),
    trailing: Text(_relTime(c['created_at'].toString()), style: const TextStyle(color: VE.textMuted, fontSize: 10)),
  );

  Widget _usersPanel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<Api>().adminUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final users = snapshot.data!;
        return _panel('Latest Registrations', Column(
          children: users.map((u) => _renderUser(u)).toList(),
        ), icon: Icons.people_rounded, accent: VE.blue);
      },
    );
  }

  Widget _renderUser(Map u) {
    final handle = u['handle'];
    final isBanned = u['is_banned'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: VEAvatar(url: u['avatar_url'], seed: handle, size: 36, radius: 12),
      title: Text('@$handle', style: TextStyle(color: isBanned ? VE.pink : VE.text, fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text('Joined ${_relTime(u['created_at'].toString())}', style: const TextStyle(color: VE.textMuted, fontSize: 11)),
      trailing: IconButton(icon: const Icon(Icons.more_vert_rounded, color: VE.textMuted), onPressed: () => _userMenu(handle)),
    );
  }

  Future<void> _userMenu(String handle) async {
    final apiDel = context.read<Api>();
    final action = await showModalBottomSheet<String>(
      // ignore: use_build_context_synchronously
      context: context,
      backgroundColor: VE.bgElevated,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.delete_forever_rounded, color: VE.pink), title: const Text('Delete Account', style: TextStyle(color: VE.pink)), onTap: () => Navigator.pop(context, 'delete')),
        ]),
      ),
    );
    if (action == 'delete') {
      // ignore: use_build_context_synchronously
      if (await veConfirm(context, title: 'Delete @$handle?', body: 'Irreversible.', confirmLabel: 'Delete')) {
        await apiDel.adminDeleteUser(handle);
        _load();
      }
    }
  }

  Widget _marketingPanel(String title, IconData icon, Future<List<Map<String, dynamic>>> Function() fetcher, Future<void> Function(int) onDelete, VoidCallback onAdd) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetcher(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final items = snapshot.data!;
        return _panel(title, Column(children: [
          ...items.map((item) {
            final media = item['media_url'] ?? '';
            final link = item['link_url'] ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: media.isNotEmpty 
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: context.read<Api>().resolveUrl(media), width: 40, height: 40, fit: BoxFit.cover))
                : Container(width: 40, height: 40, decoration: BoxDecoration(color: VE.bgElevated, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: VE.textMuted)),
              title: Text(item['title'] ?? '', style: const TextStyle(color: VE.text, fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(link.isNotEmpty ? '🔗 $link' : (item['body'] ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VE.textMuted, fontSize: 11)),
              trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: VE.pink), onPressed: () => onDelete(item['id'])),
            );
          }),
          const SizedBox(height: 8),
          VEGhostButton(label: 'Add $title', icon: Icons.add_rounded, onPressed: onAdd),
        ]), icon: icon, accent: VE.indigo);
      },
    );
  }

  Future<void> _addAnnouncement() async {
    final api = context.read<Api>();
    final title = await _promptText('New Announcement', 'Title');
    if (title == null || title.isEmpty) return;
    final body = await _promptText('Body', 'Content');
    final link = await _promptText('Link', 'https://…');
    await api.adminCreateAnnouncement({'title': title, 'body': body ?? '', 'link_url': link ?? ''});
    _load();
  }

  Future<void> _addAd() async {
    final api = context.read<Api>();
    final title = await _promptText('New Ad', 'Title');
    if (title == null || title.isEmpty) return;
    final body = await _promptText('Body', 'Content');
    final link = await _promptText('Link', 'https://…');
    String mediaUrl = '';
    // ignore: use_build_context_synchronously
    if (await veConfirm(context, title: 'Add Banner?', body: 'Upload image?', confirmLabel: 'Upload', cancelLabel: 'Skip', icon: Icons.image_rounded)) {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) mediaUrl = await api.uploadFile(File(image.path));
    }
    await api.adminCreateAd({'title': title, 'body': body ?? '', 'link_url': link ?? '', 'media_url': mediaUrl});
    _load();
  }

  Future<String?> _promptText(String title, String hint) async {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(
      backgroundColor: VE.bgElevated,
      title: Text(title, style: const TextStyle(color: VE.text)),
      content: TextField(controller: c, decoration: InputDecoration(hintText: hint), style: const TextStyle(color: VE.text)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Submit')),
      ],
    ));
  }

  Future<void> _deleteAnnouncement(int id) async { await context.read<Api>().adminDeleteAnnouncement(id); _load(); }
  Future<void> _deleteAd(int id) async { await context.read<Api>().adminDeleteAd(id); _load(); }

  String _relTime(String s) {
    final dt = DateTime.tryParse(s)?.toLocal() ?? DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ---- Posts Tab ----

  Widget _postsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<Api>().adminArchivedPosts(),
      builder: (ctx, snap) {
        final posts = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _panel('Archived Posts (${posts.length})', Column(children: [
              if (posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No archived posts.', style: TextStyle(color: VE.textMuted, fontSize: 13)),
                ),
              ...posts.map((p) {
                final id = (p['id'] as num).toInt();
                final handle = p['handle'] as String? ?? '';
                final kind = p['kind'] as String? ?? '';
                final title = p['title'] as String? ?? '';
                final body = p['body'] as String? ?? '';
                final likes = p['likes'] ?? 0;
                final comments = p['comments'] ?? 0;
                final createdAt = p['created_at'] as String? ?? '';
                final archivedAt = p['archived_at'] as String? ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    title.isNotEmpty ? title : (body.isNotEmpty ? body.substring(0, body.length.clamp(0, 60)).replaceAll('\n', ' ') : '$kind post'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: VE.text, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    '@$handle · ♥$likes 💬$comments · created ${_relTime(createdAt)} · archived ${_relTime(archivedAt)}',
                    style: const TextStyle(color: VE.textMuted, fontSize: 10),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.unarchive_rounded, size: 18, color: VE.emerald),
                    tooltip: 'Restore',
                    onPressed: () async {
                      await context.read<Api>().adminRestoreArchivedPost(id);
                      if (mounted) setState(() {});
                    },
                  ),
                );
              }),
            ]), icon: Icons.archive_rounded, accent: VE.orange),
          ],
        );
      },
    );
  }

  // ---- Server Tab ----

  Widget _serversTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: context.read<Api>().adminSystemStats(),
      builder: (ctx, snap) {
        final stats = snap.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _serverStatsPanel(stats),
            const SizedBox(height: 16),
            _sessionsPanel(),
            const SizedBox(height: 16),
            _uploadsPanel(),
          ],
        );
      },
    );
  }

  Widget _serverStatsPanel(Map stats) {
    Widget row(String label, String val, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: VE.textDim, fontSize: 12)),
        const Spacer(),
        Text(val, style: TextStyle(color: color ?? VE.text, fontWeight: FontWeight.w700, fontFamily: VE.fontMono, fontSize: 12)),
      ]),
    );

    String fmtBytes(int b) {
      if (b < 1024) return '${b}B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
      if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
      return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
    }

    final ramTotal = (stats['ram_total'] as num?)?.toInt() ?? 0;
    final ramAvail = (stats['ram_available'] as num?)?.toInt() ?? 0;
    final ramUsed = ramTotal - ramAvail;
    final ramPct = ramTotal > 0 ? (ramUsed / ramTotal * 100).toStringAsFixed(1) : '?';

    final diskTotal = (stats['disk_total'] as num?)?.toInt() ?? 0;
    final diskUsed = (stats['disk_used'] as num?)?.toInt() ?? 0;
    final diskAvail = (stats['disk_available'] as num?)?.toInt() ?? 0;

    final load1 = (stats['load_1m'] as num?)?.toDouble() ?? 0;
    final load5 = (stats['load_5m'] as num?)?.toDouble() ?? 0;
    final load15 = (stats['load_15m'] as num?)?.toDouble() ?? 0;

    final uptime = (stats['uptime_seconds'] as num?)?.toInt() ?? 0;
    final days = uptime ~/ 86400;
    final hours = (uptime % 86400) ~/ 3600;

    final processes = stats['processes'] ?? '?';
    final network = (stats['network'] as Map?) ?? {};

    return _panel('Server Hardware', Column(children: [
      row('RAM', '${fmtBytes(ramUsed)} / ${fmtBytes(ramTotal)} ($ramPct%)', color: VE.blue),
      row('Disk', '${fmtBytes(diskUsed)} / ${fmtBytes(diskTotal)}', color: VE.emerald),
      row('Available', fmtBytes(diskAvail), color: VE.emerald),
      row('CPU Load', '$load1 / $load5 / $load15', color: VE.orange),
      row('Processes', '$processes', color: VE.textDim),
      row('Uptime', '${days}d ${hours}h', color: VE.textDim),
      if (network.isNotEmpty) ...[
        Divider(height: 20, color: VE.border),
        ...network.entries.map((e) {
          final iface = e.value as Map;
          final rx = (iface['rx_bytes'] as num?)?.toInt() ?? 0;
          final tx = (iface['tx_bytes'] as num?)?.toInt() ?? 0;
          return row(e.key, '⬇${fmtBytes(rx)} ⬆${fmtBytes(tx)}', color: VE.cyan);
        }),
      ],
    ]), icon: Icons.monitor_heart_rounded, accent: VE.blue);
  }

  Widget _sessionsPanel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<Api>().adminSessions(),
      builder: (ctx, snap) {
        final sessions = snap.data ?? [];
        return _panel('Active Sessions (${sessions.length})', Column(children: [
          ...sessions.take(20).map((s) {
            final id = (s['id'] as num?)?.toInt() ?? 0;
            final handle = s['handle'] as String? ?? '';
            final device = s['device_id'] as String? ?? '';
            final ver = s['app_version'] as String? ?? '';
            final lastSeen = _relTime(s['last_seen'] as String? ?? '');
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(handle.isNotEmpty ? '@$handle' : 'anon',
                  style: const TextStyle(color: VE.text, fontWeight: FontWeight.w700, fontSize: 12)),
              subtitle: Text('$device · v$ver',
                  style: const TextStyle(color: VE.textMuted, fontSize: 10)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lastSeen, style: const TextStyle(color: VE.textMuted, fontSize: 10)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 16, color: VE.pink),
                    onPressed: () async {
                      await context.read<Api>().adminKickSession(id);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            );
          }),
        ]), icon: Icons.devices_rounded, accent: VE.purple);
      },
    );
  }

  Widget _uploadsPanel() {
    final searchCtrl = TextEditingController();
    return StatefulBuilder(builder: (ctx, setLocal) {
      return FutureBuilder<Map<String, dynamic>>(
        future: context.read<Api>().adminUploads(),
        builder: (ctx2, snap) {
          final uploads = ((snap.data?['uploads'] as List?) ?? []).cast<Map<String, dynamic>>();
          return _panel('Uploads (${uploads.length})', Column(children: [
            TextField(
              controller: searchCtrl,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: VE.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search uploads...',
                hintStyle: const TextStyle(color: VE.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: VE.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setLocal(() {}),
            ),
            const SizedBox(height: 8),
            ...uploads.where((u) {
              if (searchCtrl.text.isEmpty) return true;
              final name = (u['name'] as String? ?? '').toLowerCase();
              return name.contains(searchCtrl.text.toLowerCase());
            }).take(30).map((u) {
              final name = u['name'] as String? ?? '';
              final size = (u['size'] as num?)?.toInt() ?? 0;
              final url = u['url'] as String? ?? '';
              String fmtSize(int b) {
                if (b < 1024) return '${b}B';
                if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
                return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
              }
              final isImage = RegExp(r'\.(jpg|jpeg|png|webp|gif)$', caseSensitive: false).hasMatch(name);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(context.read<Api>().resolveUrl(url),
                            width: 36, height: 36, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 36, height: 36, color: VE.bgElevated, child: const Icon(Icons.image_rounded, size: 16, color: VE.textMuted))),
                      )
                    : Container(width: 36, height: 36, color: VE.bgElevated, child: const Icon(Icons.insert_drive_file_rounded, size: 16, color: VE.textMuted)),
                title: Text(name, style: const TextStyle(color: VE.text, fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: Text(fmtSize(size), style: const TextStyle(color: VE.textMuted, fontSize: 10)),
              );
            }),
          ]), icon: Icons.cloud_upload_rounded, accent: VE.cyan);
        },
      );
    });
  }
}
