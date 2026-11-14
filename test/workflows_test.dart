import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/app_state.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/attendance.dart';
import 'package:university_attendance_mobile/features/auth.dart';
import 'package:university_attendance_mobile/features/reports.dart';
import 'package:university_attendance_mobile/theme.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String? token) async {}
}

CourseOffering _course() => CourseOffering.fromJson({
      'id': 1,
      'code': 'CS381',
      'name': 'هندسة البرمجيات',
      'term': 'الفصل الدراسي الثاني',
      'doctor_name': 'د. رشا',
      'is_archived': false,
      'sections': [
        {
          'id': 1,
          'section_number': 1,
          'department_code': 'SE',
          'ta_name': 'المعيد',
          'student_count': 3
        }
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'partial attendance save restores marks and conflicts retain edits',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var revision = 1;
    var reads = 0;
    var reject = false;
    final saved = <int, String>{};
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            if (reject) {
              return http.Response(
                  jsonEncode({'detail': 'تغير كشف الحضور'}), 409,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }
            final body = jsonDecode(request.body) as Map;
            expect(body['revision'], revision);
            expect((body['rows'] as List).length, saved.containsKey(2) ? 2 : 1);
            for (final row in body['rows'] as List) {
              saved[row['enrollment_id'] as int] = row['status'] as String;
            }
            return http.Response(
                jsonEncode({'ok': true, 'revision': ++revision}), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          reads++;
          return http.Response(
              jsonEncode({
                'title': 'كشف السكشن',
                'state': 'draft',
                'revision': revision,
                'rows': [
                  for (var id = 1; id <= 3; id++)
                    {
                      'enrollment_id': id,
                      'full_name': 'طالب $id',
                      'university_id': '100$id',
                      'status': saved[id],
                    }
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    addTearDown(api.dispose);
    Future<void> mount() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SessionDetailPage(api, _course(), 1,
                  key: UniqueKey(), editable: true))));
      await tester.pumpAndSettle();
    }

    await mount();
    await tester.tap(find.widgetWithText(ChoiceChip, 'حاضر').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ مسودة الحضور'));
    await tester.pumpAndSettle();
    expect(saved, {1: 'present'});
    await mount();
    expect(reads, 2);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'حاضر').first)
            .selected,
        isTrue);
    reject = true;
    await tester.tap(find.widgetWithText(ChoiceChip, 'غائب').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ مسودة الحضور'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('تعارض في الحفظ · تعديلاتك محفوظة هنا'), findsOneWidget);
    expect(find.textContaining('تعديلي: غائب'), findsOneWidget);
    await tester.tap(find.text('الرجوع دون تغيير'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'غائب').first)
            .selected,
        isTrue);
    expect(saved, {1: 'present'});
    // Another editor marks a different student; keep that new server decision
    // while deliberately rebasing the local edit against the reviewed revision.
    saved[2] = 'excused';
    revision++;
    await tester.tap(find.text('حفظ مسودة الحضور'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('الاحتفاظ بتعديلاتي للمراجعة ثم الحفظ'));
    await tester.pumpAndSettle();
    reject = false;
    await tester.tap(find.text('حفظ مسودة الحضور'));
    await tester.pumpAndSettle();
    expect(saved, {1: 'absent', 2: 'excused'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic login adapts to narrow mobile, desktop and large text',
      (tester) async {
    final api = AttendanceApi(
        tokens: _Tokens(),
        client: MockClient((_) async => http.Response('[]', 200)));
    final state = AppState(api);
    addTearDown(api.dispose);
    addTearDown(state.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 640), const Size(1440, 900)]) {
      for (final dark in [false, true]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(MaterialApp(
            theme: Brand.theme(dark: dark),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(size.width < 400 ? 1.5 : 1)),
                child: Directionality(
                    textDirection: TextDirection.rtl, child: child!)),
            home: SignInPage(state)));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('login-identifier')), findsOneWidget);
        expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  test('Arabic PDF report embeds fonts and spans a complete roster', () async {
    final data = <String, dynamic>{
      'policy': null,
      'total': 64,
      'rows': [
        for (var id = 0; id < 64; id++)
          {
            'full_name': 'محمد أحمد عبد الرحمن طالب $id',
            'university_id': '2072023$id',
            'department_code': 'SE',
            'section_number': 1,
            'categories': [],
            'official_total': null,
            'attendance': {
              'lecture': {'present': 103, 'eligible': 104, 'rate': '99.04'}
            },
          },
      ]
    };
    final bytes =
        await buildStudentReport(_course(), _course().sections.first, data);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    final directory = Directory('.dart_tool/ui-refinement')
      ..createSync(recursive: true);
    File('${directory.path}/arabic-report.pdf').writeAsBytesSync(bytes);
  });
}
