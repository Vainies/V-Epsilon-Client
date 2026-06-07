import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavMode { iconsLabels, labelsOnly, hidden }

enum PostCardStyle { bordered, flat, none }

enum AvatarShape { circle, roundedSquare }

class FeatureConfig extends ChangeNotifier {
  static final FeatureConfig I = FeatureConfig._();
  FeatureConfig._();

  NavMode _navMode = NavMode.iconsLabels;
  NavMode get navMode => _navMode;

  bool _showHome = true;
  bool _showReposts = true;
  bool _showComms = true;
  bool _showProfile = true;
  bool _showFab = true;
  bool _showBannerOverlay = true;
  bool _showIcons = true;

  bool get showHome => _showHome;
  bool get showReposts => _showReposts;
  bool get showComms => _showComms;
  bool get showProfile => _showProfile;
  bool get showFab => _showFab;
  bool get showBannerOverlay => _showBannerOverlay;
  bool get showIcons => _showIcons;

  PostCardStyle _postCardStyle = PostCardStyle.bordered;
  PostCardStyle get postCardStyle => _postCardStyle;

  AvatarShape _avatarShape = AvatarShape.circle;
  AvatarShape get avatarShape => _avatarShape;

  double _avatarSize = 40.0;
  double get avatarSize => _avatarSize;

  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  String _fontFamily = 'Inter';
  String get fontFamily => _fontFamily;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _navMode = _parseNav(sp.getString('fc_nav_mode') ?? '');
    _showHome = sp.getBool('fc_show_home') ?? true;
    _showReposts = sp.getBool('fc_show_reposts') ?? true;
    _showComms = sp.getBool('fc_show_comms') ?? true;
    _showProfile = sp.getBool('fc_show_profile') ?? true;
    _showFab = sp.getBool('fc_show_fab') ?? true;
    _showBannerOverlay = sp.getBool('fc_banner_overlay') ?? true;
    _showIcons = sp.getBool('fc_show_icons') ?? true;
    _postCardStyle = _parseCardStyle(sp.getString('fc_post_card_style') ?? '');
    _avatarShape = _parseAvatarShape(sp.getString('fc_avatar_shape') ?? '');
    _avatarSize = sp.getDouble('fc_avatar_size') ?? 40.0;
    _fontScale = sp.getDouble('fc_font_scale') ?? 1.0;
    _fontFamily = sp.getString('fc_font_family') ?? 'Inter';
  }

  NavMode _parseNav(String s) {
    return NavMode.values.firstWhere((e) => e.name == s, orElse: () => NavMode.iconsLabels);
  }

  PostCardStyle _parseCardStyle(String s) {
    return PostCardStyle.values.firstWhere((e) => e.name == s, orElse: () => PostCardStyle.bordered);
  }

  AvatarShape _parseAvatarShape(String s) {
    return AvatarShape.values.firstWhere((e) => e.name == s, orElse: () => AvatarShape.circle);
  }

  Future<void> _save(String key, dynamic value) async {
    final sp = await SharedPreferences.getInstance();
    if (value is String) await sp.setString(key, value);
    else if (value is bool) await sp.setBool(key, value);
    else if (value is double) await sp.setDouble(key, value);
    notifyListeners();
  }

  Future<void> setNavMode(NavMode v) async { _navMode = v; await _save('fc_nav_mode', v.name); }
  Future<void> setTabVisibility(String tab, bool v) async {
    switch (tab) {
      case 'home': _showHome = v; break;
      case 'reposts': _showReposts = v; break;
      case 'comms': _showComms = v; break;
      case 'profile': _showProfile = v; break;
    }
    await _save('fc_show_$tab', v);
  }
  Future<void> setShowFab(bool v) async { _showFab = v; await _save('fc_show_fab', v); }
  Future<void> setShowBannerOverlay(bool v) async { _showBannerOverlay = v; await _save('fc_banner_overlay', v); }
  Future<void> setShowIcons(bool v) async { _showIcons = v; await _save('fc_show_icons', v); }
  Future<void> setPostCardStyle(PostCardStyle v) async { _postCardStyle = v; await _save('fc_post_card_style', v.name); }
  Future<void> setAvatarShape(AvatarShape v) async { _avatarShape = v; await _save('fc_avatar_shape', v.name); }
  Future<void> setAvatarSize(double v) async { _avatarSize = v; await _save('fc_avatar_size', v); }
  Future<void> setFontScale(double v) async { _fontScale = v; await _save('fc_font_scale', v); }
  Future<void> setFontFamily(String v) async {
    _fontFamily = v;
    await _save('fc_font_family', v);
  }
}
