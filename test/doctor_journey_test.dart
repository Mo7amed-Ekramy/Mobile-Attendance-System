import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_attendance_mobile/app.dart';

Future<void> enterDoctor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const AttendanceApp());
  await tester.tap(find.text('Explore local demo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Doctor / instructor'));
  await tester.pumpAndSettle();
  expect(find.text('Teaching overview'), findsOneWidget);
}

Future<void> scrollTo(WidgetTester tester, Finder target, double delta) =>
    tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets('doctor can select an assigned course and inspect its gradebook',
      (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    expect(find.text('Assigned courses'), findsOneWidget);
    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('Introduction to AI'), findsOneWidget);
    expect(find.text('Software Engineering'), findsOneWidget);

    await tester.tap(find.text('Introduction to AI'));
    await tester.pumpAndSettle();
    expect(find.text('AI204 · Fall 2026 · Section C'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    expect(find.text('AI204 · policy and assessments'), findsOneWidget);
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz 1 · 10 raw points maximum'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor rejects a raw grade above the quiz maximum',
      (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();

    Finder mariamScore() => find.descendant(
          of: find
              .ancestor(
                of: find.text('Mariam Adel'),
                matching: find.byType(Card),
              )
              .first,
          matching: find.byType(TextField),
        );
    await tester.enterText(mariamScore(), '11');
    await scrollTo(tester, find.text('Save local scores'), 200);
    await tester.tap(find.text('Save local scores'));
    await tester.pump();
    expect(find.text('Scores must be between 0 and 10, or blank.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor retains a locally saved zero', (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();

    Finder mariamScore() => find.descendant(
          of: find
              .ancestor(
                of: find.text('Mariam Adel'),
                matching: find.byType(Card),
              )
              .first,
          matching: find.byType(TextField),
        );

    await tester.enterText(mariamScore(), '0');
    expect(tester.widget<TextField>(mariamScore()).controller?.text, '0');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Save local scores'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save local scores'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Mariam Adel'), -200);
    final restored = tester.widget<TextField>(mariamScore());
    expect(restored.controller?.text, '0.0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor grade allocation is a local draft', (tester) async {
    await enterDoctor(tester);
    await scrollTo(tester, find.text('Grade allocation'), 200);
    await tester.tap(find.text('Grade allocation'));
    await tester.pumpAndSettle();
    expect(find.text('Allocated 100.0 / 100'), findsOneWidget);
    expect(find.text('Not published'), findsOneWidget);
    await scrollTo(tester, find.text('Preview balanced draft'), 200);
    await tester.tap(find.text('Preview balanced draft'));
    await tester.pump();
    expect(
      find.text(
          'Policy balanced. Publication requires the future server workflow.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor can apply an unchanged final allocation and leave',
      (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade allocation'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Final'), 200);
    await tester.tap(find.text('Final'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Allocated 100.0 / 100'), -200);
    expect(find.text('Allocated 100.0 / 100'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor can edit an allocation and see an unbalanced total',
      (tester) async {
    await enterDoctor(tester);
    await scrollTo(tester, find.text('Grade allocation'), 200);
    await tester.tap(find.text('Grade allocation'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Midterm'), 200);
    await tester.tap(find.text('Midterm'));
    await tester.pumpAndSettle();
    expect(find.text('Midterm allocation'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '25');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Allocated 105.0 / 100'), -200);
    expect(find.text('Allocated 105.0 / 100'), findsOneWidget);
    expect(find.text('5.0 points overallocated'), findsOneWidget);
    await scrollTo(tester, find.text('Preview balanced draft'), 200);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(
              FilledButton,
              'Preview balanced draft',
            ))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving untouched grades reports no changes', (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Save local scores'), 200);
    await tester.tap(find.text('Save local scores'));
    await tester.pump();
    expect(find.text('No score changes to save.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor can open and close a simulated lecture', (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Attendance').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New lecture session'));
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    await tester.tap(find.text('Open local session'));
    await tester.pumpAndSettle();
    expect(find.text('Open in demo'), findsOneWidget);
    await tester.tap(find.text('Close local session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open in demo'), findsOneWidget);
    await tester.tap(find.text('Close local session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor reports, assignments, and sign out navigate',
      (tester) async {
    await enterDoctor(tester);
    await scrollTo(tester, find.text('Course report'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course report'));
    await tester.pumpAndSettle();
    expect(find.text('CS301 report'), findsOneWidget);
    expect(find.text('Incomplete'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Teaching assignments'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teaching assignments'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned teaching staff'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Sign out of demo'), 200);
    await tester.tap(find.text('Sign out of demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Explore local demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'doctor adds a demo course, records a grade, then sign out clears it',
      (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add demo course'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add course'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a course code.'), findsOneWidget);
    expect(find.text('Enter a course title.'), findsOneWidget);
    expect(find.text('Enter a section.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), ' cs301 ');
    await tester.tap(find.text('Add course'));
    await tester.pumpAndSettle();
    expect(find.text('This course code already exists.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), ' cs999 ');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Mobile Computing');
    await tester.enterText(find.byType(TextFormField).at(2), 'Section D');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add course'));
    await tester.pumpAndSettle();
    expect(find.text('Add course'), findsNothing);

    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    expect(find.text('CS999 · policy and assessments'), findsOneWidget);
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    final firstScore = find.descendant(
      of: find
          .ancestor(
            of: find.text('Mariam Adel'),
            matching: find.byType(Card),
          )
          .first,
      matching: find.byType(TextField),
    );
    await tester.enterText(firstScore, '9.5');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Save local scores'), 200);
    await tester.tap(find.text('Save local scores'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(firstScore).controller?.text, '9.5');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Sign out of demo'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out of demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore local demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doctor / instructor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    expect(find.text('Mobile Computing'), findsNothing);
    expect(find.text('CS999'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening selected course details preserves saved grade',
      (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    Finder firstScore() => find.descendant(
          of: find
              .ancestor(
                of: find.text('Mariam Adel'),
                matching: find.byType(Card),
              )
              .first,
          matching: find.byType(TextField),
        );
    await tester.enterText(firstScore(), '7');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Save local scores'), 200);
    await tester.tap(find.text('Save local scores'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Structures'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gradebook'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(firstScore()).controller?.text, '7.0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor can search courses, inspect roster, and view profile',
      (tester) async {
    await enterDoctor(tester);
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SE220');
    await tester.pumpAndSettle();
    expect(find.text('Software Engineering'), findsOneWidget);
    expect(find.text('Data Structures'), findsNothing);
    tester.testTextInput.hide();
    await tester.tap(find.text('Software Engineering'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Course roster'), 200);
    await tester.tap(find.text('Course roster'));
    await tester.pumpAndSettle();
    expect(find.text('Mariam Adel'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Profile'), 200);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('FAC-0021'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
