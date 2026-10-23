// GENERATED RELATIONAL COLLEGE DATABASE FROM .NET LEGACY SYSTEM
// Source: legacy-attendance-system (Seeding & Migrations)
// Real college records: 415 Students, 36 Staff/Users, 14 Courses, 4 Departments, 19 Sections, 108 CourseSections

enum CollegeRole { admin, doctor, ta, student }

class CollegeDepartment {
  const CollegeDepartment({required this.id, required this.code, required this.name});
  final int id;
  final String code;
  final String name;
}

class CollegeDepartmentSection {
  const CollegeDepartmentSection({required this.id, required this.departmentId, required this.number});
  final int id;
  final int departmentId;
  final int number;
  String get name => "Section $number";
}

class CollegeUser {
  const CollegeUser({required this.id, required this.userName, required this.fullName, required this.role, this.email});
  final int id;
  final String userName;
  final String fullName;
  final CollegeRole role;
  final String? email;
}

class CollegeCourse {
  const CollegeCourse({required this.id, required this.code, required this.name, required this.semester, required this.doctorId, required this.level});
  final int id;
  final String code;
  final String name;
  final String semester;
  final int doctorId;
  final int level;
}

class CollegeCourseDepartment {
  const CollegeCourseDepartment({required this.id, required this.courseId, required this.departmentId});
  final int id;
  final int courseId;
  final int departmentId;
}

class CollegeCourseSection {
  const CollegeCourseSection({required this.id, required this.courseId, required this.departmentSectionId, required this.taId});
  final int id;
  final int courseId;
  final int departmentSectionId;
  final int taId;
}

class CollegeStudent {
  const CollegeStudent({
    required this.id,
    required this.universityId,
    required this.fullName,
    required this.userName,
    required this.level,
    required this.departmentId,
    required this.departmentSectionId,
  });
  final int id;
  final String universityId;
  final String fullName;
  final String userName;
  final int level;
  final int departmentId;
  final int departmentSectionId;
}

class CollegeEnrollment {
  const CollegeEnrollment({required this.studentId, required this.courseSectionId});
  final int studentId;
  final int courseSectionId;
}

abstract final class CollegeDatabase {
  static const departments = <CollegeDepartment>[
    CollegeDepartment(id: 1, code: 'SE', name: 'Software Engineering'),
    CollegeDepartment(id: 2, code: 'AI', name: 'Artificial Intelligence'),
    CollegeDepartment(id: 3, code: 'CS', name: 'Computer Science'),
    CollegeDepartment(id: 4, code: 'IS', name: 'Information System'),
  ];

  static const departmentSections = <CollegeDepartmentSection>[
    CollegeDepartmentSection(id: 1, departmentId: 1, number: 1),
    CollegeDepartmentSection(id: 2, departmentId: 1, number: 2),
    CollegeDepartmentSection(id: 3, departmentId: 1, number: 3),
    CollegeDepartmentSection(id: 4, departmentId: 1, number: 4),
    CollegeDepartmentSection(id: 5, departmentId: 1, number: 5),
    CollegeDepartmentSection(id: 6, departmentId: 1, number: 6),
    CollegeDepartmentSection(id: 7, departmentId: 1, number: 7),
    CollegeDepartmentSection(id: 8, departmentId: 1, number: 8),
    CollegeDepartmentSection(id: 9, departmentId: 2, number: 1),
    CollegeDepartmentSection(id: 10, departmentId: 2, number: 2),
    CollegeDepartmentSection(id: 11, departmentId: 2, number: 3),
    CollegeDepartmentSection(id: 12, departmentId: 2, number: 4),
    CollegeDepartmentSection(id: 13, departmentId: 2, number: 5),
    CollegeDepartmentSection(id: 14, departmentId: 3, number: 1),
    CollegeDepartmentSection(id: 15, departmentId: 3, number: 2),
    CollegeDepartmentSection(id: 16, departmentId: 3, number: 3),
    CollegeDepartmentSection(id: 17, departmentId: 3, number: 4),
    CollegeDepartmentSection(id: 18, departmentId: 3, number: 5),
    CollegeDepartmentSection(id: 19, departmentId: 4, number: 1),
  ];

  static const users = <CollegeUser>[
    CollegeUser(id: 0, userName: 'admin', fullName: 'System Administrator', role: CollegeRole.admin, email: null),
    CollegeUser(id: 31, userName: 'admin_mai', fullName: 'Mai Hamed', role: CollegeRole.admin, email: null),
    CollegeUser(id: 32, userName: 'admin_mahmoud', fullName: 'Mahmoud Sayed', role: CollegeRole.admin, email: null),
    CollegeUser(id: 33, userName: 'admin_mohamed', fullName: 'Mohamed Ibrahem', role: CollegeRole.admin, email: null),
    CollegeUser(id: 34, userName: 'admin_ekramy', fullName: 'Mohamed Ekramy', role: CollegeRole.admin, email: null),
    CollegeUser(id: 35, userName: 'admin_julia', fullName: 'Julia Osama', role: CollegeRole.admin, email: null),
    CollegeUser(id: 1, userName: 'doc_mamdouh12', fullName: 'mamdouh farouk mohamed', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 2, userName: 'doc_khaled13', fullName: 'khaled fathi', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 3, userName: 'doc_ibrahim14', fullName: 'ibrahim elawady', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 4, userName: 'doc_aml01', fullName: 'aml abdelazim', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 5, userName: 'doc_sarah05', fullName: 'sarah salah', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 6, userName: 'doc_rasha01', fullName: 'rasha mahmoud kamel', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 7, userName: 'doc_tarek12', fullName: 'tarek mohamed abdelkader', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 8, userName: 'doc_soha01', fullName: 'soha abdelmomen mohamed', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 9, userName: 'doc_maged32', fullName: 'maged asker', role: CollegeRole.doctor, email: null),
    CollegeUser(id: 10, userName: 'ta_sarah11', fullName: 'sarah raouf', role: CollegeRole.ta, email: null),
    CollegeUser(id: 11, userName: 'ta_salma76', fullName: 'salma osama', role: CollegeRole.ta, email: null),
    CollegeUser(id: 12, userName: 'ta_abdalla01', fullName: 'Abdalla ahmed', role: CollegeRole.ta, email: null),
    CollegeUser(id: 13, userName: 'ta_ghada74', fullName: 'ghada samer', role: CollegeRole.ta, email: null),
    CollegeUser(id: 14, userName: 'ta_mahmoud03', fullName: 'mahmoud kotb', role: CollegeRole.ta, email: null),
    CollegeUser(id: 15, userName: 'ta_radwa01', fullName: 'radwa saleh', role: CollegeRole.ta, email: null),
    CollegeUser(id: 16, userName: 'ta_ahmed25', fullName: 'ahmed hesham', role: CollegeRole.ta, email: null),
    CollegeUser(id: 17, userName: 'ta_mariam98', fullName: 'mariam malak', role: CollegeRole.ta, email: null),
    CollegeUser(id: 18, userName: 'ta_ahmed14', fullName: 'ahmed abdelrahman', role: CollegeRole.ta, email: null),
    CollegeUser(id: 19, userName: 'ta_mohamed15', fullName: 'mohamed taha', role: CollegeRole.ta, email: null),
    CollegeUser(id: 20, userName: 'ta_mahmoud26', fullName: 'mahmoud esam', role: CollegeRole.ta, email: null),
    CollegeUser(id: 21, userName: 'ta_ismail72', fullName: 'ismail akram', role: CollegeRole.ta, email: null),
    CollegeUser(id: 22, userName: 'ta_mohamed32', fullName: 'mohamed elFoly', role: CollegeRole.ta, email: null),
    CollegeUser(id: 23, userName: 'ta_elhasen28', fullName: 'elhasen mohamed', role: CollegeRole.ta, email: null),
    CollegeUser(id: 24, userName: 'ta_manal01', fullName: 'manal mahmoud', role: CollegeRole.ta, email: null),
    CollegeUser(id: 25, userName: 'ta_nehad00', fullName: 'nehad abdelrahman', role: CollegeRole.ta, email: null),
    CollegeUser(id: 26, userName: 'ta_gehad01', fullName: 'gehad zakria', role: CollegeRole.ta, email: null),
    CollegeUser(id: 27, userName: 'ta_elzahra03', fullName: 'elzahra youssif', role: CollegeRole.ta, email: null),
    CollegeUser(id: 28, userName: 'ta_asaad09', fullName: 'asaad nasr', role: CollegeRole.ta, email: null),
    CollegeUser(id: 29, userName: 'ta_mohamed02', fullName: 'mohamed abdelhamed', role: CollegeRole.ta, email: null),
    CollegeUser(id: 30, userName: 'ta_mostafa01', fullName: 'mostafa osama', role: CollegeRole.ta, email: null),
  ];

