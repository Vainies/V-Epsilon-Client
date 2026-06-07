import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'extension_runtime.dart';

enum VEThemeMode { oled, zinc, midnight, pink, custom }

class VETheme extends ChangeNotifier {
  VEThemeMode _mode = VEThemeMode.oled;
  VEThemeMode get mode => _mode;

  static final VETheme I = VETheme._();
  VETheme._();

  // Custom color overrides (from Customizer or theme extensions)
  final Map<String, String> _overrides = {};

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final m = sp.getString('theme_mode');
    if (m != null) {
      _mode = VEThemeMode.values.firstWhere((e) => e.name == m, orElse: () => VEThemeMode.oled);
    }
    loadOverrides();
  }

  void loadOverrides() {
    _overrides.clear();
    // Load customizer overrides
    final customRaw = ExtensionRuntime.I.data('customizer');
    if (customRaw != null) {
      final theme = customRaw['theme'] as Map<String, dynamic>?;
      if (theme != null) {
        for (final e in theme.entries) {
          if (e.value is String && (e.value as String).startsWith('#')) {
            _overrides[e.key] = e.value as String;
          }
        }
      }
    }
    // Load all installed theme extensions
    for (final id in ExtensionRuntime.I.installed) {
      if (id == 'customizer') continue;
      final d = ExtensionRuntime.I.data(id);
      if (d == null) continue;
      if (d['type'] != 'theme') continue;
      final theme = d['theme'] as Map<String, dynamic>?;
      if (theme == null) continue;
      for (final e in theme.entries) {
        if (e.value is String && (e.value as String).startsWith('#')) {
          _overrides[e.key] = e.value as String;
        }
      }
    }
  }

  Color _c(String key, Color fallback) {
    final v = _overrides[key];
    if (v != null && v.startsWith('#')) {
      final hex = v.substring(1);
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    }
    return fallback;
  }

  Future<void> setMode(VEThemeMode m) async {
    _mode = m;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString('theme_mode', m.name);
  }

  Future<void> setOverrides(Map<String, String> overrides) async {
    _overrides.addAll(overrides);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('custom_theme', _overrides.entries.map((e) => '${e.key}=${e.value}').join('|'));
    notifyListeners();
  }

  Future<void> clearOverrides() async {
    _overrides.clear();
    final sp = await SharedPreferences.getInstance();
    await sp.remove('custom_theme');
    notifyListeners();
  }

  void refresh() => notifyListeners();

  Color get bg => _c('bg', switch (_mode) {
    VEThemeMode.oled => const Color(0xFF000000),
    VEThemeMode.zinc => const Color(0xFF18181B),
    VEThemeMode.midnight => const Color(0xFF0F172A),
    VEThemeMode.pink => const Color(0xFF1C0A14),
    VEThemeMode.custom => const Color(0xFF000000),
  });

  Color get bgCard => _c('bgCard', switch (_mode) {
    VEThemeMode.oled => const Color(0xFF000000),
    VEThemeMode.zinc => const Color(0xFF27272A),
    VEThemeMode.midnight => const Color(0xFF1E293B),
    VEThemeMode.pink => const Color(0xFF2D1424),
    VEThemeMode.custom => const Color(0xFF000000),
  });

  Color get border => _c('border', switch (_mode) {
    VEThemeMode.oled => const Color(0xFF1F1F22),
    VEThemeMode.zinc => const Color(0xFF3F3F46),
    VEThemeMode.midnight => const Color(0xFF334155),
    VEThemeMode.pink => const Color(0xFF4A2040),
    VEThemeMode.custom => const Color(0xFF1F1F22),
  });

  Color get accent => _c('blue', const Color(0xFF3B82F6));
  Color get textCustom => _c('text', const Color(0xFFFAFAFA));

  String _fontFamily = 'Inter';
  String get fontFamily => _fontFamily;
  set fontFamily(String v) {
    _fontFamily = v;
    notifyListeners();
  }

  double _borderRadius = 12.0;
  double get borderRadius => _borderRadius;
  set borderRadius(double v) {
    _borderRadius = v;
    notifyListeners();
  }

  static const textDim = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF52525B);
  static const textFaint = Color(0xFF3F3F46);

  static const cyan = Color(0xFF06B6D4);
  static const pink = Color(0xFFEC4899);
  static const emerald = Color(0xFF10B981);
  static const purple = Color(0xFFA855F7);
  static const orange = Color(0xFFF97316);
  static const yellow = Color(0xFFFACC15);
  static const indigo = Color(0xFF6366F1);
  static const red = Color(0xFFEF4444);

  ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      surface: bg,
      primary: accent,
      secondary: cyan,
      error: red,
    ),
    fontFamily: fontFamily,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w900, fontSize: 20, color: accent),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bgCard,
      contentTextStyle: TextStyle(color: textCustom, fontSize: 13, fontFamily: fontFamily),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius * 1.33),
        side: BorderSide(color: border),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      elevation: 0,
    ),
  );
}

class VE {
  static Color get bg => VETheme.I.bg;
  static Color get bgCard => VETheme.I.bgCard;
  static Color get bgElevated => VETheme.I.bgCard;
  static Color get border => VETheme.I.border;

  static const borderStrong = Color(0xFF303034);
  static const text = Color(0xFFFAFAFA);
  static const textDim = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF52525B);
  static const textFaint = Color(0xFF3F3F46);

  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF06B6D4);
  static const pink = Color(0xFFEC4899);
  static const emerald = Color(0xFF10B981);
  static const purple = Color(0xFFA855F7);
  static const orange = Color(0xFFF97316);
  static const yellow = Color(0xFFFACC15);
  static const indigo = Color(0xFF6366F1);
  static const red = Color(0xFFEF4444);

  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r24 = 24.0;
  static const r32 = 32.0;

  static const fontSans = 'Inter';
  static const fontMono = 'Inter';
}

const kVECurve = Cubic(0.16, 1, 0.3, 1);
