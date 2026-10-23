import 'package:flutter_test/flutter_test.dart';
import 'package:university_attendance_mobile/mock_data.dart';

void main() {
  test('eligible attendance ignores excused, draft and cancelled sessions', () {
    expect(
      attendanceRate(MockData.sessions.where((s) => s.kind == 'Lecture')),
      0.5,
    );
    expect(
      attendanceRate([
        const Session(
          'Draft',
          'Today',
          'Lecture',
          Mark.unset,
          finalized: false,
        ),
      ]),
      isNull,
    );
  });

  test('normalized quiz points distinguish recorded zero and missing', () {
    final quizzes = MockData.assessments.where((a) => a.category == 'Quizzes');
    expect(normalizedPoints(quizzes, 5), 2);
    expect(
      normalizedPoints([
        const Assessment('Missing', 'Quizzes', 10, null, ScoreState.unrecorded),
      ], 5),
      isNull,
    );
  });

  test('offering switch clears local draft state', () {
    final demo = DemoState();
    demo.marks['20240112'] = Mark.present;
    demo.scores['20240112'] = 0;
    demo.allocations['Final'] = 40;
    demo.publishSectionQuiz(
      title: 'Lab Quiz',
      section: 'Section A',
      questionCount: 5,
      durationMinutes: 20,
    );
    expect(demo.activeQuiz, isNotNull);
    expect(demo.activeQuiz!.questions.length, 5);
    expect(demo.activeQuiz!.durationMinutes, 20);
    expect(demo.quizNotificationPending, isTrue);

    demo.resetScope(1);
    expect(demo.courseIndex, 1);
    expect(demo.marks, isEmpty);
    expect(demo.scores, isEmpty);
    expect(demo.allocations['Final'], 50);
    expect(demo.activeQuiz, isNull);
    expect(demo.quizNotificationPending, isFalse);
  });
}
