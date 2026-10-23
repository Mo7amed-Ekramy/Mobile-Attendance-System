import 'college_database.dart';

enum Role { student, ta, doctor }

enum Mark { unset, present, absent, excused }

enum ScoreState { unrecorded, recorded, excused, unpublished }

class Course {
  const Course(this.code, this.title, this.term, this.section, this.instructor);
  final String code;
  final String title;
  final String term;
  final String section;
  final String instructor;
}

class Session {
  const Session(
    this.title,
    this.date,
    this.kind,
    this.mark, {
    this.cancelled = false,
    this.finalized = true,
  });
  final String title;
  final String date;
  final String kind;
  final Mark mark;
  final bool cancelled;
  final bool finalized;
}

class Student {
  const Student(this.id, this.name);
  final String id;
  final String name;
}

class Assessment {
  const Assessment(
    this.title,
    this.category,
    this.rawMax,
    this.rawScore,
    this.state,
  );
  final String title;
  final String category;
  final double rawMax;
  final double? rawScore;
  final ScoreState state;
}

class QuestionOption {
  const QuestionOption(this.id, this.text, this.isCorrect);
  final String id;
  final String text;
  final bool isCorrect;
}

class QuestionItem {
  const QuestionItem(this.id, this.prompt, this.options, {this.points = 1.0});
  final String id;
  final String prompt;
  final List<QuestionOption> options;
  final double points;
}

class QuizSessionData {
  QuizSessionData({
    required this.title,
    required this.section,
    required this.durationMinutes,
    required this.questions,
    this.isOpen = true,
    this.isCompleted = false,
    this.studentScore,
  });
  final String title;
  final String section;
  final int durationMinutes;
  final List<QuestionItem> questions;
  bool isOpen;
  bool isCompleted;
  double? studentScore;
}

/// Relational data adapter bridging real university database
abstract final class MockData {
  static final courses = <Course>[
    const Course(
      'CS381',
      'software development',
      'Semester 2',
      'Section 1 (SE)',
      'Dr. Rasha Mahmoud · TA: Nehad Abdelrahman',
    ),
    const Course(
      'CS381',
      'software development',
      'Semester 2',
      'Section 2 (SE)',
      'Dr. Rasha Mahmoud · TA: Ahmed Abdelrahman',
    ),
    const Course(
      'SE332',
      'Software Construction',
      'Semester 2',
      'Section 1 (SE)',
      'Dr. Mamdouh Farouk · TA: Ahmed Hesham',
    ),
    const Course(
      'SE331',
      'Software Architecture Design',
      'Semester 2',
      'Section 1 (SE)',
      'Dr. Ibrahim Elawady · TA: Elhasen Mohamed',
    ),
    const Course(
      'CS342',
      'Automata',
      'Semester 2',
      'Section 1 (CS)',
      'Dr. Aml Abdelazim · TA: Mahmoud Esam',
    ),
    const Course(
      'SE321',
      'Software Requirements Analysis',
      'Semester 2',
      'Section 1 (SE)',
      'Dr. Sarah Salah · TA: Mohamed ElFoly',
    ),
    const Course(
      'CS361',
      'Artificial Intelligence',
      'Semester 2',
      'Section 1 (CS)',
      'Dr. Sarah Salah · TA: Ismail Akram',
    ),
    const Course(
      'AI125',
      'Decision Support Systems',
      'Semester 2',
      'Section 1 (AI)',
      'Dr. Ibrahim Elawady · TA: Manal Mahmoud',
    ),
    const Course(
      'SE112',
      'Intelligent Systems',
      'Semester 2',
      'Section 1 (AI)',
      'Dr. Sarah Salah · TA: Elzahra Youssif',
    ),
    const Course(
      'IS911',
      'Web Programming',
      'Semester 2',
      'Section 1 (IS)',
      'Dr. Tarek Mohamed · TA: Asaad Nasr',
    ),
    const Course(
      'AI216',
      'Operating Systems',
      'Semester 2',
      'Section 1 (AI)',
      'Dr. Khaled Fathi · TA: Ahmed Hesham',
    ),
    const Course(
      'CS211',
      'Image Processing',
      'Semester 2',
      'Section 1 (CS)',
      'Dr. Rasha Mahmoud · TA: Mostafa Osama',
    ),
    const Course(
      'CS22',
      'Computer Vision',
      'Semester 2',
      'Section 1 (CS)',
      'Dr. Khaled Fathi · TA: Sarah Raouf',
    ),
    const Course(
      'SE140',
      'Algorithms Design Analysis',
      'Semester 2',
      'Section 1 (SE)',
      'Dr. Maged Asker · TA: Abdalla Ahmed',
    ),
    const Course(
      'AI126',
      'Artificial Intelligence (CS)',
      'Semester 2',
      'Section 1 (CS)',
      'Dr. Aml Abdelazim · TA: Mahmoud Esam',
    ),
  ];

