// Legacy shim: GlassCard used to be a backdrop-blurred panel. The new design
// uses `SurfaceCard` instead. We keep this file so older imports don't break
// during the refactor — new code should import `surface_card.dart` directly.

import 'package:flutter/material.dart';

import 'surface_card.dart';

export 'surface_card.dart' show SurfaceCard;

/// Deprecated. Use [SurfaceCard].
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 18.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: padding,
        borderRadius: borderRadius,
        onTap: onTap,
        child: child,
      );
}
