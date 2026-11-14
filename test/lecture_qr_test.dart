import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_attendance_mobile/data/api.dart';
import 'package:university_attendance_mobile/data/models.dart';
import 'package:university_attendance_mobile/features/attendance.dart';

void main() {
  testWidgets('lecture manual QR survives scrolling out of view and back',
      (tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now().toUtc();
    const payload = 'v1.3.regression-test-payload';
    final api = AttendanceApi(client: MockClient((request) async {
      final Object body;
      if (request.url.path.endsWith('/qr')) {
        body = {
          'payload': payload,
          'valid_until': now.add(const Duration(minutes: 5)).toIso8601String(),
        };
      } else {
        body = {
          'id': 3,
          'title': 'Lecture3',
          'state': 'open',
          'ends_at': now.add(const Duration(minutes: 10)).toIso8601String(),
          'rows': [
            for (var id = 1; id <= 40; id++)
              {
                'enrollment_id': id,
                'full_name': 'Student $id',
                'status': id == 1 ? 'present' : null
              },
          ],
        };
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    addTearDown(api.dispose);
    final course = CourseOffering.fromJson({
      'id': 1,
      'code': 'CS381',
      'name': 'Software',
      'term': 'Term',
      'doctor_name': 'Doctor',
      'is_archived': false,
      'sections': <dynamic>[],
    });
    try {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: LecturePage(api, course, 3))));
      await tester.pumpAndSettle();
      final manual = find.text('عرض الرمز للإدخال اليدوي');
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(1600);
      await tester.pumpAndSettle();
      expect(manual, findsNothing);
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(manual, findsOneWidget);
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(find.text(payload), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.state<ScrollableState>(scrollable).position.jumpTo(1600);
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text(payload), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(find.text(payload), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}
