// Component acceptance checks supplement live API and Chrome TA role journeys.
// The HTTP responses here are test fixtures, never runtime application data.
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
import 'package:university_attendance_mobile/features/settings.dart';

class MemoryTokens implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String? value) async => token = value;
}

CourseOffering course() => CourseOffering.fromJson({
      'id': 1,
      'code': 'CS381',
      'name': 'software development',
      'term': 'Imported semester 2',
      'doctor_name': 'Doctor',
      'is_archived': false,
      'sections': [
        {
          'id': 1,
          'section_number': 1,
          'department_code': 'SE',
          'ta_name': 'TA',
          'student_count': 1,
        }
      ],
    });

final policy = <String, dynamic>{
  'id': 1,
  'total_points': '100',
  'state': 'published',
  'categories': [
    {
      'id': 1,
      'code': 'quiz',
      'name': 'Quizzes',
      'kind': 'assessment',
      'max_points': '100',
      'allocation_mode': 'normalized',
    }
  ],
};

Future<void> open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 1600);
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
                  child: const Text('Open TA feature'))))));
  await tester.tap(find.text('Open TA feature'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TA theme setting updates the displayed switch', (tester) async {
    final api = AttendanceApi(tokens: MemoryTokens());
    addTearDown(api.dispose);
    final state = AppState(api)
      ..user = UserProfile.fromJson({
        'id': 1,
        'username': 'ta',
        'full_name': 'TA',
        'role': 'ta',
      });
    addTearDown(state.dispose);
    await open(
        tester,
        AnimatedBuilder(
            animation: state, builder: (_, __) => SettingsPage(state)));
    expect(state.darkMode, isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(state.darkMode, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('TA can select policy category and create a section assignment',
      (tester) async {
    Map<String, dynamic>? submitted;
    final api = AttendanceApi(
        tokens: MemoryTokens(),
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/v1/courses/1/assessments');
          submitted = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{"id":10}', 200);
        }));
    addTearDown(api.dispose);
    await open(tester, AssessmentPage(api, course(), policy, sectionId: 1));
    await tester.enterText(find.byType(TextField).at(0), 'TA assignment');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quizzes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تكليف').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء التقييم'));
    await tester.pumpAndSettle();
    expect(submitted, containsPair('section_id', 1));
    expect(submitted, containsPair('category_id', 1));
    expect(submitted, containsPair('kind', 'assignment'));
    expect(submitted, containsPair('max_points', '10'));
  });

  testWidgets('TA question editor submits four choices and selected answer',
      (tester) async {
    Map<String, dynamic>? submitted;
    final api = AttendanceApi(
        tokens: MemoryTokens(),
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/courses/1/questions');
          submitted = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{"id":10}', 200);
        }));
    addTearDown(api.dispose);
    await open(tester, QuestionEditorPage(api, course()));
    final inputs = ['Question', 'A', 'B', 'C', 'D', '2'];
    for (var i = 0; i < inputs.length; i++) {
      await tester.enterText(find.byType(TextField).at(i), inputs[i]);
    }
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الاختيار 2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ السؤال'));
    await tester.pumpAndSettle();
    expect(submitted, containsPair('options', ['A', 'B', 'C', 'D']));
    expect(submitted, containsPair('correct_index', 1));
    expect(submitted, containsPair('points', '2'));
  });

  testWidgets('TA quiz form selects assigned section and category',
      (tester) async {
    Map<String, dynamic>? submitted;
    final api = AttendanceApi(
        tokens: MemoryTokens(),
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/courses/1/quizzes');
          submitted = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{"id":10}', 200);
        }));
    addTearDown(api.dispose);
    final selected = course();
    final state = AppState(api)
      ..user = UserProfile.fromJson({
        'id': 1,
        'username': 'ta',
        'full_name': 'TA',
        'role': 'ta',
      })
      ..course = selected
      ..section = selected.sections.first;
    addTearDown(state.dispose);
    await open(tester, QuizCreatorPage(state, policy, 3));
    await tester.enterText(find.byType(TextField).at(0), 'TA quiz');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.enterText(find.byType(TextField).at(2), '20');
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quizzes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الكويز وإشعار الطلاب'));
    await tester.pumpAndSettle();
    expect(submitted, containsPair('section_id', 1));
    expect(submitted, containsPair('category_id', 1));
    expect(submitted, containsPair('question_count', 2));
    expect(submitted, containsPair('duration_minutes', 20));
  });

  testWidgets('TA grade entry with zero submits a recorded result',
      (tester) async {
    Map<String, dynamic>? submitted;
    final api = AttendanceApi(
        tokens: MemoryTokens(),
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            submitted = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
              jsonEncode({
                'total': 1,
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student',
                    'university_id': '123',
                    'score': submitted == null ? null : '0.00',
                    'state': submitted == null ? 'unrecorded' : 'recorded',
                    'revision': submitted == null ? 0 : 1,
                  }
                ]
              }),
              200);
        }));
    addTearDown(api.dispose);
    await open(
        tester,
        GradebookPage(
            api, course(), {'id': 1, 'title': 'Assignment', 'max_points': '10'},
            sectionId: 1, canPublish: false));
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.tap(find.text('حفظ درجات الصفحة'));
    await tester.pumpAndSettle();
    final row = (submitted!['rows'] as List).single;
    expect(row['score'], '0');
    expect(row['state'], 'recorded');
    expect(row['revision'], 0);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '0.00');
  });

  testWidgets('TA recorded grade clears an existing excuse checkbox',
      (tester) async {
    final api = AttendanceApi(
        tokens: MemoryTokens(),
        client: MockClient((r) async {
          return http.Response(
              jsonEncode({
                'total': 1,
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'Student',
                    'university_id': '123',
                    'score': null,
                    'state': 'excused',
                    'revision': 1,
                  }
                ]
              }),
              200);
        }));
    addTearDown(api.dispose);
    await open(
        tester,
        GradebookPage(
            api, course(), {'id': 1, 'title': 'Assignment', 'max_points': '10'},
            sectionId: 1, canPublish: false));
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
        reason:
            'A recorded numeric grade must not remain displayed as excused.');
  });
}
