import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../theme.dart';

/// Fullscreen image viewer that replaces the old "tap image opens browser"
/// behaviour. Pinch to zoom, drag to pan, tap X (or tap outside the image)
/// to close. Hero tag allows a smooth transition from a feed thumbnail.
class ImageViewer extends StatelessWidget {
  final String url;
  final String? heroTag;
   const ImageViewer({super.key, required this.url, this.heroTag});

  /// Convenience push. Returns a Future that completes when the viewer is
  /// dismissed - callers don't need to care about the result.
  static Future<void> open(BuildContext context,
      {required String url, String? heroTag}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        transitionDuration:  const Duration(milliseconds: 200),
        reverseTransitionDuration:  const Duration(milliseconds: 150),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: ImageViewer(url: url, heroTag: heroTag),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = context.read<Api>().resolveUrl(url);
    final img = CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.contain,
      placeholder: (_, __) =>  const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child:
              CircularProgressIndicator(color: VE.textDim, strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) =>  const Center(
        child: Icon(Icons.broken_image_rounded,
            color: VE.textMuted, size: 48),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap on empty space dismisses.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          // The image itself - pinch/zoom, doesn't forward taps so the user
          // can still pan without closing.
          Positioned.fill(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: heroTag != null
                    ? Hero(tag: heroTag!, child: img)
                    : img,
              ),
            ),
          ),
          // Close button - always accessible, respects SafeArea.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:  const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape:  const CircleBorder(),
                  child: InkWell(
                    customBorder:  const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child:  const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