  static const courses = <CollegeCourse>[
    CollegeCourse(id: 1, code: 'CS381', name: 'software development', semester: '2', doctorId: 6, level: 3),
    CollegeCourse(id: 2, code: 'SE332', name: 'Software Construction', semester: '2', doctorId: 1, level: 3),
    CollegeCourse(id: 3, code: 'SE331', name: 'Software Architecture Design', semester: '2', doctorId: 3, level: 3),
    CollegeCourse(id: 4, code: 'CS342', name: 'Automata', semester: '2', doctorId: 4, level: 3),
    CollegeCourse(id: 5, code: 'SE321', name: 'Software Requirements Analysis', semester: '2', doctorId: 5, level: 3),
    CollegeCourse(id: 6, code: 'CS361', name: 'Artificial Intelligence', semester: '2', doctorId: 5, level: 3),
    CollegeCourse(id: 7, code: 'AI125', name: 'Decision Support Systems', semester: '2', doctorId: 3, level: 3),
    CollegeCourse(id: 8, code: 'SE112', name: 'Intelligent Systems', semester: '2', doctorId: 5, level: 3),
    CollegeCourse(id: 9, code: 'IS911', name: 'Web Programming', semester: '2', doctorId: 7, level: 3),
    CollegeCourse(id: 10, code: 'AI216', name: 'Operating_Systems', semester: '2', doctorId: 2, level: 3),
    CollegeCourse(id: 11, code: 'CS211', name: 'Image Processing', semester: '2', doctorId: 6, level: 3),
    CollegeCourse(id: 12, code: 'CS22', name: 'Computer Vision', semester: '2', doctorId: 2, level: 3),
    CollegeCourse(id: 13, code: 'SE140', name: 'Algorithms Design Analysis', semester: '2', doctorId: 9, level: 3),
    CollegeCourse(id: 14, code: 'AI126', name: 'Artificial Intelligence (CS)', semester: '2', doctorId: 4, level: 3),
  ];

  static const courseDepartments = <CollegeCourseDepartment>[
    CollegeCourseDepartment(id: 1, courseId: 1, departmentId: 1),
    CollegeCourseDepartment(id: 2, courseId: 1, departmentId: 2),
    CollegeCourseDepartment(id: 3, courseId: 1, departmentId: 3),
    CollegeCourseDepartment(id: 4, courseId: 2, departmentId: 1),
    CollegeCourseDepartment(id: 5, courseId: 3, departmentId: 1),
    CollegeCourseDepartment(id: 6, courseId: 4, departmentId: 1),
    CollegeCourseDepartment(id: 7, courseId: 4, departmentId: 3),
    CollegeCourseDepartment(id: 8, courseId: 5, departmentId: 1),
    CollegeCourseDepartment(id: 9, courseId: 6, departmentId: 1),
    CollegeCourseDepartment(id: 10, courseId: 6, departmentId: 3),
    CollegeCourseDepartment(id: 11, courseId: 7, departmentId: 2),
    CollegeCourseDepartment(id: 12, courseId: 8, departmentId: 2),
    CollegeCourseDepartment(id: 13, courseId: 9, departmentId: 2),
    CollegeCourseDepartment(id: 14, courseId: 10, departmentId: 2),
    CollegeCourseDepartment(id: 15, courseId: 11, departmentId: 2),
    CollegeCourseDepartment(id: 16, courseId: 11, departmentId: 3),
    CollegeCourseDepartment(id: 17, courseId: 12, departmentId: 3),
    CollegeCourseDepartment(id: 18, courseId: 13, departmentId: 3),
  ];

  static const courseSections = <CollegeCourseSection>[
    CollegeCourseSection(id: 1, courseId: 1, departmentSectionId: 1, taId: 25),
    CollegeCourseSection(id: 2, courseId: 1, departmentSectionId: 2, taId: 18),
    CollegeCourseSection(id: 3, courseId: 1, departmentSectionId: 3, taId: 18),
    CollegeCourseSection(id: 4, courseId: 1, departmentSectionId: 4, taId: 18),
    CollegeCourseSection(id: 5, courseId: 1, departmentSectionId: 5, taId: 18),
    CollegeCourseSection(id: 6, courseId: 1, departmentSectionId: 6, taId: 18),
    CollegeCourseSection(id: 7, courseId: 1, departmentSectionId: 7, taId: 18),
    CollegeCourseSection(id: 8, courseId: 1, departmentSectionId: 8, taId: 26),
    CollegeCourseSection(id: 9, courseId: 1, departmentSectionId: 9, taId: 26),
    CollegeCourseSection(id: 10, courseId: 1, departmentSectionId: 10, taId: 26),
    CollegeCourseSection(id: 11, courseId: 1, departmentSectionId: 11, taId: 26),
    CollegeCourseSection(id: 12, courseId: 1, departmentSectionId: 12, taId: 26),
    CollegeCourseSection(id: 13, courseId: 1, departmentSectionId: 13, taId: 25),
    CollegeCourseSection(id: 14, courseId: 1, departmentSectionId: 14, taId: 18),
    CollegeCourseSection(id: 15, courseId: 1, departmentSectionId: 15, taId: 25),
    CollegeCourseSection(id: 16, courseId: 1, departmentSectionId: 16, taId: 25),
    CollegeCourseSection(id: 17, courseId: 1, departmentSectionId: 17, taId: 26),
    CollegeCourseSection(id: 18, courseId: 1, departmentSectionId: 18, taId: 25),
    CollegeCourseSection(id: 19, courseId: 2, departmentSectionId: 1, taId: 19),
    CollegeCourseSection(id: 20, courseId: 2, departmentSectionId: 2, taId: 19),
    CollegeCourseSection(id: 21, courseId: 2, departmentSectionId: 3, taId: 19),
    CollegeCourseSection(id: 22, courseId: 2, departmentSectionId: 4, taId: 19),
    CollegeCourseSection(id: 23, courseId: 2, departmentSectionId: 5, taId: 19),
    CollegeCourseSection(id: 24, courseId: 2, departmentSectionId: 6, taId: 19),
    CollegeCourseSection(id: 25, courseId: 2, departmentSectionId: 7, taId: 19),
    CollegeCourseSection(id: 26, courseId: 2, departmentSectionId: 8, taId: 19),
    CollegeCourseSection(id: 27, courseId: 3, departmentSectionId: 1, taId: 17),
    CollegeCourseSection(id: 28, courseId: 3, departmentSectionId: 2, taId: 17),
    CollegeCourseSection(id: 29, courseId: 3, departmentSectionId: 3, taId: 23),
    CollegeCourseSection(id: 30, courseId: 3, departmentSectionId: 4, taId: 23),
    CollegeCourseSection(id: 31, courseId: 3, departmentSectionId: 5, taId: 17),
    CollegeCourseSection(id: 32, courseId: 3, departmentSectionId: 6, taId: 17),
    CollegeCourseSection(id: 33, courseId: 3, departmentSectionId: 7, taId: 17),
    CollegeCourseSection(id: 34, courseId: 3, departmentSectionId: 8, taId: 17),
    CollegeCourseSection(id: 35, courseId: 4, departmentSectionId: 1, taId: 20),
    CollegeCourseSection(id: 36, courseId: 4, departmentSectionId: 2, taId: 20),
    CollegeCourseSection(id: 37, courseId: 4, departmentSectionId: 3, taId: 20),
    CollegeCourseSection(id: 38, courseId: 4, departmentSectionId: 4, taId: 20),
    CollegeCourseSection(id: 39, courseId: 4, departmentSectionId: 5, taId: 20),
    CollegeCourseSection(id: 40, courseId: 4, departmentSectionId: 6, taId: 20),
    CollegeCourseSection(id: 41, courseId: 4, departmentSectionId: 7, taId: 20),
    CollegeCourseSection(id: 42, courseId: 4, departmentSectionId: 8, taId: 16),
    CollegeCourseSection(id: 43, courseId: 4, departmentSectionId: 14, taId: 16),
    CollegeCourseSection(id: 44, courseId: 4, departmentSectionId: 15, taId: 16),
    CollegeCourseSection(id: 45, courseId: 4, departmentSectionId: 16, taId: 16),
    CollegeCourseSection(id: 46, courseId: 4, departmentSectionId: 17, taId: 16),
    CollegeCourseSection(id: 47, courseId: 4, departmentSectionId: 18, taId: 20),
    CollegeCourseSection(id: 48, courseId: 5, departmentSectionId: 1, taId: 22),
    CollegeCourseSection(id: 49, courseId: 5, departmentSectionId: 2, taId: 22),
    CollegeCourseSection(id: 50, courseId: 5, departmentSectionId: 3, taId: 22),
    CollegeCourseSection(id: 51, courseId: 5, departmentSectionId: 4, taId: 22),
    CollegeCourseSection(id: 52, courseId: 5, departmentSectionId: 5, taId: 24),
    CollegeCourseSection(id: 53, courseId: 5, departmentSectionId: 6, taId: 22),
    CollegeCourseSection(id: 54, courseId: 5, departmentSectionId: 7, taId: 22),
    CollegeCourseSection(id: 55, courseId: 5, departmentSectionId: 8, taId: 22),
    CollegeCourseSection(id: 56, courseId: 6, departmentSectionId: 1, taId: 21),
    CollegeCourseSection(id: 57, courseId: 6, departmentSectionId: 2, taId: 21),
    CollegeCourseSection(id: 58, courseId: 6, departmentSectionId: 3, taId: 21),
    CollegeCourseSection(id: 59, courseId: 6, departmentSectionId: 4, taId: 21),
    CollegeCourseSection(id: 60, courseId: 6, departmentSectionId: 5, taId: 21),
    CollegeCourseSection(id: 61, courseId: 6, departmentSectionId: 6, taId: 21),
    CollegeCourseSection(id: 62, courseId: 6, departmentSectionId: 7, taId: 21),
    CollegeCourseSection(id: 63, courseId: 6, departmentSectionId: 8, taId: 21),
    CollegeCourseSection(id: 64, courseId: 6, departmentSectionId: 14, taId: 11),
    CollegeCourseSection(id: 65, courseId: 6, departmentSectionId: 15, taId: 11),
    CollegeCourseSection(id: 66, courseId: 6, departmentSectionId: 16, taId: 11),
    CollegeCourseSection(id: 67, courseId: 6, departmentSectionId: 17, taId: 11),
    CollegeCourseSection(id: 68, courseId: 6, departmentSectionId: 18, taId: 11),
    CollegeCourseSection(id: 69, courseId: 7, departmentSectionId: 9, taId: 24),
    CollegeCourseSection(id: 70, courseId: 7, departmentSectionId: 10, taId: 24),
    CollegeCourseSection(id: 71, courseId: 7, departmentSectionId: 11, taId: 24),
    CollegeCourseSection(id: 72, courseId: 7, departmentSectionId: 12, taId: 24),
    CollegeCourseSection(id: 73, courseId: 7, departmentSectionId: 13, taId: 24),
    CollegeCourseSection(id: 74, courseId: 8, departmentSectionId: 9, taId: 27),
    CollegeCourseSection(id: 75, courseId: 8, departmentSectionId: 10, taId: 27),
    CollegeCourseSection(id: 76, courseId: 8, departmentSectionId: 11, taId: 27),
    CollegeCourseSection(id: 77, courseId: 8, departmentSectionId: 12, taId: 27),
    CollegeCourseSection(id: 78, courseId: 8, departmentSectionId: 13, taId: 27),
    CollegeCourseSection(id: 79, courseId: 9, departmentSectionId: 9, taId: 28),
    CollegeCourseSection(id: 80, courseId: 9, departmentSectionId: 10, taId: 28),
    CollegeCourseSection(id: 81, courseId: 9, departmentSectionId: 11, taId: 28),
    CollegeCourseSection(id: 82, courseId: 9, departmentSectionId: 12, taId: 28),
    CollegeCourseSection(id: 83, courseId: 9, departmentSectionId: 13, taId: 28),
    CollegeCourseSection(id: 84, courseId: 10, departmentSectionId: 9, taId: 16),
    CollegeCourseSection(id: 85, courseId: 10, departmentSectionId: 10, taId: 16),
    CollegeCourseSection(id: 86, courseId: 10, departmentSectionId: 11, taId: 16),
    CollegeCourseSection(id: 87, courseId: 10, departmentSectionId: 12, taId: 15),
    CollegeCourseSection(id: 88, courseId: 10, departmentSectionId: 13, taId: 15),
    CollegeCourseSection(id: 89, courseId: 11, departmentSectionId: 9, taId: 30),
    CollegeCourseSection(id: 90, courseId: 11, departmentSectionId: 10, taId: 29),
    CollegeCourseSection(id: 91, courseId: 11, departmentSectionId: 11, taId: 30),
    CollegeCourseSection(id: 92, courseId: 11, departmentSectionId: 12, taId: 30),
    CollegeCourseSection(id: 93, courseId: 11, departmentSectionId: 13, taId: 29),
    CollegeCourseSection(id: 94, courseId: 11, departmentSectionId: 14, taId: 30),
    CollegeCourseSection(id: 95, courseId: 11, departmentSectionId: 15, taId: 30),
    CollegeCourseSection(id: 96, courseId: 11, departmentSectionId: 16, taId: 30),
    CollegeCourseSection(id: 97, courseId: 11, departmentSectionId: 17, taId: 30),
    CollegeCourseSection(id: 98, courseId: 11, departmentSectionId: 18, taId: 30),
    CollegeCourseSection(id: 99, courseId: 12, departmentSectionId: 14, taId: 10),
    CollegeCourseSection(id: 100, courseId: 12, departmentSectionId: 15, taId: 10),
    CollegeCourseSection(id: 101, courseId: 12, departmentSectionId: 16, taId: 10),
    CollegeCourseSection(id: 102, courseId: 12, departmentSectionId: 17, taId: 10),
    CollegeCourseSection(id: 103, courseId: 12, departmentSectionId: 18, taId: 10),
    CollegeCourseSection(id: 104, courseId: 13, departmentSectionId: 14, taId: 12),
    CollegeCourseSection(id: 105, courseId: 13, departmentSectionId: 15, taId: 12),
    CollegeCourseSection(id: 106, courseId: 13, departmentSectionId: 16, taId: 12),
    CollegeCourseSection(id: 107, courseId: 13, departmentSectionId: 17, taId: 12),
    CollegeCourseSection(id: 108, courseId: 13, departmentSectionId: 18, taId: 12),
  ];

