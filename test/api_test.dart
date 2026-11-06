import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/data/api.dart';

class TestTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? token) async {
    value = token;
  }
}

void main() {
  test('authenticated reads carry a token and retain scoped IDs', () async {
    final api = AttendanceApi(client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session');
      expect(request.url.queryParameters['section_id'], '18');
      return http.Response('[]', 200);
    }))
      ..token = 'session';
    expect(
        await api
            .request('GET', '/courses/1/roster', query: {'section_id': 18}),
        isEmpty);
    api.dispose();
  });

  test('expired authentication triggers logout and surfaces the server error',
      () async {
    var expired = false;
    final api = AttendanceApi(
        client: MockClient((request) async =>
            http.Response(jsonEncode({'detail': 'Session expired'}), 401)))
      ..token = 'expired'
      ..onSessionExpired = () => expired = true;
    await expectLater(
        api.me(),
        throwsA(isA<ApiException>()
            .having((error) => error.status, 'status', 401)));
    expect(expired, isTrue);
    api.dispose();
  });

  test('transport failure returns an error without invented fallback records',
      () async {
    final api = AttendanceApi(
        client: MockClient(
            (request) async => throw http.ClientException('offline')));
    await expectLater(api.courses(), throwsA(isA<ApiException>()));
    api.dispose();
  });

  test('writes send explicit zero and request identity', () async {
    final api = AttendanceApi(client: MockClient((request) async {
      expect(jsonDecode(request.body)['score'], '0.00');
      expect(request.headers['Idempotency-Key'], hasLength(32));
      return http.Response('{"ok":true}', 200);
    }));
    await api.request('PATCH', '/results', body: {'score': '0.00'});
    api.dispose();
  });
}
