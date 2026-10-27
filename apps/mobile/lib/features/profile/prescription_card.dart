import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';

/// Entry point on the Profile screen for reading a prescription.
class PrescriptionCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool busy;

  const PrescriptionCard({super.key, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = AppColors.ember;
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
                child: const Icon(Icons.medication_outlined,
                    color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prescription', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      busy
                          ? 'Reading your prescription…'
                          : 'Scan one to suggest conditions and allergies. You confirm before anything is saved.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontSize: 12.5),
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
