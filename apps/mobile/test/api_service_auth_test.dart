import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_token_store.dart';

const _profileJson = {
  'user_id': 'u1',
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

void main() {
  test('registers once, then sends the bearer token and no user_id', () async {
    final seen = <http.Request>[];
    final client = MockClient((req) async {
      seen.add(req);
      if (req.url.path == '/api/v1/auth/device') {
        return _json({'user_id': 'u1', 'token': 'tok-1'});
      }
      return _json(_profileJson);
    });
    final api = ApiService(
      baseUrl: 'http://test',
      client: client,
      tokenStore: MemoryAuthTokenStore(),
    );

    await api.getProfile();
    await api.getProfile();

    final registrations =
        seen.where((r) => r.url.path == '/api/v1/auth/device').length;
    expect(registrations, 1);
    final profileCalls = seen.where((r) => r.url.path == '/api/v1/profile');
    expect(profileCalls.length, 2);
    for (final r in profileCalls) {
      expect(r.headers['Authorization'], 'Bearer tok-1');
      expect(r.url.queryParameters.containsKey('user_id'), isFalse);
    }
  });

  test('concurrent first calls share a single registration', () async {
    var issued = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        issued++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json({'user_id': 'u$issued', 'token': 'tok-$issued'});
      }
      if (req.url.path.endsWith('/history')) return _json([]);
      return _json(_profileJson);
    });
    final api = ApiService(
      baseUrl: 'http://test',
      client: client,
      tokenStore: MemoryAuthTokenStore(),
    );

    await Future.wait([api.getProfile(), api.getScanHistory()]);

    expect(issued, 1);
  });

  test('a 401 drops the token, re-registers once and retries', () async {
    var issued = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/device') {
        issued++;
        return _json({'user_id': 'u$issued', 'token': 'tok-$issued'});
      }
      if (req.headers['Authorization'] == 'Bearer stale') {
        return _json({'detail': 'nope'}, 401);
      }
      return _json(_profileJson);
    });
    final store = MemoryAuthTokenStore();
    await store.write('stale');
    final api =
        ApiService(baseUrl: 'http://test', client: client, tokenStore: store);

    final profile = await api.getProfile();

    expect(profile.userId, 'u1');
    expect(issued, 1);
    expect(await store.read(), 'tok-1');
  });

  test('registration failure surfaces as an ApiException, not a crash',
      () async {
    final client = MockClient(
        (req) async => _json({'detail': 'Authentication is not configured'}, 503));
    final api = ApiService(
      baseUrl: 'http://test',
      client: client,
      tokenStore: MemoryAuthTokenStore(),
    );

    expect(api.getProfile(), throwsA(isA<ApiException>()));
  });
}
