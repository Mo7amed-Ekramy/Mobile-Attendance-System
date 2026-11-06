enum Role { student, ta, doctor }

double? amount(dynamic value) => value == null ? null : double.parse('$value');
String points(dynamic value) =>
    value == null ? '—' : amount(value)!.toStringAsFixed(2);
DateTime date(dynamic value) => DateTime.parse('$value').toUtc();

class UserProfile {
  UserProfile.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        username = json['username'] as String,
        name = json['full_name'] as String,
        role = Role.values.byName(json['role'] as String),
        universityId = json['university_id'] as String?,
        department = json['department'] as String?,
        sectionNumber = json['section_number'] as int?,
        email = json['email'] as String?;
  final int id;
  final String username, name;
  final Role role;
  final String? universityId, department, email;
  final int? sectionNumber;
  String get roleLabel => switch (role) {
        Role.doctor => 'دكتور',
        Role.ta => 'معيد',
        Role.student => 'طالب',
      };
}

class CourseSection {
  CourseSection.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        number = json['section_number'] as int,
        department = json['department_code'] as String,
        taName = json['ta_name'] as String,
        studentCount = json['student_count'] as int;
  final int id, number, studentCount;
  final String department, taName;
  String get label => 'سكشن $number ($department)';
}

class CourseOffering {
  CourseOffering.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        code = json['code'] as String,
        name = json['name'] as String,
        term = json['term'] as String,
        doctorName = json['doctor_name'] as String,
        archived = json['is_archived'] as bool,
        sections = (json['sections'] as List)
            .map((value) =>
                CourseSection.fromJson(value as Map<String, dynamic>))
            .toList();
  final int id;
  final String code, name, term, doctorName;
  final bool archived;
  final List<CourseSection> sections;
}

class AttendanceSession {
  AttendanceSession.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = json['title'] as String,
        kind = json['kind'] as String,
        state = json['state'] as String,
        startsAt = date(json['starts_at']),
        endsAt = date(json['ends_at']),
        ownStatus = json['own_status'] as String?,
        presentCount = json['present_count'] as int? ?? 0,
        eligibleCount = json['eligible_count'] as int? ?? 0;
  final int id, presentCount, eligibleCount;
  final String title, kind, state;
  final String? ownStatus;
  final DateTime startsAt, endsAt;
  bool get finalized => state == 'closed' || state == 'finalized';
  String get stateLabel => switch (state) {
        'draft' => 'مسودة',
        'open' => 'مفتوحة',
        'closed' => 'مغلقة',
        'finalized' => 'معتمدة',
        'cancelled' => 'ملغاة',
        _ => state,
      };
}

String markLabel(String? mark) => switch (mark) {
      'present' => 'حاضر',
      'absent' => 'غائب',
      'excused' => 'بعذر',
      _ => 'غير محدد',
    };

double? attendanceRate(Iterable<AttendanceSession> sessions) {
  final eligible = sessions
      .where((session) =>
          session.finalized &&
          (session.ownStatus == 'present' || session.ownStatus == 'absent'))
      .toList();
  if (eligible.isEmpty) return null;
  return eligible.where((session) => session.ownStatus == 'present').length /
      eligible.length;
}
