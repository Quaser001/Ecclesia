import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/features/profile/prescription_consent.dart';
import 'package:mobile/features/profile/prescription_merge.dart';
import 'package:mobile/features/profile/profile_screen.dart' show kConditionOptions;
import 'package:mobile/features/profile/prescription_review_screen.dart';
import 'package:mobile/models/prescription_suggestions.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json = {
  'conditions': [
    {
      'condition': 'diabetes_type_2',
      'basis': 'stated',
      'source_text': 'Type 2 diabetes'
    },
    {
      'condition': 'hypertension',
      'basis': 'inferred_from_medicine',
      'source_text': 'Amlodipine'
    },
  ],
  'allergies': [
    {'name': 'peanuts', 'source_text': 'Peanuts'}
  ],
  'unrecognised': ['Penicillin'],
  'insufficient_data': false,
  'message': null,
};

PrescriptionSuggestions _suggestions([Map<String, dynamic> j = _json]) =>
    PrescriptionSuggestions.fromJson(j);

UserProfile _profile() => UserProfile(
      userId: 'u1',
      healthConditions: const ['obesity'],
      allergies: const ['soy'],
    );

/// Pushes the review screen and records what it pops.
Future<List<UserProfile?>> _pumpReview(
  WidgetTester tester,
  PrescriptionSuggestions s,
) async {
  final results = <UserProfile?>[];
  await tester.pumpWidget(MaterialApp(localizationsDelegates: localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final r = await Navigator.push<UserProfile>(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionReviewScreen(
                      suggestions: s, currentProfile: _profile()),
                ),
              );
              results.add(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  test('PrescriptionSuggestions.fromJson parses everything', () {
    final s = _suggestions();
    expect(s.conditions.length, 2);
    expect(s.conditions[0].condition, 'diabetes_type_2');
    expect(s.conditions[0].inferred, isFalse);
    expect(s.conditions[1].inferred, isTrue);
    expect(s.allergies.single.name, 'peanuts');
    expect(s.unrecognised, ['Penicillin']);
    expect(s.isEmpty, isFalse);
  });

  group('ApiService.analyzePrescription', () {
    test('sends bearer token and a multipart photo, parses the result',
        () async {
      http.BaseRequest? seen;
      String body = '';
      final client = MockClient((req) async {
        if (req.url.path == '/api/v1/auth/device') {
          return http.Response(jsonEncode({'user_id': 'u', 'token': 't1'}), 200);
        }
        seen = req;
        body = latin1.decode(req.bodyBytes);
        return http.Response(jsonEncode(_json), 200);
      });
      final api = ApiService(
          baseUrl: 'http://test',
          client: client,
          tokenStore: MemoryAuthTokenStore());

      final result =
          await api.analyzePrescription(photoBytes: Uint8List.fromList([1, 2, 3]));

      expect(seen!.url.path, '/api/v1/profile/prescription-suggestions');
      expect(seen!.headers['Authorization'], 'Bearer t1');
      expect(body, contains('name="photo"'));
      expect(result.conditions.length, 2);
    });

    test('server message is surfaced for 503 and 429', () async {
      for (final status in [503, 429]) {
        final client = MockClient((req) async {
          if (req.url.path == '/api/v1/auth/device') {
            return http.Response(jsonEncode({'user_id': 'u', 'token': 't'}), 200);
          }
          return http.Response(jsonEncode({'detail': 'Custom reason $status'}), status);
        });
        final api = ApiService(
            baseUrl: 'http://test',
            client: client,
            tokenStore: MemoryAuthTokenStore());
        await expectLater(
          api.analyzePrescription(photoBytes: Uint8List.fromList([1])),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', 'Custom reason $status')),
        );
      }
    });
  });

  group('PrescriptionReviewScreen', () {
    testWidgets('nothing is pre-checked and Add is disabled', (tester) async {
      await _pumpReview(tester, _suggestions());
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(boxes.length, 3);
      expect(boxes.every((b) => b.value == false), isTrue);
      final add = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(add.onPressed, isNull);
    });

    testWidgets('inferred conditions are labelled', (tester) async {
      await _pumpReview(tester, _suggestions());
      expect(find.textContaining('Inferred from a medicine'), findsOneWidget);
      expect(find.textContaining('Stated on the prescription'), findsNWidgets(2));
    });

    testWidgets('adds only ticked items, merged without duplicates',
        (tester) async {
      final results = await _pumpReview(tester, _suggestions());
      await tester.tap(find.text('Type 2 diabetes'));
      await tester.tap(find.text('Peanuts'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final p = results.single!;
      expect(p.healthConditions, containsAll(['obesity', 'diabetes_type_2']));
      expect(p.healthConditions, isNot(contains('hypertension')));
      expect(p.allergies, containsAll(['soy', 'peanuts']));
      expect(p.healthConditions.toSet().length, p.healthConditions.length);
    });

    testWidgets('cancel pops null', (tester) async {
      final results = await _pumpReview(tester, _suggestions());
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(results.single, isNull);
    });

    testWidgets('empty result shows an empty state', (tester) async {
      await _pumpReview(
        tester,
        _suggestions({
          'conditions': [],
          'allergies': [],
          'unrecognised': [],
          'insufficient_data': false,
          'message': "We couldn't find anything to add from this photo.",
        }),
      );
      expect(find.textContaining("couldn't find anything"), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('PrescriptionConsent', () {
    testWidgets('asks once, remembers, and can be declined', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(localizationsDelegates: localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ));

      // Decline first.
      var future = PrescriptionConsent.ensure(ctx);
      await tester.pumpAndSettle();
      expect(find.textContaining('does not save'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await future, isFalse);

      // Agree.
      future = PrescriptionConsent.ensure(ctx);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);

      // Remembered: no sheet, immediate yes.
      final again = await PrescriptionConsent.ensure(ctx);
      await tester.pumpAndSettle();
      expect(again, isTrue);
      expect(find.text('Agree and continue'), findsNothing);
    });
  });

  group('mergePrescriptionAdditions', () {
    test('keeps edits made while the prescription was being read', () {
      final snapshot = UserProfile(userId: 'u', allergies: const ['soy']);
      // User added "milk" while Gemini was reading.
      final current = UserProfile(userId: 'u', allergies: const ['soy', 'milk']);
      final accepted = snapshot.copyWith(
          allergies: const ['soy', 'peanuts'],
          healthConditions: const ['hypertension']);

      final merged = mergePrescriptionAdditions(
          current: current, snapshot: snapshot, accepted: accepted);

      expect(merged.allergies, containsAll(['soy', 'milk', 'peanuts']));
      expect(merged.healthConditions, ['hypertension']);
      expect(merged.allergies.toSet().length, merged.allergies.length);
    });

    test('removals made meanwhile are not undone', () {
      final snapshot = UserProfile(userId: 'u', allergies: const ['soy']);
      final current = UserProfile(userId: 'u', allergies: const []);
      final accepted = snapshot.copyWith(allergies: const ['soy', 'peanuts']);

      final merged = mergePrescriptionAdditions(
          current: current, snapshot: snapshot, accepted: accepted);

      expect(merged.allergies, ['peanuts']);
    });
  });

  test('every condition the backend can suggest has a chip in Profile', () {
    const backendConditions = [
      'diabetes_type_1', 'diabetes_type_2', 'prediabetes', 'hypertension',
      'high_cholesterol', 'celiac_disease', 'ibs', 'kidney_disease',
      'heart_disease', 'obesity', 'lactose_intolerance', 'anaemia',
    ];
    for (final c in backendConditions) {
      expect(kConditionOptions.containsKey(c), isTrue,
          reason: '$c can be suggested but could not be removed in Profile');
    }
  });

  test('a malformed 200 response never prints its body to the log', () async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
    addTearDown(() => debugPrint = original);

    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        return http.Response(jsonEncode({'user_id': 'u', 'token': 't'}), 200);
      }
      return http.Response('{"conditions": [Metformin', 200);
    });
    final api = ApiService(
        baseUrl: 'http://test',
        client: client,
        tokenStore: MemoryAuthTokenStore());

    await expectLater(
      api.analyzePrescription(photoBytes: Uint8List.fromList([1])),
      throwsA(isA<ApiException>()),
    );
    expect(printed.join(' ').toLowerCase(), isNot(contains('metformin')));
  });
}
