import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Soft ambient colour behind the main tabs: a green glow top-right and a
/// faint ember glow on the left. Purely decorative, so it ignores touches and
/// stays low-contrast enough not to affect text legibility in either theme.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -140,
            right: -100,
            child: _Glow(color: AppColors.verdict, alpha: dark ? 0.16 : 0.22, size: 380),
          ),
          Positioned(
            top: 220,
            left: -170,
            child: _Glow(color: AppColors.ember, alpha: dark ? 0.07 : 0.13, size: 340),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double alpha;
  final double size;

  const _Glow({required this.color, required this.alpha, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