  static final students = CollegeDatabase.students
      .map((s) => Student(s.universityId, s.fullName))
      .toList();

  static const sessions = [
    Session('Lecture 10', '15 Oct', 'Lecture', Mark.present),
    Session('Lecture 9', '13 Oct', 'Lecture', Mark.absent),
    Session('Lecture 8', '8 Oct', 'Lecture', Mark.excused),
    Session('Lecture 7', '6 Oct', 'Lecture', Mark.unset, finalized: false),
    Session('Lecture 6', '1 Oct', 'Lecture', Mark.unset, cancelled: true),
    Session('Practical 8', '14 Oct', 'Section', Mark.present),
    Session('Practical 7', '7 Oct', 'Section', Mark.present),
    Session('Practical 6', '30 Sep', 'Section', Mark.absent),
  ];

  static const assessments = [
    Assessment('Quiz 1', 'Quizzes', 10, 8, ScoreState.recorded),
    Assessment('Quiz 2', 'Quizzes', 10, 0, ScoreState.recorded),
    Assessment('Quiz 3', 'Quizzes', 10, null, ScoreState.unrecorded),
    Assessment('Project', 'Project', 15, 12, ScoreState.recorded),
    Assessment('Midterm', 'Midterm', 20, 16, ScoreState.recorded),
    Assessment('Final exam', 'Final', 50, null, ScoreState.unpublished),
  ];

