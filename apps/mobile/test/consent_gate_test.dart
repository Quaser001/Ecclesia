import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/features/consent/consent_notice.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The privacy notice comes before anything else, is agreed per person, and
// "I agree" needs "I am 18 or older" (DPDP Act s.6, s.9; Rules r.3).

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

class _Server {
  bool agreed;
  int consentPosts = 0;
  Map<String, dynamic>? lastBody;
  int postStatus = 201;
  _Server({this.agreed = false});

  ApiService api() {
    final store = MemoryAuthTokenStore()..write('tok');
    return ApiService(
      baseUrl: 'http://test',
      tokenStore: store,
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/consent' && req.method == 'GET') {
          return _json({'current_version': consentNoticeVersion, 'agreed': agreed});
        }
        if (req.url.path == '/api/v1/consent' && req.method == 'POST') {
          consentPosts++;
          lastBody = jsonDecode(req.body) as Map<String, dynamic>;
          if (postStatus == 201) agreed = true;
          return _json({'notice_version': consentNoticeVersion, 'agreed_at': '2026-10-29T10:00:00Z'},
              postStatus);
        }
        return _json({});
      }),
    );
  }
}

Widget _app(ApiService api, {String profileId = 'p1'}) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ConsentGate(
        key: ValueKey(profileId), // as in main.dart: one gate per person
        apiService: api,
        profileId: profileId,
        child: const Scaffold(body: Text('THE APP')),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the notice comes first; "I agree" needs the 18+ box; agreeing is sent', (tester) async {
    final server = _Server();
    await tester.pumpWidget(_app(server.api()));
    await tester.pumpAndSettle();

    expect(find.text('THE APP'), findsNothing);
    expect(find.text('Before you start'), findsOneWidget);
    // Rule 3: itemised data and the way to withdraw are on the notice itself.
    expect(find.textContaining('Your health profile'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('withdraws this consent'), 200);
    expect(find.textContaining('withdraws this consent'), findsOneWidget);

    final agree = find.widgetWithText(FilledButton, 'I agree');
    expect(tester.widget<FilledButton>(agree).onPressed, isNull);
    await tester.tap(find.text('I am 18 or older'));
    await tester.pump();
    await tester.tap(agree);
    await tester.pumpAndSettle();

    expect(server.consentPosts, 1);
    expect(server.lastBody, {'notice_version': consentNoticeVersion, 'adult_confirmed': true});
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('someone who already agreed goes straight in', (tester) async {
    await tester.pumpWidget(_app(_Server(agreed: true).api()));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('each family member agrees for themselves', (tester) async {
    final server = _Server(agreed: true);
    await tester.pumpWidget(_app(server.api(), profileId: 'me'));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);

    server.agreed = false; // a new identity on the server
    await tester.pumpWidget(_app(server.api(), profileId: 'father'));
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsOneWidget);
  });

  testWidgets('a 428 from the server brings the notice back', (tester) async {
    final api = _Server(agreed: true).api();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);

    api.consentNeeded.value = true; // e.g. after "Delete my data"
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calfit.consent.p1'), isNull);
  });

  testWidgets('an out-of-date notice asks for an app update, and stays', (tester) async {
    final server = _Server()..postStatus = 409;
    await tester.pumpWidget(_app(server.api()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am 18 or older'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'I agree'));
    await tester.pumpAndSettle();
    expect(find.textContaining('out of date'), findsOneWidget);
    expect(find.text('THE APP'), findsNothing);
  });

  test('a 428 on any call is consentRequired and raises the flag', () async {
    final api = ApiService(
        baseUrl: 'http://test',
        tokenStore: MemoryAuthTokenStore()..write('tok'),
        client: MockClient((_) async => _json({'detail': 'agree first'}, 428)));
    await expectLater(
      api.getScanHistory(),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.consentRequired)),
    );
    expect(api.consentNeeded.value, isTrue);
  });
}