  static const students = <CollegeStudent>[
    CollegeStudent(id: 1, universityId: '20720236001', fullName: 'ابرام روماني جرجس عطا الله', userName: 'abram_7699', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 2, universityId: '20720236002', fullName: 'احمد ابراهيم رشدى', userName: 'ahmd_7517', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 3, universityId: '20720236003', fullName: 'احمد امير احمد جمعة', userName: 'ahmd_4657', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 4, universityId: '20720236005', fullName: 'احمد حاتم محمد السيد', userName: 'ahmd_8171', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 5, universityId: '20720236006', fullName: 'احمد خيري احمد سيد', userName: 'ahmd_8027', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 6, universityId: '20720236007', fullName: 'احمد عبد العليم سيد احمد', userName: 'ahmd_1478', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 7, universityId: '20720236008', fullName: 'احمد علاء الدين مصطفى خليفه', userName: 'ahmd_3276', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 8, universityId: '20720236009', fullName: 'احمد علي محمد علي', userName: 'ahmd_3932', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 9, universityId: '20720236010', fullName: 'احمد مبروك عبدالفتاح مبروك', userName: 'ahmd_6492', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 10, universityId: '20720236011', fullName: 'احمد محمد عبد المعتمد محمد', userName: 'ahmd_4286', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 11, universityId: '20720236013', fullName: 'احمد ناصر عبد العال احمد', userName: 'ahmd_1074', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 12, universityId: '20720236014', fullName: 'ادهم محمد احمد جلال', userName: 'adhm_4082', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 13, universityId: '20720236015', fullName: 'اروى ابراهيم احمد مصطفى', userName: 'arwy_1551', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 14, universityId: '20720236016', fullName: 'اروى عبد السلام عثمان بكر', userName: 'arwy_6963', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 15, universityId: '20720236017', fullName: 'اريج حمدان رشدى', userName: 'aryg_6495', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 16, universityId: '20720236018', fullName: 'اسراء محمد شحاته على', userName: 'asra_4005', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 17, universityId: '20720236019', fullName: 'اسراء محمد عبدالرحيم محمد', userName: 'asra_7438', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 18, universityId: '20720236020', fullName: 'اسراء محمود محمد صالح', userName: 'asra_8563', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 19, universityId: '20720236021', fullName: 'اسلام ايمن احمد توفيق', userName: 'aslam_3216', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 20, universityId: '20720236022', fullName: 'اسلام هشام سيد شاكر', userName: 'aslam_9448', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 21, universityId: '20720236024', fullName: 'الاء بدرى على', userName: 'ala_2692', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 22, universityId: '20720236025', fullName: 'الاء ممدوح سالمان عبدالمنعم', userName: 'ala_9702', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 23, universityId: '20720236026', fullName: 'البراء عبدالرحمن محمود احمد', userName: 'albra_7550', level: 3, departmentId: 1, departmentSectionId: 1),
    CollegeStudent(id: 24, universityId: '20720236027', fullName: 'الحسينى عبد الحميد مغربى', userName: 'alhsyny_8186', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 25, universityId: '20720236028', fullName: 'امانى صالحين سيد', userName: 'amany_2508', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 26, universityId: '20720236029', fullName: 'امير محمد حسن ابراهيم', userName: 'amyr_5979', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 27, universityId: '20720236030', fullName: 'ان اكرم صليب', userName: 'an_1404', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 28, universityId: '20720236031', fullName: 'اندراوس فرج صابر', userName: 'andraws_2102', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 29, universityId: '20720236032', fullName: 'انس عزام فاروق احمد', userName: 'ans_6708', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 30, universityId: '20720236202', fullName: 'ايمان تامر السيد محمد', userName: 'ayman_4634', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 31, universityId: '20720236033', fullName: 'ايريني القمص هدرا وهيب', userName: 'ayryny_3812', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 32, universityId: '20720236034', fullName: 'ايلاريه يعقوب لويس بولس', userName: 'aylaryh_7390', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 33, universityId: '20720236035', fullName: 'ايه حماده احمد', userName: 'ayh_4813', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 34, universityId: '20720236037', fullName: 'ايه محمد حسين', userName: 'ayh_4954', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 35, universityId: '20720236038', fullName: 'بيمن باسم بطرس', userName: 'bymn_6311', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 36, universityId: '20720236039', fullName: 'تامر  ياسر عبد العزيز على', userName: 'tamr_5169', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 37, universityId: '20720236040', fullName: 'تسنيم محمد صبره', userName: 'tsnym_2285', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 38, universityId: '20720236041', fullName: 'توماس نادى شوقى', userName: 'twmas_9494', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 39, universityId: '20720236042', fullName: 'جاسمين محمود مصطفى', userName: 'gasmyn_1690', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 40, universityId: '20720236043', fullName: 'جعفر على محمد', userName: 'gafr_1789', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 41, universityId: '20720236044', fullName: 'جمانة حسين عبدالعزيز حسين', userName: 'gmana_2008', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 42, universityId: '20720236045', fullName: 'جوليا اسامه عزيز', userName: 'gwlya_1323', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 43, universityId: '20720236046', fullName: 'حازم قاسم محمود', userName: 'hazm_6615', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 44, universityId: '20720236047', fullName: 'حبيبة محمود عبد الحميد', userName: 'hbyba_2996', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 45, universityId: '20720236049', fullName: 'خالد ممدوح شعبان امين', userName: 'khald_4842', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 46, universityId: '20720236050', fullName: 'دان محمد عبد اللطيف احمد', userName: 'dan_3148', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 47, universityId: '20720236051', fullName: 'رحمه نصر الدين محمد', userName: 'rhmh_5080', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 48, universityId: '20720236052', fullName: 'رناد عبدالباسط مهني ابراهيم', userName: 'rnad_4941', level: 3, departmentId: 1, departmentSectionId: 2),
    CollegeStudent(id: 49, universityId: '20720236053', fullName: 'ريهام احمد حسين', userName: 'ryham_2873', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 50, universityId: '20720236054', fullName: 'زلفى محمد محمود', userName: 'zlfy_1415', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 51, universityId: '20720236055', fullName: 'زياد احمد يوسف حسين', userName: 'zyad_4161', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 52, universityId: '20720236056', fullName: 'زياد خالد عيد فرغلى', userName: 'zyad_7772', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 53, universityId: '20720236057', fullName: 'زياد عادل عبدالفتاح', userName: 'zyad_2110', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 54, universityId: '20720236058', fullName: 'زياد علاء نجاتي عبدالرشيد', userName: 'zyad_7185', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 55, universityId: '20720236059', fullName: 'زياد محمد مراد رياض', userName: 'zyad_3867', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 56, universityId: '20720236060', fullName: 'زياد وليد محمد عبدالحي', userName: 'zyad_5471', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 57, universityId: '20720236061', fullName: 'زينب محمد عبد التواب عبد الرحيم', userName: 'zynb_8743', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 58, universityId: '20720236062', fullName: 'ساندرا سامى صدقى', userName: 'sandra_9225', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 59, universityId: '20720236063', fullName: 'سلمى محمد عبدالفتاح عبدالرحيم', userName: 'slmy_6920', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 60, universityId: '20720236064', fullName: 'سليمان على السيد على', userName: 'slyman_7469', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 61, universityId: '20720236065', fullName: 'سندس عمر حسين', userName: 'snds_3322', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 62, universityId: '20720236066', fullName: 'سها ناجح محمد البارودى', userName: 'sha_9914', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 63, universityId: '20720236067', fullName: 'سهيله قرشي عبدالمنعم زين', userName: 'shylh_9917', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 64, universityId: '20720236068', fullName: 'سيف علاء محمود احمد', userName: 'syf_5779', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 65, universityId: '20720236069', fullName: 'شنودة رزق رمزي زاخر', userName: 'shnwda_6730', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 66, universityId: '20720236070', fullName: 'شهد محمد محمود محمد', userName: 'shhd_3783', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 67, universityId: '20720236071', fullName: 'شهد وليد مصطفى حسن', userName: 'shhd_4203', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 68, universityId: '20720236072', fullName: 'شهد يحى محمد ملاحظ', userName: 'shhd_5963', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 69, universityId: '20720236073', fullName: 'صهيب محمود عبد الحميد', userName: 'shyb_3762', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 70, universityId: '20720236074', fullName: 'ضياء محمد حسن محمد', userName: 'dya_8728', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 71, universityId: '20720236075', fullName: 'طارق عمر سيد', userName: 'tarq_6172', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 72, universityId: '20720236076', fullName: 'طه محمود محمد', userName: 'th_7055', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 73, universityId: '20720236077', fullName: 'عبد الباسط رزق عبد الباسط', userName: 'abd_5676', level: 3, departmentId: 1, departmentSectionId: 3),
    CollegeStudent(id: 74, universityId: '20720236078', fullName: 'عبد الحليم ابراهيم فرغلى', userName: 'abd_7051', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 75, universityId: '20720236079', fullName: 'عبد الرحمن احمد محمد عبد الرحمن', userName: 'abd_7590', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 76, universityId: '20720236080', fullName: 'عبد الرحمن اشرف شعبان', userName: 'abd_7192', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 77, universityId: '20720236081', fullName: 'عبد الرحمن امين حسن', userName: 'abd_1578', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 78, universityId: '20720236082', fullName: 'عبد الرحمن جمال احمد رمضان', userName: 'abd_4156', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 79, universityId: '20720236083', fullName: 'عبد الرحمن عوض عبد الجابر', userName: 'abd_9951', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 80, universityId: '20720236084', fullName: 'عبد الرحمن محمد عوض', userName: 'abd_4441', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 81, universityId: '20720236085', fullName: 'عبد الله محمد شحاته', userName: 'abd_4704', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 82, universityId: '20720236086', fullName: 'عبد الله محمود يحيى عبد الصادق', userName: 'abd_8745', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 83, universityId: '20720236087', fullName: 'عبد الله نبيل طه', userName: 'abd_4735', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 84, universityId: '20720236088', fullName: 'عبدالرحمن جمال عطا', userName: 'abdalrhmn_6574', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 85, universityId: '20720236089', fullName: 'عبدالله احمد رضا نورالدين', userName: 'abdallh_7270', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 86, universityId: '20720236090', fullName: 'عبير عصمت عبد السلام', userName: 'abyr_8323', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 87, universityId: '20720236091', fullName: 'علاء جمعة العسيوي محمد', userName: 'ala_2501', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 88, universityId: '20720236092', fullName: 'على عاطف محمود', userName: 'aly_4372', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 89, universityId: '20720236093', fullName: 'على عبد العال ابراهيم محمد', userName: 'aly_5635', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 90, universityId: '20720236094', fullName: 'على مصطفى هود', userName: 'aly_1380', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 91, universityId: '20720236095', fullName: 'عماد الدين احمد شعلان عبدالعزيز', userName: 'amad_6279', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 92, universityId: '20720236096', fullName: 'عمر حربى رشاد', userName: 'amr_3274', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 93, universityId: '20720236097', fullName: 'عمر صابر سيد', userName: 'amr_6402', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 94, universityId: '20720236098', fullName: 'عمر عماد الدين عبد الله', userName: 'amr_7720', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 95, universityId: '20720236099', fullName: 'عمرو على عبد الراضى', userName: 'amrw_1227', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 96, universityId: '20720236100', fullName: 'عمرو مصطفى محمد عبدالعال', userName: 'amrw_6583', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 97, universityId: '20720236101', fullName: 'فاطمة عبدالواحد عبدة احمد', userName: 'fatma_7243', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 98, universityId: '20720236102', fullName: 'فاطمة محروص محمد امين', userName: 'fatma_9976', level: 3, departmentId: 1, departmentSectionId: 4),
    CollegeStudent(id: 99, universityId: '20720236103', fullName: 'فاطمه احمد مختار', userName: 'fatmh_5941', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 100, universityId: '20720236104', fullName: 'فتحى ابو الحسن فتحى', userName: 'fthy_9451', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 101, universityId: '20720236106', fullName: 'فهمي هاشم محمد فهمي', userName: 'fhmy_4766', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 102, universityId: '20720236107', fullName: 'كارين سامح طلعت', userName: 'karyn_8674', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 103, universityId: '20720236108', fullName: 'كريم احمد سليمان كوسى', userName: 'krym_8796', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 104, universityId: '20720236109', fullName: 'كريم سيد عيد', userName: 'krym_9163', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 105, universityId: '20720236110', fullName: 'كمال على سليمان', userName: 'kmal_5042', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 106, universityId: '20720236111', fullName: 'كيرلس ابراهيم صبحى', userName: 'kyrls_4366', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 107, universityId: '20720236112', fullName: 'كيرلس ايمن فرويز', userName: 'kyrls_5748', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 108, universityId: '20720236113', fullName: 'كيرلس رجائى يوسف', userName: 'kyrls_4610', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 109, universityId: '20720236114', fullName: 'كيرلس ناجح ثابت', userName: 'kyrls_9789', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 110, universityId: '20720236115', fullName: 'مادونا جمال كرم نسيم', userName: 'madwna_6570', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 111, universityId: '20720236176', fullName: 'مى حامد خلف حسان', userName: 'my_4915', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 112, universityId: '20720236116', fullName: 'ماركو موريس موسى', userName: 'markw_7325', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 113, universityId: '20720236117', fullName: 'ماريا اشرف حليم', userName: 'marya_1904', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 114, universityId: '20720236119', fullName: 'مايا احمد سيد محمد', userName: 'maya_8430', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 115, universityId: '20720236120', fullName: 'مايكل رومانى عاطف', userName: 'maykl_8140', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 116, universityId: '20720236121', fullName: 'محروص داود محروص جاد السيد', userName: 'mhrws_5053', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 117, universityId: '20720236122', fullName: 'محمد ابراهيم حلمي ابراهيم', userName: 'mhmd_7702', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 118, universityId: '20720236123', fullName: 'محمد ابراهيم شفيق', userName: 'mhmd_3699', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 119, universityId: '20720236124', fullName: 'محمد ابراهيم محفوظ محمد', userName: 'mhmd_4609', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 120, universityId: '20720236125', fullName: 'محمد اسامه محمد عبد الهادى', userName: 'mhmd_5660', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 121, universityId: '20720236126', fullName: 'محمد اسامه نبيه', userName: 'mhmd_2580', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 122, universityId: '20720236127', fullName: 'محمد اشرف احمد فرغلى', userName: 'mhmd_7678', level: 3, departmentId: 1, departmentSectionId: 5),
    CollegeStudent(id: 123, universityId: '20720236128', fullName: 'محمد اشرف ماهر احمد', userName: 'mhmd_5331', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 124, universityId: '20720236129', fullName: 'محمد اكرامى محمد', userName: 'mhmd_8521', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 125, universityId: '20720236130', fullName: 'محمد المعتز بالله محمد الصادق', userName: 'mhmd_3763', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 126, universityId: '20720236131', fullName: 'محمد ايمن محمد حسن', userName: 'mhmd_3993', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 127, universityId: '20720236132', fullName: 'محمد حسان على', userName: 'mhmd_9080', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 128, universityId: '20720236133', fullName: 'محمد شعبان عبد المجيد', userName: 'mhmd_5830', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 129, universityId: '20720236135', fullName: 'محمد عبد السلام عبد النعيم', userName: 'mhmd_6233', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 130, universityId: '20720236136', fullName: 'محمد عبد الله عبد الباقى', userName: 'mhmd_8025', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 131, universityId: '20720236137', fullName: 'محمد علاء الدين اكرام', userName: 'mhmd_2541', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 132, universityId: '20720236138', fullName: 'محمد على مرعى على', userName: 'mhmd_4494', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 133, universityId: '20720236139', fullName: 'محمد عماد حمدى محمد', userName: 'mhmd_5285', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 134, universityId: '20720236140', fullName: 'محمد فوزى سعد ثابت', userName: 'mhmd_1576', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 135, universityId: '20720236141', fullName: 'محمد ماهر احمد ماهر', userName: 'mhmd_7845', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 136, universityId: '20720236142', fullName: 'محمد محمد عبد الرحيم', userName: 'mhmd_3180', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 137, universityId: '20720236143', fullName: 'محمد مصطفى ثابت احمد', userName: 'mhmd_8961', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 138, universityId: '20720236144', fullName: 'محمد مصطفى سمير', userName: 'mhmd_5573', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 139, universityId: '20720236145', fullName: 'محمد ممدوح رمضان سالم', userName: 'mhmd_2626', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 140, universityId: '20720236146', fullName: 'محمد ممدوح سيد', userName: 'mhmd_2939', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 141, universityId: '20720236147', fullName: 'محمد موفق مصطفى محمود', userName: 'mhmd_8563', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 142, universityId: '20720236148', fullName: 'محمد هانى عوض', userName: 'mhmd_4457', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 143, universityId: '20720236149', fullName: 'محمد هريدي عبدالحميد هريدي', userName: 'mhmd_7113', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 144, universityId: '20720236150', fullName: 'محمد ياسر جابر', userName: 'mhmd_7943', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 145, universityId: '20720236151', fullName: 'محمد ياسر مختار', userName: 'mhmd_2046', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 146, universityId: '20720236152', fullName: 'محمد يحيى صلاح', userName: 'mhmd_4294', level: 3, departmentId: 1, departmentSectionId: 6),
    CollegeStudent(id: 147, universityId: '20720236201', fullName: 'احمد اشرف محمد كمال', userName: 'ahmd_2421', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 148, universityId: '20720236153', fullName: 'محمود سيد محمد عبدالغفار', userName: 'mhmwd_9681', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 149, universityId: '20720236154', fullName: 'محمود صلاح الفالح محمد', userName: 'mhmwd_2258', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 150, universityId: '20720236155', fullName: 'محمود علي خزيم فرعل', userName: 'mhmwd_8405', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 151, universityId: '20720236156', fullName: 'محمود محمد رشاد محمود', userName: 'mhmwd_3413', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 152, universityId: '20720236157', fullName: 'مروان احمد عرابى محمد', userName: 'mrwan_4951', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 153, universityId: '20720236158', fullName: 'مروان خالد عبد الفتاح', userName: 'mrwan_5098', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 154, universityId: '20720236159', fullName: 'مروان مصطفى رفعت', userName: 'mrwan_9682', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 155, universityId: '20720236160', fullName: 'مريم عادل عبد العال', userName: 'mrym_6771', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 156, universityId: '20720236161', fullName: 'مريم محمد سيد محمد', userName: 'mrym_2170', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 157, universityId: '20720236162', fullName: 'مصطفى ابواليسر عبدالشكور', userName: 'mstfy_6476', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 158, universityId: '20720236163', fullName: 'مصطفى حمدي عبدالرحمن', userName: 'mstfy_9067', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 159, universityId: '20720236164', fullName: 'مصطفى خالد فخرى', userName: 'mstfy_2741', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 160, universityId: '20720236165', fullName: 'مصطفى راضى السيد', userName: 'mstfy_8125', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 161, universityId: '20720236166', fullName: 'مصطفى محمد محمود', userName: 'mstfy_9384', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 162, universityId: '20720236167', fullName: 'معاذ رضا سعد احمد', userName: 'maaz_1746', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 163, universityId: '20720236168', fullName: 'معاذ مروان منصور محمود', userName: 'maaz_2768', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 164, universityId: '20720236169', fullName: 'معتز انور سليمان على', userName: 'matz_9566', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 165, universityId: '20720236170', fullName: 'ملك زكريا عبود', userName: 'mlk_2820', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 166, universityId: '20720236172', fullName: 'مها احمد محمد', userName: 'mha_6829', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 167, universityId: '20720236173', fullName: 'مونيكا ميخائيل غبريال', userName: 'mwnyka_7982', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 168, universityId: '20720236174', fullName: 'مؤمن عثمان عبد الحفيظ', userName: 'mؤmn_9609', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 169, universityId: '20720236175', fullName: 'مى ابراهيم عبد المحسن', userName: 'my_9084', level: 3, departmentId: 1, departmentSectionId: 7),
    CollegeStudent(id: 170, universityId: '20720236177', fullName: 'مى محمد سعد عبد المالك', userName: 'my_4338', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 171, universityId: '20720236178', fullName: 'ميار ياسر عباس سليم', userName: 'myar_3177', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 172, universityId: '20720236179', fullName: 'ميرولا افرايم مريس', userName: 'myrwla_5620', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 173, universityId: '20720236180', fullName: 'ميلاد عاطف فهيم', userName: 'mylad_5095', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 174, universityId: '20720236181', fullName: 'مينا عماد بركه', userName: 'myna_4035', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 175, universityId: '20720236182', fullName: 'ندى محمد انور', userName: 'ndy_8735', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 176, universityId: '20720236183', fullName: 'ندى هلال عبد الشافى', userName: 'ndy_1111', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 177, universityId: '20720236184', fullName: 'نور الدين صلاح خلف قرشي', userName: 'nwr_6842', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 178, universityId: '20720236185', fullName: 'نورا عاطف عطيه', userName: 'nwra_8642', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 179, universityId: '20720236186', fullName: 'نوران محمود جمال محمود', userName: 'nwran_9476', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 180, universityId: '20720236187', fullName: 'هاجر سعد حفظى خضر', userName: 'hagr_6472', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 181, universityId: '20720236188', fullName: 'يارا احمد عماد الدين', userName: 'yara_3683', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 182, universityId: '20720236190', fullName: 'ياسمين عادل علي عبدالرحيم', userName: 'yasmyn_1158', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 183, universityId: '20720236191', fullName: 'ياسين خالد محمد', userName: 'yasyn_7043', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 184, universityId: '20720236192', fullName: 'يحيى عبد الباسط احمد', userName: 'yhyy_8832', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 185, universityId: '20720236193', fullName: 'يوستينا عصمت صلاح حليم', userName: 'ywstyna_6418', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 186, universityId: '20720236194', fullName: 'يوسف احمد سعد', userName: 'ywsf_3158', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 187, universityId: '20720236195', fullName: 'يوسف بغدادى مطاوع', userName: 'ywsf_3811', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 188, universityId: '20720236196', fullName: 'يوسف جورج يوسف', userName: 'ywsf_8489', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 189, universityId: '20720236197', fullName: 'يوسف زكريا الهم', userName: 'ywsf_8680', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 190, universityId: '20720236198', fullName: 'يوسف على رمضان', userName: 'ywsf_3677', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 191, universityId: '20720236199', fullName: 'يوسف محمد صلاح', userName: 'ywsf_3682', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 192, universityId: '20720236203', fullName: 'عبد الرحمن محمود حسين محمود', userName: 'abd_9410', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 193, universityId: '20720236204', fullName: 'يوسف مصطفى محمد ابراهيم', userName: 'ywsf_6012', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 194, universityId: '20720236205', fullName: 'ابراهيم وائل ابراهيم محمود', userName: 'abrahym_6701', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 195, universityId: '20720239219', fullName: 'يوسف ممدوح عبد النبى', userName: 'ywsf_5359', level: 3, departmentId: 1, departmentSectionId: 8),
    CollegeStudent(id: 196, universityId: '20720238001', fullName: 'ابتسام احمد على عبد العزيز', userName: 'abtsam_5099', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 197, universityId: '20720238002', fullName: 'ابراهيم على محمد محمد', userName: 'abrahym_1664', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 198, universityId: '20720238003', fullName: 'ابراهيم وائل ابراهيم محمود', userName: 'abrahym_3730', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 199, universityId: '20720238004', fullName: 'احمد ابراهيم ادم ابراهيم', userName: 'ahmd_2625', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 200, universityId: '20720238007', fullName: 'احمد شرين نيازى نعمان', userName: 'ahmd_1407', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 201, universityId: '20720238008', fullName: 'احمد ماهر على ياسين', userName: 'ahmd_3564', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 202, universityId: '20720238009', fullName: 'احمد محمد احمد السيد', userName: 'ahmd_3785', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 203, universityId: '20720238010', fullName: 'احمد محمد احمد محمد عيسى', userName: 'ahmd_5398', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 204, universityId: '20720238011', fullName: 'احمد محمد السيد حرب', userName: 'ahmd_7249', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 205, universityId: '20720238012', fullName: 'احمد محمود شداد عبد الغنى', userName: 'ahmd_2756', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 206, universityId: '20720238013', fullName: 'احمد مؤنس كمال محمد', userName: 'ahmd_4890', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 207, universityId: '20720238014', fullName: 'احمد وردانى يسين هلالى', userName: 'ahmd_9284', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 208, universityId: '20720238015', fullName: 'اسراء احمد حسان عبد النعيم', userName: 'asra_6213', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 209, universityId: '20720238016', fullName: 'اسماء سمير محمد عبد العزيز', userName: 'asma_9282', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 210, universityId: '20720238017', fullName: 'الاء عطا صبره عبد الغني', userName: 'ala_9273', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 211, universityId: '20720238018', fullName: 'الاء محمد على محمد', userName: 'ala_8308', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 212, universityId: '20720238019', fullName: 'الاء محمد هانى احمد', userName: 'ala_6036', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 213, universityId: '20720238020', fullName: 'امانى عطيه محمد عبد الراضى', userName: 'amany_1880', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 214, universityId: '20720238021', fullName: 'انس مصطفى عبد الخالق راغب', userName: 'ans_8091', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 215, universityId: '20720238022', fullName: 'انطونيوس ماجد فهمى مسعد', userName: 'antwnyws_8508', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 216, universityId: '20720238023', fullName: 'انور ايمن انور محمد', userName: 'anwr_2071', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 217, universityId: '20720238024', fullName: 'انور سارى لوندى مجلى', userName: 'anwr_4369', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 218, universityId: '20720238025', fullName: 'ايلاريا باهى وليم ابسخرون', userName: 'aylarya_4206', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 219, universityId: '20720238026', fullName: 'بافلى ناصر مليد زكى', userName: 'bafly_5184', level: 3, departmentId: 2, departmentSectionId: 9),
    CollegeStudent(id: 220, universityId: '20720238027', fullName: 'بسنت حسن السيد عبد الرحيم', userName: 'bsnt_2875', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 221, universityId: '20720238028', fullName: 'بلال مدحت عبد العليم احمد', userName: 'blal_3887', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 222, universityId: '20720238029', fullName: 'بيشوى الهامى نصحى حسيب', userName: 'byshwy_3864', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 223, universityId: '20720238030', fullName: 'جرجس ماجد عازر عطاالله', userName: 'grgs_7964', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 224, universityId: '20720238031', fullName: 'حازم عمر عبد الناصر يوسف', userName: 'hazm_9696', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 225, universityId: '20720238032', fullName: 'حسن محمد حسن ابراهيم', userName: 'hsn_7233', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 226, universityId: '20720238033', fullName: 'حماد بخيت عبد اللاه جاد', userName: 'hmad_5616', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 227, universityId: '20720238034', fullName: 'خالد محمد عيد سيد', userName: 'khald_5979', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 228, universityId: '20720238035', fullName: 'خلود خالد احمد عبد العال', userName: 'khlwd_9399', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 229, universityId: '20720238036', fullName: 'رحمه مجدى عبد الطيف هارون', userName: 'rhmh_8540', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 230, universityId: '20720238037', fullName: 'روان خالد يوسف احمد', userName: 'rwan_4900', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 231, universityId: '20720238038', fullName: 'روان عمرو محمد عبد الحميد', userName: 'rwan_4562', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 232, universityId: '20720238039', fullName: 'روضه عمرو خالد فهمي', userName: 'rwdh_5260', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 233, universityId: '20720238040', fullName: 'روماريو جوزيف لويس رياض', userName: 'rwmaryw_9329', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 234, universityId: '20720238041', fullName: 'زياد ابراهيم عبد الحميد درغام', userName: 'zyad_1564', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 235, universityId: '20720238042', fullName: 'زياد السيد محمد السيد', userName: 'zyad_7670', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 236, universityId: '20720238043', fullName: 'زياد صلاح عبد الرحمن شعراوى', userName: 'zyad_2979', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 237, universityId: '20720238044', fullName: 'زياد عاطف يحيى حسين', userName: 'zyad_7716', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 238, universityId: '20720238045', fullName: 'زياد عبد الحميد حسن رستم', userName: 'zyad_5693', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 239, universityId: '20720238046', fullName: 'ساره مصطفى شوقى عبد الحكيم', userName: 'sarh_4310', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 240, universityId: '20720238047', fullName: 'سعد محمد سعد هارون', userName: 'sad_5177', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 241, universityId: '20720238048', fullName: 'سلمى رمضان على محمود', userName: 'slmy_3865', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 242, universityId: '20720238049', fullName: 'سما احمد كامل شكرى', userName: 'sma_9039', level: 3, departmentId: 2, departmentSectionId: 10),
    CollegeStudent(id: 243, universityId: '20720238050', fullName: 'سندس السيد عبد الفتاح', userName: 'snds_1055', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 244, universityId: '20720238051', fullName: 'سيف الدين احمد عبد العظيم مصطفى', userName: 'syf_3185', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 245, universityId: '20720238052', fullName: 'سيف الدين احمد كامل احمد', userName: 'syf_7399', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 246, universityId: '20720238053', fullName: 'شيرى عادل رياض توفيق', userName: 'shyry_8315', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 247, universityId: '20720238054', fullName: 'عائشه اسامه محمد', userName: 'aaئshh_7762', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 248, universityId: '20720238055', fullName: 'عبد الحكيم محمد عبد الحميد', userName: 'abd_8053', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 249, universityId: '20720238056', fullName: 'عبد الرحمن على عبد الرحمن', userName: 'abd_5285', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 250, universityId: '20720238057', fullName: 'عبد الرحمن قدرى الزراعى', userName: 'abd_2151', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 251, universityId: '20720238058', fullName: 'عبد الرحمن محمد احمد', userName: 'abd_2338', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 252, universityId: '20720238059', fullName: 'عبد الرحمن محمد سيد', userName: 'abd_6833', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 253, universityId: '20720238060', fullName: 'عبد الرحمن مصطفى محمد', userName: 'abd_2174', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 254, universityId: '20720238061', fullName: 'عبد الله محمود بدر', userName: 'abd_5904', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 255, universityId: '20720238062', fullName: 'علا بهاء الدين احمد', userName: 'ala_3784', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 256, universityId: '20720238063', fullName: 'على شحات عباس', userName: 'aly_4033', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 257, universityId: '20720238064', fullName: 'على عبد الفتاح مغامس خالد', userName: 'aly_6604', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 258, universityId: '20720238065', fullName: 'عمر عبد الناصر عبد القادر محمد', userName: 'amr_3891', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 259, universityId: '20720238066', fullName: 'عمر محمود عبد الهادى', userName: 'amr_9696', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 260, universityId: '20720238067', fullName: 'عهد احمد محمد', userName: 'ahd_2584', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 261, universityId: '20720238068', fullName: 'فدوى محمد عبد العال', userName: 'fdwy_3797', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 262, universityId: '20720238069', fullName: 'فليوباتير شرين رفعت', userName: 'flywbatyr_7556', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 263, universityId: '20720238070', fullName: 'كارين ايمن شرقاوى', userName: 'karyn_7839', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 264, universityId: '20720238071', fullName: 'كارين مدحت زاهر', userName: 'karyn_9480', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 265, universityId: '20720238072', fullName: 'كريم عمر عبد البر', userName: 'krym_2408', level: 3, departmentId: 2, departmentSectionId: 11),
    CollegeStudent(id: 266, universityId: '20720238073', fullName: 'كيرلس اسامه ظريف', userName: 'kyrls_4856', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 267, universityId: '20720238074', fullName: 'كيرلس جمال وهيب', userName: 'kyrls_6558', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 268, universityId: '20720238075', fullName: 'كيرلس جمال جميل ميرهم', userName: 'kyrls_3048', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 269, universityId: '20720238076', fullName: 'كيرلس ماجد ماهر', userName: 'kyrls_5845', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 270, universityId: '20720238077', fullName: 'ماثيو هانى فايق مرجان', userName: 'mathyw_5770', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 271, universityId: '20720238078', fullName: 'مارجريت عاطف شوقى فانوس', userName: 'margryt_6119', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 272, universityId: '20720238079', fullName: 'ماريا نادر مكرم بنيامين', userName: 'marya_9288', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 273, universityId: '20720238080', fullName: 'مارينا وحيد وديد عوض', userName: 'maryna_9108', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 274, universityId: '20720238081', fullName: 'مازن جابر محمود  سعداوى', userName: 'mazn_6665', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 275, universityId: '20720238082', fullName: 'مازن ضياء الدين احمد عبد اللطيف', userName: 'mazn_3336', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 276, universityId: '20720238083', fullName: 'محمد احمد بكر صديق', userName: 'mhmd_4585', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 277, universityId: '20720238084', fullName: 'محمد بدوى محمود محمد', userName: 'mhmd_7756', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 278, universityId: '20720238086', fullName: 'محمد جمال فاروق راشد عبد الرحيم', userName: 'mhmd_7761', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 279, universityId: '20720238087', fullName: 'محمد خالد جاد فواز', userName: 'mhmd_6151', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 280, universityId: '20720238088', fullName: 'محمد رأفت حسين', userName: 'mhmd_6580', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 281, universityId: '20720238089', fullName: 'محمد ضياء الدين محمد عبد المجيد', userName: 'mhmd_7562', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 282, universityId: '20720238090', fullName: 'محمد طلعت محمد ابراهيم', userName: 'mhmd_7064', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 283, universityId: '20720238091', fullName: 'محمد عادل لبيب عبد المبدى', userName: 'mhmd_5250', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 284, universityId: '20720238093', fullName: 'محمد عصام الدين محمد  عبد الحفيظ', userName: 'mhmd_7151', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 285, universityId: '20720238094', fullName: 'محمد علاء الدين محمد فتحى', userName: 'mhmd_1456', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 286, universityId: '20720238095', fullName: 'محمد على ابو الفتوح  على', userName: 'mhmd_5054', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 287, universityId: '20720238096', fullName: 'محمد فرغلى عبد الفتاح احمد', userName: 'mhmd_5368', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 288, universityId: '20720238097', fullName: 'محمد ياسر حسنى محمد', userName: 'mhmd_6210', level: 3, departmentId: 2, departmentSectionId: 12),
    CollegeStudent(id: 289, universityId: '20720238098', fullName: 'محمد ياسر محمد محمد حمود', userName: 'mhmd_9001', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 290, universityId: '20720238099', fullName: 'محمود احمد عبد الحميد مصطفى', userName: 'mhmwd_2194', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 291, universityId: '20720238100', fullName: 'محمود رفعت بخيت احمد', userName: 'mhmwd_7473', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 292, universityId: '20720238101', fullName: 'محمود عز الدين محمود', userName: 'mhmwd_9844', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 293, universityId: '20720238102', fullName: 'محمود على يحى محمد', userName: 'mhmwd_6919', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 294, universityId: '20720238103', fullName: 'محمود محمد حسنين مصطفى', userName: 'mhmwd_1896', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 295, universityId: '20720238104', fullName: 'محمود محمد عبد الباقى حسن', userName: 'mhmwd_3883', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 296, universityId: '20720238105', fullName: 'مروان حسن احمد حسن', userName: 'mrwan_5661', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 297, universityId: '20720238106', fullName: 'مريم مجدى سعد سيدهم', userName: 'mrym_4601', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 298, universityId: '20720238107', fullName: 'مريم مدحت محمود احمد', userName: 'mrym_5742', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 299, universityId: '20720238108', fullName: 'مصطفى احمد طلعت احمد', userName: 'mstfy_5726', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 300, universityId: '20720238109', fullName: 'مصطفى ممدوح سيد صالح', userName: 'mstfy_1375', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 301, universityId: '20720238110', fullName: 'مها احمد محمود كامل', userName: 'mha_3304', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 302, universityId: '20720238111', fullName: 'مؤمن حسن سيد  اسماعيل', userName: 'mؤmn_6769', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 303, universityId: '20720238112', fullName: 'مينا ايمن سيف المسيح مجلع', userName: 'myna_5685', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 304, universityId: '20720238113', fullName: 'نوران السيد عادل حجاج', userName: 'nwran_7616', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 305, universityId: '20720238114', fullName: 'نورهان حسن على احمد عبد الله', userName: 'nwrhan_3110', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 306, universityId: '20720238115', fullName: 'ياسمين ناصر محمد جمال عبد الحافظ', userName: 'yasmyn_4682', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 307, universityId: '20720238116', fullName: 'ياسين احمد محمود احمد', userName: 'yasyn_5516', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 308, universityId: '20720238117', fullName: 'يحيى محمود فاروق', userName: 'yhyy_5039', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 309, universityId: '20720238118', fullName: 'يوسف اسامه انور عطا الله', userName: 'ywsf_7600', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 310, universityId: '20720238119', fullName: 'يوسف صفى الدين حسن احمد', userName: 'ywsf_6171', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 311, universityId: '20720238200', fullName: 'فبرونيا  القس سمعان فهميم', userName: 'fbrwnya_6115', level: 3, departmentId: 2, departmentSectionId: 13),
    CollegeStudent(id: 312, universityId: '2072023001', fullName: 'امال عبد الحميد زين العابدين محمد', userName: 'amal_4010', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 313, universityId: '2072023002', fullName: 'ابراهيم رأفت ابراهيم', userName: 'abrahym_1076', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 314, universityId: '2072023003', fullName: 'احمد  محمد ابو راشد عبد الغفار', userName: 'ahmd_8907', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 315, universityId: '2072023005', fullName: 'احمد ايمن احمد سيد', userName: 'ahmd_1447', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 316, universityId: '2072023006', fullName: 'احمد جمال حسنى حامد', userName: 'ahmd_3344', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 317, universityId: '2072023007', fullName: 'احمد جمال عرفه مصطفى', userName: 'ahmd_3343', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 318, universityId: '2072023008', fullName: 'احمد زيدان تاج بكر', userName: 'ahmd_4767', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 319, universityId: '2072023009', fullName: 'احمد سعد حموده حسن', userName: 'ahmd_6103', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 320, universityId: '2072023010', fullName: 'احمد محمد سعيد عمر', userName: 'ahmd_8602', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 321, universityId: '2072023011', fullName: 'احمد محمد مصطفى محمد', userName: 'ahmd_6204', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 322, universityId: '2072023012', fullName: 'احمد وجيه على احمد', userName: 'ahmd_3325', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 323, universityId: '2072023013', fullName: 'اسلام عادل جاد الرب', userName: 'aslam_2573', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 324, universityId: '2072023014', fullName: 'اسلام علاء الدين احمد محمد', userName: 'aslam_4368', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 325, universityId: '2072023015', fullName: 'الحسن محمد فراج', userName: 'alhsn_9423', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 326, universityId: '2072023016', fullName: 'امنه خالد محمد عبدالمجيد', userName: 'amnh_6540', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 327, universityId: '2072023017', fullName: 'امنيه عبد الرؤف احمد عبد الله', userName: 'amnyh_6973', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 328, universityId: '2072023018', fullName: 'امينه سعد سيد حسن', userName: 'amynh_9607', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 329, universityId: '2072023020', fullName: 'بسام عماد فوزى شحاته', userName: 'bsam_3110', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 330, universityId: '2072023021', fullName: 'بسمله عبد الحكيم فرغلى رميح', userName: 'bsmlh_6836', level: 3, departmentId: 3, departmentSectionId: 14),
    CollegeStudent(id: 331, universityId: '2072023022', fullName: 'بهجت زكريا بهجت مرقس', userName: 'bhgt_4545', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 332, universityId: '2072023023', fullName: 'بيشوى القس روفائيل كامل', userName: 'byshwy_7027', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 333, universityId: '2072023024', fullName: 'تادرس عادل وليم', userName: 'tadrs_6330', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 334, universityId: '2072023026', fullName: 'جورج مراد عدلى اسحق', userName: 'gwrg_7018', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 335, universityId: '2072023027', fullName: 'حازم حسن عبد النعيم احمد', userName: 'hazm_2898', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 336, universityId: '2072023028', fullName: 'حسين نزيه عبد النعيم', userName: 'hsyn_5919', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 337, universityId: '2072023029', fullName: 'خليل ياسر خليل احمد', userName: 'khlyl_8411', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 338, universityId: '2072023030', fullName: 'راشد عبد الرحمن ابراهيم طلبه', userName: 'rashd_6013', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 339, universityId: '2072023031', fullName: 'ريموندا رؤف مونير ونيس', userName: 'rymwnda_1162', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 340, universityId: '2072023032', fullName: 'زياد احمد حلمى سيد', userName: 'zyad_9347', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 341, universityId: '2072023033', fullName: 'زياد مصطفى محمد عبد الصبور', userName: 'zyad_6800', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 342, universityId: '2072023034', fullName: 'سلمى مصطفى ابو المعارف مدنى', userName: 'slmy_5709', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 343, universityId: '2072023035', fullName: 'سماح محمد ابراهيم احمد', userName: 'smah_5746', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 344, universityId: '2072023036', fullName: 'سيد جامع سيد حسين', userName: 'syd_8446', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 345, universityId: '2072023037', fullName: 'شروق سيد شاكر احمد', userName: 'shrwq_1896', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 346, universityId: '2072023038', fullName: 'شهد رمضان محمد حسن', userName: 'shhd_7562', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 347, universityId: '2072023039', fullName: 'شهد وليد محمود عبداللطيف', userName: 'shhd_4733', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 348, universityId: '2072023040', fullName: 'شيماء احمد محمود اسماعيل', userName: 'shyma_2544', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 349, universityId: '2072023041', fullName: 'ضحى محمد عثمان حسن', userName: 'dhy_5367', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 350, universityId: '2072023042', fullName: 'ضياء محمد فاروق عبد الحميد', userName: 'dya_5740', level: 3, departmentId: 3, departmentSectionId: 15),
    CollegeStudent(id: 351, universityId: '2072023044', fullName: 'عبد الرحمن ممدوح رياض حسن', userName: 'abd_3477', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 352, universityId: '2072023045', fullName: 'عبد الظاهر سامى عبد الظاهرالجزار', userName: 'abd_8116', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 353, universityId: '2072023046', fullName: 'عبد العزيز حسن فؤاد حسن', userName: 'abd_3541', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 354, universityId: '2072023047', fullName: 'عبدالرحمن عاطف محمد محمد', userName: 'abdalrhmn_5734', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 355, universityId: '2072023048', fullName: 'على سيد عبد الحليم سيد', userName: 'aly_1998', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 356, universityId: '2072023049', fullName: 'عمر شلقامى عمر توفيق', userName: 'amr_2059', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 357, universityId: '2072023050', fullName: 'عمر محمد فرغل جاب الله', userName: 'amr_9382', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 358, universityId: '2072023051', fullName: 'عمر مصطفى كامل محمد', userName: 'amr_2136', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 359, universityId: '2072023053', fullName: 'عمرو محمد  عبد الحميد على', userName: 'amrw_3940', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 360, universityId: '2072023054', fullName: 'عمرو محمد محمد امبابى', userName: 'amrw_3395', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 361, universityId: '2072023055', fullName: 'فادى محمد عبد الباسط  محمد', userName: 'fady_1337', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 362, universityId: '2072023056', fullName: 'فاطمه الزهراء علاء صلاح دردير', userName: 'fatmh_1815', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 363, universityId: '2072023057', fullName: 'فاطمه محمد رفعت', userName: 'fatmh_5374', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 364, universityId: '2072023058', fullName: 'فتحى ايمن فتحى جندى', userName: 'fthy_6432', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 365, universityId: '2072023059', fullName: 'كريم جمال محمد محمد', userName: 'krym_1106', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 366, universityId: '2072023060', fullName: 'كيرلس اشرف امين فليته', userName: 'kyrls_9368', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 367, universityId: '2072023061', fullName: 'كيرلس جميل عبد المسيح كيرلس', userName: 'kyrls_9133', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 368, universityId: '2072023062', fullName: 'كيرلس صبحى غالى قيصر', userName: 'kyrls_1881', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 369, universityId: '2072023063', fullName: 'كيرلس صلاح فخرى منسي', userName: 'kyrls_3970', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 370, universityId: '2072023064', fullName: 'كيرلس عايد زكى صليب', userName: 'kyrls_5872', level: 3, departmentId: 3, departmentSectionId: 16),
    CollegeStudent(id: 371, universityId: '2072023065', fullName: 'مارتينا عطيه فوزى بطرس', userName: 'martyna_7894', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 372, universityId: '2072023066', fullName: 'مازن عماد زكريا عبدالعزيز', userName: 'mazn_5434', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 373, universityId: '2072023067', fullName: 'مازن محمد عبدالمنعم سيد', userName: 'mazn_2054', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 374, universityId: '2072023068', fullName: 'محمد احمد ابو العلا حسين', userName: 'mhmd_9112', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 375, universityId: '2072023069', fullName: 'محمد احمد حسين على', userName: 'mhmd_1082', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 376, universityId: '2072023070', fullName: 'محمد احمد محمد فوزى', userName: 'mhmd_7772', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 377, universityId: '2072023071', fullName: 'محمد احمد محمد مهران', userName: 'mhmd_7514', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 378, universityId: '2072023072', fullName: 'محمد اسامه محمد مرسى', userName: 'mhmd_5726', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 379, universityId: '2072023073', fullName: 'محمد حامد محمد عبد العظيم', userName: 'mhmd_8995', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 380, universityId: '2072023074', fullName: 'محمد خالد عبد الجواد محمد', userName: 'mhmd_2894', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 381, universityId: '2072023075', fullName: 'محمد صلاح فرغل محمد', userName: 'mhmd_3933', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 382, universityId: '2072023076', fullName: 'محمد عبد الحميد محمد عبد القادر', userName: 'mhmd_5844', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 383, universityId: '2072023077', fullName: 'محمد عبد السميع فتحى عبدالسميع', userName: 'mhmd_7574', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 384, universityId: '2072023078', fullName: 'محمد عزت محمود محمد', userName: 'mhmd_4640', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 385, universityId: '2072023079', fullName: 'محمد عصمت احمد عبدالهادي', userName: 'mhmd_1901', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 386, universityId: '2072023080', fullName: 'محمد مصطفى محمود عبد القادر', userName: 'mhmd_6297', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 387, universityId: '2072023081', fullName: 'محمد وائل رضوان عزت', userName: 'mhmd_7812', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 388, universityId: '2072023082', fullName: 'محمود سيد الصغير عبدالرحيم', userName: 'mhmwd_7631', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 389, universityId: '2072023083', fullName: 'محمود صلاح عاكف عبدالحميد', userName: 'mhmwd_5658', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 390, universityId: '2072023084', fullName: 'محمود على عبد الموجود عبدالجيد', userName: 'mhmwd_6689', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 391, universityId: '2072023085', fullName: 'محمود مصطفى احمد محمد', userName: 'mhmwd_4139', level: 3, departmentId: 3, departmentSectionId: 17),
    CollegeStudent(id: 392, universityId: '2072023086', fullName: 'مريم مبارك نعيم بخيت', userName: 'mrym_8426', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 393, universityId: '2072023087', fullName: 'مصطفى حمدي عبد الصبور محمد', userName: 'mstfy_7395', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 394, universityId: '2072023088', fullName: 'مصطفى علاء احمد مرسى', userName: 'mstfy_2097', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 395, universityId: '2072023089', fullName: 'مصطفى محمد سليمان قطب', userName: 'mstfy_6678', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 396, universityId: '2072023090', fullName: 'مصطفى محمد عبد العزيز عبدالرازق', userName: 'mstfy_3367', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 397, universityId: '2072023091', fullName: 'ملك خالد كمال سيد', userName: 'mlk_1737', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 398, universityId: '2072023093', fullName: 'منة الله محمد عامر عبد الرحمن', userName: 'mna_6707', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 399, universityId: '2072023094', fullName: 'منه جمال محمد عبدالمالك', userName: 'mnh_3897', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 400, universityId: '2072023097', fullName: 'ندا عبد الناصر محمد محمد', userName: 'nda_4136', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 401, universityId: '2072023098', fullName: 'هدى ايمن عبد الفتاح عبداللطيف', userName: 'hdy_8871', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 402, universityId: '2072023099', fullName: 'همت محى الدين عبد الكريم تسن', userName: 'hmt_4406', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 403, universityId: '2072023100', fullName: 'وليد محفوظ الفى حنا', userName: 'wlyd_6388', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 404, universityId: '2072023101', fullName: 'يسي سامح راتب جورجي', userName: 'ysy_7926', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 405, universityId: '2072023102', fullName: 'يوسف ابراهيم حنا عبد السيد', userName: 'ywsf_7036', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 406, universityId: '2072023103', fullName: 'يوسف ايهاب فايز موسي', userName: 'ywsf_3953', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 407, universityId: '2072023104', fullName: 'يوسف بهاء عبد  الحميد فهمى', userName: 'ywsf_6563', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 408, universityId: '2072023107', fullName: 'يوسف محمود محمد عبدالمجيد', userName: 'ywsf_7897', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 409, universityId: '2072023108', fullName: 'يوسف ناصر محمد سيد', userName: 'ywsf_3623', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 410, universityId: '2072023109', fullName: 'منة الله هديه ابو حسيبة عبد الرؤوف', userName: 'mna_3510', level: 3, departmentId: 3, departmentSectionId: 18),
    CollegeStudent(id: 411, universityId: '2072023043', fullName: 'عبد الرحمن عاطف محمد سيد', userName: 'abd_6117', level: 3, departmentId: 4, departmentSectionId: 19),
    CollegeStudent(id: 412, universityId: '2072023092', fullName: 'منة الله احمد عبد الصبور احمد', userName: 'mna_4567', level: 3, departmentId: 4, departmentSectionId: 19),
    CollegeStudent(id: 413, universityId: '2072023095', fullName: 'مهند احمد محمود عزت', userName: 'mhnd_8258', level: 3, departmentId: 4, departmentSectionId: 19),
    CollegeStudent(id: 414, universityId: '2072023096', fullName: 'مينا موجود زكى', userName: 'myna_6645', level: 3, departmentId: 4, departmentSectionId: 19),
    CollegeStudent(id: 415, universityId: '2072023105', fullName: 'يوسف علاء الدين عبد الواحد', userName: 'ywsf_8259', level: 3, departmentId: 4, departmentSectionId: 19),
  ];