  static const defaultQuestions = [
    QuestionItem(
      'q1',
      'Which data structure operates on a Last-In, First-Out (LIFO) basis?',
      [
        QuestionOption('a', 'Stack', true),
        QuestionOption('b', 'Queue', false),
        QuestionOption('c', 'Linked List', false),
        QuestionOption('d', 'Binary Tree', false),
      ],
    ),
    QuestionItem(
      'q2',
      'What is the worst-case time complexity of binary search on a sorted array of size n?',
      [
        QuestionOption('a', 'O(log n)', true),
        QuestionOption('b', 'O(n)', false),
        QuestionOption('c', 'O(1)', false),
        QuestionOption('d', 'O(n log n)', false),
      ],
    ),
    QuestionItem(
      'q3',
      'Which traversal of a Binary Search Tree (BST) produces keys in ascending sorted order?',
      [
        QuestionOption('a', 'In-order traversal', true),
        QuestionOption('b', 'Pre-order traversal', false),
        QuestionOption('c', 'Post-order traversal', false),
        QuestionOption('d', 'Level-order traversal', false),
      ],
    ),
    QuestionItem(
      'q4',
      'What data structure is fundamentally used to implement Breadth-First Search (BFS)?',
      [
        QuestionOption('a', 'Queue', true),
        QuestionOption('b', 'Stack', false),
        QuestionOption('c', 'Binary Heap', false),
        QuestionOption('d', 'Disjoint Set', false),
      ],
    ),
    QuestionItem(
      'q5',
      'In a Max-Heap, where is the element with the maximum key guaranteed to reside?',
      [
        QuestionOption('a', 'At the root node', true),
        QuestionOption('b', 'At the deepest leaf node', false),
        QuestionOption('c', 'In the left subtree only', false),
        QuestionOption('d', 'At any position', false),
      ],
    ),
    QuestionItem(
      'q6',
      'Which of the following sorting algorithms exhibits an O(n^2) worst-case time complexity?',
      [
        QuestionOption('a', 'Bubble Sort', true),
        QuestionOption('b', 'Merge Sort', false),
        QuestionOption('c', 'Heap Sort', false),
        QuestionOption('d', 'Quick Sort (randomized pivot)', false),
      ],
    ),
    QuestionItem(
      'q7',
      'What is the time complexity of inserting an item at the head of a singly linked list?',
      [
        QuestionOption('a', 'O(1)', true),
        QuestionOption('b', 'O(n)', false),
        QuestionOption('c', 'O(log n)', false),
        QuestionOption('d', 'O(n log n)', false),
      ],
    ),
    QuestionItem(
      'q8',
      'What does FIFO stand for in basic computer science queue data structures?',
      [
        QuestionOption('a', 'First In First Out', true),
        QuestionOption('b', 'Fast Input Fast Output', false),
        QuestionOption('c', 'Final In First Out', false),
        QuestionOption('d', 'First In Final Order', false),
      ],
    ),
    QuestionItem(
      'q9',
      'In SQL, which clause is used to filter records that are grouped by a GROUP BY clause?',
      [
        QuestionOption('a', 'HAVING', true),
        QuestionOption('b', 'WHERE', false),
        QuestionOption('c', 'ORDER BY', false),
        QuestionOption('d', 'DISTINCT', false),
      ],
    ),
    QuestionItem(
      'q10',
      'Which normal form requires the elimination of transitive functional dependencies on the primary key?',
      [
        QuestionOption('a', 'Third Normal Form (3NF)', true),
        QuestionOption('b', 'First Normal Form (1NF)', false),
        QuestionOption('c', 'Second Normal Form (2NF)', false),
        QuestionOption('d', 'BCNF only', false),
      ],
    ),
    QuestionItem(
      'q11',
      'What do the ACID properties in database transaction management stand for?',
      [
        QuestionOption('a', 'Atomicity, Consistency, Isolation, Durability', true),
        QuestionOption('b', 'Accuracy, Concurrency, Integrity, Durability', false),
        QuestionOption('c', 'Access, Control, Indexing, Data', false),
        QuestionOption('d', 'Authentication, Consistency, Isolation, Distribution', false),
      ],
    ),
    QuestionItem(
      'q12',
      'Which search algorithm in Artificial Intelligence uses f(n) = g(n) + h(n) with an admissible heuristic?',
      [
        QuestionOption('a', 'A* Search', true),
        QuestionOption('b', 'Greedy Best-First Search', false),
        QuestionOption('c', 'Depth-First Search (DFS)', false),
        QuestionOption('d', 'Minimax Algorithm', false),
      ],
    ),
    QuestionItem(
      'q13',
      'What is the primary indicator of overfitting in machine learning models?',
      [
        QuestionOption('a', 'High training accuracy but poor validation/test accuracy', true),
        QuestionOption('b', 'Low training accuracy and low validation accuracy', false),
        QuestionOption('c', 'High training loss and low validation loss', false),
        QuestionOption('d', 'Equal training and test error rates', false),
      ],
    ),
    QuestionItem(
      'q14',
      'In Software Engineering, what is the single responsibility of a Singleton design pattern?',
      [
        QuestionOption('a', 'Ensures a class has only one instance and provides global access to it', true),
        QuestionOption('b', 'Decouples abstraction from its implementation', false),
        QuestionOption('c', 'Defines a family of interchangeable algorithms', false),
        QuestionOption('d', 'Converts the interface of a class into another expected interface', false),
      ],
    ),
    QuestionItem(
      'q15',
      'What does the "O" represent in the SOLID principles of Object-Oriented Software Design?',
      [
        QuestionOption('a', 'Open/Closed Principle (open for extension, closed for modification)', true),
        QuestionOption('b', 'Object-Oriented Programming Principle', false),
        QuestionOption('c', 'Operational Independence Principle', false),
        QuestionOption('d', 'Optimized Coupling Principle', false),
      ],
    ),
    QuestionItem(
      'q16',
      'In Operating Systems, which condition is NOT one of Coffman’s four necessary conditions for deadlock?',
      [
        QuestionOption('a', 'Preemptive CPU Scheduling', true),
        QuestionOption('b', 'Mutual Exclusion', false),
        QuestionOption('c', 'Hold and Wait', false),
        QuestionOption('d', 'Circular Wait', false),
      ],
    ),
    QuestionItem(
      'q17',
      'Which Transport layer protocol provides reliable, connection-oriented data transfer with flow control?',
      [
        QuestionOption('a', 'TCP (Transmission Control Protocol)', true),
        QuestionOption('b', 'UDP (User Datagram Protocol)', false),
        QuestionOption('c', 'ICMP (Internet Control Message Protocol)', false),
        QuestionOption('d', 'IP (Internet Protocol)', false),
      ],
    ),
    QuestionItem(
      'q18',
      'What is the average time complexity of finding a key in a well-distributed Hash Table?',
      [
        QuestionOption('a', 'O(1)', true),
        QuestionOption('b', 'O(log n)', false),
        QuestionOption('c', 'O(n)', false),
        QuestionOption('d', 'O(n^2)', false),
      ],
    ),
  ];
}

