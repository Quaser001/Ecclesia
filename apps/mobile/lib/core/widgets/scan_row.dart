import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'score_badge.dart';
import 'surface_card.dart';

/// One scanned product in a list: score badge, name, a muted subtitle and a
/// chevron. Used by Home, History and Insights so they all look the same.
class ScanRow extends StatelessWidget {
  final int score;
  final String? productName;
  final String subtitle;
  final VoidCallback? onTap;

  const ScanRow({
    super.key,
    required this.score,
    required this.productName,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Row(
        children: [
          ScoreBadge(score: score),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName ?? 'Unnamed product',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
