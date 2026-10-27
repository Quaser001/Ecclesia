import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../constants/app_colors.dart';

/// CalFit's mark: an open "C" with a leaf-tick inside.
///
/// Drawn from the same geometry as the launcher icon
/// (`android/app/src/main/res/drawable/ic_calfit_mark.xml`, a 108×108
/// viewport), so the app header and the home-screen icon match.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(ring: c.brand, tick: c.accent)),
    );
  }
}

/// The mark followed by the "CalFit" wordmark.
class BrandLockup extends StatelessWidget {
  final double markSize;
  const BrandLockup({super.key, this.markSize = 30});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'CalFit',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: markSize),
          const SizedBox(width: 8),
          Text(
            'CalFit',
            style: AppTheme.ui(markSize * 0.64,
                weight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color ring;
  final Color tick;
  _MarkPainter({required this.ring, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    // The artwork (stroke included) spans about x 36–79 and y 25–83 of the
    // 108 viewport; crop to a square around it so the mark fills the widget
    // instead of floating in adaptive-icon padding.
    const box = Rect.fromLTWH(28, 25, 58, 58);
    final s = size.width / box.width;
    canvas.save();
    canvas.scale(s);
    canvas.translate(-box.left, -box.top);

    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final c = Path()
      ..moveTo(74, 32)
      ..arcToPoint(const Offset(74, 76),
          radius: const Radius.circular(24), largeArc: true, clockwise: false);
    canvas.drawPath(c, ringPaint);

    final tickPaint = Paint()
      ..color = tick
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final t = Path()
      ..moveTo(46, 54)
      ..lineTo(54, 62)
      ..lineTo(68, 46);
    canvas.drawPath(t, tickPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ring != ring || old.tick != tick;
}
