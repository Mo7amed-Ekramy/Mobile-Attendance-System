import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'college_database.dart';
import 'mock_data.dart';
import 'theme.dart';

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});
  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  final demo = DemoState();
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  int tab = 0;
  bool login = false;
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void notice(String text) =>
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
  void open(String title, Widget child) => navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(child: child),
          ),
        ),
      );
  void enter(Role role) {
    setState(() {
      demo.role = role;
      tab = 0;
    });
  }

  void setScope(int index) {
    if (index == demo.courseIndex) {
      navigatorKey.currentState?.maybePop();
      return;
    }
    setState(() {
      demo.resetScope(index);
      tab = 0;
    });
    navigatorKey.currentState?.maybePop();
    notice('Demo course changed. Local drafts were cleared.');
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          title: 'جامعة أسيوط الأهلية',
          debugShowCheckedModeBanner: false,
          theme: Brand.theme(),
          darkTheme: Brand.theme(dark: true),
          themeMode: demo.darkMode ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) =>
                demo.role == null ? _entry(context) : _shell(context),
          ),
        ),
      );

  Widget _entry(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Image.asset(
                        'national_university_logo_2.png',
                        width: 90,
                        height: 90,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'جامعة أسيوط الأهلية',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'نظام الحضور والتقييم الأكاديمي',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'سجّل دخولك للاطّلاع على مقرراتك وسكاشنك ودرجاتك وسجل حضورك',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم أو رقم الكارنيه',
                        hintText: 'e.g. doc_rasha01, ta_nehad00, 20720236007',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        hintText: 'Doctor@123 / TA@123 / University ID',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول (Sign in)'),
                      onPressed: () {
                        if (idController.text.trim().isEmpty) {
                          notice('يرجى إدخال اسم المستخدم أو رقم الكارنيه');
                          return;
                        }
                        final ok = demo.loginWithCredentials(
                          idController.text,
                          passwordController.text,
                        );
                        if (ok) {
                          setState(() {});
                        } else {
                          notice('بيانات الدخول غير صحيحة، يرجى مراجعة البيانات.');
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'أو اختر حساباً معتمداً للتجربة السريعة:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.menu_book, size: 16),
                          label: const Text('د. رشا محمود (Doctor)'),
                          onPressed: () {
                            idController.text = 'doc_rasha01';
                            passwordController.text = 'Doctor@123';
                            demo.loginWithCredentials('doc_rasha01', 'Doctor@123');
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.menu_book, size: 16),
                          label: const Text('د. ممدوح فاروق (Doctor)'),
                          onPressed: () {
                            idController.text = 'doc_mamdouh12';
                            passwordController.text = 'Doctor@123';
                            demo.loginWithCredentials('doc_mamdouh12', 'Doctor@123');
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.groups, size: 16),
                          label: const Text('م. نهاد عبد الرحمن (TA)'),
                          onPressed: () {
                            idController.text = 'ta_nehad00';
                            passwordController.text = 'TA@123';
                            demo.loginWithCredentials('ta_nehad00', 'TA@123');
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.groups, size: 16),
                          label: const Text('م. أحمد هشام (TA)'),
                          onPressed: () {
                            idController.text = 'ta_ahmed25';
                            passwordController.text = 'TA@123';
                            demo.loginWithCredentials('ta_ahmed25', 'TA@123');
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: const Text('احمد عبد العليم (Student)'),
                          onPressed: () {
                            idController.text = '20720236007';
                            passwordController.text = '20720236007';
                            demo.loginWithCredentials('20720236007', '20720236007');
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: const Text('ادهم محمد جلال (Student)'),
                          onPressed: () {
                            idController.text = '20720236014';
                            passwordController.text = '20720236014';
                            demo.loginWithCredentials('20720236014', '20720236014');
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => _roleSheet(context),
                      child: const Text('عرض قائمة الأدوار'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _roleSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختيار دور سريع بالحسابات المعتمدة',
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('د. رشا محمود كامل (Doctor)'),
                  subtitle: const Text('doc_rasha01 · رئيس قسم علوم الحاسب CS'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheet);
                    demo.selectRealRole(Role.doctor);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('م. نهاد عبد الرحمن (Teaching Assistant)'),
                  subtitle: const Text('ta_nehad00 · معيد CS381 سكشن 1'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheet);
                    demo.selectRealRole(Role.ta);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('احمد عبد العليم سيد احمد (Student)'),
                  subtitle: const Text('20720236007 · هندسة البرمجيات SE سكشن 1'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheet);
                    demo.selectRealRole(Role.student);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      );

  Widget _shell(BuildContext context) {
    final role = demo.role!;
    final labels = role == Role.student
        ? ['Home', 'Courses', 'Scan', 'Progress', 'More']
        : role == Role.ta
            ? ['Home', 'Sections', 'Grades', 'More']
            : ['Home', 'Courses', 'Attendance', 'Grades', 'More'];
    final icons = role == Role.student
        ? [
            Icons.home_outlined,
            Icons.menu_book_outlined,
            Icons.qr_code_scanner,
            Icons.show_chart,
            Icons.more_horiz,
          ]
        : role == Role.ta
            ? [
                Icons.home_outlined,
                Icons.groups_outlined,
                Icons.grade_outlined,
                Icons.more_horiz,
              ]
            : [
                Icons.home_outlined,
                Icons.menu_book_outlined,
                Icons.event_available_outlined,
                Icons.grade_outlined,
                Icons.more_horiz,
              ];
    final current = tab.clamp(0, labels.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labels[current],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              demo.courses[demo.courseIndex].term,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Choose course',
            onPressed: () => _courseSheet(context),
            icon: const Icon(Icons.swap_horiz),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: KeyedSubtree(
          key: ValueKey('${role.name}-$current'),
          child: _tabBody(context, current),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
    );
  }

  Widget _tabBody(BuildContext context, int current) {
    switch (demo.role!) {
      case Role.student:
        return [
          studentHome(context),
          courseList(context),
          scanPage(context),
          progressPage(context),
          morePage(context),
        ][current];
      case Role.ta:
        return [
          taHome(context),
          sectionsPage(context),
          taGradesPage(context),
          morePage(context),
        ][current];
      case Role.doctor:
        return [
          doctorHome(context),
          courseList(context),
          doctorAttendance(context),
          doctorGrades(context),
          morePage(context),
        ][current];
    }
  }

  void _courseSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select offering · Fall 2026',
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
                for (var i = 0; i < demo.courses.length; i++)
                  ListTile(
                    minTileHeight: 56,
                    selected: i == demo.courseIndex,
                    title: Text(
                      '${demo.courses[i].code} · ${demo.courses[i].title}',
                    ),
                    subtitle: Text(demo.courses[i].section),
                    onTap: () => setScope(i),
                  ),
              ],
            ),
          )),
        ),
      );

  Future<void> addCourse(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var code = '';
    var title = '';
    var section = '';
    final course = await showDialog<Course>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Add demo course'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Course code'),
                  onChanged: (value) => code = value.trim().toUpperCase(),
                  validator: (value) {
                    final normalized = value?.trim().toUpperCase() ?? '';
                    if (normalized.isEmpty) return 'Enter a course code.';
                    if (demo.courses.any((item) => item.code == normalized)) {
                      return 'This course code already exists.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Course title'),
                  onChanged: (value) => title = value.trim(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a course title.'
                      : null,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Section'),
                  onChanged: (value) => section = value.trim(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a section.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialog,
                Course(code, title, 'Fall 2026', section, 'Dr. Salma Hassan'),
              );
            },
            child: const Text('Add course'),
          ),
        ],
      ),
    );
    if (course == null || !mounted) return;
    setState(() {
      demo.courses.add(course);
      demo.resetScope(demo.courses.length - 1);
    });
  }

  Widget studentHome(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'مرحباً، ${demo.currentUserName}',
            '${demo.currentUserDepartment} · ${demo.currentUserSection}',
          ),
          const DemoBanner(),
          if (demo.activeQuiz != null) ...[
            Card(
              color: demo.activeQuiz!.isCompleted
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          demo.activeQuiz!.isCompleted
                              ? Icons.task_alt
                              : Icons.notifications_active_outlined,
                          color: demo.activeQuiz!.isCompleted
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            demo.activeQuiz!.isCompleted
                                ? 'Section Quiz Completed'
                                : 'Live Section Quiz Alert',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${demo.activeQuiz!.durationMinutes} min',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${demo.activeQuiz!.title} · ${demo.activeQuiz!.section}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      demo.activeQuiz!.isCompleted
                          ? 'Your score: ${demo.activeQuiz!.studentScore?.toStringAsFixed(1) ?? '—'} / ${demo.activeQuiz!.questions.length} points'
                          : '${demo.activeQuiz!.questions.length} randomized questions from test bank.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => open(
                        demo.activeQuiz!.title,
                        quizRunnerPage(context),
                      ),
                      icon: Icon(
                        demo.activeQuiz!.isCompleted
                            ? Icons.visibility_outlined
                            : Icons.timer_outlined,
                      ),
                      label: Text(
                        demo.activeQuiz!.isCompleted
                            ? 'Review submission'
                            : 'Start timed quiz',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SectionTitle('Current course'),
          courseCard(context, demo.courses[demo.courseIndex]),
          const SectionTitle('Quick actions'),
          ActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan lecture QR',
            detail: 'Scanner preview only',
            onTap: () => setState(() => tab = 2),
          ),
          ActionCard(
            icon: Icons.insights_outlined,
            title: 'View progress',
            detail: 'Attendance and published grades',
            onTap: () => setState(() => tab = 3),
          ),
          const SectionTitle('Recent activity'),
          const StatusRow(
            title: 'Quiz 2',
            subtitle: 'Published · 0 / 10 raw points',
            status: 'Recorded zero',
            icon: Icons.check_circle_outline,
          ),
          StatusRow(
            title: 'Lecture 10',
            subtitle: '15 Oct · ${demo.courses[demo.courseIndex].title}',
            status: 'Present',
            icon: Icons.check_circle_outline,
          ),
        ],
      );

  Widget courseList(BuildContext context) {
    var search = '';
    return StatefulBuilder(builder: (context, refresh) {
      final filtered = demo.courses
          .where((course) => '${course.code} ${course.title}'
              .toLowerCase()
              .contains(search.toLowerCase()))
          .toList();
      return PageContent(children: [
        greeting(
            context,
            demo.role == Role.student ? 'My courses' : 'Assigned courses',
            'Fall 2026'),
        TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), labelText: 'Search courses'),
            onChanged: (value) => refresh(() => search = value)),
        if (demo.role == Role.doctor)
          FilledButton.icon(
            onPressed: () => addCourse(context),
            icon: const Icon(Icons.add),
            label: const Text('Add demo course'),
          ),
        if (filtered.isEmpty)
          const EmptyPanel(
              'No matching courses', 'Try a different course title or code.'),
        for (final course in filtered) courseCard(context, course),
      ]);
    });
  }

  Widget courseCard(BuildContext context, Course course) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Brand.radius),
          onTap: () {
            final index = demo.courses.indexOf(course);
            if (index != demo.courseIndex) {
              setState(() => demo.resetScope(index));
            }
            open(course.code, courseDetail(context, course));
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ScopeChip(course.code),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  course.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  '${course.term} · ${course.section}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );

  Widget courseDetail(BuildContext context, Course course) => PageContent(
        children: [
          Text(
            course.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text('${course.code} · ${course.term} · ${course.section}'),
          Text(course.instructor),
          const SizedBox(height: 8),
          const DemoBanner(),
          if (demo.role == Role.student) ...[
            const SectionTitle('Attendance'),
            ActionCard(
              icon: Icons.event_available_outlined,
              title: 'Lecture history',
              detail: '1 present · 1 absent · 1 excused',
              onTap: () => open('Lecture history', historyPage('Lecture')),
            ),
            ActionCard(
              icon: Icons.groups_outlined,
              title: 'Section history',
              detail: '2 present · 1 absent',
              onTap: () => open('Section history', historyPage('Section')),
            ),
            const SectionTitle('Grades'),
            ActionCard(
              icon: Icons.bar_chart,
              title: 'Grade breakdown',
              detail: 'Published and pending results',
              onTap: () => open('Grade breakdown', gradeBreakdown(context)),
            ),
          ] else if (demo.role == Role.ta) ...[
            ActionCard(
              icon: Icons.people_outline,
              title: 'Section roster',
              detail: '${MockData.students.length} demo students',
              onTap: () => open('Section roster', rosterPage(context)),
            ),
            ActionCard(
              icon: Icons.fact_check_outlined,
              title: 'Take attendance',
              detail: 'Create a local roll draft',
              onTap: () => open('Manual attendance', rollPage(context)),
            ),
            ActionCard(
              icon: Icons.edit_note,
              title: 'Quiz scores',
              detail: 'Enter raw marks',
              onTap: () => open('Quiz scores', scoreEntryPage(context)),
            ),
          ] else ...[
            ActionCard(
              icon: Icons.people_outline,
              title: 'Course roster',
              detail: '${MockData.students.length} demo students',
              onTap: () => open('Course roster', rosterPage(context)),
            ),
            ActionCard(
              icon: Icons.supervisor_account_outlined,
              title: 'Teaching assignments',
              detail: 'Section and capability summary',
              onTap: () =>
                  open('Teaching assignments', assignmentsPage(context)),
            ),
            ActionCard(
              icon: Icons.tune,
              title: 'Grade allocation',
              detail: 'Draft policy preview',
              onTap: () => open('Grade allocation', policyPage(context)),
            ),
            ActionCard(
              icon: Icons.qr_code_2,
              title: 'Lecture session',
              detail: 'Simulated QR display',
              onTap: () => open('Lecture attendance', lecturePage(context)),
            ),
            ActionCard(
              icon: Icons.assessment_outlined,
              title: 'Reports',
              detail: 'Local sample aggregates',
              onTap: () => open('Reports', reportsPage(context)),
            ),
          ],
        ],
      );

  Widget scanPage(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'Scan lecture QR',
            'Choose the correct course before scanning.',
          ),
          const DemoBanner(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    height: 210,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Camera preview is simulated in this phase.'),
                  const SizedBox(height: 8),
                  Text(
                    'No QR is read and no attendance is submitted.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () =>
                notice('Demo scanner only. No attendance was submitted.'),
            icon: const Icon(Icons.info_outline),
            label: const Text('Preview scanner state'),
          ),
        ],
      );

  Widget historyPage(String kind) {
    final items = MockData.sessions.where((s) => s.kind == kind);
    final rate = attendanceRate(items);
    return PageContent(
      children: [
        const DemoBanner(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eligible attendance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  rate == null
                      ? 'No eligible sessions'
                      : '${(rate * 100).round()}%',
                ),
                const Text(
                  'Cancelled, unfinalized and excused sessions are excluded from the denominator.',
                ),
              ],
            ),
          ),
        ),
        for (final s in items)
          StatusRow(
            title: s.title,
            subtitle: '${s.date} · $kind',
            status: s.cancelled
                ? 'Cancelled'
                : !s.finalized
                    ? 'Unfinalized'
                    : markLabel(s.mark),
            icon: s.cancelled
                ? Icons.event_busy
                : s.finalized
                    ? Icons.event_available
                    : Icons.pending_outlined,
          ),
      ],
    );
  }

  Widget progressPage(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'Academic progress',
            'Published results for ${demo.courses[demo.courseIndex].code}',
          ),
          const DemoBanner(),
          const StatusRow(
            title: 'Grade status',
            subtitle: 'Final exam is pending publication.',
            status: 'Incomplete',
            icon: Icons.pending_outlined,
          ),
          const SectionTitle('Attendance'),
          ActionCard(
            icon: Icons.event_note,
            title: 'Lectures',
            detail: '50% · 1 of 2 eligible',
            onTap: () => open('Lecture history', historyPage('Lecture')),
          ),
          ActionCard(
            icon: Icons.groups_outlined,
            title: 'Practical section',
            detail: '67% · 2 of 3 eligible',
            onTap: () => open('Section history', historyPage('Section')),
          ),
          const SectionTitle('Grades'),
          ActionCard(
            icon: Icons.grade_outlined,
            title: 'View grade breakdown',
            detail: 'Raw quiz scores and allocated points are separate',
            onTap: () => open('Grade breakdown', gradeBreakdown(context)),
          ),
        ],
      );

  Widget gradeBreakdown(BuildContext context) {
    final quiz = normalizedPoints(
      MockData.assessments.where((a) => a.category == 'Quizzes'),
      5,
    );
    final lectureRate =
        attendanceRate(MockData.sessions.where((s) => s.kind == 'Lecture'));
    final sectionRate =
        attendanceRate(MockData.sessions.where((s) => s.kind == 'Section'));
    return PageContent(
      children: [
        const DemoBanner(),
        const StatusRow(
          title: 'Course total',
          subtitle: 'Policy v1 · final exam unpublished',
          status: 'No official total',
          icon: Icons.info_outline,
        ),
        const SectionTitle('Published categories'),
        const StatusRow(
          title: 'Midterm',
          subtitle: '16 / 20 allocated points',
          status: 'Published',
          icon: Icons.check_circle_outline,
        ),
        const StatusRow(
          title: 'Project',
          subtitle: '12 / 15 allocated points',
          status: 'Published',
          icon: Icons.check_circle_outline,
        ),
        StatusRow(
          title: 'Lecture attendance',
          subtitle: lectureRate == null
              ? 'No eligible sessions'
              : '${(5 * lectureRate).toStringAsFixed(2)} / 5 sample allocated points · 1 of 2 eligible',
          status: 'Sample proportional mode',
          icon: Icons.event_note,
        ),
        StatusRow(
          title: 'Section attendance',
          subtitle: sectionRate == null
              ? 'No eligible sessions'
              : '${(5 * sectionRate).toStringAsFixed(2)} / 5 sample allocated points · 2 of 3 eligible',
          status: 'Sample proportional mode',
          icon: Icons.groups_outlined,
        ),
        StatusRow(
          title: 'Quizzes',
          subtitle:
              '${quiz?.toStringAsFixed(2) ?? 'Unavailable'} / 5 allocated points · normalized pool',
          status: 'Incomplete',
          icon: Icons.pending_outlined,
        ),
        const StatusRow(
          title: 'Final exam',
          subtitle: '50 allocated points',
          status: 'Pending publication',
          icon: Icons.lock_outline,
        ),
        const SectionTitle('Quiz raw scores'),
        for (final a in MockData.assessments.where(
          (a) => a.category == 'Quizzes',
        ))
          StatusRow(
            title: a.title,
            subtitle: a.state == ScoreState.recorded
                ? '${a.rawScore!.toStringAsFixed(0)} / ${a.rawMax.toStringAsFixed(0)} raw points'
                : 'No recorded result',
            status: a.state == ScoreState.recorded ? 'Published' : 'Not graded',
            icon: a.state == ScoreState.recorded
                ? Icons.check_circle_outline
                : Icons.pending_outlined,
          ),
        Text(
          'A recorded zero contributes to the quiz denominator. An unrecorded result does not. The course total stays incomplete until all categories are available.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget taHome(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'مرحباً، ${demo.currentUserName}',
            'متابعة الحضور ورصد الدرجات والسكاشن',
          ),
          const DemoBanner(),
          const SectionTitle('Selected assignment'),
          courseCard(context, demo.courses[demo.courseIndex]),
          const SectionTitle('Actions'),
          ActionCard(
            icon: Icons.fact_check_outlined,
            title: 'Take attendance',
            detail:
                '${demo.courses[demo.courseIndex].section} · draft roll',
            onTap: () => open('Manual attendance', rollPage(context)),
          ),
          ActionCard(
            icon: Icons.edit_note,
            title: 'Enter quiz scores',
            detail: 'Raw scores are validated against item maximum',
            onTap: () => open('Quiz scores', scoreEntryPage(context)),
          ),
        ],
      );

  Widget sectionsPage(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'Assigned sections',
            'Showing all sections for ${demo.currentUserName}',
          ),
          for (final course in demo.courses)
            ActionCard(
              icon: Icons.groups_outlined,
              title: '${course.code} · ${course.section}',
              detail: course.title,
              onTap: () {
                final index = demo.courses.indexOf(course);
                if (index != demo.courseIndex) {
                  setState(() => demo.resetScope(index));
                }
                open('Section overview', courseDetail(context, course));
              },
            ),
        ],
      );

  Widget rosterPage(BuildContext context) {
    var search = '';
    return StatefulBuilder(
      builder: (context, refresh) {
        final roster = demo.currentStudents;
        final filtered = roster
            .where((s) => '${s.nameAr} ${s.nameEn} ${s.id}'
                .toLowerCase()
                .contains(search.toLowerCase()))
            .toList();
        return PageContent(
          children: [
            const DemoBanner(),
            Text(
              '${roster.length} students enrolled · ${demo.courses[demo.courseIndex].section}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search student name or ID',
              ),
              onChanged: (value) => refresh(() => search = value),
            ),
            if (filtered.isEmpty)
              const EmptyPanel(
                  'No matching students', 'Try another name or university ID.'),
            for (final student in filtered)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      student.nameAr.isNotEmpty
                          ? student.nameAr.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join()
                          : (student.nameEn.isNotEmpty ? student.nameEn.substring(0, 1) : 'S'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(student.nameAr.isNotEmpty ? student.nameAr : student.nameEn),
                  subtitle: Text('ID: ${student.id} · ${student.department} · ${student.section} · GPA ${student.gpa.toStringAsFixed(2)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        demo.role == Role.ta
                            ? demo.courses[demo.courseIndex].section
                            : 'Enrolled',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (student.phone != null)
                        Text(
                          student.phone!,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget rollPage(BuildContext context) => StatefulBuilder(
        builder: (context, refresh) {
          final roster = demo.currentStudents;
          final count = <Mark, int>{
            for (final mark in Mark.values)
              mark: roster
                  .where((s) => (demo.marks[s.id] ?? Mark.unset) == mark)
                  .length,
          };
          return PageContent(
            children: [
              const DemoBanner(),
              Text(
                '${demo.courses[demo.courseIndex].code} · ${demo.courses[demo.courseIndex].section}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${roster.length} students · Present ${count[Mark.present]} · Absent ${count[Mark.absent]} · Excused ${count[Mark.excused]} · Unset ${count[Mark.unset]}',
              ),
              if (demo.rollFinalized)
                const StatusRow(
                  title: 'Local roll finalized',
                  subtitle: 'Prototype confirmation only',
                  status: 'Finalized',
                  icon: Icons.check_circle_outline,
                ),
              OutlinedButton(
                onPressed: demo.rollFinalized
                    ? null
                    : () async {
                        final confirmed = await confirm(
                          context,
                          'Mark all absent?',
                          'You can adjust each student before finalizing.',
                        );
                        if (confirmed && context.mounted) {
                          refresh(() {
                            for (final student in roster) {
                              demo.marks[student.id] = Mark.absent;
                            }
                          });
                        }
                      },
                child: const Text('Mark all absent'),
              ),
              for (final student in roster)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.nameAr.isNotEmpty ? student.nameAr : student.nameEn,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${student.id} · ${student.department} · ${student.section}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: switch (demo.marks[student.id] ?? Mark.unset) {
                                  Mark.present => Colors.green.withValues(alpha: 0.15),
                                  Mark.absent  => Colors.red.withValues(alpha: 0.15),
                                  Mark.excused => Colors.orange.withValues(alpha: 0.15),
                                  Mark.unset   => Colors.grey.withValues(alpha: 0.10),
                                },
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                markLabel(demo.marks[student.id] ?? Mark.unset),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final mark in [
                              Mark.present,
                              Mark.absent,
                              Mark.excused,
                            ])
                              ChoiceChip(
                                label: Text(markLabel(mark)),
                                selected: demo.marks[student.id] == mark,
                                onSelected: demo.rollFinalized
                                    ? null
                                    : (_) => refresh(
                                          () => demo.marks[student.id] = mark,
                                        ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                onPressed: demo.rollFinalized
                    ? null
                    : () async {
                        if (count[Mark.unset]! > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Resolve every unset student before finalizing.',
                              ),
                            ),
                          );
                          return;
                        }
                        final confirmed = await confirm(
                          context,
                          'Finalize local roll?',
                          'This saves only in memory for this demo.',
                        );
                        if (confirmed && context.mounted) {
                          refresh(() => demo.rollFinalized = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Local demo roll finalized.'),
                            ),
                          );
                        }
                      },
                child: const Text('Review and finalize'),
              ),
            ],
          );
        },
      );

  Widget taGradesPage(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'Grade work',
            'Assigned assessments · ${demo.courses[demo.courseIndex].code}',
          ),
          const DemoBanner(),
          ActionCard(
            icon: Icons.add_task,
            title: 'Create quiz draft',
            detail: 'Local assessment preview',
            onTap: () => open('Create quiz', quizCreationPage(context)),
          ),
          ActionCard(
            icon: Icons.edit_note,
            title: 'Quiz 1 · scores',
            detail: 'Maximum 10 raw points',
            onTap: () => open('Quiz score entry', scoreEntryPage(context)),
          ),
          ActionCard(
            icon: Icons.quiz_outlined,
            title: 'Test bank',
            detail:
                '${demo.questionBank.length} questions available for random selection',
            onTap: () => open('Test bank', questionBankPage(context)),
          ),
          ActionCard(
            icon: Icons.auto_awesome,
            title: 'Generate section quiz',
            detail: demo.activeQuiz == null
                ? 'Random selection from test bank with timer & section notification'
                : 'Active: ${demo.activeQuiz!.title} (${demo.activeQuiz!.section} · ${demo.activeQuiz!.durationMinutes} min)',
            onTap: () =>
                open('Generate section quiz', quizGeneratorPage(context)),
          ),
        ],
      );

  Widget quizCreationPage(BuildContext context) {
    final title = TextEditingController();
    final max = TextEditingController();
    return PageContent(
      children: [
        const DemoBanner(),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Quiz title'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: max,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Raw maximum points'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(max.text);
            if (title.text.trim().isEmpty || value == null || value <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a title and a positive maximum.'),
                ),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Local quiz draft “${title.text.trim()}” created.',
                ),
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Create local draft'),
        ),
      ],
    );
  }

  Widget scoreEntryPage(BuildContext context) {
    final roster = demo.currentStudents;
    final controllers = {
      for (final student in roster)
        student.id: TextEditingController(
          text: demo.scores[student.id]?.toString(),
        ),
    };
    final maxScore = 10.0;
    return StatefulBuilder(
      builder: (context, refresh) => PageContent(
        children: [
          const DemoBanner(),
          Text(
            'Quiz 1 · ${maxScore.toStringAsFixed(0)} raw points maximum',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${roster.length} students · Blank = unrecorded. Typed 0 = recorded zero.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final student in roster)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      child: Text(
                        student.nameAr.isNotEmpty
                            ? student.nameAr.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join()
                            : (student.nameEn.isNotEmpty ? student.nameEn.substring(0, 1) : 'S'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.nameAr.isNotEmpty ? student.nameAr : student.nameEn),
                          Text(
                            '${student.id} · ${student.department} · ${student.section}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 94,
                      child: TextField(
                        controller: controllers[student.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Score',
                          hintText: '—',
                        ),
                        onChanged: (_) => refresh(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          FilledButton(
            onPressed: () {
              final values = <String, double?>{};
              for (final entry in controllers.entries) {
                final raw = entry.value.text.trim();
                final score = raw.isEmpty ? null : double.tryParse(raw);
                if (raw.isNotEmpty &&
                    (score == null || score < 0 || score > maxScore)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Scores must be between 0 and ${maxScore.toStringAsFixed(0)}, or blank.',
                      ),
                    ),
                  );
                  return;
                }
                values[entry.key] = score;
              }
              if (values.entries.every(
                (entry) => demo.scores[entry.key] == entry.value,
              )) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No score changes to save.')),
                );
                return;
              }
              refresh(() => demo.scores.addAll(values));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scores saved in this demo only.'),
                ),
              );
            },
            child: const Text('Save local scores'),
          ),
        ],
      ),
    );
  }

  Widget questionBankPage(BuildContext context) => StatefulBuilder(
        builder: (context, refresh) => PageContent(
          children: [
            const DemoBanner(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Test bank · ${demo.questionBank.length} questions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final newQ = await _showAddQuestionDialog(context);
                    if (newQ != null) {
                      refresh(() => demo.questionBank.add(newQ));
                      notice('Question added to test bank.');
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add question'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < demo.questionBank.length; i++) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScopeChip('Q${i + 1}'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              demo.questionBank[i].prompt,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final opt in demo.questionBank[i].options)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                opt.isCorrect
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: opt.isCorrect ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${opt.id.toUpperCase()}. ${opt.text}',
                                  style: TextStyle(
                                    fontWeight: opt.isCorrect
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: opt.isCorrect ? Colors.green : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Future<QuestionItem?> _showAddQuestionDialog(BuildContext context) async {
    final promptCtrl = TextEditingController();
    final optA = TextEditingController(text: 'Option A');
    final optB = TextEditingController(text: 'Option B');
    final optC = TextEditingController(text: 'Option C');
    final optD = TextEditingController(text: 'Option D');
    var correct = 'a';
    return showDialog<QuestionItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add test bank question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Question prompt'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                for (final id in ['a', 'b', 'c', 'd']) ...[
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          correct == id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: correct == id
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onPressed: () => setDState(() => correct = id),
                      ),
                      Expanded(
                        child: TextField(
                          controller: id == 'a'
                              ? optA
                              : id == 'b'
                                  ? optB
                                  : id == 'c'
                                      ? optC
                                      : optD,
                          decoration: InputDecoration(
                            labelText: 'Option ${id.toUpperCase()}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (promptCtrl.text.trim().isEmpty) return;
                final q = QuestionItem(
                  'q_${DateTime.now().millisecondsSinceEpoch}',
                  promptCtrl.text.trim(),
                  [
                    QuestionOption('a', optA.text.trim(), correct == 'a'),
                    QuestionOption('b', optB.text.trim(), correct == 'b'),
                    QuestionOption('c', optC.text.trim(), correct == 'c'),
                    QuestionOption('d', optD.text.trim(), correct == 'd'),
                  ],
                );
                Navigator.pop(ctx, q);
              },
              child: const Text('Save to bank'),
            ),
          ],
        ),
      ),
    );
  }

  Widget quizGeneratorPage(BuildContext context) {
    var title = 'Weekly Section Quiz';
    var selectedSection = demo.courses[demo.courseIndex].section;
    var questionCount = 5.clamp(1, demo.questionBank.length);
    var durationMinutes = 20;
    var notifyGroup = true;

    return StatefulBuilder(
      builder: (context, refresh) => PageContent(
        children: [
          const DemoBanner(),
          Text(
            'Configure section quiz',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Select questions randomly from test bank and notify target section.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: title,
            decoration: const InputDecoration(labelText: 'Quiz title'),
            onChanged: (v) => title = v.trim(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedSection,
            decoration:
                const InputDecoration(labelText: 'Target group / section'),
            items: [
              for (final c in demo.courses)
                DropdownMenuItem(value: c.section, child: Text(c.section)),
            ],
            onChanged: (v) {
              if (v != null) refresh(() => selectedSection = v);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Random questions to pick: $questionCount of ${demo.questionBank.length} available',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: questionCount.toDouble(),
            min: 1,
            max: demo.questionBank.length.toDouble(),
            divisions: demo.questionBank.length > 1
                ? demo.questionBank.length - 1
                : 1,
            label: '$questionCount questions',
            onChanged: (v) => refresh(() => questionCount = v.round()),
          ),
          const SizedBox(height: 8),
          Text(
            'Quiz time limit: $durationMinutes minutes',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: durationMinutes.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$durationMinutes min',
            onChanged: (v) => refresh(() => durationMinutes = v.round()),
          ),
          SwitchListTile(
            title: const Text('Send notification to section'),
            subtitle: Text('Alert all students enrolled in $selectedSection'),
            value: notifyGroup,
            onChanged: (v) => refresh(() => notifyGroup = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              demo.publishSectionQuiz(
                title: title.isEmpty ? 'Section Quiz' : title,
                section: selectedSection,
                questionCount: questionCount,
                durationMinutes: durationMinutes,
              );
              notice(
                'Quiz published! $questionCount questions randomly drawn. Notification sent to $selectedSection.',
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Generate & send to section'),
          ),
        ],
      ),
    );
  }

  Widget quizRunnerPage(BuildContext context) => _QuizRunnerView(
        quiz: demo.activeQuiz!,
        onComplete: (score) {
          setState(() {
            demo.activeQuiz!.studentScore = score;
            demo.activeQuiz!.isCompleted = true;
            demo.scores['20240112'] =
                (score / demo.activeQuiz!.questions.length) * 10;
          });
        },
      );

  Widget doctorHome(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'مرحباً، ${demo.currentUserName}',
            'متابعة المحاضرات والسكاشن ونسب الحضور والغياب',
          ),
          const DemoBanner(),
          const SectionTitle('Selected course'),
          courseCard(context, demo.courses[demo.courseIndex]),
          const SectionTitle('Teaching actions'),
          ActionCard(
            icon: Icons.qr_code_2,
            title: 'Lecture attendance',
            detail: demo.lectureOpen
                ? 'Local session open'
                : 'Create a simulated session',
            onTap: () => open('Lecture attendance', lecturePage(context)),
          ),
          ActionCard(
            icon: Icons.tune,
            title: 'Grade allocation',
            detail: 'Review six course categories',
            onTap: () => open('Grade allocation', policyPage(context)),
          ),
          ActionCard(
            icon: Icons.assessment_outlined,
            title: 'Course report',
            detail: 'Attendance and grade summary',
            onTap: () => open('Reports', reportsPage(context)),
          ),
          ActionCard(
            icon: Icons.supervisor_account_outlined,
            title: 'Teaching assignments',
            detail: 'View section and capability grants',
            onTap: () => open('Teaching assignments', assignmentsPage(context)),
          ),
        ],
      );

  Widget assignmentsPage(BuildContext context) {
    final currentCourseCode = demo.courses.isNotEmpty ? demo.courses[demo.courseIndex].code : 'CS381';
    final courseObj = CollegeDatabase.courses.firstWhere(
      (c) => c.code == currentCourseCode,
      orElse: () => CollegeDatabase.courses.first,
    );
    final cSections = CollegeDatabase.courseSections
        .where((cs) => cs.courseId == courseObj.id)
        .toList();

    return PageContent(children: [
      Text('Assigned teaching staff · $currentCourseCode',
          style: Theme.of(context).textTheme.titleLarge),
      if (cSections.isEmpty)
        const Text('No assigned teaching assistants.')
      else
        for (final cs in cSections) ...[
          Builder(builder: (ctx) {
            final ta = CollegeDatabase.userMap[cs.taId];
            final ds = CollegeDatabase.departmentSectionMap[cs.departmentSectionId];
            final dept = ds != null ? CollegeDatabase.departmentMap[ds.departmentId] : null;
            final studentCount = CollegeDatabase.getStudentsForCourseSection(cs.id).length;
            return StatusRow(
              title: '${ta?.fullName ?? "TA"} · Teaching Assistant',
              subtitle: 'Section ${ds?.number ?? 1} (${dept?.code ?? ""}) · $studentCount enrolled students',
              status: 'Assigned',
              icon: Icons.person_outline,
            );
          }),
        ],
    ]);
  }

  Widget doctorAttendance(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'Attendance',
            '${demo.courses[demo.courseIndex].code} · lecture sessions',
          ),
          const DemoBanner(),
          ActionCard(
            icon: Icons.add_circle_outline,
            title: 'New lecture session',
            detail: 'Simulated QR display and counts',
            onTap: () => open('Lecture session', lecturePage(context)),
          ),
          const SectionTitle('Recent sessions'),
          for (final s in MockData.sessions.where((s) => s.kind == 'Lecture'))
            StatusRow(
              title: s.title,
              subtitle: s.date,
              status: s.cancelled
                  ? 'Cancelled'
                  : s.finalized
                      ? 'Finalized'
                      : 'Unfinalized',
              icon: s.cancelled ? Icons.event_busy : Icons.event_note,
            ),
        ],
      );

  Widget lecturePage(BuildContext context) => StatefulBuilder(
        builder: (context, refresh) => PageContent(
          children: [
            const DemoBanner(),
            Text(
              '${demo.courses[demo.courseIndex].code} · Lecture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            StatusRow(
              title: 'Session status',
              subtitle: 'Local preview · no server token',
              status: demo.lectureOpen ? 'Open in demo' : 'Closed',
              icon: demo.lectureOpen
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            Card(
              child: SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        demo.lectureOpen ? Icons.qr_code_2 : Icons.qr_code,
                        size: 110,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      const Text('QR display placeholder'),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              'This is not a scannable attendance credential.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            FilledButton(
              onPressed: () async {
                if (demo.lectureOpen) {
                  if (!await confirm(
                    context,
                    'Close local session?',
                    'No attendance records are submitted.',
                  )) {
                    return;
                  }
                }
                refresh(() => demo.lectureOpen = !demo.lectureOpen);
              },
              child: Text(
                demo.lectureOpen ? 'Close local session' : 'Open local session',
              ),
            ),
          ],
        ),
      );

  Widget doctorGrades(BuildContext context) => PageContent(
        children: [
          greeting(
            context,
            'Grades',
            '${demo.courses[demo.courseIndex].code} · policy and assessments',
          ),
          const DemoBanner(),
          ActionCard(
            icon: Icons.tune,
            title: 'Grade allocation',
            detail:
                'Total ${demo.allocations.values.fold<double>(0, (a, b) => a + b).toStringAsFixed(0)} / 100',
            onTap: () => open('Grade allocation', policyPage(context)),
          ),
          ActionCard(
            icon: Icons.edit_note,
            title: 'Gradebook',
            detail: 'Quiz 1 raw scores',
            onTap: () => open('Gradebook', scoreEntryPage(context)),
          ),
          const SectionTitle('Assessments'),
          for (final a in MockData.assessments)
            StatusRow(
              title: a.title,
              subtitle:
                  '${a.category} · ${a.rawMax.toStringAsFixed(0)} raw max',
              status: a.state == ScoreState.unpublished
                  ? 'Unpublished'
                  : a.state == ScoreState.unrecorded
                      ? 'Not graded'
                      : 'Published',
              icon: Icons.assignment_outlined,
            ),
        ],
      );

  Widget policyPage(BuildContext context) => StatefulBuilder(
        builder: (context, refresh) {
          final total =
              demo.allocations.values.fold<double>(0, (a, b) => a + b);
          return PageContent(
            children: [
              const DemoBanner(),
              const StatusRow(
                title: 'Policy draft',
                subtitle: 'Local preview · course total 100',
                status: 'Not published',
                icon: Icons.edit_note,
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allocated ${total.toStringAsFixed(1)} / 100',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: (total / 100).clamp(0, 1)),
                      const SizedBox(height: 8),
                      Text(
                        total == 100
                            ? 'Balanced'
                            : '${(100 - total).abs().toStringAsFixed(1)} points ${total < 100 ? 'unallocated' : 'overallocated'}',
                      ),
                    ],
                  ),
                ),
              ),
              for (final name in demo.allocations.keys.toList())
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    title: Text(name),
                    subtitle: Text(
                      name == 'Quizzes'
                          ? 'Normalized raw score pool'
                          : name.contains('attendance')
                              ? 'Sample proportional mode · pending approval'
                              : 'Fixed allocation',
                    ),
                    trailing: Text(
                      '${demo.allocations[name]!.toStringAsFixed(1)} pts',
                    ),
                    onTap: () async {
                      var draft = demo.allocations[name]!.toStringAsFixed(1);
                      final value = await showDialog<double>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: Text('$name allocation'),
                          content: TextFormField(
                            initialValue: draft,
                            onChanged: (value) => draft = value,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Allocated points',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                dialog,
                                double.tryParse(draft),
                              ),
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      );
                      if (value != null && value >= 0 && context.mounted) {
                        refresh(() => demo.allocations[name] = value);
                      }
                    },
                  ),
                ),
              FilledButton(
                onPressed: total == 100
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Policy balanced. Publication requires the future server workflow.',
                            ),
                          ),
                        )
                    : null,
                child: const Text('Preview balanced draft'),
              ),
              Text(
                'Raw item maxima do not add to category allocations. Publication and version changes are unavailable in this local prototype.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      );

  Widget reportsPage(BuildContext context) => PageContent(
        children: [
          const DemoBanner(),
          Text(
            '${demo.courses[demo.courseIndex].code} report',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const StatusRow(
            title: 'Lecture attendance',
            subtitle: 'Finalized eligible sessions only',
            status: '1 / 2 present',
            icon: Icons.event_note,
          ),
          const StatusRow(
            title: 'Section attendance',
            subtitle: 'Finalized eligible sessions only',
            status: '2 / 3 present',
            icon: Icons.groups_outlined,
          ),
          const StatusRow(
            title: 'Grade publication',
            subtitle: 'Final exam pending',
            status: 'Incomplete',
            icon: Icons.grade_outlined,
          ),
          Text(
            'These are fixture summaries. Export and live analytics require the future API.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  Widget morePage(BuildContext context) => PageContent(
        children: [
          greeting(context, 'More', 'Account and app preferences'),
          const DemoBanner(),
          ActionCard(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            detail: 'Published results and attendance updates',
            onTap: () => open(
              'Notifications',
              PageContent(
                children: const [
                  StatusRow(
                    title: 'Quiz 2 published',
                    subtitle: 'CS301 · 14 Oct',
                    status: 'Read',
                    icon: Icons.notifications_outlined,
                  ),
                  StatusRow(
                    title: 'Attendance updated',
                    subtitle: 'CS301 · 13 Oct',
                    status: 'Read',
                    icon: Icons.notifications_outlined,
                  ),
                ],
              ),
            ),
          ),
          ActionCard(
            icon: Icons.person_outline,
            title: 'Profile',
            detail: '${demo.currentUserName} · ${demo.role!.name.toUpperCase()}',
            onTap: () => open(
              'Profile',
              PageContent(
                children: [
                  StatusRow(
                    title: 'Full Name / الاسم الكامل',
                    subtitle: demo.currentUserName,
                    status: 'Active',
                    icon: Icons.person_outline,
                  ),
                  StatusRow(
                    title: 'ID / الكارنيه / اسم المستخدم',
                    subtitle: demo.currentUserId,
                    status: 'Official',
                    icon: Icons.badge_outlined,
                  ),
                  StatusRow(
                    title: 'Department / القسم',
                    subtitle: demo.currentUserDepartment,
                    status: demo.currentUserSection,
                    icon: Icons.account_balance_outlined,
                  ),
                  StatusRow(
                    title: 'Role / الدور الأكاديمي',
                    subtitle: switch (demo.role!) {
                      Role.doctor => 'عضو هيئة تدريس (Doctor)',
                      Role.ta => 'معيد / مدرس مساعد (TA)',
                      Role.student => 'طالب جامعي (Student)',
                    },
                    status: 'Verified',
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
          ),
          ActionCard(
            icon: Icons.account_balance_outlined,
            title: 'University database',
            detail: 'Departments, students, courses & faculty directory',
            onTap: () => open('University database', databaseExplorerPage(context)),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Dark theme'),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: demo.darkMode,
              onChanged: (value) => setState(() => demo.darkMode = value),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (await confirm(
                context,
                'Leave demo?',
                'All in-memory changes will be discarded.',
              )) {
                setState(() {
                  demo.resetDemo();
                  tab = 0;
                });
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out of demo'),
          ),
        ],
      );

  Widget databaseExplorerPage(BuildContext context) {
    var search = '';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.account_balance), text: 'Departments'),
            Tab(icon: Icon(Icons.people), text: 'Students'),
            Tab(icon: Icon(Icons.menu_book), text: 'Courses'),
            Tab(icon: Icon(Icons.badge), text: 'Faculty & TAs'),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Departments
            PageContent(
              children: [
                const DemoBanner(),
                Text(
                  'Academic departments',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Four core departments with 7 sections each (~25 students/section).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final dept in UniversityDatabase.departments)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ScopeChip(dept.code),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${dept.nameEn} · ${dept.nameAr}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Department Head: ${dept.head}'),
                          Text('Sections: ${dept.sectionsCount} practical groups (175 students capacity)'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Tab 2: Students
            StatefulBuilder(
              builder: (ctx, refresh) {
                final list = UniversityDatabase.allStudents.where((s) {
                  final q = search.toLowerCase();
                  return s.nameEn.toLowerCase().contains(q) ||
                      s.nameAr.contains(q) ||
                      s.id.contains(q) ||
                      s.department.toLowerCase().contains(q);
                }).toList();
                return PageContent(
                  children: [
                    const DemoBanner(),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search student name, ID, or department',
                      ),
                      onChanged: (v) => refresh(() => search = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Showing ${list.length} university students',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final s in list)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Text(
                                  s.nameEn.substring(0, 1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${s.nameEn} (${s.nameAr})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'ID: ${s.id} · ${s.department} · ${s.section}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      'GPA: ${s.gpa.toStringAsFixed(2)} · ${s.email}',
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Tab 3: Courses
            PageContent(
              children: [
                const DemoBanner(),
                Text(
                  'University course catalog',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Fall 2026 semester offerings across AI, CS, SE, and IS.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final course in demo.courses)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ScopeChip(course.code),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  course.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(course.term),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Instructor: ${course.instructor}'),
                          Text('Enrolled section: ${course.section}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Tab 4: Faculty & Staff
            PageContent(
              children: [
                const DemoBanner(),
                Text(
                  'Faculty & teaching assistants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final staff in UniversityDatabase.staff)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                staff.role.contains('Professor')
                                    ? Icons.school
                                    : Icons.supervisor_account,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${staff.nameEn} · ${staff.nameAr}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ScopeChip(staff.department),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(staff.role, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Assigned: ${staff.assignedSections}'),
                          Text(staff.email, style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget greeting(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}

String markLabel(Mark mark) => switch (mark) {
      Mark.present => 'Present',
      Mark.absent => 'Absent',
      Mark.excused => 'Excused',
      Mark.unset => 'Unset',
    };

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Brand.gutter,
              8,
              Brand.gutter,
              24,
            ),
            children: [
              for (final child in children)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12), child: child),
            ],
          ),
        ),
      );
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class ScopeChip extends StatelessWidget {
  const ScopeChip(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Brand.radius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(detail,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}

class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(this.title, this.message, {super.key});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.search_off_outlined,
                size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall)
          ])));
}

class _QuizRunnerView extends StatefulWidget {
  const _QuizRunnerView({
    required this.quiz,
    required this.onComplete,
  });
  final QuizSessionData quiz;
  final void Function(double score) onComplete;

  @override
  State<_QuizRunnerView> createState() => _QuizRunnerViewState();
}

class _QuizRunnerViewState extends State<_QuizRunnerView> {
  late int _remainingSeconds;
  Timer? _timer;
  final _answers = <String, String>{};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.quiz.durationMinutes * 60;
    if (!widget.quiz.isCompleted) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          timer.cancel();
          _submit(autoSubmit: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit({bool autoSubmit = false}) {
    _timer?.cancel();
    double earned = 0;
    for (final q in widget.quiz.questions) {
      final selectedId = _answers[q.id];
      if (selectedId != null) {
        final opt = q.options.firstWhere(
          (o) => o.id == selectedId,
          orElse: () => const QuestionOption('', '', false),
        );
        if (opt.isCorrect) earned += q.points;
      }
    }
    widget.onComplete(earned);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(autoSubmit ? 'Time is up!' : 'Quiz submitted!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your score: ${earned.toStringAsFixed(1)} / ${widget.quiz.questions.length} points',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your grade has been automatically computed and recorded in your course breakdown.',
              style: Theme.of(dialogCtx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
            },
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz.questions;
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final isWarning = _remainingSeconds < 180;

    return PageContent(
      children: [
        Card(
          color: widget.quiz.isCompleted
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : isWarning
                  ? Colors.red.shade50
                  : Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  widget.quiz.isCompleted
                      ? Icons.check_circle_outline
                      : Icons.alarm,
                  color: widget.quiz.isCompleted
                      ? Colors.green
                      : isWarning
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.quiz.isCompleted
                      ? 'Quiz completed'
                      : 'Time remaining: $minutes:$seconds',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.quiz.isCompleted
                        ? Colors.green
                        : isWarning
                            ? Colors.red
                            : null,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.quiz.section,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / questions.length,
        ),
        const SizedBox(height: 12),
        Text(
          'Question ${_currentIndex + 1} of ${questions.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Text(
          questions[_currentIndex].prompt,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        for (final opt in questions[_currentIndex].options) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radius),
              side: BorderSide(
                color: _answers[questions[_currentIndex].id] == opt.id
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ListTile(
              leading: Icon(
                _answers[questions[_currentIndex].id] == opt.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _answers[questions[_currentIndex].id] == opt.id
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(opt.text),
              onTap: widget.quiz.isCompleted
                  ? null
                  : () {
                      setState(
                        () => _answers[questions[_currentIndex].id] = opt.id,
                      );
                    },
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (_currentIndex > 0)
              OutlinedButton.icon(
                onPressed: () => setState(() => _currentIndex--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
            const Spacer(),
            if (_currentIndex < questions.length - 1)
              FilledButton.icon(
                onPressed: () => setState(() => _currentIndex++),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              )
            else if (!widget.quiz.isCompleted)
              FilledButton.icon(
                onPressed: () => _submit(),
                icon: const Icon(Icons.check),
                label: const Text('Submit quiz'),
              ),
          ],
        ),
      ],
    );
  }
}