class Department {
  const Department({
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.head,
    required this.sectionsCount,
  });
  final String code;
  final String nameEn;
  final String nameAr;
  final String head;
  final int sectionsCount;
}

class UniversityMember {
  const UniversityMember({
    required this.nameEn,
    required this.nameAr,
    required this.role,
    required this.department,
    required this.email,
    required this.assignedSections,
  });
  final String nameEn;
  final String nameAr;
  final String role;
  final String department;
  final String email;
  final String assignedSections;
}

class DetailedStudent {
  const DetailedStudent({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.department,
    required this.section,
    required this.gpa,
    required this.email,
    this.phone,
    this.level = 3,
  });
  final String id;
  final String nameEn;
  final String nameAr;
  final String department;
  final String section;
  final double gpa;
  final String email;
  final String? phone;
  final int level;
}

abstract final class UniversityDatabase {
  static const departments = [
    Department(
      code: 'SE',
      nameEn: 'Software Engineering',
      nameAr: 'هندسة البرمجيات',
      head: 'Dr. Mamdouh Farouk Mohamed',
      sectionsCount: 8,
    ),
    Department(
      code: 'AI',
      nameEn: 'Artificial Intelligence',
      nameAr: 'الذكاء الاصطناعي',
      head: 'Dr. Khaled Fathi',
      sectionsCount: 5,
    ),
    Department(
      code: 'CS',
      nameEn: 'Computer Science',
      nameAr: 'علوم الحاسب',
      head: 'Dr. Rasha Mahmoud Kamel',
      sectionsCount: 5,
    ),
    Department(
      code: 'IS',
      nameEn: 'Information Systems',
      nameAr: 'نظم المعلومات',
      head: 'Dr. Tarek Mohamed Abdelkader',
      sectionsCount: 1,
    ),
  ];

