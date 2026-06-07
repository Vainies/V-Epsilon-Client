import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../theme.dart';

/// Colored gradient placeholder avatar when no network image is set.
/// Keeps app working offline / without any backend images.
class VEAvatar extends StatelessWidget {
  final String? url;
  final String seed; // used for gradient color when url is empty
  final double size;
  final double radius;
  final VoidCallback? onTap;
  final bool showOnline;

  const VEAvatar({
    super.key,
    this.url,
    this.seed = '',
    this.size = 40,
    this.radius = 14,
    this.onTap,
    this.showOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final clipShape = BorderRadius.circular(radius);
    final api = context.read<Api>();
    final resolved = url != null && url!.trim().isNotEmpty ? api.resolveUrl(url!) : '';
    final hasUrl = resolved.isNotEmpty;

    Widget image = SizedBox(
      width: size,
      height: size,
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              errorWidget: (_, __, ___) => _gradient(),
              placeholder: (_, __) => _gradient(),
            )
          : _gradient(),
    );

    Widget core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: clipShape,
        border: Border.all(color: VE.border, width: 1),
      ),
      child: ClipRRect(borderRadius: clipShape, child: image),
    );

    Widget result = core;

    if (showOnline) {
      // Wrap in a sized box slightly larger than the avatar so the dot fits inside.
      final dotSize = (size * 0.24).clamp(10.0, 14.0);
      final extra = dotSize * 0.5;
      result = SizedBox(
        width: size + extra,
        height: size + extra,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(top: 0, left: 0, child: core),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: VE.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: VE.bg, width: 2.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (onTap == null) return result;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: result,
    );
  }

  Widget _gradient() {
    // Deterministic color from seed
    final hash = seed.isEmpty ? 0 : seed.codeUnits.fold<int>(0, (p, c) => p + c);
    final palettes = [
      [const Color(0xFF3B82F6), const Color(0xFF06B6D4)], // blue-cyan
      [const Color(0xFFA855F7), const Color(0xFFEC4899)], // purple-pink
      [const Color(0xFFF97316), const Color(0xFFFACC15)], // orange-yellow
      [const Color(0xFF10B981), const Color(0xFF06B6D4)], // emerald-cyan
      [const Color(0xFF6366F1), const Color(0xFF3B82F6)], // indigo-blue
      [const Color(0xFFEC4899), const Color(0xFFF97316)], // pink-orange
    ];
    final p = palettes[hash % palettes.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p),
      ),
      alignment: Alignment.center,
      child: seed.isEmpty
          ? null
          : Text(
              seed.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.42,
                height: 1,
              ),
            ),
    );
  }
}

/// Small colored badge chip with icon (human/verified/creator/kernel/top_tier).
class VEBadge extends StatelessWidget {
  final String type;
  const VEBadge({super.key, required this.type});

  static final _config = {
    'human': (icon: Icons.verified_user_rounded, color: VE.emerald),
    'verified': (icon: Icons.check_circle_rounded, color: VE.blue),
    'creator': (icon: Icons.videocam_rounded, color: VE.purple),
    'kernel': (icon: Icons.memory_rounded, color: VE.orange),
    'top_tier': (icon: Icons.workspace_premium_rounded, color: VE.yellow),
    'developer': (icon: Icons.code_rounded, color: VE.cyan),
  };

  @override
  Widget build(BuildContext context) {
    final c = _config[type];
    if (c == null) return const SizedBox.shrink();
    return Icon(c.icon, size: 12, color: c.color);
  }
}

/// Container with subtle border matching mockup cards.
class VECard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const VECard({
    super.key,
    required this.child,
    this.padding,
    this.radius = VE.r24,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? VE.bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? VE.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}

/// Primary button - white pill.
class VEPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const VEPrimaryButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16, color: Colors.black) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: VE.text,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontFamily: VE.fontSans, fontWeight: FontWeight.w900, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r16)),
        elevation: 0,
      ),
    );
  }
}

/// Ghost / outline button
class VEGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const VEGhostButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: VE.text,
        backgroundColor: const Color(0x33181818),
        side: BorderSide(color: VE.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontFamily: VE.fontSans, fontWeight: FontWeight.w700, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VE.r16)),
      ),
    );
  }
}

/// Filter chip row (All / Video / Blog / Code / Polls)
class VEChipRow extends StatelessWidget {
  final List<String> labels;
  final String active;
  final ValueChanged<String> onChanged;
  const VEChipRow({super.key, required this.labels, required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final l = labels[i];
          final isActive = l.toLowerCase() == active.toLowerCase();
          return GestureDetector(
            onTap: () => onChanged(l.toLowerCase()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: kVECurve,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: isActive ? VE.text : const Color(0xFF0E0E0E),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isActive ? VE.text : VE.border),
              ),
              alignment: Alignment.center,
              child: Text(
                l,
                style: TextStyle(
                  fontFamily: VE.fontSans,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isActive ? Colors.black : VE.textDim,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Centered square confirm dialog. Opaque bg, destructive action in pink.
/// Returns true if user confirmed.
Future<bool> veConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  Color confirmColor = VE.pink,
  IconData? icon,
  Color? iconColor,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => Dialog(
      backgroundColor: VE.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VE.r24),
        side: BorderSide(color: VE.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: (iconColor ?? confirmColor).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: (iconColor ?? confirmColor)
                            .withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon,
                      color: iconColor ?? confirmColor, size: 30),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: VE.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    height: 1.25)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: VE.textDim, fontSize: 13, height: 1.55)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: VE.textDim,
                    ),
                    child: Text(cancelLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VE.r16)),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return r == true;
}
