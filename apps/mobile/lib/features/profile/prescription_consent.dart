import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../services/profile_registry.dart';

/// One-time, plain-language consent before a prescription photo is sent
/// anywhere. Declining changes nothing. Agreement is remembered on the device.
class PrescriptionConsent {
  static const _base = 'calfit.rx_consent';

  // Per profile: one family member agreeing doesn't agree for the others.
  static String get _key {
    final id = ProfileRegistry.current?.activeId;
    return id == null ? _base : '$_base.$id';
  }

  /// After "Delete my data": the next identity asks for consent again.
  static Future<void> forget() async =>
      (await SharedPreferences.getInstance()).remove(_key);

  static Future<bool> isGiven() async =>
      (await SharedPreferences.getInstance()).getBool(_key) == true;

  /// Withdrawing must be as easy as agreeing (DPDP Rules r.3(c)(i)). Also
  /// clears the un-namespaced key builds before family profiles wrote.
  static Future<void> withdraw() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_base);
  }

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
    final l = context.l10n;
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
            Text(l.prescriptionConsentTitle,
                style: AppTheme.display(24, color: theme.textTheme.displayMedium?.color)),
            const SizedBox(height: 14),
            point(Icons.cloud_upload_outlined, l.prescriptionConsentGemini),
            point(Icons.delete_outline_rounded, l.prescriptionConsentNoSave),
            point(Icons.fact_check_outlined, l.prescriptionConsentSuggestOnly),
            point(Icons.medical_information_outlined, l.prescriptionConsentNotAdvice),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.agreeAndContinue),
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
