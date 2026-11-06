import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/grading.dart';

import 'api_test.dart' show TestTokenStore;

void main() {
  testWidgets(
      'sign-in requires identifier and password and offers no role bypass',
      (tester) async {
    await tester.pumpWidget(
        AttendanceApp(api: AttendanceApi(tokens: TestTokenStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل اسم المستخدم أو الرقم الجامعي.'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور.'), findsOneWidget);
    expect(find.text('Explore local demo'), findsNothing);
  });

  testWidgets('login supports a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
        AttendanceApp(api: AttendanceApi(tokens: TestTokenStore())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-identifier')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grade conflicts reload stored values before another edit',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var score = '0.00';
    var revision = 1;
    var writes = 0;
    var reads = 0;
    final api = AttendanceApi(
        tokens: TestTokenStore(),
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            writes++;
            final row = (jsonDecode(request.body)['rows'] as List).single;
            if (writes == 1) {
              expect(row['revision'], 1);
              score = '7.00';
              revision = 2;
              return http.Response(
                  jsonEncode({'detail': 'Grades changed'}), 409);
            }
            expect(row['revision'], 2);
            expect(row['score'], '9');
            score = '9.00';
            revision = 3;
            return http.Response('{"ok":true}', 200);
          }
          reads++;
          return http.Response(
              jsonEncode({
                'total': 1,
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student',
                    'university_id': '123',
                    'score': score,
                    'state': 'recorded',
                    'revision': revision,
                  }
                ],
              }),
              200);
        }));
    addTearDown(api.dispose);
    final course = CourseOffering.fromJson({
      'id': 1,
      'code': 'CS1',
      'name': 'Course',
      'term': 'Term',
      'doctor_name': 'Doctor',
      'is_archived': false,
      'sections': <dynamic>[],
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GradebookPage(api, course,
                {'id': 1, 'title': 'Assessment', 'max_points': '10'},
                canPublish: false))));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).at(1);
    await tester.enterText(field, '8');
    await tester.tap(find.text('حفظ درجات الصفحة'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(reads, 2);
    expect(tester.widget<TextField>(field).controller!.text, '7.00');
    await tester.enterText(field, '9');
    await tester.tap(find.text('حفظ درجات الصفحة'));
    await tester.pumpAndSettle();
    expect(writes, 2);
    expect(tester.widget<TextField>(field).controller!.text, '9.00');
  });
}
