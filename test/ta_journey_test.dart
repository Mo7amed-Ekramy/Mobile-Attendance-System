import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_attendance_mobile/app.dart';

Future<void> enterTa(WidgetTester tester) async {
  await tester.pumpWidget(const AttendanceApp());
  await tester.tap(find.text('Explore local demo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Teaching assistant'));
  await tester.pumpAndSettle();
  expect(find.text('Section workspace'), findsOneWidget);
}

Future<void> tapVisible(WidgetTester tester, Finder finder,
    {double scrollDelta = 300}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, scrollDelta,
        scrollable: find.byType(Scrollable).first);
    // scrollUntilVisible stops as soon as a lazy row is built, which may leave
    // its tappable center clipped at the viewport boundary.
    await tester.drag(
        find.byType(ListView).last, Offset(0, scrollDelta > 0 ? -160 : 160));
    await tester.pumpAndSettle();
  }
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.drag(
        find.byType(ListView).last, Offset(0, scrollDelta > 0 ? -160 : 160));
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TA resolves and finalizes a local attendance roll',
      (tester) async {
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await enterTa(tester);
    await tapVisible(tester, find.text('Take attendance'));
    expect(find.textContaining('Unset 6'), findsOneWidget);

    await tapVisible(tester, find.text('Review and finalize'));
    expect(find.text('Resolve every unset student before finalizing.'),
        findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Mark all absent'), scrollDelta: -300);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Unset 6'), -300);
    expect(find.textContaining('Unset 6'), findsOneWidget);

    await tapVisible(tester, find.text('Mark all absent'), scrollDelta: -300);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Absent 6'), -300);
    expect(find.textContaining('Absent 6'), findsOneWidget);
    expect(find.textContaining('Unset 0'), findsOneWidget);

    await tapVisible(tester, find.text('Review and finalize'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Local roll finalized'), -300);
    expect(find.text('Local roll finalized'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TA roster search and course switch update assignment',
      (tester) async {
    await enterTa(tester);
    await tapVisible(tester, find.text('Sections').last);
    expect(find.text('Assigned sections'), findsOneWidget);
    await tapVisible(tester, find.text('CS301 · Section A'));
    await tapVisible(tester, find.text('Section roster'));
    expect(find.text('Mariam Adel'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search student name or ID'),
        '20240156');
    await tester.pumpAndSettle();
    expect(find.text('Kareem Fathy'), findsOneWidget);
    expect(find.text('Mariam Adel'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search student name or ID'), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No matching students'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI204 · Introduction to AI'));
    await tester.pumpAndSettle();
    expect(find.text('Section workspace'), findsOneWidget);
    expect(find.text('Introduction to AI'), findsOneWidget);
    await tapVisible(tester, find.text('Take attendance'));
    expect(find.text('AI204 · Section C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TA edits individual marks and can cancel finalization',
      (tester) async {
    await enterTa(tester);
    await tapVisible(tester, find.text('Take attendance'));
    await tapVisible(tester, find.text('Mark all absent'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final mariamCard = find.ancestor(
        of: find.text('Mariam Adel'), matching: find.byType(Card));
    await tapVisible(tester,
        find.descendant(of: mariamCard, matching: find.text('Present')));
    final youssefCard = find.ancestor(
        of: find.text('Youssef Ali'), matching: find.byType(Card));
    await tapVisible(tester,
        find.descendant(of: youssefCard, matching: find.text('Excused')));
    await tester.scrollUntilVisible(find.textContaining('Present 1'), -300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Present 1 · Absent 4 · Excused 1 · Unset 0'),
        findsOneWidget);

    await tapVisible(tester, find.text('Review and finalize'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Local roll finalized'), findsNothing);
    await tapVisible(tester, find.text('Review and finalize'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mariam Adel'), -300,
        scrollable: find.byType(Scrollable).first);
    final presentChip = tester.widget<ChoiceChip>(find
        .ancestor(of: find.text('Present'), matching: find.byType(ChoiceChip))
        .first);
    expect(presentChip.onSelected, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TA validates scores, retains them locally, and signs out',
      (tester) async {
    await enterTa(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    expect(find.text('Grade work'), findsOneWidget);
    await tapVisible(tester, find.text('Quiz 1 · scores'));
    expect(find.text('Quiz 1 · 10 raw points maximum'), findsOneWidget);

    final scoreFields = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scoreFields.first, '11');
    await tapVisible(tester, find.text('Save local scores'));
    expect(find.text('Scores must be between 0 and 10, or blank.'),
        findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Mariam Adel'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(scoreFields.first, '0');
    await tapVisible(tester, find.text('Save local scores'));
    expect(find.text('Scores saved in this demo only.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quiz 1 · scores'));
    expect(tester.widget<TextField>(scoreFields.first).controller!.text, '0.0');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI204 · Introduction to AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quiz 1 · scores'));
    expect(tester.widget<TextField>(scoreFields.first).controller!.text, '');
    await tester.pageBack();
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Create quiz draft'));
    await tapVisible(tester, find.text('Create local draft'));
    expect(find.text('Enter a title and a positive maximum.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Quiz title'), 'Practical quiz');
    await tester.enterText(
        find.widgetWithText(TextField, 'Raw maximum points'), '12');
    await tapVisible(tester, find.text('Create local draft'));
    expect(find.text('Grade work'), findsOneWidget);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Sign out of demo'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Explore local demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TA opens account pages, changes theme and cancels sign out',
      (tester) async {
    await enterTa(tester);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Notifications').last);
    expect(find.text('Quiz 2 published'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Profile'));
    expect(find.text('Nour Ibrahim'), findsOneWidget);
    expect(find.text('TA-0104'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Dark theme'));
    expect(Theme.of(tester.element(find.text('More').first)).brightness,
        Brightness.dark);
    await tapVisible(tester, find.text('Sign out of demo'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Explore local demo'), findsNothing);
    expect(find.text('More').first, findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'TA keeps scores when reopening same course and skips unchanged save',
      (tester) async {
    await enterTa(tester);
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quiz 1 · scores'));
    final scoreFields = find.widgetWithText(TextField, 'Score');
    await tester.enterText(scoreFields.first, '7');
    await tapVisible(tester, find.text('Save local scores'));
    expect(find.text('Scores saved in this demo only.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sections').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('CS301 · Section A'));
    expect(find.text('Data Structures'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CS301 · Data Structures'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quiz 1 · scores'));
    expect(tester.widget<TextField>(scoreFields.first).controller!.text, '7.0');
    await tapVisible(tester, find.text('Save local scores'));
    expect(find.text('No score changes to save.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI204 · Introduction to AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quiz 1 · scores'));
    expect(tester.widget<TextField>(scoreFields.first).controller!.text, '');
    expect(tester.takeException(), isNull);
  });
}
