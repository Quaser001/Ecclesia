import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/insights/insights_screen.dart';
import 'package:mobile/models/insights.dart';
import 'package:mobile/navigation/bottom_navigation.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

const _profile = {
  'user_id': 'u1',
  'name': 'Suhail',
  'health_conditions': ['diabetes_type_1'],
  'allergies': ['peanut'],
  'dietary_preferences': [],
  'health_goals': [],
};

Map<String, dynamic> _insights({int total = 3}) => {
      'total_scans': total,
      'average_score': total == 0 ? null : 42,
      'suitability_counts': {
        'excellent': total == 0 ? 0 : 1,
        'good': 0,
        'fair': 0,
        'poor': total == 0 ? 0 : 1,
        'not_suitable': total == 0 ? 0 : 1,
      },
      'weekly': [
        for (var i = 0; i < 8; i++)
          {
            'week_start': DateTime(2026, 9, 7)
                .add(Duration(days: 7 * i))
                .toIso8601String()
                .substring(0, 10),
            'scans': i == 7 && total > 0 ? 3 : 0,
            'average_score': i == 7 && total > 0 ? 42 : null,
          },
      ],
      'top_flags': total == 0
          ? []
          : [
              {'rule_id': 'R-SUGAR', 'title': 'Very high sugar', 'severity': 'critical', 'count': 2},
            ],
      'best': total == 0
          ? []
          : [
              {'scan_id': 's1', 'product_name': 'Rolled Oats', 'brand': 'Saffola',
               'score': 95, 'suitability': 'excellent'},
            ],
      'needs_attention': total == 0
          ? []
          : [
              {'scan_id': 's2', 'product_name': 'Masala Munch', 'brand': 'Kurkure',
               'score': 0, 'suitability': 'not_suitable'},
            ],
    };

ApiService _api(Map<String, Object> routes) {
  final client = MockClient((req) async {
    if (req.url.path == '/api/v1/auth/device') {
      return _json({'user_id': 'u1', 'token': 'tok'});
    }
    final body = routes[req.url.path];
    return body == null ? _json({'detail': 'nope'}, 404) : _json(body);
  });
  return ApiService(baseUrl: 'http://test', client: client, tokenStore: MemoryAuthTokenStore());
}

Widget _app(Widget home) => MaterialApp(localizationsDelegates: localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, theme: AppTheme.lightTheme, home: home);

void main() {
  setUp(() {
    // The "not medical advice" dialog has already been acknowledged.
    SharedPreferences.setMockInitialValues({'calfit.disclaimer_acknowledged.v1': true});
  });

  test('a week without scans parses as unknown, not zero', () {
    final data = Insights.fromJson(_insights());
    expect(data.totalScans, 3);
    expect(data.weekly, hasLength(8));
    expect(data.weekly.first.averageScore, isNull);
    expect(data.weekly.last.averageScore, 42);
    expect(data.topFlags.single.title, 'Very high sugar');
  });

  testWidgets('bottom bar has two tabs on each side of Scan, all the same width',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final api = _api({
      '/api/v1/profile': _profile,
      '/api/v1/scans/history': <Object>[],
    });
    await tester.pumpWidget(_app(BottomNavigation(apiService: api)));
    await tester.pumpAndSettle();

    final scan = tester.getCenter(find.byTooltip('Scan a product')).dx;
    Rect tab(String label) => tester.getRect(find.bySemanticsLabel(label));
    final home = tab('Home'), history = tab('History'),
        insights = tab('Insights'), profile = tab('Profile');

    expect(home.center.dx < scan && history.center.dx < scan, isTrue);
    expect(insights.center.dx > scan && profile.center.dx > scan, isTrue);
    for (final r in [history, insights, profile]) {
      expect(r.width, closeTo(home.width, 0.5));
    }
    // Mirror-symmetric around the Scan button.
    expect(scan - home.center.dx, closeTo(profile.center.dx - scan, 0.5));
    expect(scan - history.center.dx, closeTo(insights.center.dx - scan, 0.5));
  });

  testWidgets('Insights shows the average, top issue and picks', (tester) async {
    final api = _api({'/api/v1/insights': _insights()});
    await tester.pumpWidget(_app(InsightsScreen(apiService: api)));
    await tester.pumpAndSettle();

    expect(find.text('4.2'), findsWidgets); // average 42 tenths, shown out of 10
    await tester.scrollUntilVisible(find.text('Very high sugar'), 300);
    expect(find.text('Very high sugar'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Masala Munch'), 300);
    expect(find.text('Rolled Oats'), findsOneWidget);
    expect(find.text('Masala Munch'), findsOneWidget);
  });

  testWidgets('goal cards show how many scans fit, and say when a goal is not tracked',
      (tester) async {
    final data = _insights()
      ..['goals'] = [
        {'goal': 'manage_blood_sugar', 'tracked': true, 'basis': 'Sugar per serving',
         'checked': 3, 'fits': 2, 'main_issue': 'Very high sugar'},
        {'goal': 'improve_energy', 'tracked': false, 'basis': 'no rule',
         'checked': 0, 'fits': 0, 'main_issue': null},
      ];
    final api = _api({
      '/api/v1/insights': data,
      '/api/v1/profile': {..._profile, 'weight_kg': 80, 'target_weight_kg': 72},
    });
    await tester.pumpWidget(_app(InsightsScreen(apiService: api)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Manage blood sugar'), 300);
    expect(find.text('2 of 3 scans fit this goal'), findsOneWidget);
    expect(find.text('Most common issue: Very high sugar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('More energy'), 300);
    expect(find.textContaining('Not tracked yet'), findsOneWidget);
  });

  testWidgets('Insights with no scans offers to scan instead of empty charts',
      (tester) async {
    var scanStarted = false;
    final api = _api({'/api/v1/insights': _insights(total: 0)});
    await tester.pumpWidget(
        _app(InsightsScreen(apiService: api, onStartScan: () => scanStarted = true)));
    await tester.pumpAndSettle();

    expect(find.text('Your trends live here'), findsOneWidget);
    await tester.tap(find.text('Scan a product'));
    expect(scanStarted, isTrue);
  });

  testWidgets('a failed Insights load shows an error with retry, not an empty state',
      (tester) async {
    final api = _api({}); // every route 404s
    await tester.pumpWidget(_app(InsightsScreen(apiService: api)));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your insights"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Your trends live here'), findsNothing);
  });
}
