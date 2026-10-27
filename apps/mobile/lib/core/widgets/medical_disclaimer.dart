import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../constants/app_colors.dart';
import '../../l10n/l10n.dart';

/// Shared "not medical advice" copy for CalFit.
///
/// We say the same sentence everywhere so the user hears one consistent
/// message, not a dozen hand-written variants. Keep the wording honest and
/// without hedging — the point is that CalFit is a label reader, not a doctor.
class MedicalDisclaimer {
  static const String shortLine =
      'CalFit reads labels; it is not medical advice. Ask a doctor or '
      'dietitian for a diagnosis or treatment.';

  static const String onboardingTitle = 'A quick note before you start';
  static const String onboardingBody =
      'CalFit scans a product label and tells you how well it fits the '
      "profile you set. It cannot replace a doctor or dietitian and it won't "
      'know everything that is in a food.\n\n'
      "Always read the pack yourself if you have an allergy, and check with "
      'your clinician before changing anything in your diet because of a scan.';

  static const String _ackKey = 'calfit.disclaimer_acknowledged.v1';

  /// Returns true if the user has already acknowledged the onboarding notice.
  static Future<bool> isAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ackKey) ?? false;
  }

  static Future<void> markAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ackKey, true);
  }

  /// Show the one-time onboarding dialog if the user has not acknowledged it.
  /// Safe to call from `initState` with a `WidgetsBinding.instance.addPostFrameCallback`.
  static Future<void> showOnFirstLaunch(BuildContext context) async {
    if (await isAcknowledged()) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(ctx.l10n.disclaimerTitle),
          content: Text(ctx.l10n.disclaimerBody),
          actions: [
            TextButton(
              onPressed: () async {
                await markAcknowledged();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(ctx.l10n.gotIt),
            ),
          ],
        );
      },
    );
  }
}

/// Small footer line shown under every scan result so a user never forgets
/// the frame. Keeps the point low-key — we don't need a red banner on every
/// screen, just a steady reminder.
class MedicalDisclaimerFooter extends StatelessWidget {
  const MedicalDisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: context.colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.disclaimerShort,
              style: AppTheme.ui(12.5, color: theme.textTheme.bodySmall?.color),
            ),
          ),
        ],
      ),
    );
  }
}
