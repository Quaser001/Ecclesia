import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/profile/prescription_merge.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/navigation/bottom_navigation.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'calfit.disclaimer_acknowledged.v1': true});
  });

  testWidgets('a phone language CalFit does not offer falls back to English', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ta', 'IN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((req) async => req.url.path == '/api/v1/auth/device'
          ? _json({'user_id': 'u', 'token': 't'})
          : req.url.path == '/api/v1/scans/history'
              ? _json(<Object>[])
              : _json({'user_id': 'u'})),
      tokenStore: MemoryAuthTokenStore(),
    );
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: localizationsDelegates,
      home: BottomNavigation(apiService: api, userId: 'u'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  test('confirming a prescription keeps body details and other fields', () {
    final current = UserProfile(
      userId: 'u', name: 'Suhail', heightCm: 172, weightKg: 80, birthYear: 1998,
      sex: 'male', activityLevel: 'light', targetWeightKg: 72, avoidCaffeine: true,
      healthConditions: ['hypertension'],
    );
    final merged = mergePrescriptionAdditions(
      current: current,
      snapshot: current,
      accepted: current.copyWith(healthConditions: ['hypertension', 'diabetes_type_2']),
    );
    expect(merged.healthConditions, containsAll(['hypertension', 'diabetes_type_2']));
    expect([merged.heightCm, merged.weightKg, merged.birthYear, merged.sex,
            merged.activityLevel, merged.targetWeightKg, merged.avoidCaffeine],
        [172, 80, 1998, 'male', 'light', 72, true]);
  });

  test('saving sends avoid_caffeine and body details, and null clears a field', () async {
    Map<String, dynamic>? sent;
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/auth/device') return _json({'user_id': 'u', 'token': 't'});
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return _json({'user_id': 'u', ...sent!});
      }),
      tokenStore: MemoryAuthTokenStore(),
    );
    final p = UserProfile(userId: 'u', avoidCaffeine: true, heightCm: 172, weightKg: 80);
    await api.updateProfile(p.copyWith(weightKg: null));
    expect(sent!['avoid_caffeine'], isTrue);
    expect(sent!['height_cm'], 172);
    expect(sent!.containsKey('weight_kg'), isTrue);
    expect(sent!['weight_kg'], isNull);
  });

  test('delete with a rejected token reports an error and never re-registers', () async {
    var registrations = 0;
    final store = MemoryAuthTokenStore();
    await store.write('stale-token');
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/auth/device') {
          registrations++;
          return _json({'user_id': 'new', 'token': 'fresh'});
        }
        return _json({'detail': 'invalid'}, 401);
      }),
      tokenStore: store,
    );
    await expectLater(api.deleteMyData(), throwsA(isA<ApiException>()));
    expect(registrations, 0);
    expect(await store.read(), 'stale-token'); // nothing reset on failure
  });
}
