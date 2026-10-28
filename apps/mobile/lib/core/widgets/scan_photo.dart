import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A scan's photo from a short-lived signed link. Fades in when loaded and
/// falls back to a quiet placeholder if the link has expired or the photo
/// can't be fetched. Decorative in lists, so hidden from screen readers.
class ScanPhoto extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final VoidCallback? onTap;

  const ScanPhoto({super.key, required this.url, this.size = 44, this.radius = 10, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: c.elevated,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          frameBuilder: (context, child, frame, wasSync) => wasSync
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: child,
                ),
          errorBuilder: (context, error, stack) =>
              Icon(Icons.image_outlined, color: c.muted, size: size * 0.45),
        ),
      ),
    );
    if (onTap == null) return ExcludeSemantics(child: image);
    return GestureDetector(onTap: onTap, child: image);
  }
}
