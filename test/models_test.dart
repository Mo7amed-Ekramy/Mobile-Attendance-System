import 'package:flutter_test/flutter_test.dart';
import 'package:university_attendance_mobile/data/models.dart';

AttendanceSession session(String state, String? mark) =>
    AttendanceSession.fromJson({
      'id': 1,
      'title': 'Session',
      'kind': 'lecture',
      'state': state,
      'starts_at': '2026-10-31T10:00:00Z',
      'ends_at': '2026-10-31T11:00:00Z',
      'own_status': mark,
    });

void main() {
  test('attendance percentages exclude drafts, cancellations, and excuses', () {
    expect(
        attendanceRate([
          session('closed', 'present'),
          session('closed', 'absent'),
          session('cancelled', 'absent'),
          session('open', 'present'),
          session('finalized', 'excused')
        ]),
        .5);
    expect(
        attendanceRate([session('open', null), session('closed', 'excused')]),
        isNull);
  });

  test('zero scores and unavailable scores remain distinct', () {
    expect(points('0.00'), '0.00');
    expect(points(null), '—');
    expect(amount(null), isNull);
  });
}