  static const staff = [
    UniversityMember(
      nameEn: 'Dr. Mamdouh Farouk Mohamed',
      nameAr: 'د. ممدوح فاروق محمد',
      role: 'Professor · Dept Head',
      department: 'SE',
      email: 'doc_mamdouh12@college.edu.eg',
      assignedSections: 'SE332 Software Construction',
    ),
    UniversityMember(
      nameEn: 'Dr. Khaled Fathi',
      nameAr: 'د. خالد فتحي',
      role: 'Associate Professor · Dept Head',
      department: 'AI',
      email: 'doc_khaled13@college.edu.eg',
      assignedSections: 'AI216 Operating Systems, CS22 Computer Vision',
    ),
    UniversityMember(
      nameEn: 'Dr. Ibrahim Elawady',
      nameAr: 'د. إبراهيم العوضي',
      role: 'Associate Professor',
      department: 'SE',
      email: 'doc_ibrahim14@college.edu.eg',
      assignedSections: 'SE331 Software Architecture, AI125 DSS',
    ),
    UniversityMember(
      nameEn: 'Dr. Aml Abdelazim',
      nameAr: 'د. أمل عبد العظيم',
      role: 'Associate Professor',
      department: 'CS',
      email: 'doc_aml01@college.edu.eg',
      assignedSections: 'CS342 Automata, AI126 AI (CS)',
    ),
    UniversityMember(
      nameEn: 'Dr. Sarah Salah',
      nameAr: 'د. سارة صلاح',
      role: 'Associate Professor',
      department: 'CS',
      email: 'doc_sarah05@college.edu.eg',
      assignedSections: 'SE321 Requirements, CS361 AI, SE112 Intelligent Sys',
    ),
    UniversityMember(
      nameEn: 'Dr. Rasha Mahmoud Kamel',
      nameAr: 'د. رشا محمود كامل',
      role: 'Professor · Dept Head',
      department: 'CS',
      email: 'doc_rasha01@college.edu.eg',
      assignedSections: 'CS381 Software Dev, CS211 Image Processing',
    ),
    UniversityMember(
      nameEn: 'Dr. Tarek Mohamed Abdelkader',
      nameAr: 'د. طارق محمد عبد القادر',
      role: 'Professor · Dept Head',
      department: 'IS',
      email: 'doc_tarek12@college.edu.eg',
      assignedSections: 'IS911 Web Programming',
    ),
    UniversityMember(
      nameEn: 'Dr. Soha Abdelmomen Mohamed',
      nameAr: 'د. سهى عبد المؤمن محمد',
      role: 'Associate Professor',
      department: 'CS',
      email: 'doc_soha01@college.edu.eg',
      assignedSections: 'CS Academic Advising',
    ),
    UniversityMember(
      nameEn: 'Dr. Maged Asker',
      nameAr: 'د. ماجد عسكر',
      role: 'Professor',
      department: 'SE',
      email: 'doc_maged32@college.edu.eg',
      assignedSections: 'SE140 Algorithms Design Analysis',
    ),
    // Teaching Assistants:
    UniversityMember(
      nameEn: 'Eng. Sarah Raouf',
      nameAr: 'م. سارة رؤوف',
      role: 'Teaching Assistant',
      department: 'CS',
      email: 'ta_sarah11@college.edu.eg',
      assignedSections: 'CS22 Computer Vision (Sec 1-5)',
    ),
    UniversityMember(
      nameEn: 'Eng. Salma Osama',
      nameAr: 'م. سلمى أسامة',
      role: 'Teaching Assistant',
      department: 'CS',
      email: 'ta_salma76@college.edu.eg',
      assignedSections: 'CS361 AI (Sec 14-18)',
    ),
    UniversityMember(
      nameEn: 'Eng. Abdalla Ahmed',
      nameAr: 'م. عبد الله أحمد',
      role: 'Teaching Assistant',
      department: 'SE',
      email: 'ta_abdalla01@college.edu.eg',
      assignedSections: 'SE140 Algorithms (Sec 14-18)',
    ),
    UniversityMember(
      nameEn: 'Eng. Ahmed Hesham',
      nameAr: 'م. أحمد هشام',
      role: 'Teaching Assistant',
      department: 'AI',
      email: 'ta_ahmed25@college.edu.eg',
      assignedSections: 'AI216 Operating Systems, CS342 Automata',
    ),
    UniversityMember(
      nameEn: 'Eng. Mahmoud Esam',
      nameAr: 'م. محمود عصام',
      role: 'Teaching Assistant',
      department: 'CS',
      email: 'ta_mahmoud26@college.edu.eg',
      assignedSections: 'CS342 Automata, AI126 AI (CS)',
    ),
    UniversityMember(
      nameEn: 'Eng. Ismail Akram',
      nameAr: 'م. إسماعيل أكرم',
      role: 'Teaching Assistant',
      department: 'CS',
      email: 'ta_ismail72@college.edu.eg',
      assignedSections: 'CS361 Artificial Intelligence',
    ),
    UniversityMember(
      nameEn: 'Eng. Mohamed ElFoly',
      nameAr: 'م. محمد الفولي',
      role: 'Teaching Assistant',
      department: 'SE',
      email: 'ta_mohamed32@college.edu.eg',
      assignedSections: 'SE321 Software Requirements',
    ),
    UniversityMember(
      nameEn: 'Eng. Elhasen Mohamed',
      nameAr: 'م. الحسن محمد',
      role: 'Teaching Assistant',
      department: 'SE',
      email: 'ta_elhasen28@college.edu.eg',
      assignedSections: 'SE331 Software Architecture',
    ),
    UniversityMember(
      nameEn: 'Eng. Manal Mahmoud',
      nameAr: 'م. منال محمود',
      role: 'Teaching Assistant',
      department: 'AI',
      email: 'ta_manal01@college.edu.eg',
      assignedSections: 'AI125 Decision Support Systems',
    ),
    UniversityMember(
      nameEn: 'Eng. Asaad Nasr',
      nameAr: 'م. أسعد نصر',
      role: 'Teaching Assistant',
      department: 'IS',
      email: 'ta_asaad09@college.edu.eg',
      assignedSections: 'IS911 Web Programming',
    ),
    UniversityMember(
      nameEn: 'Eng. Mostafa Osama',
      nameAr: 'م. مصطفى أسامة',
      role: 'Teaching Assistant',
      department: 'CS',
      email: 'ta_mostafa01@college.edu.eg',
      assignedSections: 'CS211 Image Processing',
    ),
    UniversityMember(
      nameEn: 'Eng. Nehad Abdelrahman',
      nameAr: 'م. نهاد عبد الرحمن',
      role: 'Teaching Assistant',
      department: 'SE',
      email: 'ta_nehad00@college.edu.eg',
      assignedSections: 'CS381 Software Development (Sec 1)',
    ),
    UniversityMember(
      nameEn: 'Eng. Ahmed Abdelrahman',
      nameAr: 'م. أحمد عبد الرحمن',
      role: 'Teaching Assistant',
      department: 'SE',
      email: 'ta_ahmed14@college.edu.eg',
      assignedSections: 'CS381 Software Development (Sec 2-7)',
    ),
  ];

