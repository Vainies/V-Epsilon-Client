import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api.dart';
import '../theme.dart';
import 'profile.dart';

class QrShareScreen extends StatelessWidget {
  final String handle;
  const QrShareScreen({super.key, required this.handle});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    final url = api.webUrlFor(handle);
    return Scaffold(
      backgroundColor: VE.bg,
      appBar: AppBar(
        backgroundColor: VE.bg, surfaceTintColor: VE.bg, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VE.text),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('@$handle', style: const TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 240,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            Text('Scan to find @$handle',
                style: const TextStyle(color: VE.textDim, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? _controller;
  bool _found = false;
  bool _cameraReady = false;
  bool _cameraError = false;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    try {
      final controller = MobileScannerController(
        torchEnabled: false,
        formats: [BarcodeFormat.qrCode],
      );
      // Wait briefly to detect if camera starts
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _cameraReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cameraError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _found = true;
      _controller?.stop();
      _resolve(raw);
      return;
    }
  }

  void _resolve(String raw) async {
    if (!mounted) return;
    final api = context.read<Api>();
    String handle = raw;
    if (raw.contains('/@')) {
      handle = raw.split('/@').last.split('?').first.split('/').first;
    } else if (raw.contains('/u/')) {
      handle = raw.split('/u/').last.split('?').first.split('/').first;
    }
    try {
      final user = await api.getUser(handle);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found'), backgroundColor: VE.red),
      );
      _found = false;
      _controller?.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VE.bg,
      appBar: AppBar(
        backgroundColor: VE.bg, surfaceTintColor: VE.bg, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VE.text),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Scan QR', style: TextStyle(color: VE.text, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: _cameraError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined, color: VE.textDim, size: 48),
                  const SizedBox(height: 12),
                  const Text('Camera not available', style: TextStyle(color: VE.textDim, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() { _cameraError = false; _cameraReady = false; });
                      _initScanner();
                    },
                    child: const Text('Retry', style: TextStyle(color: VE.blue)),
                  ),
                ],
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator(color: VE.blue))
              : Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                    CustomPaint(
                      size: Size.infinite,
                      painter: _QrOverlayPainter(),
                    ),
                    Positioned(
                      left: 0, right: 0, bottom: 60,
                      child: Text(
                        'Center QR code in the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _QrOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    final scanSize = size.shortestSide * 0.65;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2 - 32;

    // top strip
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), paint);
    // bottom strip
    canvas.drawRect(Rect.fromLTWH(0, top + scanSize, size.width, size.height - top - scanSize), paint);
    // left strip
    canvas.drawRect(Rect.fromLTWH(0, top, left, scanSize), paint);
    // right strip
    canvas.drawRect(Rect.fromLTWH(left + scanSize, top, size.width - left - scanSize, scanSize), paint);

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const bracketLen = 24.0;
    final corners = [
      (left, top, 1.0, 1.0),
      (left + scanSize, top, -1.0, 1.0),
      (left, top + scanSize, 1.0, -1.0),
      (left + scanSize, top + scanSize, -1.0, -1.0),
    ];
    for (final (x, y, dx, dy) in corners) {
      canvas.drawLine(Offset(x, y + dy * bracketLen), Offset(x, y), cornerPaint);
      canvas.drawLine(Offset(x + dx * bracketLen, y), Offset(x, y), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}