// Read-only academic checks against the running local API. Login sessions are
// created and revoked; no attendance, assessment, or quiz records are written.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:university_attendance_mobile/data/models.dart';

Future<void> main() async {
  final base =
      Platform.environment['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api/v1';
  final accounts = [
    ('doctor', 'doc_rasha01', 'Doctor@123'),
    ('ta', 'ta_nehad00', 'TA@123'),
    ('student', '20720236007', '20720236007'),
  ];
  final client = http.Client();
  Future<dynamic> call(String method, String path,
      {String? token, Object? body, int expected = 200}) async {
    final request = http.Request(method, Uri.parse('$base$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 20)));
    if (response.statusCode != expected) {
      throw StateError('$method $path returned ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  try {
    final health = await call('GET', '/health');
    if (health['status'] != 'ok') throw StateError('API is unhealthy');
    for (final (role, username, password) in accounts) {
      final login = await call('POST', '/auth/login', body: {
        'identifier':
            Platform.environment['${role.toUpperCase()}_USERNAME'] ?? username,
        'password':
            Platform.environment['${role.toUpperCase()}_PASSWORD'] ?? password,
      }) as Map<String, dynamic>;
      final token = login['token'] as String;
      try {
        final user =
            UserProfile.fromJson(login['user'] as Map<String, dynamic>);
        final me = UserProfile.fromJson(
            await call('GET', '/me', token: token) as Map<String, dynamic>);
        if (user.role.name != role || me.id != user.id) {
          throw StateError('Login profile mismatch');
        }
        final courses = (await call('GET', '/courses', token: token) as List)
            .map((row) => CourseOffering.fromJson(row as Map<String, dynamic>))
            .toList();
        if (courses.isEmpty) throw StateError('$role has no seeded courses');
        final course = courses.first;
        if (course.sections.isEmpty) {
          throw StateError('Missing course sections');
        }
        final root = '/courses/${course.id}';
        final sessions =
            (await call('GET', '$root/sessions', token: token) as List)
                .map((row) =>
                    AttendanceSession.fromJson(row as Map<String, dynamic>))
                .toList();
        await call('GET', '$root/policy', token: token);
        await call('GET', '$root/assessments', token: token);
        await call('GET', '$root/quizzes', token: token);
        await call('GET', '/notifications', token: token);
        if (role == 'student') {
          await call('GET', '$root/grades', token: token);
          await call('GET', '$root/roster', token: token, expected: 403);
        } else {
          final roster = await call('GET', '$root/roster', token: token);
          if ((roster['total'] as int) <= 0) {
            throw StateError('Seeded roster is empty');
          }
          await call('GET', '$root/assignments', token: token);
          await call('GET', '$root/questions', token: token);
          await call('GET', '$root/report', token: token);
        }
        stdout.writeln('$role: ${courses.length} courses, '
            '${course.sections.length} scoped sections in ${course.code}, '
            '${sessions.length} saved sessions; profile and workflows OK');
      } finally {
        await call('POST', '/auth/logout', token: token);
        await call('GET', '/me', token: token, expected: 401);
      }
    }
    stdout.writeln(
        'Live PostgreSQL API verification passed for all three roles.');
  } finally {
    client.close();
  }
}
