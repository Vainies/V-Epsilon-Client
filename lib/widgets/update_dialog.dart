import 'package:flutter/material.dart';
import '../theme.dart';
import '../updater.dart';
import 'common.dart';

/// Dialog that offers to download + install a new version.
/// Shows progress during download, hands off to Android installer at the end.
/// [isRequired] — LATER hidden, only UPDATE NOW.
/// [isEmergency] — same as required but with critical red styling.
class UpdateDialog extends StatefulWidget {
  final Updater updater;
  final ReleaseInfo info;
  final bool isRequired;
  final bool isEmergency;
   const UpdateDialog({super.key, required this.updater, required this.info, this.isRequired = false, this.isEmergency = false});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  int _received = 0;
  int _total = 0;
  bool _downloading = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    final path = await widget.updater.download(widget.info, onProgress: (p, r, t) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        _received = r;
        _total = t;
      });
    });
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _downloading = false;
        _error = 'Download failed. Check your connection and try again.';
      });
      return;
    }
    final ok = await widget.updater.install(path);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _downloading = false;
        _error = 'Install blocked. Allow "Install unknown apps" for V Epsilon in Android settings.';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return Dialog(
      backgroundColor: VE.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r24)),
      child: Container(
        padding:  const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: VE.border),
          borderRadius: BorderRadius.circular(VE.r24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isEmergency ? VE.red.withValues(alpha: 0.15) : widget.isRequired ? VE.pink.withValues(alpha: 0.15) : VE.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VE.r12),
                    ),
                    child:  Icon(widget.isEmergency ? Icons.error_rounded : widget.isRequired ? Icons.warning_rounded : Icons.system_update_rounded, color: widget.isEmergency ? VE.red : widget.isRequired ? VE.pink : VE.blue, size: 22),
                  ),
                   const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(widget.isEmergency ? 'EMERGENCY PATCH' : widget.isRequired ? 'REQUIRED UPDATE' : 'UPDATE AVAILABLE',
                           style:  TextStyle(
                             fontFamily: VE.fontMono,
                             fontSize: 10,
                             color: widget.isEmergency ? VE.red : widget.isRequired ? VE.pink : VE.textMuted,
                             letterSpacing: 2,
                             fontWeight: FontWeight.w900,
                           )),
                        const SizedBox(height: 4),
                        Text('v${info.version}',
                            style:  TextStyle(
                              fontFamily: VE.fontSans,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: widget.isEmergency ? VE.red : VE.text,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            if (info.releaseNotes.isNotEmpty) ...[
               const SizedBox(height: 16),
              _ReleaseNotesBox(notes: info.releaseNotes, version: info.version),
            ],
            if (info.apkSize > 0) ...[
               const SizedBox(height: 12),
              Text(
                'Size: ${_formatBytes(info.apkSize)}',
                style:  const TextStyle(
                  fontFamily: VE.fontMono,
                  fontSize: 11,
                  color: VE.textMuted,
                ),
              ),
            ],
            if (_downloading) ...[
               const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor:  const Color(0xFF181818),
                  valueColor:  const AlwaysStoppedAnimation(VE.blue),
                  minHeight: 6,
                ),
              ),
               const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style:  const TextStyle(
                        fontFamily: VE.fontMono, fontSize: 11, color: VE.textDim, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_formatBytes(_received)} / ${_formatBytes(_total)}',
                    style:  const TextStyle(
                        fontFamily: VE.fontMono, fontSize: 11, color: VE.textMuted),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
               const SizedBox(height: 16),
              Text(_error!, style:  const TextStyle(color: VE.pink, fontSize: 12)),
            ],
             const SizedBox(height: 20),
            Row(
              children: [
                if (!widget.isRequired && !widget.isEmergency)
                  Expanded(
                    child: TextButton(
                      onPressed: _downloading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding:  const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: VE.textDim,
                      ),
                      child:  const Text('LATER',
                          style: TextStyle(
                              fontFamily: VE.fontMono,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 2,
                              color: VE.textDim)),
                    ),
                  ),
                if (!widget.isRequired && !widget.isEmergency)
                   const SizedBox(width: 8),
                Expanded(
                  flex: (widget.isRequired || widget.isEmergency) ? 1 : 2,
                  child: VEPrimaryButton(
                    label: _downloading ? 'DOWNLOADING...' : (_error != null ? 'RETRY' : 'UPDATE NOW'),
                    onPressed: _downloading ? null : _start,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }
}

/// Release notes preview: shows up to 3 lines then a "Read more" pill that
/// opens a full-screen styled modal. Bullets (`-`, `*`) and semicolons/
/// periods are converted into separate lines for readability.
class _ReleaseNotesBox extends StatelessWidget {
  final String notes;
  final String version;
   const _ReleaseNotesBox({required this.notes, required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:  const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VE.bgCard,
        borderRadius: BorderRadius.circular(VE.r12),
        border: Border.all(color: VE.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text(
            "WHAT'S NEW",
            style: TextStyle(
              fontFamily: VE.fontMono,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 2,
              color: VE.textMuted,
            ),
          ),
           const SizedBox(height: 8),
          Text(
            notes,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style:  const TextStyle(
                color: VE.textDim, fontSize: 13, height: 1.5),
          ),
          if (notes.length > 100 || _lineCount(notes) > 3) ...[
             const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _showFull(context),
                child: Container(
                  padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: VE.blue.withValues(alpha: 0.12),
                    border: Border.all(color: VE.blue.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child:  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Read more',
                          style: TextStyle(
                              color: VE.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: VE.blue),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _lineCount(String s) => s.split(RegExp(r'\n|(?<=[.;!?])\s+')).length;

  void _showFull(BuildContext context) {
    // Split notes into readable bullet-like rows.
    final items = _parseBullets(notes);
    showModalBottomSheet(
      context: context,
      backgroundColor: VE.bg,
      isScrollControlled: true,
      shape:  const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(VE.r24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scroll) => Padding(
          padding:  const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: VE.border,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
               const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding:
                         const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VE.blue.withValues(alpha: 0.12),
                      border:
                          Border.all(color: VE.blue.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('v$version',
                        style:  const TextStyle(
                            fontFamily: VE.fontMono,
                            color: VE.blue,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1)),
                  ),
                ],
              ),
               const SizedBox(height: 8),
               const Text('Release notes',
                  style: TextStyle(
                      color: VE.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
               const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>  const SizedBox(height: 10),
                  itemBuilder: (_, i) => _bulletRow(items[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bulletRow(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin:  const EdgeInsets.only(top: 7),
            width: 6,
            height: 6,
            decoration:  const BoxDecoration(
                color: VE.blue, shape: BoxShape.circle),
          ),
           const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:  const TextStyle(
                    color: VE.text, fontSize: 14, height: 1.5)),
          ),
        ],
      );

  List<String> _parseBullets(String s) {
    // Strip known bullet markers and split on newlines or sentence boundaries.
    final normalized = s.replaceAll(RegExp(r'^[\s]*[\-\*•]\s*', multiLine: true), '');
    final rough = normalized.split(RegExp(r'\n|(?<=[.;!?])\s+(?=[A-Z(])'));
    return rough.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
