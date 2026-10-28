import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/scan/scan_result_screen.dart';
import 'package:mobile/features/settings/settings_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/navigation/bottom_navigation.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

final _profile = {
  'user_id': 'u', 'name': 'Suhail Ahmed Choudhury',
  'health_conditions': ['diabetes_type_1', 'high_cholesterol', 'lactose_intolerance'],
  'allergies': ['peanut', 'tree nuts'], 'dietary_preferences': ['vegetarian'],
  'health_goals': ['weight_loss', 'manage_blood_sugar'],
  'height_cm': 172, 'weight_kg': 80, 'target_weight_kg': 72, 'birth_year': 1998,
  'sex': 'male', 'activity_level': 'very_active', 'bmi': 27.0, 'bmi_category': 'obese',
};

final _scan = {
  'scan_id': 's1', 'user_id': 'u', 'scanned_at': '2026-10-27T09:00:00Z',
  'product_name': 'Haldiram\'s Aloo Bhujia Masala Namkeen Family Pack',
  'brand': 'Haldiram\'s', 'score': 15, 'suitability': 'not_suitable', 'image_url': null,
};

ApiService _api() => ApiService(
      baseUrl: 'http://test',
      tokenStore: MemoryAuthTokenStore(),
      client: MockClient((req) async => switch (req.url.path) {
            '/api/v1/auth/device' => _json({'user_id': 'u', 'token': 't'}),
            '/api/v1/scans/history' => _json([_scan, {..._scan, 'scan_id': 's2'}]),
            '/api/v1/scans/stats' => _json({'total': 31, 'average': 18, 'best': 75}),
            '/api/v1/insights' => _json({
                'total_scans': 31, 'average_score': 18,
                'suitability_counts': {'excellent': 3, 'good': 5, 'fair': 6, 'poor': 7, 'not_suitable': 10},
                'weekly': [for (var i = 0; i < 8; i++)
                  {'week_start': DateTime(2026, 9, 7).add(Duration(days: 7 * i)).toIso8601String().substring(0, 10),
                   'scans': 4, 'average_score': 10 * i}],
                'top_flags': [{'rule_id': 'R', 'title': 'Critical sugar level for diabetes',
                               'severity': 'critical', 'count': 12}],
                'best': [{..._scan, 'score': 85, 'suitability': 'excellent'}],
                'needs_attention': [_scan],
                'goals': [{'goal': 'manage_blood_sugar', 'tracked': true,
                           'basis': 'Sugar per serving and high-glycaemic ingredients',
                           'checked': 31, 'fits': 9, 'main_issue': 'Critical sugar level for diabetes'}],
              }),
            _ => _json(_profile),
          }),
    );

/// A small phone (360 dp wide) with text at double size: the in-app
/// "Extra large" on top of a large system font.
Widget _big(Widget home) => MediaQuery(
      data: const MediaQueryData(size: Size(360, 780), textScaler: TextScaler.linear(2.0)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: home,
      ),
    );

Future<void> _check(WidgetTester tester, Widget screen, {List<String> tabs = const []}) async {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_big(screen));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  for (final t in tabs) {
    await tester.tap(find.text(t).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow on the $t tab');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {'calfit.disclaimer_acknowledged.v1': true, 'calfit.onboarded.v1': true}));

  testWidgets('every tab fits at double text size on a small phone', (tester) async {
    await _check(tester, BottomNavigation(apiService: _api(), userId: 'u'),
        tabs: ['History', 'Insights', 'Profile', 'Home']);
  });

  testWidgets('settings fit at double text size', (tester) async {
    await _check(tester, SettingsScreen(apiService: _api()));
  });

  testWidgets('onboarding fits at double text size', (tester) async {
    await _check(tester, OnboardingScreen(apiService: _api(), onDone: () {}));
  });

  testWidgets('a scan result fits at double text size', (tester) async {
    final result = ScanResult.fromJson({
      ..._scan,
      'product': {'product_name': _scan['product_name'], 'brand': _scan['brand'],
                  'ingredients': ['gram flour', 'palmolein', 'salt'],
                  'nutrition': {'calories_kcal': 586, 'sodium_mg': 615, 'sugars_g': 1.5}},
      'score_result': {'score': 15, 'suitability': 'not_suitable', 'risk_level': 'high',
                       'findings': [{'rule_id': 'R', 'severity': 'critical',
                                     'title': 'Critical sugar level for diabetes',
                                     'detail': '27 g of sugar per serving', 'score_impact': 45}],
                       'rules_applied': []},
      'explanation': 'High sugar and sodium for your profile.',
      'serving_size_unknown': true,
      'identification': {'status': 'confident',
                         'chosen': {'code': '8901262200189', 'source': 'open_food_facts',
                                    'name': "Haldiram's Aloo Bhujia Masala Namkeen Family Pack",
                                    'brand': "Haldiram's", 'quantity': '1 kg'}},
      'nutrient_levels': [
        {'nutrient': 'fat', 'per_100': 35.0, 'unit': 'g', 'basis': '100g', 'level': 'high'},
        {'nutrient': 'saturated_fat', 'per_100': 12.4, 'unit': 'g', 'basis': '100g', 'level': 'high'},
        {'nutrient': 'sugars', 'per_100': 2.5, 'unit': 'g', 'basis': '100g', 'level': 'low'},
        {'nutrient': 'salt', 'per_100': 1.54, 'unit': 'g', 'basis': '100g', 'level': 'high'},
      ],
      'alternatives': [{'type': 'product', 'name': 'Moong Dal', 'brand': 'Haldiram\'s',
                        'reason': 'Same category (Namkeen & bhujia). 79% less sodium per 100 g.',
                        'verified': true}],
    });
    await _check(tester, ScanResultScreen(scanResult: result, apiService: _api()));
  });

  testWidgets('icon-only buttons all have a label for screen readers', (tester) async {
    await _check(tester, BottomNavigation(apiService: _api(), userId: 'u'), tabs: ['Profile']);
    for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
      expect(b.tooltip, isNotNull, reason: 'IconButton without a tooltip');
    }
  });
}
