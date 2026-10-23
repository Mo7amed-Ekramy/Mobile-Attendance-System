import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_attendance_mobile/app.dart';

Future<void> enterStudent(WidgetTester tester) async {
  await tester.pumpWidget(const AttendanceApp());
  await tester.tap(find.text('Explore local demo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Student'));
  await tester.pumpAndSettle();
  expect(find.text('Good morning, Mariam'), findsOneWidget);
}

void main() {
  testWidgets('student searches courses and opens attendance and grade detail',
      (tester) async {
    await enterStudent(tester);

    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    expect(find.text('My courses'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'AI204');
    await tester.pumpAndSettle();
    expect(find.text('Introduction to AI'), findsOneWidget);
    expect(find.text('Data Structures'), findsNothing);

    await tester.tap(find.text('Introduction to AI'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Omar Nabil'), findsOneWidget);
    await tester.tap(find.text('Lecture history'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Unfinalized'), 200);
    expect(find.text('Unfinalized'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cancelled'), 200);
    expect(find.text('Cancelled'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Section history'));
    await tester.pumpAndSettle();
    expect(find.text('67%'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grade breakdown'));
    await tester.pumpAndSettle();
    expect(find.text('No official total'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('0 / 10 raw points'), 200);
    expect(find.text('0 / 10 raw points'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No recorded result'), 200);
    expect(find.text('No recorded result'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pending publication'), -200);
    expect(find.text('Pending publication'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student switches course, scans preview, opens progress',
      (tester) async {
    await enterStudent(tester);
    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SE220 · Software Engineering'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo course changed'), findsOneWidget);
    expect(find.text('Software Engineering'), findsOneWidget);

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    expect(find.text('No QR is read and no attendance is submitted.'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('Preview scanner state'), 200);
    await tester.tap(find.text('Preview scanner state'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Published results for SE220'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('View grade breakdown'), 200);
    await tester.tap(find.text('View grade breakdown'));
    await tester.pumpAndSettle();
    expect(find.text('No official total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing current course keeps tab; choosing another resets home',
      (tester) async {
    await enterStudent(tester);
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Published results for CS301'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CS301 · Data Structures'));
    await tester.pumpAndSettle();
    expect(find.text('Published results for CS301'), findsOneWidget);
    expect(find.textContaining('Demo course changed'), findsNothing);

    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI204 · Introduction to AI'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Mariam'), findsOneWidget);
    expect(find.text('Introduction to AI'), findsOneWidget);
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Published results for AI204'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student profile, theme and confirmed sign out', (tester) async {
    await enterStudent(tester);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Mariam Adel'), findsOneWidget);
    expect(find.text('20240112'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Dark theme'))).brightness,
        Brightness.dark);
    await tester.scrollUntilVisible(find.text('Sign out of demo'), 200);
    await tester.tap(find.text('Sign out of demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('More'), findsWidgets);

    await tester.tap(find.text('Sign out of demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Explore local demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student sees empty search and can recover', (tester) async {
    await enterStudent(tester);
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.enterText(search, 'unknown 999');
    await tester.pumpAndSettle();
    expect(find.text('No matching courses'), findsOneWidget);
    expect(find.text('Try a different course title or code.'), findsOneWidget);
    await tester.enterText(search, 'CS301');
    await tester.pumpAndSettle();
    expect(find.text('No matching courses'), findsNothing);
    expect(find.text('Data Structures'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student home shortcuts and notifications open correct screens',
      (tester) async {
    await enterStudent(tester);
    await tester.tap(find.text('Scan lecture QR'));
    await tester.pumpAndSettle();
    expect(find.text('No QR is read and no attendance is submitted.'),
        findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('View progress'), 200);
    await tester.tap(find.text('View progress'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('View grade breakdown'), 200);
    expect(find.text('View grade breakdown'), findsOneWidget);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz 2 published'), findsOneWidget);
    expect(find.text('Attendance updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student primary tabs render on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await enterStudent(tester);
    for (final tab in ['Courses', 'Scan', 'Progress', 'More', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab did not render');
    }
  });
}
