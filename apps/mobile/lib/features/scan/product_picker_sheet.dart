import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/scan_photo.dart';
import '../../l10n/l10n.dart';
import '../../models/scan_result.dart';

/// "Is this the product?" (one option) or "Which one is it?" (up to three)
/// after a front-of-pack photo. Every option is a real product from the
/// CalFit database or Open Food Facts. Returns the pick, or null to retake.
Future<ProductOption?> showProductPicker(BuildContext context, Identification ident) {
  return showModalBottomSheet<ProductOption>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProductPickerSheet(identification: ident),
  );
}

class ProductPickerSheet extends StatelessWidget {
  final Identification identification;
  const ProductPickerSheet({super.key, required this.identification});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final single = identification.status == IdentificationStatus.confirm;
    final options = identification.options;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(single ? l.pickerConfirmTitle : l.pickerChooseTitle,
                style: theme.textTheme.headlineMedium),
            if (identification.readAs != null) ...[
              const SizedBox(height: 4),
              Text(l.pickerReadAs(identification.readAs!), style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            for (final o in options) ...[
              _OptionTile(
                option: o,
                onTap: single ? null : () => _pick(context, o),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            if (single)
              FilledButton(
                onPressed: () => _pick(context, options.first),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(l.pickerYes),
              ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(single ? l.pickerNoRetake : l.pickerNoneRetake),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, ProductOption o) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, o);
  }
}

class _OptionTile extends StatelessWidget {
  final ProductOption option;
  final VoidCallback? onTap;
  const _OptionTile({required this.option, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;
    final detail = [option.brand, option.quantity].whereType<String>().join(' · ');
    final source = option.fromOpenFoodFacts ? l.sourceOpenFoodFacts : l.sourceCalfitDb;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (option.imageUrl != null)
                ScanPhoto(url: option.imageUrl!, size: 56, radius: 12)
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: c.brand),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.name, style: theme.textTheme.titleMedium),
                    if (detail.isNotEmpty) Text(detail, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(source,
                        style: AppTheme.ui(12, weight: FontWeight.w600, color: c.muted)),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}