  /// ALL 415 real students dynamically mapped from legacy database
  static final List<DetailedStudent> allStudents = CollegeDatabase.students.map((s) {
    final ds = CollegeDatabase.departmentSectionMap[s.departmentSectionId];
    final dept = CollegeDatabase.departmentMap[s.departmentId];
    final secNum = ds?.number ?? 1;
    final deptCode = dept?.code ?? 'CS';
    return DetailedStudent(
      id: s.universityId,
      nameEn: s.userName,
      nameAr: s.fullName,
      department: deptCode,
      section: 'Section $secNum ($deptCode)',
      gpa: 2.80 + ((s.id * 13) % 120) / 100.0,
      email: '${s.userName}@college.edu.eg',
      phone: '+20 100 ${(1000000 + s.id)}',
      level: s.level,
    );
  }).toList();

  /// Returns students enrolled in [dept] department + [section].
  static List<DetailedStudent> studentsFor(String dept, String section) {
    return allStudents.where((s) {
      final deptMatches = s.department.toLowerCase() == dept.toLowerCase();
      final secMatches = s.section.toLowerCase().contains(section.toLowerCase()) ||
          section.toLowerCase().contains(s.section.toLowerCase());
      return deptMatches && secMatches;
    }).toList();
  }

  /// Returns students for a given [course] matching relational CourseSection
  static List<DetailedStudent> studentsForCourse(Course course) {
    for (final cs in CollegeDatabase.courseSections) {
      final c = CollegeDatabase.courseMap[cs.courseId];
      final ds = CollegeDatabase.departmentSectionMap[cs.departmentSectionId];
      final d = ds != null ? CollegeDatabase.departmentMap[ds.departmentId] : null;
      if (c != null && ds != null && d != null) {
        if (c.code == course.code && course.section.contains('Section ${ds.number}')) {
          if (course.section.contains(d.code)) {
            final realList = CollegeDatabase.getStudentsForCourseSection(cs.id);
            if (realList.isNotEmpty) {
              return realList.map((s) {
                return DetailedStudent(
                  id: s.universityId,
                  nameEn: s.userName,
                  nameAr: s.fullName,
                  department: d.code,
                  section: 'Section ${ds.number} (${d.code})',
                  gpa: 2.80 + ((s.id * 13) % 120) / 100.0,
                  email: '${s.userName}@college.edu.eg',
                  phone: '+20 100 ${(1000000 + s.id)}',
                  level: s.level,
                );
              }).toList();
            }
          }
        }
      }
    }
    // Fallback: match by department code prefix
    final deptPrefix = course.code.replaceAll(RegExp(r'[0-9]'), '');
    final direct = studentsFor(deptPrefix, course.section);
    if (direct.isNotEmpty) return direct;
    final bySec = allStudents.where((s) => s.section == course.section).toList();
    if (bySec.isNotEmpty) return bySec;
    return allStudents.take(24).toList();
  }
}

class DemoState {
  static const initialAllocations = <String, double>{
    'Final': 50,
    'Midterm': 20,
    'Lecture attendance': 5,
    'Section attendance': 5,
    'Project': 15,
    'Quizzes': 5,
  };
  Role? role;
  CollegeUser? loggedInStaff;
  CollegeStudent? loggedInStudent;
  final courses = <Course>[...MockData.courses];
  int courseIndex = 0;
  int sectionIndex = 0;
  final marks = <String, Mark>{};
  final scores = <String, double?>{};
  final allocations = <String, double>{...initialAllocations};
  final questionBank = <QuestionItem>[...MockData.defaultQuestions];
  QuizSessionData? activeQuiz;
  bool quizNotificationPending = false;
  bool rollFinalized = false;
  bool lectureOpen = false;
  bool darkMode = false;

  /// Students enrolled in the currently selected course (section-filtered).
  List<DetailedStudent> get currentStudents =>
      UniversityDatabase.studentsForCourse(courses[courseIndex]);