  // Quick index maps
  static final Map<int, CollegeDepartment> departmentMap = {
    for (final d in departments) d.id: d,
  };
  static final Map<int, CollegeDepartmentSection> departmentSectionMap = {
    for (final ds in departmentSections) ds.id: ds,
  };
  static final Map<int, CollegeUser> userMap = {
    for (final u in users) u.id: u,
  };
  static final Map<int, CollegeCourse> courseMap = {
    for (final c in courses) c.id: c,
  };
  static final Map<int, CollegeCourseSection> courseSectionMap = {
    for (final cs in courseSections) cs.id: cs,
  };
  static final Map<int, CollegeStudent> studentMap = {
    for (final s in students) s.id: s,
  };

  // Helper getters
  static List<CollegeUser> get doctors =>
      users.where((u) => u.role == CollegeRole.doctor).toList();

  static List<CollegeUser> get tas =>
      users.where((u) => u.role == CollegeRole.ta).toList();

  static List<CollegeCourseSection> getSectionsForTa(int taId) =>
      courseSections.where((cs) => cs.taId == taId).toList();

  static List<CollegeCourse> getCoursesForDoctor(int doctorId) =>
      courses.where((c) => c.doctorId == doctorId).toList();

  static List<CollegeStudent> getStudentsForDepartmentSection(int deptSectionId) =>
      students.where((s) => s.departmentSectionId == deptSectionId).toList();

