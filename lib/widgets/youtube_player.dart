import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

/// In-app YouTube player using WebView + JS AdBlocker.
/// Loads the mobile embed URL and injects CSS/JS to hide ads and branding.
class WebYouTubePlayer extends StatefulWidget {
  final String youtubeUrl;
  const WebYouTubePlayer({super.key, required this.youtubeUrl});

  @override
  State<WebYouTubePlayer> createState() => _WebYouTubePlayerState();
}

class _WebYouTubePlayerState extends State<WebYouTubePlayer> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final videoId = _extractId(widget.youtubeUrl);
    final embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=0&rel=0&modestbranding=1&iv_load_policy=3';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _injectAdBlocker();
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl));
  }

  /// Injects CSS and JS to hide YouTube elements that look like ads or 
  /// links to external pages.
  void _injectAdBlocker() {
    const css = """
      /* Hide top header and share buttons */
      .ytp-chrome-top, .ytp-share-button, .ytp-show-cards-title { display: none !important; }
      /* Hide YouTube logo / watermarks */
      .ytp-watermark, .ytp-youtube-button { display: none !important; }
      /* Hide pause-overlay 'more videos' */
      .ytp-pause-overlay { display: none !important; }
    """;
    
    _controller.runJavaScript("""
      (function() {
        var style = document.createElement('style');
        style.innerHTML = `$css`;
        document.head.appendChild(style);
        
        // Repeatedly check for and remove ad overlays that might appear later
        setInterval(function() {
          var ads = document.querySelectorAll('.video-ads, .ytp-ad-module, .ytp-ad-overlay-container');
          for(var i=0; i<ads.length; i++) { ads[i].style.display = 'none'; }
        }, 500);
      })();
    """);
  }

  String _extractId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
    if (uri.pathSegments.contains('shorts')) return uri.pathSegments.last;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(VE.r16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: VE.pink, strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
