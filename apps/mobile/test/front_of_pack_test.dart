import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/scan/product_picker_sheet.dart';
import 'package:mobile/features/scan/scan_result_screen.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';

const _lassi200 = {'code': '8901262200189', 'source': 'open_food_facts', 'name': 'Lassi',
                   'brand': 'Amul', 'quantity': '200mL', 'image_url': null};
const _lassiPlain = {'code': '8901262202046', 'source': 'open_food_facts', 'name': 'Amul Lassi',
                     'brand': 'Amul', 'quantity': null, 'image_url': null};

ScanResult _result({Map<String, dynamic>? identification, bool servingUnknown = false,
    Map<String, dynamic>? nutrition, String? dataSource}) =>
    ScanResult.fromJson({
      'scan_id': 's1', 'user_id': 'u', 'scanned_at': '2026-10-28T09:00:00Z',
      'product': {'product_name': 'Lassi', 'brand': 'Amul', 'data_source': dataSource,
                  'nutrition': nutrition ?? {'sugars_g': 6.8}},
      'score_result': {'score': 40, 'suitability': 'fair', 'risk_level': 'moderate',
                       'findings': [], 'rules_applied': []},
      'explanation': '',
      'identification': identification,
      'serving_size_unknown': servingUnknown,
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

/// A screen with one button that opens the picker and shows what came back.
class _PickerHost extends StatefulWidget {
  final Identification ident;
  const _PickerHost(this.ident);
  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  String picked = 'nothing yet';
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TextButton(
            onPressed: () async {
              final o = await showProductPicker(context, widget.ident);
              setState(() => picked = o?.code ?? 'retake');
            },
            child: const Text('open'),
          ),
          Text('picked: $picked'),
        ]),
      );
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing among several real products returns the one tapped', (tester) async {
    final ident = Identification.fromJson({
      'status': 'choose', 'read_as': 'Amul Lassi', 'options': [_lassiPlain, _lassi200]})!;
    expect(ident.needsChoice, isTrue);
    await tester.pumpWidget(_app(_PickerHost(ident)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Which one is it?'), findsOneWidget);
    expect(find.text('We read “Amul Lassi” on the pack.'), findsOneWidget);
    expect(find.text('Amul · 200mL'), findsOneWidget);
    expect(find.text('Open Food Facts'), findsNWidgets(2));
    await tester.tap(find.text('Amul · 200mL'));
    await tester.pumpAndSettle();
    expect(find.text('picked: 8901262200189'), findsOneWidget);
  });

  testWidgets('confirming one product: yes picks it, no means retake', (tester) async {
    final ident = Identification.fromJson(
        {'status': 'confirm', 'read_as': 'Amul Lassi 200 ml', 'options': [_lassi200]})!;
    await tester.pumpWidget(_app(_PickerHost(ident)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Is this the product?'), findsOneWidget);
    await tester.tap(find.text("Yes, that's it"));
    await tester.pumpAndSettle();
    expect(find.text('picked: 8901262200189'), findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, retake the photo'));
    await tester.pumpAndSettle();
    expect(find.text('picked: retake'), findsOneWidget);
  });

  testWidgets('retake, not found and unavailable never ask the user to pick', (tester) async {
    for (final status in ['retake', 'not_found', 'unavailable', 'confident']) {
      expect(Identification.fromJson({'status': status, 'options': [_lassi200]})!.needsChoice,
          isFalse);
    }
  });

  testWidgets('the result says which product and source were used', (tester) async {
    final result = _result(
      identification: {'status': 'confident', 'options': [_lassi200], 'chosen': _lassi200},
      dataSource: 'open_food_facts',
      nutrition: {'serving_size_g': 100, 'sugars_g': 14.5},
    );
    await tester.pumpWidget(_app(ScanResultScreen(scanResult: result)));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Identified as Lassi · 200mL'));
    expect(find.text('Nutrition per 100 g/ml from Open Food Facts'), findsOneWidget);
    expect(find.text('Not this product?'), findsNothing); // no ApiService: nothing to remove
    await _scrollTo(tester, find.text('Per 100 g/ml, from Open Food Facts. A dash means it isn\'t known.'));
  });

  testWidgets('"Not this product?" asks first, then deletes the scan', (tester) async {
    final rec = _Recorder();
    final result = _result(
        identification: {'status': 'confident', 'options': [_lassi200], 'chosen': _lassi200});
    await tester.pumpWidget(_app(Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => ScanResultScreen(scanResult: result, apiService: rec.api())),
    )));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Not this product?'));
    await tester.tap(find.text('Not this product?'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this scan?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(rec.requests, isEmpty);

    await tester.tap(find.text('Not this product?'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(rec.requests.single.method, 'DELETE');
    expect(rec.requests.single.url.path, '/api/v1/scans/s1');
  });

  testWidgets('serving size unknown: the answer is sent and confirmed', (tester) async {
    final rec = _Recorder();
    await tester.pumpWidget(_app(
        ScanResultScreen(scanResult: _result(servingUnknown: true), apiService: rec.api())));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Add serving size'));
    expect(find.text('Serving size unknown'), findsOneWidget);
    await tester.tap(find.text('Add serving size'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull); // nothing typed yet
    await tester.enterText(find.byType(TextField), '99999');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull); // impossible size
    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.text('Per serving'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final req = rec.requests.single;
    expect(req.method, 'PUT');
    expect(req.url.path, '/api/v1/scans/s1/serving');
    expect(jsonDecode(req.body), {'serving_size_g': 250.0, 'label_basis': 'per_serving'});
    // The card gets shorter, so the list may scroll it partly out of view.
    expect(find.text("Saved: 250 g/ml per serving. We'll use it the next time you scan this product.",
            skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('a failed save keeps the sheet open and says so', (tester) async {
    final rec = _Recorder()..status = 500;
    await tester.pumpWidget(_app(
        ScanResultScreen(scanResult: _result(servingUnknown: true), apiService: rec.api())));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Add serving size'));
    await tester.tap(find.text('Add serving size'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '200');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save. Check your connection and try again."), findsOneWidget);
    expect(find.text('Serving size'), findsOneWidget); // still on the sheet
  });
}
