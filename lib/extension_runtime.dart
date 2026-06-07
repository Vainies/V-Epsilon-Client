import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _installedKey = 'ext_installed';
const _dataPrefix = 'ext_data_';

class ExtensionRuntime extends ChangeNotifier {
  static final ExtensionRuntime I = ExtensionRuntime._();
  ExtensionRuntime._();

  final Set<String> _installed = {};
  final Map<String, Map<String, dynamic>> _data = {};

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_installedKey) ?? [];
    _installed.addAll(raw);
    for (final id in _installed) {
      final d = sp.getString(_dataPrefix + id);
      if (d != null) {
        _data[id] = jsonDecode(d) as Map<String, dynamic>;
      }
    }
  }

  bool isInstalled(String id) => _installed.contains(id);

  Set<String> get installed => Set.unmodifiable(_installed);

  Map<String, dynamic>? data(String id) => _data[id];

  Future<void> install(String id, Map<String, dynamic> data) async {
    _installed.add(id);
    _data[id] = data;
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_installedKey, _installed.toList());
    await sp.setString(_dataPrefix + id, jsonEncode(data));
    notifyListeners();
  }

  Future<void> uninstall(String id) async {
    _installed.remove(id);
    _data.remove(id);
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_installedKey, _installed.toList());
    await sp.remove(_dataPrefix + id);
    notifyListeners();
  }
}

String? extThemeValue(String id, String key) {
  final d = ExtensionRuntime.I.data(id);
  if (d == null) return null;
  final theme = d['theme'] as Map<String, dynamic>?;
  if (theme == null) return null;
  return theme[key] as String?;
}

Color? extThemeColor(String id, String key) {
  final v = extThemeValue(id, key);
  if (v == null || !v.startsWith('#')) return null;
  final hex = v.substring(1);
  if (hex.length == 6) {
    return Color(int.parse('FF$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return null;
}
