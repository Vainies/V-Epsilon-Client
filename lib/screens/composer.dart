import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/voice.dart';

class ComposerScreen extends StatefulWidget {
  const ComposerScreen({super.key});

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _linkInput = TextEditingController();
  final _spoilerLabel = TextEditingController();
  final _attachments = <Attachment>[];
  static const _maxAttachments = 4;
  bool _busy = false;
  bool _spoiler = false;
  bool _showLinkField = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _linkInput.dispose();
    _spoilerLabel.dispose();
    super.dispose();
  }

  bool get _atAttachmentLimit => _attachments.length >= _maxAttachments;

  void _showLimitSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Maximum $_maxAttachments attachments per post'),
        backgroundColor: VE.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImageFrom(ImageSource source) async {
    if (_atAttachmentLimit) { _showLimitSnack(); return; }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90, maxWidth: 3072);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop image',
          toolbarColor: const Color(0xFF000000),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF3B82F6),
          backgroundColor: const Color(0xFF000000),
          cropFrameColor: Colors.white,
          cropGridColor: const Color(0x55FFFFFF),
          dimmedLayerColor: const Color(0xAA000000),
          hideBottomControls: false,
          showCropGrid: true,
          lockAspectRatio: false,
        ),
      ],
    );
    if (cropped == null) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final url = await context.read<Api>().uploadFile(File(cropped.path));
      if (!mounted) return;
      setState(() => _attachments.add(Attachment(type: 'image', url: url)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Image upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addVoice(String path, int seconds) async {
    if (_atAttachmentLimit) { _showLimitSnack(); return; }
    setState(() => _busy = true);
    try {
      final url = await context.read<Api>().uploadFile(File(path));
      if (!mounted) return;
      final duration = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      setState(() => _attachments.add(Attachment(type: 'voice', url: url, title: duration)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Voice upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addLink() {
    final url = _linkInput.text.trim();
    if (url.isEmpty) return;
    if (_atAttachmentLimit) { _showLimitSnack(); return; }
    setState(() {
      _attachments.add(Attachment.fromUrl(url));
      _linkInput.clear();
      _showLinkField = false;
    });
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<Api>().createPost({
        'kind': 'post',
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        if (_spoiler) 'spoiler': true,
        if (_spoiler) 'spoiler_label': _spoilerLabel.text.trim(),
        'metadata': {
          'attachments': _attachments.map((a) => a.toJson()).toList(),
        },
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _title.text.trim().isNotEmpty ||
        _body.text.trim().isNotEmpty ||
        _attachments.isNotEmpty;
    return Scaffold(
      backgroundColor: VE.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: VE.bg,
        surfaceTintColor: VE.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: VE.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('New post',
            style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: FilledButton(
              onPressed: _busy || !hasContent ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: VE.text,
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF1A1A1A),
                disabledForegroundColor: VE.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('POST'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_spoiler) _spoilerBanner(),
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  maxLines: null,
                  maxLength: 50,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontFamily: VE.fontSans,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: VE.text,
                    height: 1.25,
                  ),
                  cursorColor: VE.blue,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                    counterText: '',
                    hintText: 'Title (optional)',
                    hintStyle: TextStyle(color: VE.textMuted, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _body,
                  maxLines: null,
                  minLines: 4,
                  maxLength: 1000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: VE.text, fontSize: 15, height: 1.6),
                  cursorColor: VE.blue,
                  buildCounter: null,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                    hintText: 'Write something...',
                    hintStyle: TextStyle(color: VE.textMuted, fontSize: 15),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_spoiler) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: VE.bgElevated,
                      border: Border.all(color: VE.border),
                      borderRadius: BorderRadius.circular(VE.r12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.label_outline_rounded, size: 16, color: VE.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _spoilerLabel,
                          style: const TextStyle(color: VE.text, fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            hintText: 'Spoiler label (e.g. NSFW)',
                            hintStyle: TextStyle(color: VE.textMuted, fontSize: 13),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (_showLinkField) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: VE.bgElevated,
                      border: Border.all(color: VE.border),
                      borderRadius: BorderRadius.circular(VE.r16),
                    ),
                    child: Row(children: [
                      const Icon(Icons.link_rounded, size: 18, color: VE.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _linkInput,
                          autofocus: true,
                          style: const TextStyle(color: VE.text, fontSize: 14),
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintText: 'Paste URL',
                            hintStyle: TextStyle(color: VE.textMuted, fontSize: 13),
                          ),
                          onSubmitted: (_) => _addLink(),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() { _linkInput.clear(); _showLinkField = false; }),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded, size: 18, color: VE.textMuted),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _addLink,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(color: VE.blue, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._attachments.asMap().entries.map((e) => _attachmentCard(e.key, e.value)),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: VE.pink, fontSize: 12)),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          _toolbar(),
        ],
      ),
    );
  }

  Widget _spoilerBanner() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: VE.orange.withValues(alpha: 0.08),
      border: Border.all(color: VE.orange.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(VE.r16),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: VE.orange, size: 16),
        const SizedBox(width: 8),
        const Text('SPOILER', style: TextStyle(fontFamily: VE.fontMono, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: VE.orange)),
        const Spacer(),
        InkWell(
          onTap: () => setState(() { _spoiler = false; }),
          child: const Icon(Icons.close_rounded, size: 16, color: VE.orange),
        ),
      ],
    ),
  );

  Widget _toolbar() {
    return Container(
      decoration: BoxDecoration(
        color: VE.bg,
        border: Border(top: BorderSide(color: VE.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              _toolBtn(Icons.image_rounded, color: VE.emerald, onTap: _busy || _atAttachmentLimit ? null : () => _pickImageFrom(ImageSource.gallery)),
              const SizedBox(width: 6),
              _toolBtn(Icons.photo_camera_rounded, color: VE.blue, onTap: _busy || _atAttachmentLimit ? null : () => _pickImageFrom(ImageSource.camera)),
              const SizedBox(width: 6),
              _toolBtn(Icons.mic_rounded, color: VE.pink, onTap: _busy || _atAttachmentLimit ? null : _openVoiceRecorder),
              const SizedBox(width: 6),
              _toolBtn(Icons.link_rounded, color: VE.blue, active: _showLinkField, onTap: _atAttachmentLimit && !_showLinkField ? null : () => setState(() => _showLinkField = !_showLinkField)),
              const SizedBox(width: 6),
              _toolBtn(Icons.visibility_off_outlined, color: VE.orange, active: _spoiler, onTap: () => setState(() => _spoiler = !_spoiler)),
              const Spacer(),
              if (_attachments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: VE.bgElevated,
                    border: Border.all(color: VE.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${_attachments.length}/$_maxAttachments', style: const TextStyle(fontFamily: VE.fontMono, fontWeight: FontWeight.w800, fontSize: 11, color: VE.textDim)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, {VoidCallback? onTap, bool active = false, Color color = VE.blue}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VE.r12),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : VE.bgElevated,
          borderRadius: BorderRadius.circular(VE.r12),
          border: Border.all(color: active ? color.withValues(alpha: 0.45) : VE.border),
        ),
        child: Icon(icon, size: 20, color: active ? color : VE.text),
      ),
    );
  }

  Future<void> _openVoiceRecorder() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: VE.bgElevated,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(VE.r24)),
        side: BorderSide(color: VE.border),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: VE.bgElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(VE.r24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: VE.border, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 24),
              const Text('Record voice', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 6),
              const Text('Hold the mic to record, release to attach. Max 2 min.', textAlign: TextAlign.center, style: TextStyle(color: VE.textMuted, fontSize: 13)),
              const SizedBox(height: 28),
              VoiceRecordButton(size: 72, color: VE.pink, onComplete: (path, seconds) {
                Navigator.of(sheetCtx).maybePop();
                _addVoice(path, seconds);
              }),
              const SizedBox(height: 28),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).maybePop(),
                child: const Text('Cancel', style: TextStyle(color: VE.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentCard(int idx, Attachment a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VE.bgElevated,
              border: Border.all(color: VE.border),
              borderRadius: BorderRadius.circular(VE.r16),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _colorFor(a.type).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VE.r12),
                  ),
                  child: Icon(_iconFor(a.type), size: 18, color: _colorFor(a.type)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.type.toUpperCase(), style: TextStyle(fontFamily: VE.fontMono, fontWeight: FontWeight.w900, fontSize: 9, color: _colorFor(a.type), letterSpacing: 2)),
                      const SizedBox(height: 2),
                      Text(a.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VE.text, fontSize: 13, fontFamily: VE.fontMono)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6, right: 6,
            child: InkWell(
              onTap: () => setState(() => _attachments.removeAt(idx)),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: VE.bg, shape: BoxShape.circle, border: Border.all(color: VE.border)),
                child: const Icon(Icons.close_rounded, size: 14, color: VE.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.play_circle_rounded;
      case 'voice': return Icons.mic_rounded;
      case 'youtube': return Icons.smart_display_rounded;
      case 'github': return Icons.code_rounded;
      default: return Icons.link_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'image': return VE.emerald;
      case 'video': return VE.pink;
      case 'voice': return VE.pink;
      case 'youtube': return VE.pink;
      case 'github': return VE.textDim;
      default: return VE.blue;
    }
  }
}
