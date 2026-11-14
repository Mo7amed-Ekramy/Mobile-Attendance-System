import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app.dart';
import 'package:university_attendance_mobile/app_state.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/data/preferences.dart';
import 'package:university_attendance_mobile/features/grading.dart';
import 'package:university_attendance_mobile/features/courses.dart';
import 'package:university_attendance_mobile/theme.dart';

import 'api_test.dart' show TestTokenStore;

class _Preferences implements PreferencesStore {
  _Preferences([this.value]);
  UserPreferences? value;
  @override
  Future<UserPreferences?> read(int id) async => value;
  @override
  Future<void> write(int id, UserPreferences saved) async {
    value = saved;
  }
}

Future<AppState> _mount(WidgetTester tester, Role role, double width,
    {List<Uri>? requests, _Preferences? preferences}) async {
  tester.view.physicalSize = Size(width, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final courseData = [
    for (var id = 1; id <= 2; id++)
      {
        'id': id,
        'code': id == 1 ? 'CS342' : 'CS381',
        'name': id == 1 ? 'Automata' : 'Software Development',
        'term': 'Term',
        'doctor_name': 'Doctor',
        'is_archived': false,
        'sections': [
          for (var section = 1;
              section <= (role == Role.student ? 1 : 2);
              section++)
            {
              'id': id * 10 + section,
              'section_number': section,
              'department_code': 'SE',
              'ta_name': 'Teaching assistant',
              'student_count': 2
            },
        ],
      },
  ];
  final userData = {
    'id': 1,
    'username': 'tester',
    'full_name': 'حساب الاختبار',
    'role': role.name
  };
  final courses = courseData.map(CourseOffering.fromJson).toList();
  final api = AttendanceApi(
      tokens: TestTokenStore(),
      client: MockClient((request) async {
        requests?.add(request.url);
        final Object? body = switch (request.url.path.split('/').last) {
          'courses' => courseData,
          'login' => {'user': userData, 'token': 'test-session'},
          'policy' => null,
          'grades' => {'policy': null, 'official_total': null},
          'report' => {'students': 2, 'finalized': 0, 'policy': null},
          _ => <dynamic>[],
        };
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
  final state = AppState(api, preferences: preferences ?? _Preferences())
    ..user = UserProfile.fromJson(userData)
    ..courses = courses
    ..course = courses.first
    ..section = role == Role.doctor ? null : courses.first.sections.first;
  addTearDown(() {
    state.dispose();
    api.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    theme: Brand.theme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: AnimatedBuilder(
        animation: state, builder: (_, child) => AppShell(state)),
  ));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('TA tabs keep independent scroll positions for each section',
      (tester) async {
    final state = await _mount(tester, Role.ta, 800);
    for (var number = 3; number <= 14; number++) {
      state.course!.sections.add(CourseSection.fromJson({
        'id': 100 + number,
        'section_number': number,
        'department_code': 'SE',
        'ta_name': 'TA',
        'student_count': 2,
      }));
    }
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السكاشن').last);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('سكاشني المسندة')).dy,
        inInclusiveRange(64, 140));
    expect(tester.takeException(), isNull);
  });

  for (final width in [800.0, 1280.0]) {
    testWidgets('desktop $width changes scope once without moving page or tab',
        (tester) async {
      final requests = <Uri>[];
      final state = await _mount(tester, Role.ta, width, requests: requests);
      await tester.tap(find.text('الدرجات').last);
      await tester.pumpAndSettle();
      final pagePosition = tester.getTopLeft(find.byType(GradesPage));
      expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
      await tester.tap(find.byKey(const ValueKey('scope-switcher')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getTopLeft(find.byType(GradesPage)), pagePosition);
      await tester.enterText(
          find.byKey(const ValueKey('scope-search')), 'CS381');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scope-course-2')));
      await tester.pumpAndSettle();
      expect(state.course!.id, 1);
      var notifications = 0;
      state.addListener(() => notifications++);
      requests.clear();
      await tester.tap(find.byKey(const ValueKey('scope-section-22')));
      await tester.pumpAndSettle();
      expect(state.course!.id, 2);
      expect(state.section!.id, 22);
      expect(notifications, 1);
      expect(find.byType(GradesPage), findsOneWidget);
      expect(find.byKey(const ValueKey('scope-search')), findsNothing);
      expect(
          requests
              .where((r) => r.path.endsWith('/assessments'))
              .single
              .queryParameters['section_id'],
          '22');
      expect(tester.getTopLeft(find.byType(GradesPage)), pagePosition);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      '320px student selects its assigned section directly with keyboard',
      (tester) async {
    final state = await _mount(tester, Role.student, 320);
    await tester.tap(find.byKey(const ValueKey('scope-switcher')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('scope-all-sections')), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(find.byKey(const ValueKey('scope-search')), 'CS381');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scope-course-2')));
    await tester.pumpAndSettle();
    expect(state.course!.id, 2);
    expect(state.section!.id, 21);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'phone TA can change course and section without an all-sections option',
      (tester) async {
    final state = await _mount(tester, Role.ta, 390);
    await tester.tap(find.byKey(const ValueKey('scope-switcher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scope-all-sections')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('scope-back-to-courses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scope-course-2')));
    await tester.pumpAndSettle();
    expect(state.course!.id, 1);
    await tester.tap(find.byKey(const ValueKey('scope-section-22')));
    await tester.pumpAndSettle();
    expect(state.course!.id, 2);
    expect(state.section!.id, 22);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dismissals discard a pending choice and reset search',
      (tester) async {
    final state = await _mount(tester, Role.ta, 1000);
    final trigger = find.byKey(const ValueKey('scope-switcher'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('scope-search')), 'CS381');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scope-course-2')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scope-search')), findsNothing);
    expect(state.course!.id, 1);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('scope-search')))
            .controller!
            .text,
        isEmpty);
    expect(find.byKey(const ValueKey('scope-section-11')), findsOneWidget);
    await tester.tapAt(const Offset(10, 700));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scope-search')), findsNothing);
    expect(state.course!.id, 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1000.0]) {
    testWidgets(
        'doctor $width switches only courses and keeps data course-wide',
        (tester) async {
      final requests = <Uri>[];
      final state =
          await _mount(tester, Role.doctor, width, requests: requests);
      await tester.tap(find.text('الدرجات').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scope-switcher')));
      await tester.pumpAndSettle();
      expect(find.text('تغيير المقرر'), findsOneWidget);
      expect(find.text('اختيار السكشن'), findsNothing);
      expect(find.text('جميع السكاشن'), findsNothing);
      expect(find.textContaining(RegExp(r'^سكشن ')), findsNothing);
      requests.clear();
      await tester.tap(find.byKey(const ValueKey('scope-course-2')));
      await tester.pumpAndSettle();
      expect(state.course!.id, 2);
      expect(state.section, isNull);
      expect(find.byKey(const ValueKey('scope-search')), findsNothing);
      expect(find.byType(GradesPage), findsOneWidget);
      expect(
          requests.where((r) => r.path.endsWith('/assessments')), hasLength(1));
      expect(
          requests.every((r) => !r.queryParameters.containsKey('section_id')),
          isTrue);
      await tester.tap(find.text('المقررات').last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(CoursesPage),
          matching: find.text('CS381 · Software Development')));
      await tester.pumpAndSettle();
      expect(find.byType(CourseDetailPage), findsOneWidget);
      expect(find.textContaining('سكشن'), findsNothing);
      expect(find.textContaining('السكاشن'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'doctor restores the course but clears a previously saved section',
      (tester) async {
    final preferences = _Preferences(
        const UserPreferences(courseId: 2, sectionId: 22, darkMode: true));
    final state =
        await _mount(tester, Role.doctor, 800, preferences: preferences);
    await state.signIn('doctor', 'test-password');
    await tester.pumpAndSettle();
    expect(state.course!.id, 2);
    expect(state.section, isNull);
    expect(state.darkMode, isTrue);
    expect(preferences.value!.sectionId, isNull);
    state.selectScope(state.course!,
        selectedSection: state.course!.sections.last);
    expect(state.section, isNull);
    state.selectSection(state.course!.sections.first);
    expect(state.section, isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
