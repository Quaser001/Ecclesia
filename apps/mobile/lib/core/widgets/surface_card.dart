import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../constants/app_colors.dart';

/// The one card used across the app: a flat surface with a hairline border.
///
/// No gradients and no glow. In light mode it gets a very soft shadow so
/// white cards separate from the off-white page; in dark mode the border
/// does that job. An [accent] tints the card and its border for moments that
/// carry meaning (the latest scan's verdict), and nothing else.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? background;
  final Color? borderColor;
  final Color? accent;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = AppTheme.radius,
    this.onTap,
    this.background,
    this.borderColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final Color fill = background ??
        (accent != null
            ? Color.alphaBlend(c.tint(accent!, theme.brightness),
                theme.colorScheme.surface)
            : theme.colorScheme.surface);
    final Color border = borderColor ??
        (accent != null ? accent!.withValues(alpha: 0.35) : c.divider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D2B2117),
                  blurRadius: 12,
                  offset: Offset(0, 3),
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
