import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/app_theme.dart';
import 'package:mobile/core/widgets/profile_switcher.dart';
import 'package:mobile/features/profile/prescription_consent.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/profile_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Family profiles: one separate server identity per person on the phone
// (.10x/reviews/2026-10-29-data-privacy-audit.md, section 5).

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => ProfileRegistry.current = null);

  test('the existing sign-in becomes the first profile, so nobody loses data', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    final r = await ProfileRegistry.load();
    expect(r.profiles, hasLength(1));
    expect(r.active.token, 'tok-sharon');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calfit.auth_token'), isNull); // moved, not copied
    expect((await ProfileRegistry.load()).active.token, 'tok-sharon'); // survives a restart
  });

  test('each person signs in separately and sees only their own data', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    final r = await ProfileRegistry.load();
    final sharonId = r.activeId;
    final seen = <String?>[];
    var issued = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') return _json({'user_id': 'u', 'token': 'tok-new-${++issued}'});
      seen.add(req.headers['Authorization']);
      return _json([]);
    });
    ApiService apiFor(String id) =>
        ApiService(baseUrl: 'http://test', client: client, tokenStore: ProfileTokenStore(r, id));

    final fatherId = await r.add('Father');
    expect(r.activeId, fatherId);
    await apiFor(fatherId).getScanHistory();
    await apiFor(sharonId).getScanHistory();

    expect(seen, ['Bearer tok-new-1', 'Bearer tok-sharon']);
    expect(r.byId(fatherId)!.token, 'tok-new-1');
    expect(r.byId(sharonId)!.token, 'tok-sharon');
  });

  test('a request finishing after a switch stays with the person it was for', () async {
    SharedPreferences.setMockInitialValues({});
    final r = await ProfileRegistry.load();
    final first = r.activeId;
    final store = ProfileTokenStore(r, first);
    await r.add('Mother'); // switched away mid-request
    await store.write('tok-first'); // the first profile's registration completes
    expect(r.byId(first)!.token, 'tok-first');
    expect(r.active.token, isNull);
  });

  test('delete my data removes that person only; the last profile stays, empty', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    final r = await ProfileRegistry.load();
    final sharon = r.activeId;
    final father = await r.add('Father');
    await r.forget(father);
    expect(r.profiles.map((p) => p.id), [sharon]);
    expect(r.activeId, sharon);
    await r.forget(sharon);
    expect(r.profiles, hasLength(1));
    expect(r.active.token, isNull);
    expect(r.active.label, '');
  });

  test('prescription consent is per person', () async {
    SharedPreferences.setMockInitialValues({});
    final r = await ProfileRegistry.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calfit.rx_consent.${r.activeId}', true);
    final mother = await r.add('Mother');
    await prefs.setBool('calfit.rx_consent.$mother', true);
    await PrescriptionConsent.forget(); // Mother deletes her data
    expect(prefs.getBool('calfit.rx_consent.$mother'), isNull);
    expect(prefs.getBool('calfit.rx_consent.${r.profiles.first.id}'), isTrue);
  });

  testWidgets('add a family member from the switcher, adults only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final r = await tester.runAsync(ProfileRegistry.load);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Center(child: ProfileSwitcherButton())),
    ));
    await tester.tap(find.byType(ProfileSwitcherButton));
    await tester.pumpAndSettle();
    expect(find.text('Me'), findsWidgets);
    await tester.tap(find.text('Add family member'));
    await tester.pumpAndSettle();
    expect(find.textContaining('For adults (18+)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Father');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(r!.profiles.map((p) => p.label), ['', 'Father']);
    expect(r.active.label, 'Father');
  });
}
