import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'attendance.dart';
import 'grading.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage(this.state, {super.key});
  final AppState state;
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ta = state.user!.role == Role.ta;
    bool matchesCourse(CourseOffering course) =>
        course.code.toLowerCase().contains(search) ||
        course.name.toLowerCase().contains(search);
    bool matchesSection(CourseSection section) =>
        section.label.toLowerCase().contains(search);
    final courses = state.courses
        .where((course) =>
            matchesCourse(course) ||
            (ta && course.sections.any(matchesSection)))
        .toList();
    return PageContent(children: [
      PageHeading(
          state.user!.role == Role.student
              ? 'مقرراتي الدراسية'
              : state.user!.role == Role.ta
                  ? 'سكاشني المسندة'
                  : 'المقررات المسندة',
          ta
              ? '${state.courses.length} مقرر · اختر السكشن لفتح الحضور والدرجات وكشف الطلاب'
              : '${state.courses.length} مقرر · اختر مقرراً لمتابعة الحضور والدرجات'),
      TextField(
          decoration: InputDecoration(
              labelText:
                  ta ? 'البحث في المقررات والسكاشن' : 'البحث في المقررات',
              prefixIcon: const Icon(Icons.search)),
          onChanged: (value) =>
              setState(() => search = value.trim().toLowerCase())),
      if (state.user!.role == Role.doctor)
        AsyncButton(
            label: 'إضافة مقرر',
            icon: Icons.add,
            onPressed: () async {
              await openPage(context, 'إضافة مقرر', AddCoursePage(state));
            }),
      if (courses.isEmpty)
        const EmptyPanel(
            'لا توجد مقررات مطابقة', 'حدّث البيانات أو غيّر كلمات البحث.'),
      for (final course in courses) ...[
        if (ta)
          PageHeading('${course.code} · ${course.name}',
              'دكتور المقرر: ${course.doctorName}')
        else
          ActionCard(
              title: '${course.code} · ${course.name}',
              detail: state.user!.role == Role.doctor
                  ? course.termLabel
                  : '${course.doctorName} · ${course.sections.length} سكشن',
              icon: Icons.menu_book_outlined,
              onTap: () async {
                state.selectCourse(course);
                await openPage(context, course.name, CourseDetailPage(state));
              }),
        if (ta)
          for (final section in course.sections.where(
              (section) => matchesCourse(course) || matchesSection(section)))
            ActionCard(
                title: '${course.code} · ${section.label}',
                detail:
                    '${section.studentCount} طالب · الحضور والدرجات وكشف الطلاب',
                icon: Icons.groups_outlined,
                onTap: () {
                  state.selectScope(course, selectedSection: section);
                  openPage(context, section.label, SectionWorkspacePage(state));
                }),
      ],
    ]);
  }
}

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => PageContent(children: [
        StatusRow('${state.course!.code} · ${state.course!.name}',
            '${state.course!.doctorName} · ${state.course!.termLabel}'),
        if (state.user!.role != Role.doctor)
          for (final section in state.course!.sections)
            if (state.user!.role == Role.student)
              StatusRow(section.label,
                  '${section.taName} · ${section.studentCount} طالب')
            else
              ActionCard(
                  title: section.label,
                  detail: '${section.taName} · ${section.studentCount} طالب',
                  icon: Icons.groups_outlined,
                  onTap: () {
                    state.selectSection(section);
                    openPage(
                        context, section.label, SectionWorkspacePage(state));
                  }),
        ActionCard(
            title: 'سجل الحضور',
            detail: state.user!.role == Role.doctor
                ? 'حضور طلاب المقرر'
                : 'المحاضرات والسكاشن',
            icon: Icons.event_note,
            onTap: () => openPage(context, 'الحضور', AttendancePage(state))),
        ActionCard(
            title: 'الدرجات والتقييمات',
            detail: 'لائحة المقرر والنتائج',
            icon: Icons.grade_outlined,
            onTap: () => openPage(context, 'الدرجات', GradesPage(state))),
        if (state.user!.role != Role.student)
          ActionCard(
              title: 'كشف الطلاب',
              detail: 'الطلاب المسجلون فعلياً',
              icon: Icons.groups,
              onTap: () => openPage(
                  context,
                  'كشف الطلاب',
                  RosterPage(state.api, state.course!,
                      sectionId: state.section?.id))),
      ]);
}

