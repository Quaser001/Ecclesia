import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../constants/app_colors.dart';
import '../../l10n/l10n.dart';
import '../utils/score_format.dart';

/// A score in a softly tinted rounded square. The number is always shown,
/// so the colour is never the only signal.
class ScoreBadge extends StatelessWidget {
  final int score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.score(score);
    return Semantics(
      label: context.l10n.scoreOutOf10(formatScore(score)),
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.tint(color, Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: Text(
          formatScore(score),
          maxLines: 1,
          style: AppTheme.display(size * 0.32, weight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
