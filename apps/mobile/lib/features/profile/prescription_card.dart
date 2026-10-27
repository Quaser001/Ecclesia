import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';

/// Entry point on the Profile screen for reading a prescription.
class PrescriptionCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool busy;

  const PrescriptionCard({super.key, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.colors.accent;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      onTap: busy ? null : onTap,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.medication_outlined, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.prescription, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      busy ? context.l10n.prescriptionReading : context.l10n.prescriptionBody,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!busy)
                Icon(Icons.document_scanner_outlined,
                    color: theme.colorScheme.primary),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
