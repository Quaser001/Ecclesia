import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/scan/scan_result_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';

ScanResult _result() => ScanResult.fromJson({
      'scan_id': 's1',
      'user_id': 'u',
      'scanned_at': '2026-10-28T09:00:00Z',
      'product': {
        'product_name': 'Lays Classic Salted',
        'nutrition': {'serving_size_g': 30, 'total_fat_g': 10.5},
      },
      'score_result': {
        'score': 40, 'suitability': 'fair', 'risk_level': 'moderate',
        'findings': [], 'rules_applied': [],
      },
      'explanation': '',
      'nutrient_levels': [
        {'nutrient': 'fat', 'per_100': 35.0, 'unit': 'g', 'basis': '100g', 'level': 'high'},
        {'nutrient': 'sugars', 'per_100': 1.0, 'unit': 'g', 'basis': '100g', 'level': 'low'},
        {'nutrient': 'salt', 'per_100': 1.25, 'unit': 'g', 'basis': '100g', 'level': 'medium'},
        {'nutrient': 'fat', 'per_100': 1.0, 'unit': 'g', 'basis': '100g', 'level': 'bogus'},
      ],
    });

class _Recorder {
  final requests = <http.Request>[];
  int status = 204;
  ApiService api() => ApiService(
        baseUrl: 'http://test',
        tokenStore: MemoryAuthTokenStore(),
        client: MockClient((req) async {
          if (req.url.path == '/api/v1/auth/device') {
            return http.Response(jsonEncode({'user_id': 'u', 'token': 't'}), 200,
                headers: {'content-type': 'application/json'});
          }
          requests.add(req);
          return http.Response('', status);
        }),
      );
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nutrient levels show a word and amount; unknown levels are dropped',
      (tester) async {
    await tester.pumpWidget(_app(ScanResultScreen(scanResult: _result())));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('At a glance'));
    expect(find.text('High'), findsOneWidget);
    expect(find.text('35 g'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('1.25 g'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.bySemanticsLabel('Total fat: High, 35 g'), findsOneWidget);
  });

  testWidgets('no feedback question without an ApiService', (tester) async {
    await tester.pumpWidget(_app(ScanResultScreen(scanResult: _result())));
    await tester.pumpAndSettle();
    expect(find.text('Was this result right?', skipOffstage: false), findsNothing);
  });

  testWidgets('"Not quite" sends the picked issues and says thanks', (tester) async {
    final rec = _Recorder();
    await tester.pumpWidget(_app(ScanResultScreen(scanResult: _result(), apiService: rec.api())));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Not quite'));
    await tester.tap(find.text('Not quite'));
    await tester.pumpAndSettle();

    // Send stays disabled until something is picked.
    final send = find.widgetWithText(FilledButton, 'Send');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(find.text('Nutrition numbers'));
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(rec.requests.single.url.path, '/api/v1/scans/s1/feedback');
    expect(jsonDecode(rec.requests.single.body),
        {'accurate': false, 'issues': ['wrong_nutrition']});
    expect(find.text('Thank you. This helps us get better.'), findsOneWidget);
  });

  testWidgets('"Yes" is one tap', (tester) async {
    final rec = _Recorder();
    await tester.pumpWidget(_app(ScanResultScreen(scanResult: _result(), apiService: rec.api())));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Yes'));
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(jsonDecode(rec.requests.single.body), {'accurate': true, 'issues': []});
    expect(find.text('Thank you. This helps us get better.'), findsOneWidget);
  });

  testWidgets('a failed send says so and keeps the picks', (tester) async {
    final rec = _Recorder()..status = 500;
    await tester.pumpWidget(_app(ScanResultScreen(scanResult: _result(), apiService: rec.api())));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Not quite'));
    await tester.tap(find.text('Not quite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong product'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send that. Check your connection and try again."), findsOneWidget);
    expect(find.text('Thank you. This helps us get better.'), findsNothing);
    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Wrong product'));
    expect(chip.selected, isTrue);
  });
}
