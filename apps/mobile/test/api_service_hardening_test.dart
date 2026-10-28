import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';

// The 2026-10-29 hardening pass (.10x/specs/2026-10-29-production-hardening.md).

const _profileJson = {
  'user_id': 'u2',
  'name': null,
  'health_conditions': [],
  'allergies': [],
  'dietary_preferences': [],
  'health_goals': [],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

void main() {
  test('[AP] a 401 on a scan is never retried on a fresh, empty identity', () async {
    final scans = <String?>[];
    final store = MemoryAuthTokenStore();
    await store.write('old-token');
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        return _json({'user_id': 'u2', 'token': 'new-token'});
      }
      if (req.url.path == '/api/v1/scans') {
        scans.add(req.headers['Authorization']);
        return _json({'detail': 'Missing or invalid credentials.'}, 401);
      }
      return _json(_profileJson);
    });
    final api = ApiService(baseUrl: 'http://test', client: client, tokenStore: store);

    await expectLater(
      api.submitScan(photoBytes: _photo),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.profileReset)),
    );
    expect(scans, ['Bearer old-token']); // not re-sent with a new identity
    expect(await store.profileResetPending(), isTrue);

    // Still refused before anything is sent, until the profile is saved again.
    await expectLater(api.submitScan(photoBytes: _photo), throwsA(isA<ApiException>()));
    expect(scans.length, 1);

    await api.updateProfile(UserProfile.fromJson(_profileJson));
    expect(await store.profileResetPending(), isFalse);
  });

  test('[AR] error bodies (which can echo health data) are not logged', () async {
    final logged = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logged.add(message ?? '');
    addTearDown(() => debugPrint = original);

    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        return _json({'user_id': 'u2', 'token': 't'});
      }
      return _json({'detail': 'allergies: peanut, diabetes'}, 422);
    });
    final api = ApiService(baseUrl: 'http://test', client: client, tokenStore: MemoryAuthTokenStore());

    await expectLater(api.getProfile(), throwsA(isA<ApiException>()));
    expect(logged.join('\n'), isNot(contains('peanut')));
  });

  test('a prescription feature switched off is not shown as a server outage', () async {
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        return _json({'user_id': 'u2', 'token': 't'});
      }
      return _json({'detail': 'Prescription reading is not enabled on this server.'}, 503);
    });
    final api = ApiService(baseUrl: 'http://test', client: client, tokenStore: MemoryAuthTokenStore());

    await expectLater(
      api.analyzePrescription(photoBytes: _photo),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.other)),
    );
  });

  test('[AV] the prescription daily limit is its own error, not a generic one', () async {
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        return _json({'user_id': 'u2', 'token': 't'});
      }
      return _json({'detail': "You've reached today's prescription limit (5)."}, 429);
    });
    final api = ApiService(baseUrl: 'http://test', client: client, tokenStore: MemoryAuthTokenStore());

    await expectLater(
      api.analyzePrescription(photoBytes: _photo),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.prescriptionLimit)),
    );
  });
}
