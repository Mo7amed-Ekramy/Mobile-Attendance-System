import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app_state.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/attendance.dart';
import 'package:university_attendance_mobile/features/courses.dart';
import 'package:university_attendance_mobile/features/grading.dart';
import 'package:university_attendance_mobile/features/settings.dart';
import 'package:university_attendance_mobile/theme.dart';
import 'package:university_attendance_mobile/widgets/common.dart';

AppState _state(WidgetTester tester,
    [Object? Function(http.Request)? respond]) {
  final api = AttendanceApi(
      client: MockClient((request) async => http.Response(
          jsonEncode(respond?.call(request)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'})));
  final course = CourseOffering.fromJson({
    'id': 1,
    'code': 'CS381',
    'name': 'Software',
    'term': 'Term',
    'doctor_name': 'Doctor',
    'is_archived': false,
    'sections': [
      {
        'id': 51,
        'section_number': 5,
        'department_code': 'AI',
        'ta_name': 'TA',
        'student_count': 23
      },
      {
        'id': 52,
        'section_number': 2,
        'department_code': 'CS',
        'ta_name': 'TA',
        'student_count': 20
      },
    ],
  });
  final state = AppState(api)
    ..user = UserProfile.fromJson(
        {'id': 2, 'username': 'ta', 'full_name': 'TA', 'role': 'ta'})
    ..courses = [course]
    ..course = course
    ..section = course.sections.first;
  addTearDown(() {
    state.dispose();
    api.dispose();
  });
  return state;
}

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: Brand.theme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TA settings omit the assistants directory', (tester) async {
    final state = _state(tester);
    await _mount(tester, SettingsPage(state));
    expect(find.text('معيدو المقرر'), findsNothing);
    expect(find.text('تقرير السكشن'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
  });

  testWidgets(
      'TA course grouping opens its section directly without a duplicate menu',
      (tester) async {
    final state = _state(tester);
    await _mount(tester, CoursesPage(state));
    expect(find.widgetWithText(ActionCard, 'CS381 · Software'), findsNothing);
    expect(find.text('CS381 · Software'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'سكشن 2');
    await tester.pumpAndSettle();
    expect(find.text('CS381 · سكشن 5 (AI)'), findsNothing);
    var changes = 0;
    state.addListener(() => changes++);
    await tester.tap(find.text('CS381 · سكشن 2 (CS)'));
    await tester.pumpAndSettle();
    expect(state.section!.id, 52);
    expect(changes, 1);
    expect(find.byType(SectionWorkspacePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an active electronic quiz gradebook is read-only',
      (tester) async {
    final state = _state(tester, (request) {
      expect(request.method, 'GET');
      return {
        'total': 1,
        'editable': false,
        'editing_unavailable_reason': 'التصحيح تلقائي حتى إغلاق الكويز.',
        'rows': [
          {
            'enrollment_id': 1,
            'full_name': 'Student',
            'university_id': '123',
            'score': '2',
            'state': 'recorded',
            'revision': 1,
            'visibility': 'draft'
          }
        ]
      };
    });
    await _mount(
        tester,
        GradebookPage(state.api, state.course!,
            {'id': 10, 'title': 'Online quiz', 'max_points': '5'},
            sectionId: 51, canPublish: false));
    expect(find.text('حفظ درجات الصفحة'), findsNothing);
    expect(find.text('نشر نتائج التقييم'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull);
    expect(find.text('التصحيح تلقائي حتى إغلاق الكويز.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty TA sections cannot start an unfinishable attendance roster',
      (tester) async {
    final state = _state(tester, (request) {
      expect(request.method, 'GET');
      expect(request.url.queryParameters['section_id'], '51');
      return {'total': 0, 'rows': []};
    });
    await _mount(tester, CreateSessionPage(state));
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'إنشاء كشف الحضور'));
    expect(button.onPressed, isNull);
    expect(find.textContaining('لا يوجد طلاب مسجلون في هذا السكشن.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pending attendance requests only drafts for the selected section',
      (tester) async {
    final state = _state(tester, (request) {
      if (request.url.path.endsWith('/summary')) return {};
      expect(request.url.queryParameters['state'], 'draft');
      expect(request.url.queryParameters['section_id'], '51');
      return [];
    });
    await _mount(tester, AttendancePage(state, initialPendingOnly: true));
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shared lecture details carry the selected section and are not editable',
      (tester) async {
    final state = _state(tester, (request) {
      expect(request.url.queryParameters['section_id'], '51');
      return {
        'title': 'Lecture',
        'kind': 'lecture',
        'state': 'closed',
        'course_code': 'CS381',
        'course_section_id': null,
        'rows': [
          {
            'enrollment_id': 1,
            'full_name': 'Student',
            'university_id': '123',
            'status': 'present'
          }
        ]
      };
    });
    await _mount(
        tester, SessionDetailPage(state.api, state.course!, 3, sectionId: 51));
    expect(find.textContaining('محاضرة · للاطلاع فقط'), findsOneWidget);
    expect(find.textContaining('سكشن 5 (AI)'), findsOneWidget);
    expect(find.textContaining('جميع السكاشن'), findsNothing);
    expect(find.text('مراجعة واعتماد الكشف'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
