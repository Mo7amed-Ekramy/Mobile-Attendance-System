import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app_state.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/data/preferences.dart';
import 'package:university_attendance_mobile/features/attendance.dart';
import 'package:university_attendance_mobile/features/courses.dart';
import 'package:university_attendance_mobile/features/dashboard.dart';
import 'package:university_attendance_mobile/features/grading.dart';
import 'package:university_attendance_mobile/features/quizzes.dart';
import 'package:university_attendance_mobile/widgets/common.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> read() async => 'test-session';
  @override
  Future<void> write(String? token) async {}
}

class _Preferences implements PreferencesStore {
  final values = <int, UserPreferences>{};
  @override
  Future<UserPreferences?> read(int id) async => values[id];
  @override
  Future<void> write(int id, UserPreferences value) async => values[id] = value;
}

Map<String, dynamic> _courseJson(int id) => {
      'id': id,
      'code': id == 1 ? 'CS381' : 'CS211',
      'name': 'Software',
      'term': 'Imported semester 2',
      'doctor_name': 'Doctor',
      'is_archived': false,
      'sections': [
        {
          'id': id * 10,
          'section_number': id,
          'department_code': 'SE',
          'ta_name': 'TA',
          'student_count': 2
        }
      ],
    };

CourseOffering _course() => CourseOffering.fromJson(_courseJson(1));
UserProfile _user(Role role, {int id = 1}) => UserProfile.fromJson({
      'id': id,
      'username': role.name,
      'full_name': 'اسم جامعي طويل لاختبار عرض الواجهة',
      'role': role.name,
    });

