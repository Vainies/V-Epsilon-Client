import 'package:flutter/material.dart';
import '../theme.dart';

class StudioScreen extends StatelessWidget {
   const StudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:  const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VE.bgCard,
                borderRadius: BorderRadius.circular(VE.r16),
                border: Border.all(color: VE.border),
              ),
              child:  const Icon(Icons.live_tv_rounded, color: VE.textDim, size: 28),
            ),
             const SizedBox(height: 16),
            Text('Studio',
                style: Theme.of(context).textTheme.displayMedium),
             const SizedBox(height: 8),
            Container(
              padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: VE.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: VE.orange.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'DISABLED',
                style: TextStyle(
                  fontFamily: VE.fontMono,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: VE.orange,
                  letterSpacing: 2,
                ),
              ),
            ),
             const SizedBox(height: 16),
             const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Video hosting and live streaming is not yet available. This section will open up once the media pipeline is ready.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VE.textMuted, fontSize: 13, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
