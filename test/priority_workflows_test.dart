import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/attendance.dart';
import 'package:university_attendance_mobile/features/grading.dart';
import 'package:university_attendance_mobile/features/quizzes.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String? token) async {}
}

CourseOffering course() => CourseOffering.fromJson({
      'id': 1,
      'code': 'CS381',
      'name': 'Software',
      'term': 'Imported semester 2',
      'doctor_name': 'Doctor',
      'is_archived': false,
      'sections': [
        {
          'id': 1,
          'section_number': 1,
          'department_code': 'SE',
          'ta_name': 'TA',
          'student_count': 5
        }
      ],
    });

http.Response response(Object? data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> mount(WidgetTester tester, Widget page,
    {double width = 800}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'bulk absence preserves marked and hidden students, supports undo',
      (tester) async {
    Map? saved;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            saved = jsonDecode(r.body) as Map;
            return response({'revision': 2});
          }
          return response({
            'title': 'Roster',
            'course_section_id': 1,
            'state': 'draft',
            'revision': 1,
            'rows': [
              for (var id = 1; id <= 5; id++)
                {
                  'enrollment_id': id,
                  'full_name': 'Student $id',
                  'university_id': '$id',
                  'status': id == 1
                      ? 'present'
                      : id == 2
                          ? 'excused'
                          : null,
                }
            ],
          });
        }));
    addTearDown(api.dispose);
    await mount(tester, SessionDetailPage(api, course(), 1, editable: true));
    await tester.enterText(find.byType(TextField), 'Student 3');
    await tester.tap(find.text('تحديد غير المحدد غائب'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('3 طالب غير محدد'), findsOneWidget);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تراجع عن التحديد الجماعي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('غير محدد 3'), findsOneWidget);
    await tester.tap(find.text('تحديد غير المحدد غائب'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ مسودة الحضور'));
    await tester.pumpAndSettle();
    expect(saved!['rows'], [
      {'enrollment_id': 1, 'status': 'present'},
      {'enrollment_id': 2, 'status': 'excused'},
      for (var id = 3; id <= 5; id++) {'enrollment_id': id, 'status': 'absent'},
    ]);
  });

  testWidgets('policy cancel preserves edits, save and leave persists them',
      (tester) async {
    var policy = <String, dynamic>{
      'id': 1,
      'state': 'draft',
      'total_points': '100',
      'categories': [
        {
          'code': 'quiz',
          'name': 'Quizzes',
          'kind': 'assessment',
          'max_points': '100',
          'allocation_mode': 'normalized'
        }
      ]
    };
    var writes = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            writes++;
            policy = {...policy, ...jsonDecode(r.body) as Map<String, dynamic>};
          }
          return response(policy);
        }));
    addTearDown(api.dispose);
    await mount(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => Scaffold(
                            appBar: AppBar(),
                            body: PolicyPage(api, course(), editable: true)))),
                child: const Text('Open policy'))));
    await tester.tap(find.text('Open policy'));
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'اسم البند');
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Updated quizzes');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('تعديلات اللائحة غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, 'Updated quizzes');
    expect(writes, 0);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Open policy'), findsOneWidget);
    expect((policy['categories'] as List).single['name'], 'Updated quizzes');
    await tester.tap(find.text('Open policy'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, 'Updated quizzes');
  });

  testWidgets(
      'quiz readiness starts only on confirmation and failed choice can be retried',
      (tester) async {
    var starts = 0, saves = 0;
    var submitted = false;
    final delayed = Completer<http.Response>();
    final now = DateTime.now().toUtc();
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/readiness')) {
            return response({
              'title': 'Quiz',
              'course_code': 'CS381',
              'course_name': 'Software',
              'section_number': 1,
              'department_code': 'SE',
              'duration_minutes': 20,
              'state': 'active',
              'attempt': null,
              'server_now': now.toIso8601String(),
              'starts_at':
                  now.subtract(const Duration(minutes: 1)).toIso8601String(),
              'ends_at': now.add(const Duration(minutes: 10)).toIso8601String(),
            });
          }
          if (r.url.path.endsWith('/answers')) {
            saves++;
            expect(jsonDecode(r.body)['answers'], [
              {'question_id': 1, 'option_id': 11}
            ]);
            if (saves == 1) return delayed.future;
            return response({'ok': true});
          }
          if (r.url.path.endsWith('/submit')) {
            submitted = true;
            expect(jsonDecode(r.body)['answers'], isEmpty);
          } else {
            starts++;
          }
          return response({
            'id': 1,
            'state': submitted ? 'submitted' : 'in_progress',
            'title': 'Quiz',
            'server_now': now.toIso8601String(),
            'deadline_at':
                now.add(const Duration(minutes: 10)).toIso8601String(),
            'questions': [
              for (var id = 1; id <= 2; id++)
                {
                  'id': id,
                  'prompt': 'Question $id',
                  'options': [
                    {'id': id * 10 + 1, 'text': 'Option $id'}
                  ]
                }
            ],
            'answers': saves > 1
                ? [
                    {'question_id': 1, 'option_id': 11}
                  ]
                : [],
            'score': null,
            'max_points': '2'
          });
        }));
    addTearDown(api.dispose);
    await mount(tester, QuizRunnerPage(api, 1), width: 400);
    expect(find.text('قبل بدء الكويز'), findsOneWidget);
    expect(starts, 0);
    expect(find.textContaining('أقل من مدة المحاولة'), findsOneWidget);
    await tester.ensureVisible(find.text('ابدأ المحاولة الآن'));
    await tester.tap(find.text('ابدأ المحاولة الآن'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    await tester.tap(find.text('Option 1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('جارٍ حفظ الإجابة…'), findsOneWidget);
    expect(find.text('الإجابات المؤكدة: 0 من 2'), findsOneWidget);
    delayed.complete(response({'detail': 'Network save failed'}, 503));
    await tester.pumpAndSettle();
    expect(find.text('اختيار معلّق · لم يتأكد حفظه'), findsOneWidget);
    await tester.tap(find.text('إعادة حفظ الاختيار المعلّق'));
    await tester.pumpAndSettle();
    expect(find.text('تم الحفظ على الخادم'), findsOneWidget);
    expect(find.text('الإجابات المؤكدة: 1 من 2'), findsOneWidget);
    await tester.ensureVisible(find.text('تسليم الكويز'));
    await tester.tap(find.text('تسليم الكويز'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('أسئلة بلا إجابة مؤكدة: 1'), findsOneWidget);
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
    expect(find.text('تم التسليم يدويًا'), findsOneWidget);
  });

  testWidgets(
      'publication preview describes full scope and cancel does not publish',
      (tester) async {
    var writes = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/publication-preview')) {
            return response({
              'title': 'Assessment',
              'scope': 'جميع سكاشن المقرر',
              'eligible': 150,
              'recorded': 140,
              'excused': 2,
              'unrecorded': 8,
              'pending_changes': 3,
              'saved_results': 142,
              'republication': true,
              'fingerprint': 'reviewed-revision',
            });
          }
          if (r.url.path.endsWith('/publish')) {
            writes++;
            expect(jsonDecode(r.body)['fingerprint'], 'reviewed-revision');
            return response({'ok': true});
          }
          return response({
            'total': 1,
            'assessment': {},
            'rows': [
              {
                'enrollment_id': 1,
                'full_name': 'Student',
                'university_id': '1',
                'score': '0',
                'state': 'recorded',
                'revision': 1
              }
            ]
          });
        }));
    addTearDown(api.dispose);
    await mount(
        tester,
        GradebookPage(
            api, course(), {'id': 1, 'title': 'Assessment', 'max_points': '10'},
            sectionId: 1, canPublish: true),
        width: 400);
    await tester.tap(find.text('نشر نتائج التقييم'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('جميع الطلاب المؤهلين: 150'), findsOneWidget);
    expect(find.textContaining('جميع سكاشن المقرر'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('تم نشر النتائج.'), findsNothing);
    await tester.tap(find.text('نشر نتائج التقييم'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });
}
