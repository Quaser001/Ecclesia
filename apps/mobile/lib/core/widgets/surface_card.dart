import 'package:flutter/material.dart';

/// A quiet, considered surface — not a glass card.
///
/// A flat elevated surface with a 1px border, a faint top-left highlight for
/// depth, and a soft shadow in light mode. Content stays legible in both
/// themes and *actually* elevated things (score, verdict) carry more weight.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? background;
  final Color? borderColor;

  /// Optional accent: tints the card with a gentle gradient and border.
  final Color? accent;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 18.0,
    this.onTap,
    this.background,
    this.borderColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = background ?? theme.colorScheme.surface;
    final radius = BorderRadius.circular(borderRadius);

    final Color top;
    if (accent != null) {
      top = Color.alphaBlend(accent!.withValues(alpha: dark ? 0.16 : 0.12), base);
    } else {
      top = Color.alphaBlend(Colors.white.withValues(alpha: dark ? 0.05 : 0.0), base);
    }
    final border = borderColor ??
        (accent != null ? accent!.withValues(alpha: 0.32) : theme.dividerColor);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, base],
        ),
        border: Border.all(color: border, width: 1),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14102A22),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
