import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/history/history_screen.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

/// 25 scans, newest first, one hour apart.
final _all = [
  for (var i = 24; i >= 0; i--)
    {
      'scan_id': 's$i',
      'user_id': 'u',
      'scanned_at': DateTime.utc(2026, 10, 1).add(Duration(hours: i)).toIso8601String(),
      'product_name': 'Product $i',
      'brand': 'B',
      'score': 50,
      'suitability': 'fair',
      'image_url': null,
    },
];

ApiService _api(List<Uri> seen) => ApiService(
      baseUrl: 'http://test',
      tokenStore: MemoryAuthTokenStore(),
      client: MockClient((req) async {
        seen.add(req.url);
        switch (req.url.path) {
          case '/api/v1/auth/device':
            return _json({'user_id': 'u', 'token': 't'});
          case '/api/v1/scans/stats':
            return _json({'total': 31, 'average': 18, 'best': 75});
          case '/api/v1/scans/history':
            final limit = int.parse(req.url.queryParameters['limit'] ?? '20');
            final before = req.url.queryParameters['before'];
            final rows = _all
                .where((r) => before == null ||
                    DateTime.parse(r['scanned_at'] as String).isBefore(DateTime.parse(before)))
                .take(limit)
                .toList();
            return _json(rows);
          default:
            return _json({'user_id': 'u', 'name': 'Suhail'});
        }
      }),
    );

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('History loads the next page when you scroll to the end', (tester) async {
    final seen = <Uri>[];
    await tester.pumpWidget(_app(HistoryScreen(apiService: _api(seen))));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Product 0'), 400, maxScrolls: 60);
    await tester.pumpAndSettle();

    final pages = seen.where((u) => u.path == '/api/v1/scans/history').toList();
    expect(pages.length, 2);
    expect(pages.last.queryParameters['before'], isNotNull);
    expect(find.text('Product 0'), findsOneWidget); // the 25th, from page two
    expect(find.text('Product 24'), findsNothing); // scrolled away, not duplicated
  });

  testWidgets('Home shows totals across all scans, not just one page', (tester) async {
    final seen = <Uri>[];
    await tester.pumpWidget(_app(HomeScreen(apiService: _api(seen))));
    await tester.pumpAndSettle();
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1.8'), findsOneWidget); // average 18 tenths, shown out of 10
    expect(find.text('7.5'), findsOneWidget);
  });
}