Future<void> _mount(WidgetTester tester, Widget child,
    {double width = 800}) async {
  tester.view.physicalSize = Size(width, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  test('saved scope stays permitted and preferences do not cross accounts',
      () async {
    var account = 1;
    var offerings = [_courseJson(1), _courseJson(2)];
    final preferences = _Preferences()
      ..values[1] =
          const UserPreferences(courseId: 2, sectionId: 20, darkMode: true);
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          final user = {
            'id': account,
            'username': 'ta',
            'full_name': 'TA',
            'role': 'ta'
          };
          return http.Response(
              jsonEncode(r.url.path.endsWith('/courses')
                  ? offerings
                  : r.url.path.endsWith('/me')
                      ? user
                      : {'token': 'new-session', 'user': user}),
              200);
        }));
    addTearDown(api.dispose);
    final state = AppState(api, preferences: preferences);
    addTearDown(state.dispose);
    await state.restore();
    await state.flushPreferences();
    expect(state.course!.id, 2);
    expect(state.section!.id, 20);
    expect(state.darkMode, isTrue);
    offerings = [_courseJson(1)];
    await state.refreshCourses();
    await state.flushPreferences();
    expect(state.course!.id, 1);
    expect(state.section!.id, 10);
    account = 2;
    await state.signIn('other', 'password');
    await state.flushPreferences();
    expect(state.darkMode, isFalse);
    expect(preferences.values[1]!.darkMode, isTrue);
    expect(preferences.values[2]!.darkMode, isFalse);
  });

  for (final role in Role.values) {
    testWidgets('${role.name} dashboard has useful role actions at phone width',
        (tester) async {
      final api = AttendanceApi(
          tokens: _Tokens(),
          client: MockClient((r) async {
            final path = r.url.path;
            final Object body;
            if (path.endsWith('/quizzes') || path.endsWith('/sessions')) {
              body = [];
            } else if (path.endsWith('/grades')) {
              expect(role, Role.student);
              body = {'policy': null, 'official_total': null};
            } else {
              expect(role, isNot(Role.student));
              expect(path.endsWith('/report'), isTrue);
              body = {'students': 2, 'finalized': 0, 'policy': null};
            }
            return http.Response(jsonEncode(body), 200);
          }));
      addTearDown(api.dispose);
      final selected = _course();
      final state = AppState(api, preferences: _Preferences())
        ..user = _user(role)
        ..course = selected
        ..section = selected.sections.first;
      addTearDown(state.dispose);
      await _mount(tester, HomePage(state), width: 320);
      final action = switch (role) {
        Role.doctor => 'فتح محاضرة',
        Role.ta => 'إنشاء كشف حضور السكشن',
        Role.student => 'مسح رمز الحضور',
      };
      await tester.ensureVisible(find.text(action));
      expect(find.text(action), findsOneWidget);
      if (role == Role.student) {
        expect(find.text('كشف الطلاب'), findsNothing);
        expect(find.text('فتح محاضرة'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TA section shortcut preserves the exact selected scope',
      (tester) async {
    final api = AttendanceApi(tokens: _Tokens());
    addTearDown(api.dispose);
    final course = _course();
    final state = AppState(api, preferences: _Preferences())
      ..user = _user(Role.ta)
      ..courses = [course]
      ..course = course;
    addTearDown(state.dispose);
    await _mount(tester, CoursesPage(state));
    await tester.tap(find.text('CS381 · سكشن 1 (SE)'));
    await tester.pumpAndSettle();
    expect(state.section!.id, 10);
    expect(find.byType(SectionWorkspacePage), findsOneWidget);
    expect(find.text('إنشاء كشف حضور السكشن'), findsOneWidget);
  });

  test('closed and expired unstarted quizzes do not offer a futile retry', () {
    final now = DateTime.now().toUtc();
    final quiz = <String, dynamic>{
      'state': 'active',
      'attempt': null,
      'starts_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'ends_at': now.subtract(const Duration(hours: 1)).toIso8601String()
    };
    expect(quizCanOpen(quiz), isFalse);
    quiz['attempt'] = {'state': 'submitted'};
    expect(quizHasCompletedAttempt(quiz), isTrue);
    expect(quizCanOpen(quiz), isTrue);
    quiz['attempt'] = null;
    quiz['ends_at'] = now.add(const Duration(hours: 1)).toIso8601String();
    quiz['state'] = 'closed';
    expect(quizCanOpen(quiz), isFalse);
  });

  testWidgets('refresh and failed retry retain form input', (tester) async {
    final pending = Completer<String>();
    var reads = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _mount(
        tester,
        RemotePage<String>(
            load: () => ++reads == 1 ? Future.value('stored') : pending.future,
            builder: (_, reload) => PageContent(children: [
                  TextField(controller: controller),
                  TextButton(onPressed: reload, child: const Text('Refresh')),
                ])));
    await tester.enterText(find.byType(TextField), 'unfinished edit');
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'unfinished edit');
    pending.completeError(const ApiException('Connection unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'unfinished edit');
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grade paging requires explicit discard and keeps save visible',
      (tester) async {
    var reads = 0;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          reads++;
          final offset = int.parse(r.url.queryParameters['offset']!);
          return http.Response(
              jsonEncode({
                'total': 51,
                'rows': [
                  for (var i = offset + 1; i <= (offset == 0 ? 50 : 51); i++)
                    {
                      'enrollment_id': i,
                      'full_name': 'Student $i',
                      'university_id': '$i',
                      'score': null,
                      'state': 'unrecorded',
                      'revision': 0
                    }
                ]
              }),
              200);
        }));
    addTearDown(api.dispose);
    await _mount(
        tester,
        GradebookPage(api, _course(),
            {'id': 1, 'title': 'Assignment', 'max_points': '10'},
            canPublish: false),
        width: 320);
    final field = find
        .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'الدرجة')
        .first;
    await tester.ensureVisible(field);
    await tester.enterText(field, '3');
    final save = find.text('حفظ درجات الصفحة');
    expect(tester.getRect(save).bottom, lessThan(740));
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(tester.widget<TextField>(field).controller!.text, '3');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Student 51'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TA pending filter retains all marks for finalization',
      (tester) async {
    Map<String, dynamic>? submitted;
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            submitted = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
              jsonEncode({
                'title': 'Section',
                'state': submitted == null ? 'draft' : 'finalized',
                'revision': 1,
                'rows': [
                  {
                    'enrollment_id': 1,
                    'full_name': 'One',
                    'university_id': '1',
                    'status': submitted == null ? null : 'present'
                  },
                  {
                    'enrollment_id': 2,
                    'full_name': 'Two',
                    'university_id': '2',
                    'status': submitted == null ? null : 'excused'
                  },
                ]
              }),
              200);
        }));
    addTearDown(api.dispose);
    await _mount(tester, SessionDetailPage(api, _course(), 1, editable: true));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'حاضر').first);
    await tester.tap(find.widgetWithText(ChoiceChip, 'حاضر').first);
    await tester.pump();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'بعذر'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'بعذر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة واعتماد الكشف'));
    // AsyncButton remains busy while the confirmation dialog is open.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(submitted!['rows'], [
      {'enrollment_id': 1, 'status': 'present'},
      {'enrollment_id': 2, 'status': 'excused'}
    ]);
    expect(find.text('مراجعة واعتماد الكشف'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a partial attendance roster requires explicit discard',
      (tester) async {
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((r) async => http.Response(
            jsonEncode({
              'title': 'Section',
              'state': 'draft',
              'revision': 1,
              'rows': [
                {
                  'enrollment_id': 1,
                  'full_name': 'One',
                  'university_id': '1',
                  'status': null
                }
              ]
            }),
            200)));
    addTearDown(api.dispose);
    await _mount(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => Scaffold(
                            body: SessionDetailPage(api, _course(), 1,
                                editable: true)))),
                child: const Text('Open roster'))));
    await tester.tap(find.text('Open roster'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'حاضر'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'حاضر'));
    await tester.pump();
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('حالات حضور غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'حاضر'))
            .selected,
        isTrue);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(find.text('Open roster'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
