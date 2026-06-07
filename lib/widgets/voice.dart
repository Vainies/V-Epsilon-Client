import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import '../theme.dart';

/// Hold-to-record voice button. Max 120 seconds. Outputs AAC-LC in an .m4a
/// container — small files and widely compatible with Android media players.
///
/// Gestures:
///   tap       → toast asking user to hold
///   long-press → start recording, show timer + waveform pulse
///   release    → stop, call [onComplete] with the file path + duration
///   tap CANCEL → abort without uploading
class VoiceRecordButton extends StatefulWidget {
  /// Invoked when the user releases after a valid recording (>= 1s).
  final void Function(String path, int seconds)? onComplete;
  final Color color;
  final double size;

  /// Hard cap on recording length in seconds.
  static  int maxSeconds = 120;

   const VoiceRecordButton({
    super.key,
    this.onComplete,
    this.color = VE.blue,
    this.size = 44,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _cancelled = false;
  Timer? _ticker;
  int _seconds = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration:  const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
                content: Text(
                    'Microphone permission denied. Enable it in your phone settings.')),
          );
        }
        return;
      }
      final dir = Directory.systemTemp;
      final path =
          '${dir.path}/epsilon_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
         const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _cancelled = false;
        _seconds = 0;
      });
      _ticker = Timer.periodic( const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= VoiceRecordButton.maxSeconds) _stop();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Recording failed: $e')));
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    final path = await _recorder.stop();
    final secs = _seconds;
    if (!mounted) return;
    setState(() {
      _recording = false;
      _seconds = 0;
    });
    if (path != null && !_cancelled && secs >= 1) {
      widget.onComplete?.call(path, secs);
    } else if (path != null) {
      // Cancelled or too short — scrub the file so we don't leak temp data.
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _cancel() async {
    _cancelled = true;
    await _stop();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_recording) {
      return GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                const Text('Hold the mic button to record a voice message.'),
            backgroundColor: VE.bgElevated,
            duration: const Duration(seconds: 2),
          ));
        },
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _cancel,
        child: Material(
          color: widget.color,
          shape:  const CircleBorder(),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child:
                 const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
          ),
        ),
      );
    }
    // Recording UI: inline row with cancel pill, red pulse, timer, stop btn.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _cancel,
          child: Container(
            padding:
                 const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VE.pink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child:  const Text(
              'CANCEL',
              style: TextStyle(
                  color: VE.pink,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.5),
            ),
          ),
        ),
         const SizedBox(width: 10),
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 10,
            height: 10,
            decoration:
                 const BoxDecoration(color: VE.pink, shape: BoxShape.circle),
          ),
        ),
         const SizedBox(width: 6),
        Text(
          _fmt(_seconds),
          style:  const TextStyle(
              fontFamily: VE.fontMono,
              fontWeight: FontWeight.w900,
              color: VE.text,
              fontSize: 14),
        ),
         const SizedBox(width: 6),
        Text(
          '/ ${_fmt(VoiceRecordButton.maxSeconds)}',
          style:  const TextStyle(
              fontFamily: VE.fontMono,
              fontSize: 11,
              color: VE.textMuted),
        ),
         const SizedBox(width: 10),
        GestureDetector(
          onTap: _stop,
          child: Material(
            color: VE.emerald,
            shape:  const CircleBorder(),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child:  const Icon(Icons.stop_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline voice message player. Streams the URL, shows progress + duration.
class VoicePlayer extends StatefulWidget {
  final String url;
  final String duration; // optional preformatted mm:ss
  final Color accent;
   const VoicePlayer({
    super.key,
    required this.url,
    this.duration = '',
    this.accent = VE.blue,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _player.setUrl(widget.url);
      if (mounted && d != null) setState(() => _dur = d);
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds > 0 ? _dur :  const Duration(seconds: 1);
    final progress =
        (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Container(
      padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VE.bgElevated,
        border: Border.all(color: VE.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: widget.accent,
            shape:  const CircleBorder(),
            child: InkWell(
              customBorder:  const CircleBorder(),
              onTap: _toggle,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                    _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20),
              ),
            ),
          ),
           const SizedBox(width: 12),
          _VisualizerBars(
              progress: progress, accent: widget.accent, playing: _playing),
           const SizedBox(width: 12),
          Text(
            _dur.inMilliseconds > 0
                ? (_playing
                    ? _fmt(_pos)
                    : _fmt(_dur))
                : (widget.duration.isNotEmpty ? widget.duration : '…'),
            style:  const TextStyle(
                fontFamily: VE.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: VE.textDim),
          ),
        ],
      ),
    );
  }
}

/// Static-looking audio visualizer: 28 thin vertical bars of varied heights.
/// Bars to the left of the playhead are tinted with the accent color; the
/// rest stay muted. Gentle pulse while playing to feel alive without
/// needing a real FFT (which just_audio doesn't expose easily).
class _VisualizerBars extends StatefulWidget {
  final double progress; // 0..1
  final Color accent;
  final bool playing;
   const _VisualizerBars({
    required this.progress,
    required this.accent,
    required this.playing,
  });

  @override
  State<_VisualizerBars> createState() => _VisualizerBarsState();
}

class _VisualizerBarsState extends State<_VisualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  // Precomputed deterministic heights so the same message always looks the
  // same. 28 bars covers enough width without overcrowding the bubble.
  static  final _heights = <double>[
    0.35, 0.55, 0.8, 0.45, 0.7, 0.9, 0.6, 0.5,
    0.75, 0.4, 0.65, 0.85, 0.5, 0.7, 0.95, 0.55,
    0.35, 0.6, 0.8, 0.45, 0.7, 0.5, 0.9, 0.55,
    0.4, 0.65, 0.75, 0.5,
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration:  const Duration(milliseconds: 600),
    );
    if (widget.playing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _VisualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.playing && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 26,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final wobble = widget.playing
              ? (0.92 + 0.08 * _pulse.value)
              : 1.0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_heights.length, (i) {
              final played = (i / _heights.length) <= widget.progress;
              final h = _heights[i] * 26 * wobble;
              return Padding(
                padding:  const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: 3,
                  height: h.clamp(6, 26),
                  decoration: BoxDecoration(
                    color: played
                        ? widget.accent
                        : VE.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
