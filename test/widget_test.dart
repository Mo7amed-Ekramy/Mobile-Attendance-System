import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_attendance_mobile/app.dart';

void main() {
  testWidgets('demo role enters student navigation and scanner is honest',
      (tester) async {
    await tester.pumpWidget(const AttendanceApp());
    await tester.tap(find.text('Explore local demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Mariam'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.qr_code_scanner).first);
    await tester.pumpAndSettle();
    expect(find.text('No QR is read and no attendance is submitted.'),
        findsOneWidget);
  });

  testWidgets('TA and doctor journeys open on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AttendanceApp());
    await tester.tap(find.text('Explore local demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teaching assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Section workspace'), findsOneWidget);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    expect(find.text('Grade work'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out of demo'), 200);
    await tester.tap(find.text('Sign out of demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore local demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doctor / instructor'));
    await tester.pumpAndSettle();
    expect(find.text('Teaching overview'), findsOneWidget);
    await tester.tap(find.text('Attendance').last);
    await tester.pumpAndSettle();
    expect(find.text('New lecture session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TA local roll requires resolved rows and confirms finalization',
      (tester) async {
    await tester.pumpWidget(const AttendanceApp());
    await tester.tap(find.text('Explore local demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teaching assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take attendance'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unset 6'), findsOneWidget);
    await tester.tap(find.text('Mark all absent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unset 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Review and finalize'), 200);
    await tester.tap(find.text('Review and finalize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Local roll finalized'), -200);
    expect(find.text('Local roll finalized'), findsOneWidget);
  });
}