  String get currentUserName {
    if (loggedInStaff != null) return loggedInStaff!.fullName;
    if (loggedInStudent != null) return loggedInStudent!.fullName;
    if (role == Role.doctor) return 'د. رشا محمود كامل';
    if (role == Role.ta) return 'م. نهاد عبد الرحمن';
    return 'احمد عبد العليم سيد احمد';
  }

  String get currentUserId {
    if (loggedInStaff != null) return loggedInStaff!.userName;
    if (loggedInStudent != null) return loggedInStudent!.universityId;
    if (role == Role.doctor) return 'doc_rasha01';
    if (role == Role.ta) return 'ta_nehad00';
    return '20720236007';
  }

  String get currentUserDepartment {
    if (loggedInStudent != null) {
      final dept = CollegeDatabase.departmentMap[loggedInStudent!.departmentId];
      return dept?.name ?? 'Software Engineering';
    }
    if (loggedInStaff != null) {
      return loggedInStaff!.role == CollegeRole.doctor
          ? 'Computer Science'
          : 'Software Engineering';
    }
    return 'Software Engineering';
  }

  String get currentUserSection {
    if (loggedInStudent != null) {
      final ds = CollegeDatabase.departmentSectionMap[loggedInStudent!.departmentSectionId];
      return 'Section ${ds?.number ?? 1}';
    }
    return courses.isNotEmpty ? courses[courseIndex].section : 'Section 1';
  }

  bool loginWithCredentials(String identifier, String password) {
    final cleanId = identifier.trim().toLowerCase();
    final cleanPass = password.trim();

    // 1. Staff check (Doctor, TA, Admin)
    for (final u in CollegeDatabase.users) {
      if (u.userName.toLowerCase() == cleanId ||
          u.fullName.toLowerCase() == cleanId ||
          cleanId.contains(u.userName.toLowerCase())) {
        final expected = u.role == CollegeRole.doctor ? 'Doctor@123' : 'TA@123';
        if (cleanPass == expected ||
            cleanPass == u.userName ||
            cleanPass == '123' ||
            cleanPass.isEmpty) {
          setStaffUser(u);
          return true;
        }
      }
    }

    // 2. Student check
    for (final s in CollegeDatabase.students) {
      if (s.universityId == cleanId ||
          s.userName.toLowerCase() == cleanId ||
          s.fullName.toLowerCase().contains(cleanId)) {
        if (cleanPass == s.universityId ||
            cleanPass == 'User@123' ||
            cleanPass == s.userName ||
            cleanPass == '123' ||
            cleanPass.isEmpty) {
          setStudentUser(s);
          return true;
        }
      }
    }
    return false;
  }

  void setStaffUser(CollegeUser u) {
    loggedInStaff = u;
    loggedInStudent = null;
    role = u.role == CollegeRole.doctor ? Role.doctor : Role.ta;

    courses.clear();
    if (u.role == CollegeRole.doctor) {
      final docCourses = CollegeDatabase.getCoursesForDoctor(u.id);
      for (final dc in docCourses) {
        final cSections = CollegeDatabase.courseSections
            .where((cs) => cs.courseId == dc.id)
            .toList();
        if (cSections.isNotEmpty) {
          for (final cs in cSections) {
            final ds = CollegeDatabase.departmentSectionMap[cs.departmentSectionId];
            final d = ds != null ? CollegeDatabase.departmentMap[ds.departmentId] : null;
            final ta = CollegeDatabase.userMap[cs.taId];
            courses.add(Course(
              dc.code,
              dc.name,
              'Semester ${dc.semester}',
              'Section ${ds?.number ?? 1} (${d?.code ?? ""})',
              '${u.fullName} · TA: ${ta?.fullName ?? ""}',
            ));
          }
        } else {
          courses.add(Course(
            dc.code,
            dc.name,
            'Semester ${dc.semester}',
            'All Sections',
            u.fullName,
          ));
        }
      }
    } else {
      final taSections = CollegeDatabase.getSectionsForTa(u.id);
      for (final ts in taSections) {
        final c = CollegeDatabase.courseMap[ts.courseId];
        final ds = CollegeDatabase.departmentSectionMap[ts.departmentSectionId];
        final d = ds != null ? CollegeDatabase.departmentMap[ds.departmentId] : null;
        final doc = c != null ? CollegeDatabase.userMap[c.doctorId] : null;
        if (c != null && ds != null) {
          courses.add(Course(
            c.code,
            c.name,
            'Semester ${c.semester}',
            'Section ${ds.number} (${d?.code ?? ""})',
            '${doc?.fullName ?? ""} · TA: ${u.fullName}',
          ));
        }
      }
    }

    if (courses.isEmpty) {
      courses.addAll(MockData.courses);
    }
    resetScope(0);
  }

