import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../models.dart';
import '../extension_runtime.dart';
import '../feature_config.dart';
import '../push_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppUser? _me;
  bool _loading = true;
  bool _busy = false;
  String? _msg;
  String? _pendingAvatarPath;
  String? _pendingBannerPath;
  String? _pendingBgPath;

  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _status = TextEditingController();
  final _email = TextEditingController();
  final _currentPass = TextEditingController();
  final _newPass = TextEditingController();

  @override
  void dispose() {
    _name.dispose(); _bio.dispose(); _status.dispose(); _email.dispose();
    _currentPass.dispose(); _newPass.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await context.read<Api>().me();
      if (!mounted) return;
      setState(() {
        _me = me; _loading = false;
        _name.text = me.name; _bio.text = me.bio; _status.text = me.status;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _flash(String m) {
    setState(() => _msg = m);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _msg == m) setState(() => _msg = null);
    });
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Settings',
            style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: VE.blue, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
              children: [
                if (_msg != null) _flashBanner(),
                _profileCard(),
                const SizedBox(height: 24),
                _section('Privacy', _privacyTiles()),
                _section('Notifications', _notifTiles()),
                _section('Security', _securityFields(), collapsed: true),
                _section('Appearance', _appearanceTiles(), collapsed: true),
                _section('Layout', _layoutTiles(), collapsed: true),
                if (_me?.isMod == true || _me?.isAdmin == true)
                  _section('Mods', [_customizerModCard()]),
                _section('Epsilon', [..._epsilonTiles(), _exportTile(), _privacyPolicyTile()], collapsed: true),
                const SizedBox(height: 20),
                _deleteCard(),
              ],
            ),
    );
  }

  Widget _profileCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: VE.bgCard,
      borderRadius: BorderRadius.circular(VE.r24),
      border: Border.all(color: VE.border),
    ),
    child: Column(
      children: [
        if (_pendingBannerPath != null || (_me?.bannerUrl.isNotEmpty ?? false))
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VE.r16),
              image: DecorationImage(
                image: _pendingBannerPath != null
                    ? FileImage(File(_pendingBannerPath!))
                    : NetworkImage(_me!.bannerUrl) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Row(
          children: [
            Stack(
              children: [
                VEAvatar(
                  url: _pendingAvatarPath ?? _me?.avatarUrl,
                  seed: _me?.handle ?? '',
                  size: 56, radius: 18,
                ),
                if (_pendingAvatarPath != null)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: VE.emerald, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_me?.name ?? 'User', style: const TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('@${_me?.handle ?? "handle"}', style: const TextStyle(color: VE.textMuted, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: _pickAvatar,
              icon: const Icon(Icons.edit_rounded, color: VE.blue, size: 20),
              style: IconButton.styleFrom(backgroundColor: VE.blue.withValues(alpha: 0.1)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, style: const TextStyle(color: VE.text, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: VE.fontSans),
          decoration: const InputDecoration(labelText: 'Display name', labelStyle: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontSans), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isCollapsed: true)),
        const SizedBox(height: 12),
        TextField(controller: _status, style: const TextStyle(color: VE.blue, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: VE.fontSans),
          decoration: const InputDecoration(labelText: 'Status / role', labelStyle: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontSans), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isCollapsed: true)),
        const SizedBox(height: 12),
        TextField(controller: _bio, maxLines: 3, style: const TextStyle(color: VE.text, fontSize: 14, height: 1.5, fontFamily: VE.fontSans),
          decoration: const InputDecoration(labelText: 'Bio', labelStyle: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontSans), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isCollapsed: true)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: VEPrimaryButton(label: _busy ? 'SAVING...' : 'UPDATE PROFILE', onPressed: _busy ? null : _saveProfile),
            ),
            const SizedBox(width: 10),
            VEGhostButton(label: 'BANNER', icon: Icons.panorama_rounded, onPressed: _busy ? null : _pickBanner),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: VEGhostButton(label: 'BG IMAGE',
                  icon: Icons.wallpaper_rounded, onPressed: _busy ? null : _pickProfileBg),
            ),
            if (_pendingBgPath != null || (_me?.profileBgUrl.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: VEGhostButton(label: 'CLEAR', icon: Icons.close_rounded, onPressed: _busy ? null : () {
                  setState(() => _pendingBgPath = '');
                }),
              ),
          ],
        ),
        if (_pendingBannerPath != null || _pendingAvatarPath != null || _pendingBgPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Preview shown — save to apply changes',
                style: const TextStyle(color: VE.emerald, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
      ],
    ),
  );

  Widget _flashBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: VE.emerald.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(VE.r16),
      border: Border.all(color: VE.emerald.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: VE.emerald, size: 16),
        const SizedBox(width: 10),
        Text(_msg ?? '', style: const TextStyle(color: VE.emerald, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  final Set<String> _collapsed = {};

  Widget _section(String title, List<Widget> children, {bool collapsed = false}) {
    final isCollapsed = collapsed && _collapsed.contains(title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: collapsed ? () => setState(() {
              if (!_collapsed.remove(title)) _collapsed.add(title);
            }) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: VE.textMuted)),
                  ),
                  if (collapsed)
                    Icon(isCollapsed ? Icons.chevron_right_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16, color: VE.textMuted),
                ],
              ),
            ),
          ),
          if (!isCollapsed) ...children,
        ],
      ),
    );
  }

  // -- Privacy --
  List<Widget> _privacyTiles() {
    Future<void> toggle(String key, bool v) async {
      setState(() => _busy = true);
      try {
        await context.read<Api>().updateMe({key: v});
        await _load();
        _flash('Privacy updated');
      } catch (e) { _flash('Failed: $e'); }
      finally { if (mounted) setState(() => _busy = false); }
    }
    return [
      _switchTile('Private profile', 'Hide bio from non-followers', _me?.privacyProfile ?? false, (v) => toggle('privacy_profile', v)),
      _switchTile('Private posts', 'Only followers see your feed', _me?.privacyPosts ?? false, (v) => toggle('privacy_posts', v)),
      _switchTile('Hide interactions', 'Likes/reposts on profile', _me?.privacyLikes ?? false, (v) => toggle('privacy_likes', v)),
      _switchTile('Hide followers', 'Follower counts hidden', _me?.privacyFollowers ?? false, (v) => toggle('privacy_followers', v)),
      _switchTile('Hide reposts tab', 'Remove reposts from your profile', _me?.hideReposts ?? false, (v) => toggle('hide_reposts', v)),
    ];
  }

  // -- Security --
  List<Widget> _securityFields() => [
    TextField(controller: _currentPass, obscureText: true, decoration: const InputDecoration(labelText: 'Current password', labelStyle: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontSans), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isCollapsed: true),
      style: const TextStyle(color: VE.text, fontFamily: VE.fontSans)),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: TextField(controller: _newPass, obscureText: true, decoration: const InputDecoration(labelText: 'New password', labelStyle: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontSans), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isCollapsed: true),
        style: const TextStyle(color: VE.text, fontFamily: VE.fontSans))),
      const SizedBox(width: 10),
      VEGhostButton(label: 'CHANGE', icon: Icons.lock_reset_rounded, onPressed: _busy ? null : _changePass),
    ]),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Recovery email', labelStyle: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: VE.fontSans), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isCollapsed: true),
        style: const TextStyle(color: VE.text, fontFamily: VE.fontSans))),
      const SizedBox(width: 10),
      VEGhostButton(label: 'SAVE', icon: Icons.alternate_email_rounded, onPressed: _busy ? null : _saveEmail),
    ]),
  ];

  // -- Notifications --
  List<Widget> _notifTiles() => [
    _switchTileNotif('Likes', 'likes'),
    _switchTileNotif('Comments', 'comments'),
    _switchTileNotif('New followers', 'follows'),
    _switchTileNotif('System updates', 'updates'),
  ];

  Widget _switchTileNotif(String title, String key) {
    return StatefulBuilder(builder: (ctx, setLocal) {
      return _switchTile(title, null, _boolForKey(key), (v) async {
        await PushService.I.setCategory(key, v);
        setLocal(() {});
      });
    });
  }

  bool _boolForKey(String key) {
    switch (key) {
      case 'likes': return PushService.I.likesOn;
      case 'comments': return PushService.I.commentsOn;
      case 'follows': return PushService.I.followsOn;
      case 'updates': return PushService.I.updatesOn;
      default: return false;
    }
  }

  // -- Switches --
  Widget _switchTile(String title, String? subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: VE.text, fontSize: 13, fontWeight: FontWeight.w800)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: VE.textMuted, fontSize: 11)) : null,
      value: value, activeColor: VE.blue, contentPadding: EdgeInsets.zero, dense: true,
      onChanged: onChanged,
    );
  }

  // -- Appearance --
  double _bgOpacity = 0.5;
  Color _bgBackColor = const Color(0xFF000000);
  final _themeNameCtrl = TextEditingController();

  void _loadBgPrefs() {
    final p = ExtensionRuntime.I.data('bg_prefs');
    _bgOpacity = (p?['opacity'] as num?)?.toDouble() ?? 0.5;
    final hex = p?['backColor'] as String?;
    if (hex != null && hex.startsWith('#')) {
      _bgBackColor = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
    _themeNameCtrl.text = (p?['themeName'] as String?) ?? '';
  }

  Future<void> _saveBgPrefs() async {
    final data = <String, dynamic>{
      'opacity': _bgOpacity,
      'backColor': '#${_bgBackColor.toARGB32().toRadixString(16).substring(2).toUpperCase().padLeft(6, '0')}',
      'themeName': _themeNameCtrl.text,
    };
    await ExtensionRuntime.I.install('bg_prefs', data);
  }

  List<Widget> _appearanceTiles() => [
    Consumer<VETheme>(builder: (ctx, theme, _) => Column(
      children: [
        _themeRow(ctx, theme, VEThemeMode.oled, 'OLED Black'),
        _themeRow(ctx, theme, VEThemeMode.zinc, 'Deep Zinc'),
        _themeRow(ctx, theme, VEThemeMode.midnight, 'Midnight'),
        _themeRow(ctx, theme, VEThemeMode.pink, 'PINKY'),
        if (ExtensionRuntime.I.isInstalled('customizer'))
          _themeRow(ctx, theme, VEThemeMode.custom, 'Custom'),
      ],
    )),
    Divider(height: 20, color: VE.border),
    Row(
      children: [
        const Text('BG opacity', style: TextStyle(color: VE.textDim, fontSize: 12)),
        Expanded(
          child: Slider(
            value: _bgOpacity, min: 0.0, max: 1.0,
            activeColor: VE.blue, inactiveColor: VE.border,
            onChanged: (v) {
              setState(() => _bgOpacity = v);
              _saveBgPrefs();
            },
          ),
        ),
        Text('${(_bgOpacity * 100).round()}%', style: const TextStyle(color: VE.textMuted, fontSize: 11, fontFamily: VE.fontMono)),
      ],
    ),
    Row(
      children: [
        const Text('BG back color', style: TextStyle(color: VE.textDim, fontSize: 12)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final picked = await showDialog<Color>(
              context: context,
              builder: (ctx) => _ColorPickerDialog(current: _bgBackColor, title: 'Back color'),
            );
            if (picked != null) {
              setState(() => _bgBackColor = picked);
              _saveBgPrefs();
            }
          },
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _bgBackColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VE.border),
            ),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _layoutTiles() => [
    Consumer<FeatureConfig>(builder: (ctx, fc, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Navigation', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 4),
        _radioTile('Icons + Labels', NavMode.iconsLabels, fc.navMode, (v) => fc.setNavMode(v)),
        _radioTile('Labels only', NavMode.labelsOnly, fc.navMode, (v) => fc.setNavMode(v)),
        _radioTile('Hidden', NavMode.hidden, fc.navMode, (v) => fc.setNavMode(v)),
        const SizedBox(height: 4),
        if (fc.navMode == NavMode.iconsLabels)
          _switchTile('Show icons', null, fc.showIcons, (v) => fc.setShowIcons(v)),
        Divider(height: 16, color: VE.border),
        const Text('Tab Visibility', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 4),
        _switchTile('Home', null, fc.showHome, (v) => fc.setTabVisibility('home', v)),
        _switchTile('Reposts', null, fc.showReposts, (v) => fc.setTabVisibility('reposts', v)),
        _switchTile('Comms', null, fc.showComms, (v) => fc.setTabVisibility('comms', v)),
        _switchTile('Profile', null, fc.showProfile, (v) => fc.setTabVisibility('profile', v)),
        _switchTile('FAB (compose)', null, fc.showFab, (v) => fc.setShowFab(v)),
        Divider(height: 16, color: VE.border),
        const Text('Post Cards', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 4),
        _radioTile('Bordered', PostCardStyle.bordered, fc.postCardStyle, (v) => fc.setPostCardStyle(v)),
        _radioTile('Flat', PostCardStyle.flat, fc.postCardStyle, (v) => fc.setPostCardStyle(v)),
        _radioTile('None (no background)', PostCardStyle.none, fc.postCardStyle, (v) => fc.setPostCardStyle(v)),
        Divider(height: 16, color: VE.border),
        const Text('Avatar', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 4),
        _radioTile('Circle', AvatarShape.circle, fc.avatarShape, (v) => fc.setAvatarShape(v)),
        _radioTile('Rounded Square', AvatarShape.roundedSquare, fc.avatarShape, (v) => fc.setAvatarShape(v)),
        Row(children: [
          const Text('Avatar size', style: TextStyle(color: VE.textDim, fontSize: 12)),
          Expanded(child: Slider(value: fc.avatarSize, min: 28, max: 56, divisions: 7,
            activeColor: VE.blue, inactiveColor: VE.border,
            label: '${fc.avatarSize.round()}',
            onChanged: (v) => fc.setAvatarSize(v))),
          Text('${fc.avatarSize.round()}', style: const TextStyle(color: VE.textMuted, fontSize: 11, fontFamily: VE.fontMono)),
        ]),
        Divider(height: 16, color: VE.border),
        const Text('Scale', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 4),
        _slider('Font scale', (fc.fontScale * 100).round(), 80, 150, (v) => fc.setFontScale(v / 100)),
        _slider('Border radius', VETheme.I.borderRadius.round(), 4, 32, (v) { VETheme.I.borderRadius = v.toDouble(); }),
        const SizedBox(height: 8),
        _fontPicker(),
        _switchTile('Banner overlay', 'Show gradient darkening on profile banners', fc.showBannerOverlay, (v) => fc.setShowBannerOverlay(v)),
      ],
    )),
  ];

  Widget _radioTile<T>(String label, T value, T current, ValueChanged<T> onChanged) {
    final active = value == current;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: active ? VE.blue : VE.textMuted, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: active ? VE.text : VE.textDim, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _slider(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: VE.textDim, fontSize: 12))),
        Expanded(child: Slider(value: value.toDouble(), min: min.toDouble(), max: max.toDouble(),
          divisions: max - min, activeColor: VE.blue, inactiveColor: VE.border,
          label: '$value', onChanged: (v) => onChanged(v.round()))),
        SizedBox(width: 32, child: Text('$value', style: const TextStyle(color: VE.textMuted, fontSize: 10, fontFamily: VE.fontMono))),
      ]),
    );
  }

  static const _fontOptions = [
    'Inter', 'Roboto', 'sans-serif', 'serif', 'monospace',
    'Noto Sans', 'Source Sans Pro', 'Oxygen', 'Fira Sans',
  ];

  Widget _fontPicker() {
    return Consumer<FeatureConfig>(builder: (ctx, fc, _) {
      final current = fc.fontFamily;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showDialog<String>(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: VE.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r24), side: BorderSide(color: VE.border)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Pick Font', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: VE.text)),
                    const SizedBox(height: 12),
                    ..._fontOptions.map((f) {
                      final active = f == current;
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(f),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Icon(active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18, color: active ? VE.blue : VE.textDim),
                            const SizedBox(width: 10),
                            Text(f, style: TextStyle(fontFamily: f, color: active ? VE.text : VE.textDim, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
          if (picked != null && picked != current) {
            await fc.setFontFamily(picked);
            VETheme.I.fontFamily = picked;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            const Icon(Icons.text_fields_rounded, size: 18, color: VE.textDim),
            const SizedBox(width: 12),
            Expanded(child: Text('Font', style: const TextStyle(color: VE.text, fontWeight: FontWeight.w800, fontSize: 14))),
            Text(current, style: TextStyle(color: VE.blue, fontSize: 12, fontFamily: current)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 16, color: VE.textMuted),
          ]),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _loadBgPrefs();
    _load();
  }

  Widget _themeRow(BuildContext ctx, VETheme theme, VEThemeMode mode, String title) {
    final active = theme.mode == mode;
    return InkWell(
      onTap: () => theme.setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: active ? VE.blue : VE.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: active ? VE.text : VE.textDim, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _customizerModCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: VE.bgCard,
      borderRadius: BorderRadius.circular(VE.r16),
      border: Border.all(color: VE.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Theme Colors', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Pick colors for your custom theme.', style: TextStyle(color: VE.textMuted, fontSize: 11)),
        const SizedBox(height: 12),
        _themePreview(),
        const SizedBox(height: 12),
        _colorPicker('Background', 'bg', const Color(0xFF000000)),
        _colorPicker('Card', 'bgCard', const Color(0xFF000000)),
        _colorPicker('Border', 'border', const Color(0xFF1F1F22)),
        _colorPicker('Accent', 'blue', const Color(0xFF3B82F6)),
        _colorPicker('Text', 'text', const Color(0xFFFAFAFA)),
        const SizedBox(height: 8),
        Text('Theme name', style: const TextStyle(color: VE.textDim, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: _themeNameCtrl,
          style: const TextStyle(color: VE.text, fontSize: 13, fontFamily: VE.fontSans),
          decoration: const InputDecoration(
            hintText: 'My Theme',
            hintStyle: TextStyle(color: VE.textMuted, fontSize: 13),
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none, filled: false,
            contentPadding: EdgeInsets.zero, isCollapsed: true,
          ),
          onChanged: (_) => _saveBgPrefs(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: VEPrimaryButton(label: 'APPLY', onPressed: () => VETheme.I.setMode(VEThemeMode.custom)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VEGhostButton(label: 'RESET', icon: Icons.refresh_rounded, onPressed: _resetCustom),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: VE.border),
        VEPrimaryButton(label: 'PUBLISH GLOBAL', icon: Icons.public_rounded,
          onPressed: _publishGlobal),
        const SizedBox(height: 8),
        VEGhostButton(label: 'USE AS PROFILE COLORS', icon: Icons.palette_rounded,
          onPressed: _saveProfileTheme),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: VEGhostButton(label: 'EXPORT', icon: Icons.file_download_rounded, onPressed: _exportTheme)),
          const SizedBox(width: 8),
          Expanded(child: VEGhostButton(label: 'IMPORT', icon: Icons.file_upload_rounded, onPressed: _importTheme)),
        ]),
      ],
    ),
  );

  Future<void> _publishGlobal() async {
    final data = ExtensionRuntime.I.data('customizer');
    if (data == null) { _flash('No custom theme to publish'); return; }
    final theme = (data['theme'] as Map?)?.cast<String, String>() ?? {};
    if (theme.isEmpty) { _flash('No theme colors set'); return; }
    final name = _themeNameCtrl.text.trim();
    try {
      await context.read<Api>().publishGlobalTheme(theme, name: name);
      _flash(name.isEmpty ? 'Global theme published' : '"$name" published');
    } catch (e) {
      _flash('Publish failed: $e');
    }
  }

  Future<void> _saveProfileTheme() async {
    final data = ExtensionRuntime.I.data('customizer');
    if (data == null) { _flash('No custom theme to save'); return; }
    final theme = (data['theme'] as Map?)?.cast<String, String>() ?? {};
    if (theme.isEmpty) { _flash('No theme colors set'); return; }
    try {
      await context.read<Api>().updateMe({'profile_theme': theme});
      _flash('Profile colors saved — others see them on your profile');
    } catch (e) {
      _flash('Failed: $e');
    }
  }

  Future<void> _resetCustom() async {
    await ExtensionRuntime.I.uninstall('customizer');
    final data = <String, dynamic>{'type': 'customizer', 'theme': {'bg': '#000000', 'bgCard': '#000000', 'border': '#1F1F22'}};
    await ExtensionRuntime.I.install('customizer', data);
    VETheme.I.loadOverrides();
    VETheme.I.refresh();
    if (VETheme.I.mode == VEThemeMode.custom) {
      await VETheme.I.setMode(VEThemeMode.oled);
    }
    _flash('Custom theme reset');
  }

  Widget _themePreview() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VE.bg,
        borderRadius: BorderRadius.circular(VE.r12),
        border: Border.all(color: VE.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16, width: 80,
            decoration: BoxDecoration(
              color: VE.blue,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          Row(children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: VE.textDim,
                borderRadius: BorderRadius.circular(VE.r12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: VE.text.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: VE.blue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: VE.bgCard,
              borderRadius: BorderRadius.circular(VE.r12),
              border: Border.all(color: VE.border),
            ),
            child: Row(children: [
              const SizedBox(width: 10),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: VE.textDim, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 4, width: 60, decoration: BoxDecoration(color: VE.textMuted, borderRadius: BorderRadius.circular(2)))),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTheme() async {
    final data = ExtensionRuntime.I.data('customizer');
    if (data == null) { _flash('No custom theme'); return; }
    final theme = data['theme'] as Map? ?? {};
    final json = jsonEncode(theme);
    await Clipboard.setData(ClipboardData(text: json));
    _flash('Theme JSON copied to clipboard');
  }

  Future<void> _importTheme() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: VE.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r24), side: BorderSide(color: VE.border)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Paste theme JSON', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: VE.text)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl, maxLines: 6,
                style: const TextStyle(color: VE.text, fontSize: 11, fontFamily: VE.fontMono),
                decoration: const InputDecoration(
                  hintText: '{"bg":"#000000","bgCard":"#...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              VEPrimaryButton(label: 'IMPORT', onPressed: () => Navigator.of(ctx).pop(ctrl.text)),
            ],
          ),
        ),
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    try {
      final theme = jsonDecode(result) as Map<String, dynamic>;
      final cleaned = <String, String>{};
      for (final e in theme.entries) {
        if (e.value is String && (e.value as String).startsWith('#')) {
          cleaned[e.key] = e.value as String;
        }
      }
      if (cleaned.isEmpty) { _flash('No valid hex colors found'); return; }
      final data = Map<String, dynamic>.from(ExtensionRuntime.I.data('customizer') ?? {});
      data['theme'] = cleaned;
      await ExtensionRuntime.I.install('customizer', data);
      VETheme.I.loadOverrides();
      VETheme.I.refresh();
      _flash('Theme imported');
    } catch (e) {
      _flash('Invalid JSON: $e');
    }
  }

  Widget _colorPicker(String label, String key, Color defaultColor) {
    final currentStr = ExtensionRuntime.I.data('customizer')?['theme']?[key] as String?;
    final current = currentStr != null ? Color(int.parse(currentStr.substring(1), radix: 16) + 0xFF000000) : defaultColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickColor(label, key, current),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: current,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VE.border),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: VE.text, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('#${current.toARGB32().toRadixString(16).substring(2).toUpperCase().padLeft(6, '0')}',
              style: const TextStyle(color: VE.textMuted, fontSize: 10, fontFamily: VE.fontMono)),
        ],
      ),
    );
  }

  Future<void> _pickColor(String label, String key, Color current) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(current: current, title: label),
    );
    if (picked == null || !mounted) return;
    final hex = '#${picked.toARGB32().toRadixString(16).substring(2).toUpperCase().padLeft(6, '0')}';
    final data = Map<String, dynamic>.from(ExtensionRuntime.I.data('customizer') ?? {});
    final theme = Map<String, dynamic>.from(data['theme'] as Map<String, dynamic>? ?? {});
    theme[key] = hex;
    data['theme'] = theme;
    await ExtensionRuntime.I.install('customizer', data);
    VETheme.I.loadOverrides();
    VETheme.I.refresh();
  }

  // -- Epsilon tiles --
  List<Widget> _epsilonTiles() => [
    _serverTile(),
    Consumer<Api>(builder: (ctx, api, _) => Column(children: [
      _switchTile('Beta builds', null, api.betaMode, (v) async {
        await api.setBetaMode(v);
        _flash(v ? 'Beta enabled' : 'Stable only');
      }),
      _switchTile('Automatic updates', null, api.allowUpdates, (v) async {
        await api.setAllowUpdates(v);
        _flash(v ? 'Auto-updates ON' : 'Auto-updates OFF');
      }),
    ])),
  ];

  Widget _serverTile() => Consumer<Api>(builder: (ctx, api, _) {
    final current = api.baseUrl;
    final seen = <String>{current};
    final all = [current,
      ...Api.builtinUrls.where((u) => seen.add(u)),
      ...api.knownUrls.where((u) => seen.add(u)),
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showServerDialog(api, all),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.dns_rounded, size: 18, color: VE.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Server', style: TextStyle(color: VE.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(current, style: const TextStyle(color: VE.blue, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, size: 16, color: VE.textMuted),
          ],
        ),
      ),
    );
  });

  void _showServerDialog(Api api, List<String> urls) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final current = api.baseUrl;
        return Dialog(
          backgroundColor: VE.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VE.r24),
            side: BorderSide(color: VE.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: VE.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.dns_rounded, size: 18, color: VE.blue),
                    ),
                    const SizedBox(width: 12),
                    const Text('Server', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: VE.text)),
                  ],
                ),
                const SizedBox(height: 16),
                ...urls.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (u != current) {
                        api.setServer(u);
                        Navigator.of(ctx).pop();
                        _flash('Switched to $u');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: u == current ? VE.blue.withValues(alpha: 0.1) : VE.bg,
                      ),
                      child: Row(children: [
                        Icon(u == current ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 16, color: u == current ? VE.blue : VE.textDim),
                        const SizedBox(width: 10),
                        Expanded(child: Text(u, style: TextStyle(
                          color: u == current ? VE.blue : VE.text,
                          fontSize: 13, fontWeight: FontWeight.w700,
                        ))),
                        if (!Api.builtinUrls.contains(u))
                          InkWell(
                            onTap: () async {
                              await api.removeKnownUrl(u);
                              setLocal(() {});
                            },
                            child: const Icon(Icons.close_rounded, size: 16, color: VE.textDim),
                          ),
                      ]),
                    ),
                  ),
                )),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: ctrl,
                    style: const TextStyle(color: VE.text, fontSize: 13, fontFamily: VE.fontSans),
                    decoration: const InputDecoration(
                      hintText: 'http://10.0.0.1:6967',
                      hintStyle: TextStyle(color: VE.textMuted, fontSize: 13),
                      border: InputBorder.none, enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none, filled: false,
                      contentPadding: EdgeInsets.zero, isCollapsed: true,
                    ),
                  )),
                  const SizedBox(width: 8),
                  VEGhostButton(label: 'ADD', icon: Icons.add_rounded, onPressed: () async {
                    final url = ctrl.text.trim();
                    if (url.isEmpty) return;
                    await api.addKnownUrl(url);
                    await api.setServer(url);
                    ctrl.clear();
                    Navigator.of(ctx).pop();
                    _flash('Connected to $url');
                  }),
                ]),
                const SizedBox(height: 10),
                TextButton(onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done', style: TextStyle(color: VE.blue, fontSize: 14))),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _exportTile() => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: _busy ? null : _export,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.download_rounded, size: 18, color: VE.textDim),
          const SizedBox(width: 12),
          const Expanded(child: Text('Data Export', style: TextStyle(color: VE.text, fontWeight: FontWeight.w800, fontSize: 14))),
          Text('Download JSON', style: TextStyle(color: VE.textMuted, fontSize: 11)),
        ],
      ),
    ),
  );

  Widget _privacyPolicyTile() => InkWell(
    onTap: _showPrivacyPolicy,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18, color: VE.textDim),
          const SizedBox(width: 12),
          const Expanded(child: Text('Privacy Policy', style: TextStyle(color: VE.text, fontWeight: FontWeight.w800, fontSize: 14))),
          const Icon(Icons.chevron_right_rounded, size: 18, color: VE.textMuted),
        ],
      ),
    ),
  );

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => Dialog(
        backgroundColor: VE.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VE.r24),
          side: BorderSide(color: VE.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VE.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_rounded, size: 18, color: VE.blue),
                  ),
                  const SizedBox(width: 12),
                  const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: VE.text)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Epsilon collects the minimum data needed to operate:\n'
                '• Your handle, display name, and avatar\n'
                '• Posts, comments, likes, and follows you create\n'
                '• IP addresses for rate-limiting and abuse prevention\n'
                '• Optional recovery email (never shared)\n\n'
                'Your data stays yours. We do not sell, share, or train AI on your content. '
                'You can export or delete everything at any time from Settings.\n\n'
                'GB users: Face ID liability is not implemented. By using Epsilon you '
                'acknowledge this is not our fault. If you lose your phone, blame the '
                'Android fragmentation team.\n\n'
                'Epsilon reserves the right to use your cringey 2019-era posts '
                'as internal comedy material. This is non-negotiable.',
                style: TextStyle(color: VE.textDim, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('UNDERSTOOD',
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, color: VE.blue)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: VE.pink.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(VE.r16),
      border: Border.all(color: VE.pink.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text('Delete account', style: TextStyle(color: VE.pink, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
        VEGhostButton(label: 'DELETE', icon: Icons.delete_forever_rounded, onPressed: _confirmDelete),
      ],
    ),
  );

  Future<void> _pickAvatar() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048);
    if (p == null) return;
    final cropped = await ImageCropper().cropImage(sourcePath: p.path, aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [ AndroidUiSettings(toolbarTitle: 'Crop Avatar', toolbarColor: Colors.black, toolbarWidgetColor: Colors.white, lockAspectRatio: true) ]);
    if (cropped == null) return;
    setState(() => _pendingAvatarPath = cropped.path);
  }

  Future<void> _pickBanner() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048);
    if (p == null) return;
    final cropped = await ImageCropper().cropImage(sourcePath: p.path, aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 1),
      uiSettings: [ AndroidUiSettings(toolbarTitle: 'Crop Banner', toolbarColor: Colors.black, toolbarWidgetColor: Colors.white, lockAspectRatio: true) ]);
    if (cropped == null) return;
    setState(() => _pendingBannerPath = cropped.path);
  }

  Future<void> _pickProfileBg() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 3072);
    if (p == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: p.path,
      aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 2),
      uiSettings: [AndroidUiSettings(
        toolbarTitle: 'Crop Background',
        toolbarColor: Colors.black,
        toolbarWidgetColor: Colors.white,
        lockAspectRatio: true,
      )],
    );
    if (cropped == null) return;
    setState(() => _pendingBgPath = cropped.path);
  }

  Future<void> _saveProfile() async {
    final api = context.read<Api>();
    setState(() => _busy = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'status': _status.text.trim(),
      };
      if (_pendingAvatarPath != null) {
        data['avatar_url'] = await api.uploadFile(File(_pendingAvatarPath!));
      }
      if (_pendingBannerPath != null) {
        data['banner_url'] = await api.uploadFile(File(_pendingBannerPath!));
      }
      if (_pendingBgPath != null) {
        if (_pendingBgPath!.isNotEmpty) {
          data['profile_bg_url'] = await api.uploadFile(File(_pendingBgPath!));
        } else {
          data['profile_bg_url'] = '';
        }
      }
      await api.updateMe(data);
      _pendingAvatarPath = null;
      _pendingBannerPath = null;
      _pendingBgPath = null;
      await _load();
      _flash('Profile saved');
    } catch (e) {
      _flash('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEmail() async {
    if (_email.text.trim().isEmpty) return;
    final api = context.read<Api>();
    setState(() => _busy = true);
    try { await api.updateMe({'email': _email.text.trim()}); _email.clear(); _flash('Email updated'); }
    catch (e) { _flash('Failed: $e'); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _changePass() async {
    if (_newPass.text.length < 6) { _flash('Pass too short'); return; }
    final api = context.read<Api>();
    setState(() => _busy = true);
    try { await api.changePassword(_currentPass.text, _newPass.text); _currentPass.clear(); _newPass.clear(); _flash('Password changed'); }
    catch (e) { _flash('Failed: $e'); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _export() async {
    final api = context.read<Api>();
    setState(() => _busy = true);
    try { final json = await api.exportMe(); final dir = await getApplicationDocumentsDirectory(); final file = File('${dir.path}/export.json'); await file.writeAsString(json); await Share.shareXFiles([XFile(file.path)], text: 'My data'); }
    catch (e) { _flash('Export failed: $e'); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _confirmDelete() async {
    final api = context.read<Api>();
    if (await veConfirm(context, title: 'Delete Account?', body: 'Irreversible removal of all data.', icon: Icons.delete_forever_rounded, confirmLabel: 'Delete', confirmColor: VE.pink)) {
      try { await api.deleteMe(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen(firstRun: true)), (_) => false); }
      catch (e) { _flash('Delete failed: $e'); }
    }
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color current;
  final String title;
  const _ColorPickerDialog({required this.current, required this.title});
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _color = widget.current;
  }

  static const _presets = [
    Color(0xFF000000), Color(0xFF0F172A), Color(0xFF18181B), Color(0xFF1C0A14),
    Color(0xFF27272A), Color(0xFF1E293B), Color(0xFF2D1424), Color(0xFF3F3F46),
    Color(0xFF334155), Color(0xFF4A2040), Color(0xFF52525B), Color(0xFFA1A1AA),
    Color(0xFF3B82F6), Color(0xFF06B6D4), Color(0xFF10B981), Color(0xFFEC4899),
    Color(0xFFA855F7), Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VE.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r24), side: BorderSide(color: VE.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick ${widget.title}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: VE.text)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(VE.r12), border: Border.all(color: VE.border)),
            ),
            const SizedBox(height: 12),
            const Text('Presets', style: TextStyle(color: VE.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _presets.map((c) => GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _color == c ? VE.text : VE.border, width: _color == c ? 2 : 1),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(foregroundColor: VE.textMuted, side: BorderSide(color: VE.border)),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: VEPrimaryButton(label: 'SELECT', onPressed: () => Navigator.of(context).pop(_color)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
