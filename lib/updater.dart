import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Semver-ish comparison. Accepts "1.2.3"; pads missing parts with 0.
int compareVersions(String a, String b) {
  List<int> parse(String s) => s.split('.').map((p) => int.tryParse(p.split('-')[0]) ?? 0).toList();
  final pa = parse(a);
  final pb = parse(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

class ReleaseInfo {
  final String version;
  final int build;
  final String apkUrl;
  final int apkSize;
  final String releaseNotes;
  final List<String> badVersions;
  final String requiredVersion;
  final bool isEmergency;

  ReleaseInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.apkSize,
    required this.releaseNotes,
    this.badVersions = const [],
    this.requiredVersion = '',
    this.isEmergency = false,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> j) => ReleaseInfo(
        version: (j['version'] ?? '0.0.0') as String,
        build: (j['build'] as num?)?.toInt() ?? 0,
        apkUrl: (j['apk_url'] ?? '') as String,
        apkSize: (j['apk_size'] as num?)?.toInt() ?? 0,
        releaseNotes: (j['release_notes'] ?? '') as String,
        badVersions: ((j['bad_versions'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        requiredVersion: (j['required_version'] ?? '') as String,
        isEmergency: (j['emergency'] as bool?) ?? false,
      );
}

class Updater {
  final String baseUrl;
  Updater(this.baseUrl);

  /// Returns remote release info if an update is available, null if up-to-date.
  /// Also returns info if the current version is marked bad (forced update).
  /// Only actually runs on Android; returns null elsewhere.
  Future<ReleaseInfo?> check([bool betaMode = false]) async {
    if (!Platform.isAndroid) return null;
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;
      final url = betaMode ? '$baseUrl/api/v1/app/version?beta_mode=true' : '$baseUrl/api/v1/app/version';
      final res = await http
          .get(Uri.parse(url))
          .timeout( const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final info = ReleaseInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      if (info.version.isEmpty || info.version == '0.0.0') return null;
      // If current is flagged as bad AND remote has a different version, force update.
      if (info.badVersions.contains(current) && info.version != current) {
        return info;
      }
      
      // If required_version is set and current is below it, force update.
      if (info.requiredVersion.isNotEmpty && compareVersions(current, info.requiredVersion) < 0) {
        return info;
      }
      
      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
      final cmp = compareVersions(info.version, current);
      if (cmp < 0) return null;
      if (cmp == 0 && info.build <= currentBuild) return null;
      
      return info;
    } catch (e) {
      if (kDebugMode) debugPrint('[updater] check failed: $e');
      return null;
    }
  }

  /// Returns true if the currently installed version is on the bad list.
  Future<bool> currentVersionIsBad([bool betaMode = false]) async {
    if (!Platform.isAndroid) return false;
    try {
      final pkg = await PackageInfo.fromPlatform();
      final url = betaMode ? '$baseUrl/api/v1/app/version?beta_mode=true' : '$baseUrl/api/v1/app/version';
      final res = await http
          .get(Uri.parse(url))
          .timeout( const Duration(seconds: 6));
      if (res.statusCode != 200) return false;
      final info = ReleaseInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      return info.badVersions.contains(pkg.version);
    } catch (_) {
      return false;
    }
  }

  /// Download APK with progress. Returns file path on success, null on failure.
  Future<String?> download(
    ReleaseInfo info, {
    required void Function(double progress, int received, int total) onProgress,
  }) async {
    try {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/v-epsilon-${info.version}.apk');
      if (await file.exists()) await file.delete();

      final url = info.apkUrl.startsWith('http') ? info.apkUrl : '$baseUrl${info.apkUrl}';
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      // Keep connection alive: server uses 60s write timeout now
      req.headers['Connection'] = 'keep-alive';
      final resp = await client.send(req).timeout( const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        client.close();
        return null;
      }

      final total = resp.contentLength ?? info.apkSize;
      final sink = file.openWrite();
      int received = 0;
      DateTime lastProgress = DateTime.now();
      await for (final chunk in resp.stream) {
        received += chunk.length;
        sink.add(chunk);
        // Throttle progress updates to every 200ms so UI doesn't rebuild 10k times
        final now = DateTime.now();
        if (now.difference(lastProgress).inMilliseconds >= 200 || received == total) {
          onProgress(total > 0 ? received / total : 0, received, total);
          lastProgress = now;
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      // Verify file size
      final size = await file.length();
      if (info.apkSize > 0 && size < info.apkSize - 1024) {
        // Incomplete - likely dropped connection
        if (kDebugMode) debugPrint('[updater] incomplete: got $size / ${info.apkSize}');
        return null;
      }
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[updater] download failed: $e');
      return null;
    }
  }

  /// Open the downloaded APK in Android package installer.
  /// Requests install permission if needed.
  Future<bool> install(String apkPath) async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final req = await Permission.requestInstallPackages.request();
        if (!req.isGranted) return false;
      }
    }
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    return result.type == ResultType.done;
  }

  /// Clean up old downloaded APK files from app data directory.
  /// Should be called at startup after a successful update.
  Future<void> cleanup() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final dir = (await getExternalStorageDirectory()) ?? (await getApplicationDocumentsDirectory());
      if (!await dir.exists()) return;
      final files = await dir.list().toList();
      for (final f in files) {
        if (f is! File) continue;
        final name = f.path.split('/').last;
        if (name.startsWith('v-epsilon-') && name.endsWith('.apk') && !name.contains(pkg.version)) {
          await f.delete();
          if (kDebugMode) debugPrint('[updater] cleaned: $name');
        }
      }
    } catch (_) {}
  }
}
