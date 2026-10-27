import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';

/// One-time, plain-language consent before a prescription photo is sent
/// anywhere. Declining changes nothing. Agreement is remembered on the device.
class PrescriptionConsent {
  static const _key = 'calfit.rx_consent';

  /// Returns true if the user has agreed (now or earlier).
  static Future<bool> ensure(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return true;
    if (!context.mounted) return false;

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ConsentSheet(),
    );
    if (agreed == true) {
      await prefs.setBool(_key, true);
      return true;
    }
    return false;
  }
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Read a prescription?',
                style: AppTheme.display(24,
                    color: theme.textTheme.displayMedium?.color)),
            const SizedBox(height: 14),
            point(Icons.cloud_upload_outlined,
                'Your photo is sent to Google Gemini to be read.'),
            point(Icons.delete_outline_rounded,
                'CalFit does not save the photo or what is read from it.'),
            point(Icons.fact_check_outlined,
                'We only suggest conditions and allergies. Nothing is added unless you tick it and confirm.'),
            point(Icons.info_outline_rounded,
                'This is not medical advice. Check every suggestion.'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.verdict,
                      foregroundColor: AppColors.bg,
                    ),
                    child: const Text('Agree and continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
