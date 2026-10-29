import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/scan/scan_result_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/scan_result.dart';

// ADR-007: a past rating is history. It shows the profile it was scored for,
// and says that editing the profile doesn't change it.

ScanResult _scan({Map<String, dynamic>? scoredFor}) => ScanResult.fromJson({
      'scan_id': 's1',
      'user_id': 'u1',
      'scanned_at': '2026-10-08T09:00:00Z',
      'product': {'product_name': 'Sting Energy Drink', 'brand': 'Sting', 'ingredients': ['water']},
      'score_result': {
        'score': 100, 'suitability': 'excellent', 'risk_level': 'low',
        'findings': [], 'rules_applied': [],
        'scored_for': ?scoredFor,
      },
      'explanation': '',
      'alternatives': [],
    });

Future<void> _show(WidgetTester tester, ScanResult result, {required bool past}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ScanResultScreen(scanResult: result, isPastScan: past),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a past scan shows the profile it was scored for', (tester) async {
    await _show(tester, _scan(scoredFor: {
      'allergies': ['peanut'],
      'health_conditions': ['high_cholesterol'],
    }), past: true);
    expect(find.text('Scored for'), findsOneWidget);
    expect(find.textContaining('Peanut'), findsOneWidget);
    expect(find.textContaining("doesn't change this rating"), findsOneWidget);
  });

  testWidgets('a scan saved before this was recorded still says ratings are history',
      (tester) async {
    await _show(tester, _scan(), past: true);
    expect(find.text('Scored for'), findsOneWidget);
    expect(find.textContaining("doesn't change this rating"), findsOneWidget);
    expect(find.textContaining('Peanut'), findsNothing);
  });

  testWidgets('scored with an empty profile says so', (tester) async {
    await _show(tester, _scan(scoredFor: {}), past: false);
    expect(find.text('No allergies, conditions, diets or goals were set.'), findsOneWidget);
  });
}