  void setStudentUser(CollegeStudent s) {
    loggedInStudent = s;
    loggedInStaff = null;
    role = Role.student;

    courses.clear();
    final deptCourseIds = CollegeDatabase.courseDepartments
        .where((cd) => cd.departmentId == s.departmentId)
        .map((cd) => cd.courseId)
        .toSet();

    for (final cId in deptCourseIds) {
      final c = CollegeDatabase.courseMap[cId];
      final ds = CollegeDatabase.departmentSectionMap[s.departmentSectionId];
      final d = CollegeDatabase.departmentMap[s.departmentId];
      final doc = c != null ? CollegeDatabase.userMap[c.doctorId] : null;
      final cs = CollegeDatabase.courseSections.firstWhere(
        (sec) =>
            sec.courseId == cId &&
            sec.departmentSectionId == s.departmentSectionId,
        orElse: () => CollegeCourseSection(
          id: 0,
          courseId: cId,
          departmentSectionId: s.departmentSectionId,
          taId: 0,
        ),
      );
      final ta = CollegeDatabase.userMap[cs.taId];
      if (c != null) {
        courses.add(Course(
          c.code,
          c.name,
          'Semester ${c.semester}',
          'Section ${ds?.number ?? 1} (${d?.code ?? ""})',
          '${doc?.fullName ?? ""} · TA: ${ta?.fullName ?? ""}',
        ));
      }
    }

    if (courses.isEmpty) {
      courses.addAll(MockData.courses);
    }
    resetScope(0);
  }

  void selectRealRole(Role targetRole) {
    if (targetRole == Role.doctor) {
      final doc = CollegeDatabase.users.firstWhere(
        (u) => u.userName == 'doc_rasha01',
        orElse: () => CollegeDatabase.doctors.first,
      );
      setStaffUser(doc);
    } else if (targetRole == Role.ta) {
      final ta = CollegeDatabase.users.firstWhere(
        (u) => u.userName == 'ta_nehad00',
        orElse: () => CollegeDatabase.tas.first,
      );
      setStaffUser(ta);
    } else {
      final student = CollegeDatabase.students.firstWhere(
        (s) => s.universityId == '20720236007',
        orElse: () => CollegeDatabase.students.first,
      );
      setStudentUser(student);
    }
  }

  void resetDemo() {
    role = null;
    loggedInStaff = null;
    loggedInStudent = null;
    courses
      ..clear()
      ..addAll(MockData.courses);
    resetScope(0);
  }

  void resetScope(int index) {
    courseIndex = index;
    sectionIndex = 0;
    marks.clear();
    scores.clear();
    allocations
      ..clear()
      ..addAll(initialAllocations);
    rollFinalized = false;
    lectureOpen = false;
    activeQuiz = null;
    quizNotificationPending = false;
  }

  void publishSectionQuiz({
    required String title,
    required String section,
    required int questionCount,
    required int durationMinutes,
  }) {
    final pool = [...questionBank]..shuffle();
    final selected = pool.take(questionCount).toList();
    activeQuiz = QuizSessionData(
      title: title,
      section: section,
      durationMinutes: durationMinutes,
      questions: selected,
    );
    quizNotificationPending = true;
  }
}

double? attendanceRate(Iterable<Session> sessions) {
  final eligible = sessions
      .where(
        (s) =>
            s.finalized &&
            !s.cancelled &&
            (s.mark == Mark.present || s.mark == Mark.absent),
      )
      .toList();
  if (eligible.isEmpty) return null;
  return eligible.where((s) => s.mark == Mark.present).length / eligible.length;
}

double? normalizedPoints(Iterable<Assessment> assessments, double allocation) {
  final included = assessments
      .where((a) => a.state == ScoreState.recorded && a.rawScore != null)
      .toList();
  final denominator = included.fold<double>(0, (sum, a) => sum + a.rawMax);
  if (denominator == 0) return null;
  return allocation *
      included.fold<double>(0, (sum, a) => sum + a.rawScore!) /
      denominator;
}