  /// EF Core Relational Logic (from DbSeeder.GenerateEnrollments):
  /// A student enrolled in department D and section S takes course C if:
  /// (C is mapped to D in CourseDepartment) AND (CourseSection matches C and S).
  static List<CollegeStudent> getStudentsForCourseSection(int courseSectionId) {
    final cs = courseSectionMap[courseSectionId];
    if (cs == null) return const [];
    // All students who belong to cs.departmentSectionId
    return getStudentsForDepartmentSection(cs.departmentSectionId);
  }

  /// Get formatted display string for a course section
  /// e.g. "CS381 \u00B7 Section 1 (SE)"
  static String getCourseSectionTitle(int courseSectionId) {
    final cs = courseSectionMap[courseSectionId];
    if (cs == null) return 'Section $courseSectionId';
    final course = courseMap[cs.courseId];
    final ds = departmentSectionMap[cs.departmentSectionId];
    final dept = ds != null ? departmentMap[ds.departmentId] : null;
    final cCode = course?.code ?? 'Course';
    final sNum = ds?.number ?? 1;
    final dCode = dept?.code ?? '';
    return '$cCode \u00B7 Section $sNum ($dCode)';
  }

  static String getCourseSectionSubtitle(int courseSectionId) {
    final cs = courseSectionMap[courseSectionId];
    if (cs == null) return '';
    final course = courseMap[cs.courseId];
    final ta = userMap[cs.taId];
    final studentCount = getStudentsForCourseSection(courseSectionId).length;
    return '${course?.name ?? ""} \u00B7 TA: ${ta?.fullName ?? ""} \u00B7 $studentCount students';
  }
}

