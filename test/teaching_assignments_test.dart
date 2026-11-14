import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/teaching_assignments.dart';
import 'package:university_attendance_mobile/theme.dart';

Map<String, dynamic> _assignment(int id, int assistantId, String name,
        String department, int number, int students) =>
    {
      'id': id,
      'ta_user_id': assistantId,
      'ta_name': name,
      'department_code': department,
      'section_number': number,
      'student_count': students,
    };

Future<void> _mount(
    WidgetTester tester, List<Map<String, dynamic>> rows) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = AttendanceApi(client: MockClient((request) async {
    expect(request.url.path, '/api/v1/courses/7/assignments');
    expect(request.url.queryParameters.containsKey('section_id'), isFalse);
    return http.Response(jsonEncode(rows), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }));
  addTearDown(api.dispose);
  final course = CourseOffering.fromJson({
    'id': 7,
    'code': 'CS381',
    'name': 'Software Development',
    'term': 'Term',
    'doctor_name': 'Doctor',
    'is_archived': false,
    'sections': <dynamic>[],
  });
  await tester.pumpWidget(MaterialApp(
    theme: Brand.theme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: TeachingAssignmentsPage(api, course)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one card per assistant groups sections by department on a phone',
      (tester) async {
    final first =
        _assignment(1, 11, 'اسم المعيد الأول لاختبار العرض', 'AI', 3, 24);
    await _mount(tester, [
      first,
      _assignment(2, 11, 'اسم المعيد الأول لاختبار العرض', 'AI', 1, 23),
      _assignment(3, 11, 'اسم المعيد الأول لاختبار العرض', 'CS', 1, 20),
      _assignment(4, 22, 'المعيد الثاني', 'SE', 2, 0),
      first,
    ]);
    final firstCard = find.byKey(const ValueKey('teaching-assistant-11'));
    final secondCard = find.byKey(const ValueKey('teaching-assistant-22'));
    expect(firstCard, findsOneWidget);
    expect(secondCard, findsOneWidget);
    expect(find.text('عدد المعيدين: 2'), findsOneWidget);
    expect(find.text('معيد المقرر'), findsNWidgets(2));
    expect(find.text('اسم المعيد الأول لاختبار العرض'), findsOneWidget);
    expect(
        find.descendant(of: firstCard, matching: find.text('عدد السكاشن: 3')),
        findsOneWidget);
    expect(
        find.descendant(
            of: firstCard, matching: find.text('إجمالي الطلاب المسجّلين: 67')),
        findsOneWidget);
    expect(find.descendant(of: firstCard, matching: find.text('السكاشن: 1، 3')),
        findsOneWidget);
    expect(find.descendant(of: firstCard, matching: find.text('AI')),
        findsOneWidget);
    expect(find.descendant(of: firstCard, matching: find.text('CS')),
        findsOneWidget);
    expect(find.descendant(of: secondCard, matching: find.text('سكشن: 2')),
        findsOneWidget);
    expect(
        find.descendant(
            of: secondCard, matching: find.text('إجمالي الطلاب المسجّلين: 0')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('different assistant accounts with the same name remain separate',
      (tester) async {
    await _mount(tester, [
      _assignment(1, 11, 'اسم مشترك', 'AI', 1, 24),
      _assignment(2, 22, 'اسم مشترك', 'CS', 2, 20),
    ]);
    expect(find.text('اسم مشترك'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('teaching-assistant-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('teaching-assistant-22')), findsOneWidget);
    expect(find.text('عدد المعيدين: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course with no assignments explains the empty state',
      (tester) async {
    await _mount(tester, []);
    expect(find.text('CS381 · Software Development'), findsOneWidget);
    expect(find.text('عدد المعيدين: 0'), findsOneWidget);
    expect(find.text('لم يُسند معيدون لهذا المقرر'), findsOneWidget);
    expect(find.text('معيد المقرر'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