class SectionWorkspacePage extends StatelessWidget {
  const SectionWorkspacePage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => PageContent(children: [
        PageHeading('${state.course!.code} · ${state.section!.label}',
            'المعيد: ${state.section!.taName} · عدد الطلاب: ${state.section!.studentCount}'),
        if (state.user!.role == Role.ta)
          ActionCard(
              title: 'إنشاء كشف حضور السكشن',
              detail: 'تحديد الحالات ومراجعة الكشف قبل الاعتماد',
              icon: Icons.playlist_add_check,
              onTap: () =>
                  openPage(context, 'كشف جديد', CreateSessionPage(state))),
        ActionCard(
            title: 'سجل الحضور',
            detail: 'الجلسات السابقة والكشوف التي لم تُعتمد',
            icon: Icons.event_note_outlined,
            onTap: () => openPage(context, 'الحضور', AttendancePage(state))),
        ActionCard(
            title: 'الدرجات والتقييمات',
            detail: 'العمل على طلاب هذا السكشن',
            icon: Icons.grade_outlined,
            onTap: () => openPage(context, 'الدرجات', GradesPage(state))),
        ActionCard(
            title: 'كشف الطلاب',
            detail: 'البحث بالاسم أو الرقم الجامعي',
            icon: Icons.groups_outlined,
            onTap: () => openPage(
                context,
                'كشف الطلاب',
                RosterPage(state.api, state.course!,
                    sectionId: state.section!.id))),
      ]);
}

class RosterPage extends StatefulWidget {
  const RosterPage(this.api, this.course, {super.key, this.sectionId});
  final AttendanceApi api;
  final CourseOffering course;
  final int? sectionId;
  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  final searchController = TextEditingController();
  Timer? debounceTimer;
  String search = '';
  int offset = 0;

  @override
  void dispose() {
    searchController.dispose();
    debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageContent(children: [
        TextField(
            controller: searchController,
            decoration: const InputDecoration(
                labelText: 'اسم الطالب أو الرقم الجامعي',
                prefixIcon: Icon(Icons.search)),
            onChanged: (value) {
              debounceTimer?.cancel();
              debounceTimer = Timer(const Duration(milliseconds: 250), () {
                if (mounted) {
                  setState(() {
                    search = value.trim();
                    offset = 0;
                  });
                }
              });
            }),
        RemotePage<dynamic>(
            scope: '$search:$offset',
            load: () => widget.api.getCourse(widget.course, 'roster',
                sectionId: widget.sectionId,
                query: {'search': search, 'offset': offset, 'limit': 50}),
            builder: (data, reload) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${data['total']} طالب'),
                    const SizedBox(height: 8),
                    if ((data['rows'] as List).isEmpty)
                      const EmptyPanel(
                          'لا يوجد طلاب مطابقون', 'راجع البحث والسكشن المحدد.')
                    else
                      for (final row in data['rows'] as List) ...[
                        StatusRow(row['full_name'] as String,
                            '${row['university_id']} · سكشن ${row['section_number']} (${row['department_code']})'),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: offset == 0
                                  ? null
                                  : () => setState(() => offset -= 50),
                              child: const Text('السابق'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: OutlinedButton(
                              onPressed: offset + 50 >= (data['total'] as int)
                                  ? null
                                  : () => setState(() => offset += 50),
                              child: const Text('التالي')))
                    ]),
                  ],
                )),
      ]);
}

class AddCoursePage extends StatefulWidget {
  const AddCoursePage(this.state, {super.key});
  final AppState state;
  @override
  State<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  final code = TextEditingController();
  final name = TextEditingController();
  final level = TextEditingController(text: '3');
  int? section, ta;
  @override
  void dispose() {
    code.dispose();
    name.dispose();
    level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RemotePage<dynamic>(
      load: () => widget.state.api.request('GET', '/catalog-options'),
      builder: (options, reload) => PageContent(children: [
            TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'كود المقرر')),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم المقرر')),
            TextField(
                controller: level,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'المستوى الدراسي')),
            DropdownButtonFormField<int>(
                initialValue: section,
                decoration: const InputDecoration(labelText: 'السكشن'),
                items: [
                  for (final item in options['sections'] as List)
                    DropdownMenuItem(
                        value: item['id'] as int,
                        child: Text('سكشن ${item['number']} (${item['code']})'))
                ],
                onChanged: (value) => section = value),
            DropdownButtonFormField<int>(
                initialValue: ta,
                decoration: const InputDecoration(labelText: 'المعيد'),
                items: [
                  for (final item in options['tas'] as List)
                    DropdownMenuItem(
                        value: item['id'] as int,
                        child: Text(item['full_name'] as String))
                ],
                onChanged: (value) => ta = value),
            const Text('سيتم تسجيل طلاب المستوى والسكشن المختارين في المقرر.'),
            AsyncButton(
                label: 'إنشاء المقرر',
                onPressed: () async {
                  if (code.text.trim().isEmpty ||
                      name.text.trim().isEmpty ||
                      section == null ||
                      ta == null ||
                      int.tryParse(level.text) == null) {
                    throw const ApiException(
                        'أكمل بيانات المقرر والسكشن والمعيد.');
                  }
                  final result =
                      await widget.state.api.request('POST', '/courses', body: {
                    'code': code.text.trim(),
                    'name': name.text.trim(),
                    'department_section_id': section,
                    'ta_user_id': ta,
                    'level': int.parse(level.text)
                  });
                  await widget.state.refreshCourses();
                  widget.state.selectCourse(widget.state.courses
                      .firstWhere((course) => course.id == result['id']));
                  if (context.mounted) Navigator.pop(context, true);
                }),
          ]));
}
