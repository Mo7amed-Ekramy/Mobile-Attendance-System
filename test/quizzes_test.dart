import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app_state.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/grading.dart';
import 'package:university_attendance_mobile/features/quizzes.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String? token) async {}
}

AppState _ta(AttendanceApi api) {
  final course = CourseOffering.fromJson({
    'id': 1,
    'code': 'CS381',
    'name': 'Software',
    'term': 'Term',
    'doctor_name': 'Doctor',
    'is_archived': false,
    'sections': [
      {
        'id': 1,
        'section_number': 1,
        'department_code': 'SE',
        'ta_name': 'TA',
        'student_count': 2
      },
    ],
  });
  return AppState(api)
    ..user = UserProfile.fromJson({
      'id': 1,
      'username': 'ta',
      'full_name': 'TA',
      'role': 'ta',
    })
    ..course = course
    ..section = course.sections.first;
}

Future<void> _mount(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  test('quiz preview rounds 40/40/20 while keeping every supported total exact',
      () {
    const examples = {
      1: [1, 0, 0],
      2: [1, 1, 0],
      3: [1, 1, 1],
      4: [2, 1, 1],
      5: [2, 2, 1],
      6: [3, 2, 1],
      7: [3, 3, 1],
      10: [4, 4, 2],
      60: [24, 24, 12],
    };
    for (final example in examples.entries) {
      expect(quizDifficultyCounts(example.key).values.toList(), example.value);
    }
    for (var total = 1; total <= 100; total++) {
      final counts = quizDifficultyCounts(total);
      expect(counts.values.reduce((a, b) => a + b), total);
      for (final entry in {'easy': .4, 'medium': .4, 'hard': .2}.entries) {
        expect((counts[entry.key]! - total * entry.value).abs(), lessThan(1));
      }
    }
  });

  testWidgets(
      'quiz preview flags level shortages even when total bank is large enough',
      (tester) async {
    var writes = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          writes++;
          return http.Response('{"id":1}', 200);
        }));
    final state = _ta(api);
    addTearDown(api.dispose);
    addTearDown(state.dispose);
    await _mount(
        tester,
        QuizCreatorPage(state, {
          'categories': [
            {'id': 1, 'kind': 'assessment', 'name': 'Quiz'}
          ],
        }, [
          for (var i = 0; i < 4; i++) {'difficulty': 'easy'},
          for (var i = 0; i < 4; i++) {'difficulty': 'medium'},
          {'difficulty': null},
        ]));
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.pumpAndSettle();
    expect(
        find.text('توزيع الكويز · سهل: 2 · متوسط: 2 · صعب: 1'), findsOneWidget);
    expect(find.textContaining('صعب: مطلوب 1، متاح 0'), findsOneWidget);
    final button =
        find.widgetWithText(FilledButton, 'فتح الكويز وإشعار الطلاب');
    await tester.ensureVisible(button);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(writes, 0);
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pumpAndSettle();
    expect(
        find.text('توزيع الكويز · سهل: 1 · متوسط: 1 · صعب: 0'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField).at(1), '101');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets(
      'TA quiz roster refreshes automatic scores and keeps zero distinct from missing',
      (tester) async {
    var reads = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/courses/1/quizzes/10/results');
          reads++;
          return http.Response(
              jsonEncode({
                'title': 'Section quiz',
                'max_points': '5.00',
                'section_number': 1,
                'department_code': 'SE',
                'difficulty_counts': {'easy': 2, 'medium': 2, 'hard': 1},
                'summary': {
                  'total': 2,
                  'not_started': reads == 1 ? 2 : 1,
                  'in_progress': 0,
                  'submitted': reads == 1 ? 0 : 1,
                  'timed_out': 0
                },
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student A',
                    'university_id': '1001',
                    'attempt_state': reads == 1 ? 'not_started' : 'submitted',
                    'score': reads == 1 ? null : '0.00'
                  },
                  {
                    'enrollment_id': 2,
                    'full_name': 'Student B',
                    'university_id': '1002',
                    'attempt_state': 'not_started',
                    'score': null
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final state = _ta(api);
    addTearDown(api.dispose);
    addTearDown(state.dispose);
    await _mount(
        tester,
        QuizResultsPage(state, {
          'id': 10,
          'assessment_id': 3,
          'course_section_id': 1,
        }));
    expect(find.text('—'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text(pointRatio('0.00', '5.00')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('1001 · تم التسليم'), findsOneWidget);
    expect(find.text('تم التسليم: 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'TA gradebook automatically displays a newly submitted zero score',
      (tester) async {
    var reads = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/courses/1/assessments/3/results');
          reads++;
          return http.Response(
              jsonEncode({
                'total': 1,
                'editable': false,
                'editing_unavailable_reason':
                    'التصحيح تلقائي حتى إغلاق الكويز.',
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student A',
                    'university_id': '1001',
                    'score': reads == 1 ? null : '0.00',
                    'state': reads == 1 ? 'unrecorded' : 'recorded',
                    'revision': reads == 1 ? 0 : 1,
                    'visibility': 'draft',
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final state = _ta(api);
    addTearDown(api.dispose);
    addTearDown(state.dispose);
    await _mount(
        tester,
        GradebookPage(
            api,
            state.course!,
            {
              'id': 3,
              'title': 'Quiz',
              'max_points': '5.00',
            },
            sectionId: 1,
            canPublish: false));
    final grade = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'الدرجة');
    expect(tester.widget<TextField>(grade).controller!.text, isEmpty);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(tester.widget<TextField>(grade).controller!.text, '0.00');
    expect(
        find.text(
            'تغييرات غير محفوظة · احفظ درجات الصفحة قبل الانتقال أو النشر.'),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'gradebook refresh waits while TA has unsaved edits and resumes when they are reverted',
      (tester) async {
    var reads = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          reads++;
          return http.Response(
              jsonEncode({
                'total': 1,
                'editable': true,
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student A',
                    'university_id': '1001',
                    'score': reads == 1 ? '1.00' : '3.00',
                    'state': 'recorded',
                    'revision': reads,
                    'visibility': 'draft',
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final state = _ta(api);
    addTearDown(api.dispose);
    addTearDown(state.dispose);
    await _mount(
        tester,
        GradebookPage(
            api,
            state.course!,
            {
              'id': 3,
              'title': 'Quiz',
              'max_points': '5.00',
            },
            sectionId: 1,
            canPublish: false));
    final grade = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'الدرجة');
    await tester.enterText(grade, '2.00');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(tester.widget<TextField>(grade).controller!.text, '2.00');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(grade, '1.00');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(tester.widget<TextField>(grade).controller!.text, '3.00');
    await tester.pumpWidget(const SizedBox());
  });
}
