import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app_state.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/grading.dart';
import 'package:university_attendance_mobile/features/settings.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String? value) async {}
}

CourseOffering _course() => CourseOffering.fromJson({
      'id': 1,
      'code': 'CS381',
      'name': 'Software development',
      'term': 'Imported semester 2',
      'doctor_name': 'Doctor',
      'is_archived': false,
      'sections': [
        {
          'id': 1,
          'section_number': 1,
          'department_code': 'SE',
          'ta_name': 'TA',
          'student_count': 4
        }
      ],
    });

Future<void> _open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.push<void>(context,
                      MaterialPageRoute(builder: (_) => Scaffold(body: child))),
                  child: const Text('Open feature'))))));
  await tester.tap(find.text('Open feature'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('section report loads and refreshes the selected scope',
      (tester) async {
    var summaryReads = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          expect(request.url.queryParameters['section_id'], '1');
          Object response;
          if (request.url.path.endsWith('/report')) {
            response = {
              'students': 4,
              'sessions': 2,
              'finalized': 2,
              'policy': null
            };
          } else if (request.url.path.endsWith('/sessions/summary')) {
            summaryReads++;
            response = {
              'lecture': {'present': 2, 'eligible': 4}
            };
          } else {
            expect(request.url.path.endsWith('/assessments'), isTrue);
            response = [];
          }
          return http.Response(jsonEncode(response), 200);
        }));
    addTearDown(api.dispose);
    final selected = _course();
    final state = AppState(api)
      ..user = UserProfile.fromJson(
          {'id': 1, 'username': 'ta', 'full_name': 'TA', 'role': 'ta'})
      ..course = selected
      ..section = selected.sections.first;
    addTearDown(state.dispose);
    await _open(tester, SettingsPage(state));
    await tester.ensureVisible(find.text('تقرير السكشن'));
    await tester.tap(find.text('تقرير السكشن'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('50.0%'), findsOneWidget);
    await tester.ensureVisible(find.text('تحديث التقرير'));
    await tester.tap(find.text('تحديث التقرير'));
    await tester.pumpAndSettle();
    expect(summaryReads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'password validation and failed credential retry preserve the session',
      (tester) async {
    var submissions = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/change-password');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['new_password'], 'replacement123');
          submissions++;
          return submissions == 1
              ? http.Response(
                  jsonEncode({'detail': 'كلمة المرور الحالية غير صحيحة.'}), 422)
              : http.Response('{"ok":true}', 200);
        }))
      ..token = 'test-session';
    addTearDown(api.dispose);
    final state = AppState(api)
      ..user = UserProfile.fromJson({
        'id': 1,
        'username': 'student',
        'full_name': 'Student',
        'role': 'student'
      });
    addTearDown(state.dispose);
    await _open(tester, SettingsPage(state));
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'incorrect');
    await tester.enterText(find.byType(TextFormField).at(1), 'replacement123');
    await tester.enterText(find.byType(TextFormField).at(2), 'mismatch123');
    await tester.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(submissions, 0);
    await tester.enterText(find.byType(TextFormField).at(2), 'replacement123');
    await tester.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(state.user, isNotNull);
    expect(api.token, 'test-session');
    await tester.enterText(find.byType(TextFormField).at(0), 'correct123');
    await tester.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(submissions, 2);
    expect(state.user, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final existing in [false, true]) {
    testWidgets(
        existing
            ? 'equivalent numeric grade formatting does not show an unsaved warning'
            : 'grade route exit can retain edits or discard them explicitly',
        (tester) async {
      final api = AttendanceApi(
          tokens: _Tokens(),
          client: MockClient((request) async => http.Response(
              jsonEncode({
                'total': 1,
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student',
                    'university_id': '123',
                    'score': existing ? '0.00' : null,
                    'state': existing ? 'recorded' : 'unrecorded',
                    'revision': existing ? 1 : 0
                  }
                ]
              }),
              200)));
      addTearDown(api.dispose);
      await _open(
          tester,
          GradebookPage(api, _course(),
              {'id': 1, 'title': 'Assignment', 'max_points': '10'},
              sectionId: 1, canPublish: false));
      await tester.enterText(
          find.byType(TextField).at(1), existing ? '0' : '3');
      await tester.pump();
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      if (!existing) {
        expect(find.text('توجد تغييرات غير محفوظة'), findsOneWidget);
        await tester.tap(find.text('تراجع'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextField>(find.byType(TextField).at(1))
                .controller!
                .text,
            '3');
        await navigator.maybePop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('خروج بدون حفظ'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Open feature'), findsOneWidget);
      expect(find.byType(GradebookPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
