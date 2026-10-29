import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/profile_registry.dart';
import 'package:mobile/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sign-in tokens live in the Android Keystore, not in plain preferences.

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Future<String> _prefsDump() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonEncode({for (final k in prefs.getKeys()) k: prefs.get(k)});
}

void main() {
  late MemorySecretStore secrets;
  setUp(() {
    ProfileRegistry.current = null;
    secrets = MemorySecretStore();
  });

  test('the pre-family token moves to the Keystore and leaves prefs', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    final r = await ProfileRegistry.load(secrets);
    expect(r.active.token, 'tok-sharon');
    expect(secrets.values.values, ['tok-sharon']);
    // Kept in prefs until a later launch proves the Keystore copy reached disk.
    expect(await _prefsDump(), contains('tok-sharon'));
    expect((await ProfileRegistry.load(secrets)).active.token, 'tok-sharon');
    expect(await _prefsDump(), isNot(contains('tok-sharon')));
    // From then on the token comes from the Keystore alone.
    expect((await ProfileRegistry.load(secrets)).active.token, 'tok-sharon');
  });

  test('a Keystore copy lost before it reached disk is written again', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    await ProfileRegistry.load(secrets);
    secrets.values.clear(); // the app was killed before the plugin saved
    expect((await ProfileRegistry.load(secrets)).active.token, 'tok-sharon');
    expect(await _prefsDump(), contains('tok-sharon')); // still the safe copy
    expect((await ProfileRegistry.load(secrets)).active.resetPending, isFalse);
    expect(await _prefsDump(), isNot(contains('tok-sharon')));
  });

  test('tokens kept in the profiles list by the last build move too', () async {
    SharedPreferences.setMockInitialValues({
      'calfit.profiles.v1': jsonEncode([
        {'id': 'a', 'label': '', 'token': 'tok-a', 'reset_pending': false},
        {'id': 'b', 'label': 'Father', 'token': 'tok-b', 'reset_pending': true},
        {'id': 'c', 'label': 'Mother', 'token': null, 'reset_pending': false},
      ]),
      'calfit.profiles.active': 'b',
    });
    final r = await ProfileRegistry.load(secrets);
    final again = await ProfileRegistry.load(secrets);
    expect(await _prefsDump(), allOf(isNot(contains('tok-a')), isNot(contains('tok-b'))));
    expect(again.activeId, 'b');
    expect([for (final p in again.profiles) p.token], ['tok-a', 'tok-b', null]);
    expect(again.byId('b')!.resetPending, isTrue); // unchanged by the move
    expect(r.byId('c')!.resetPending, isFalse); // never signed in: just new
  });

  test('if the Keystore refuses the move, the token stays in prefs and works', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    secrets.failWrites = true;
    final r = await ProfileRegistry.load(secrets);
    expect(r.active.token, 'tok-sharon');
    expect(await _prefsDump(), contains('tok-sharon')); // not lost
    // Later launches, with a working Keystore, finish the move.
    secrets.failWrites = false;
    await ProfileRegistry.load(secrets);
    final again = await ProfileRegistry.load(secrets);
    expect(again.active.token, 'tok-sharon');
    expect(await _prefsDump(), isNot(contains('tok-sharon')));
  });

  for (final broken in ['empty', 'unreadable']) {
    test('a Keystore that is $broken means "save the profile again", not a new user', () async {
      SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
      await ProfileRegistry.load(secrets);
      await ProfileRegistry.load(secrets); // move confirmed: prefs no longer hold it
      broken == 'empty' ? secrets.values.clear() : secrets.failReads = true;

      final r = await ProfileRegistry.load(secrets);
      expect(r.active.token, isNull);
      expect(r.active.resetPending, isTrue);

      // So a scan is refused before anything is sent, instead of being
      // scored on a fresh identity that knows none of the person's allergies.
      final sent = <String>[];
      final api = ApiService(
        baseUrl: 'http://test',
        client: MockClient((req) async {
          sent.add(req.url.path);
          return _json({});
        }),
        tokenStore: ProfileTokenStore(r, r.activeId),
      );
      await expectLater(
        api.submitScan(photoBytes: Uint8List.fromList([0xFF, 0xD8])),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.profileReset)),
      );
      expect(sent, isEmpty);
    });
  }

  test('the old per-phone id, never used or sent, is wiped', () async {
    SharedPreferences.setMockInitialValues({'calfit.device_id': '9606aeb9-0000-4000-8000-000000000000'});
    await ProfileRegistry.load(secrets);
    expect(await _prefsDump(), isNot(contains('9606aeb9')));
  });

  test('a new sign-in is written to the Keystore, never to prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final r = await ProfileRegistry.load(secrets);
    await ProfileTokenStore(r, r.activeId).write('tok-new');
    expect(secrets.values.values, ['tok-new']);
    expect(await _prefsDump(), isNot(contains('tok-new')));
    expect((await ProfileRegistry.load(secrets)).active.token, 'tok-new');
  });

  test('a Keystore write failure is an error, not a forgotten sign-in', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-old'});
    final r = await ProfileRegistry.load(secrets);
    secrets.failWrites = true;
    await expectLater(ProfileTokenStore(r, r.activeId).write('tok-new'), throwsStateError);
    expect(r.active.token, 'tok-old');
  });

  test('a failed Keystore delete does not turn a finished delete into an error', () async {
    SharedPreferences.setMockInitialValues({});
    final r = await ProfileRegistry.load(secrets);
    await ProfileTokenStore(r, r.activeId).write('tok');
    secrets.failWrites = true;
    await ProfileTokenStore(r, r.activeId).clear(); // after the server deleted the data
    expect(r.active.token, isNull);
  });

  test('delete my data removes the token from the Keystore', () async {
    SharedPreferences.setMockInitialValues({'calfit.auth_token': 'tok-sharon'});
    final r = await ProfileRegistry.load(secrets);
    final father = await r.add('Father');
    await ProfileTokenStore(r, father).write('tok-father');
    await r.forget(father);
    expect(secrets.values.values, ['tok-sharon']);
    await r.forget(r.activeId); // the last profile stays, empty
    expect(secrets.values, isEmpty);
    expect((await ProfileRegistry.load(secrets)).active.resetPending, isFalse);
  });
}
