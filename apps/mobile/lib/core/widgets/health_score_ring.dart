import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../app/app_theme.dart';

/// The hero moment of a scan: the score reveals from 0 to its final value
/// over ~900ms with an eased curve. Serif numerals (Fraunces) make the
/// number itself feel considered, not generated.
class HealthScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final double strokeWidth;
  final bool animate;

  const HealthScoreRing({
    super.key,
    required this.score,
    this.size = 180.0,
    this.strokeWidth = 10.0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final target = score.clamp(0, 100).toDouble();
    final theme = Theme.of(context);
    final trackColor = theme.brightness == Brightness.dark
        ? AppColors.elevated
        : AppColors.lightElevated;

    return TweenAnimationBuilder<double>(
      duration: animate ? const Duration(milliseconds: 900) : Duration.zero,
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: target),
      builder: (context, value, _) {
        final current = value.round();
        final color = AppColors.scoreColor(current);
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value / 100,
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$current',
                    style: AppTheme.display(
                      size * 0.36,
                      weight: FontWeight.w500,
                      color: theme.textTheme.displayLarge?.color,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'out of 100',
                    style: AppTheme.ui(
                      size * 0.075,
                      weight: FontWeight.w500,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
