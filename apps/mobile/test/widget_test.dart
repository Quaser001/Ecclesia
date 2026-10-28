import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/features/scan/scan_result_screen.dart';
import 'package:mobile/models/scan_result.dart';

void main() {
  testWidgets('ScanResultScreen shows product, animated score and alternative',
      (WidgetTester tester) async {
    final mockResult = ScanResult(
      scanId: 'scan-1',
      userId: 'user-1',
      scannedAt: DateTime.now(),
      product: ProductObservation(
        brand: 'Healthy Co',
        productName: 'Organic Roasted Chickpeas',
        category: 'snacks',
        ingredients: const ['Chickpeas', 'Olive oil', 'Sea salt'],
        nutrition:
            NutritionInfo(caloriesKcal: 160, proteinG: 7, sodiumMg: 150),
        allergensDeclared: const [],
        visibleClaims: const ['High Protein', 'Gluten Free'],
        extractionConfidence: 0.98,
        insufficientData: false,
      ),
      scoreResult: ScoreResult(
        score: 85,
        suitability: SuitabilityStatus.excellent,
        riskLevel: 'low',
        findings: const [],
        rulesApplied: const [],
      ),
      explanation: 'Excellent choice with high protein and low sodium.',
      alternatives: [
        AlternativeItem(
          type: 'product',
          name: 'Roasted Edamame',
          brand: 'GreenSnack',
          reason: 'Even higher protein content',
          verified: true,
        ),
      ],
      insufficientData: false,
    );

    await tester.pumpWidget(
      MaterialApp(localizationsDelegates: localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: ScanResultScreen(scanResult: mockResult)),
    );
    // Let the score ring animation (900ms easeOutCubic) and any skeleton
    // transitions finish before asserting on their final frames.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Organic Roasted Chickpeas'), findsOneWidget);
    // Score animates 0 → 85. After pumpAndSettle it should land on 85.
    expect(find.text('8.5'), findsOneWidget); // score 85 tenths, shown out of 10
    // The verdict is shown as a coloured pill with its label, so the colour
    // is never the only signal.
    expect(find.text('Excellent fit'), findsOneWidget);
    // Alternatives sit below the fold in a lazily built list.
    await tester.scrollUntilVisible(find.text('Roasted Edamame'), 300);
    expect(find.text('Roasted Edamame'), findsOneWidget);
  });

  testWidgets('ScanResultScreen shows an insufficient-data state when flagged',
      (WidgetTester tester) async {
    final mockResult = ScanResult(
      scanId: 'scan-2',
      userId: 'user-1',
      scannedAt: DateTime.now(),
      product: ProductObservation(
        ingredients: const [],
        nutrition: NutritionInfo(),
        allergensDeclared: const [],
        visibleClaims: const [],
        extractionConfidence: 0.0,
        insufficientData: true,
      ),
      scoreResult: ScoreResult(
        score: 0,
        suitability: SuitabilityStatus.unknown,
        riskLevel: 'unknown',
        findings: const [],
        rulesApplied: const [],
      ),
      explanation: '',
      alternatives: const [],
      insufficientData: true,
      pipelineMessage: 'The image was blurry.',
    );

    await tester.pumpWidget(
      MaterialApp(localizationsDelegates: localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: ScanResultScreen(scanResult: mockResult)),
    );
    await tester.pumpAndSettle();

    expect(find.text("We couldn't read this label"), findsOneWidget);
    expect(find.text('The image was blurry.'), findsOneWidget);
  });
}
