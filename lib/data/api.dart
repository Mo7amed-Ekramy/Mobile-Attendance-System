import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'attendance_session');
  @override
  Future<void> write(String? token) => token == null
      ? _storage.delete(key: 'attendance_session')
      : _storage.write(key: 'attendance_session', value: token);
}

class AttendanceApi {
  AttendanceApi({http.Client? client, TokenStore? tokens, String? baseUrl})
      : _client = client ?? http.Client(),
        tokens = tokens ?? const SecureTokenStore(),
        baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL',
                defaultValue: 'http://localhost:8000/api/v1');
  final http.Client _client;
  final TokenStore tokens;
  final String baseUrl;
  String? token;
  void Function()? onSessionExpired;

  Future<dynamic> request(String method, String path,
      {Object? body,
      Map<String, dynamic>? query,
      bool authenticated = true}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {
      for (final entry in (query ?? <String, dynamic>{}).entries)
        if (entry.value != null) entry.key: '${entry.value}',
    });
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (method != 'GET') {
      final random = Random.secure();
      headers['Idempotency-Key'] = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
    }
    try {
      final outbound = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) outbound.body = jsonEncode(body);
      final response = await http.Response.fromStream(
          await _client.send(outbound).timeout(const Duration(seconds: 20)));
      final decoded = response.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && authenticated) {
          onSessionExpired?.call();
        }
        final detail = decoded is Map ? decoded['detail'] : null;
        throw ApiException(
            detail is String ? detail : 'يرجى مراجعة البيانات المدخلة.',
            status: response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
          'انتهت مهلة الاتصال. تحقق من الشبكة ثم حدّث الصفحة لمعرفة نتيجة الطلب.');
    } on http.ClientException {
      throw const ApiException(
          'تعذر الاتصال بالخادم. تحقق من تشغيله ومن اتصال الشبكة.');
    } on FormatException {
      throw const ApiException('استجابة الخادم غير صحيحة.');
    }
  }

  Future<UserProfile> login(String identifier, String password) async {
    final data = await request('POST', '/auth/login',
            authenticated: false,
            body: {'identifier': identifier.trim(), 'password': password})
        as Map<String, dynamic>;
    token = data['token'] as String;
    await tokens.write(token);
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> me() async =>
      UserProfile.fromJson(await request('GET', '/me') as Map<String, dynamic>);

  Future<List<CourseOffering>> courses() async =>
      (await request('GET', '/courses') as List)
          .map(
              (value) => CourseOffering.fromJson(value as Map<String, dynamic>))
          .toList();

  Future<void> logout() async {
    try {
      if (token != null) await request('POST', '/auth/logout');
    } finally {
      token = null;
      await tokens.write(null);
    }
  }

  Future<dynamic> getCourse(CourseOffering course, String path,
          {int? sectionId, Map<String, dynamic>? query}) =>
      request('GET', '/courses/${course.id}/$path',
          query: {'section_id': sectionId, ...?query});

  Future<dynamic> writeCourse(CourseOffering course, String path, Object? body,
          {String method = 'POST'}) =>
      request(method, '/courses/${course.id}/$path', body: body);

  void dispose() => _client.close();
}
