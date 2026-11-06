import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'data/api.dart';
import 'data/models.dart';
import 'features/attendance.dart';
import 'features/auth.dart';
import 'features/courses.dart';
import 'features/dashboard.dart';
import 'features/grading.dart';
import 'features/settings.dart';
import 'theme.dart';
import 'widgets/common.dart';

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key, this.api});
  final AttendanceApi? api;
  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final AppState state;
  final navigator = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    state = AppState(widget.api ?? AttendanceApi())
      ..addListener(_sessionChanged);
    state.restore();
  }

  void _sessionChanged() {
    if (state.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigator.currentState?.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    state.removeListener(_sessionChanged);
    state.api.dispose();
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            title: 'جامعة أسيوط الأهلية',
            theme: Brand.theme(),
            darkTheme: Brand.theme(dark: true),
            themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('ar', 'EG'),
            supportedLocales: const [Locale('ar', 'EG')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: state.restoring
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()))
                : state.user == null
                    ? SignInPage(state)
                    : AppShell(state, key: ValueKey(state.user!.id)),
          ));
}

class AppShell extends StatefulWidget {
  const AppShell(this.state, {super.key});
  final AppState state;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  AppState get state => widget.state;
  Future<void> selectScope() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .7,
                child: ListView(children: [
                  const ListTile(title: Text('اختيار المقرر والسكشن')),
                  for (final course in state.courses)
                    ExpansionTile(
                        title: Text('${course.code} · ${course.name}'),
                        initiallyExpanded: course.id == state.course?.id,
                        children: [
                          if (state.user!.role == Role.doctor)
                            ListTile(
                                title: const Text('جميع السكاشن'),
                                onTap: () {
                                  state.selectCourse(course);
                                  setState(() => tab = 0);
                                  Navigator.pop(sheet);
                                }),
                          for (final section in course.sections)
                            ListTile(
                                title: Text(section.label),
                                subtitle: Text(section.taName),
                                onTap: () {
                                  state.selectCourse(course);
                                  state.selectSection(section);
                                  setState(() => tab = 0);
                                  Navigator.pop(sheet);
                                }),
                        ]),
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    final role = state.user!.role;
    final labels = role == Role.student
        ? ['الرئيسية', 'المقررات', 'الحضور', 'الدرجات', 'المزيد']
        : role == Role.ta
            ? ['الرئيسية', 'السكاشن', 'الحضور', 'الدرجات', 'المزيد']
            : ['الرئيسية', 'المقررات', 'الحضور', 'الدرجات', 'المزيد'];
    final icons = role == Role.student
        ? [
            Icons.home_outlined,
            Icons.menu_book,
            Icons.qr_code_scanner,
            Icons.grade_outlined,
            Icons.more_horiz
          ]
        : role == Role.ta
            ? [
                Icons.home_outlined,
                Icons.groups_outlined,
                Icons.event_note_outlined,
                Icons.grade_outlined,
                Icons.more_horiz
              ]
            : [
                Icons.home_outlined,
                Icons.menu_book,
                Icons.event_note,
                Icons.grade_outlined,
                Icons.more_horiz
              ];
    Widget body;
    if (tab == labels.length - 1) {
      body = SettingsPage(state);
    } else if (tab == 1) {
      body = CoursesPage(state);
    } else if (state.course == null) {
      body = PageContent(children: [
        EmptyPanel(
            state.startupError == null
                ? 'لا توجد مقررات مسندة'
                : 'تعذر تحميل المقررات',
            state.startupError ?? 'لم يتم تسجيل مقررات لهذا الحساب بعد.'),
        AsyncButton(
            label: 'تحديث المقررات',
            icon: Icons.refresh,
            onPressed: state.refreshCourses)
      ]);
    } else if (tab == 0) {
      body = HomePage(state);
    } else if (tab == 2) {
      body = AttendancePage(state);
    } else {
      body = GradesPage(state);
    }
    return Scaffold(
        appBar: AppBar(
            title: const Text('جامعة أسيوط الأهلية'),
            actions: [
              IconButton(
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    try {
                      await state.refreshCourses();
                    } catch (error) {
                      if (context.mounted) notice(context, '$error');
                    }
                  }),
            ],
            bottom: state.course == null
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(56),
                    child: InkWell(
                        onTap: selectScope,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(children: [
                              const Icon(Icons.menu_book_outlined, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      '${state.course!.code} · ${state.section?.label ?? 'جميع السكاشن'}',
                                      maxLines: 2)),
                              const Icon(Icons.expand_more),
                            ]))))),
        body: SafeArea(child: body),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (index) => setState(() => tab = index),
            destinations: [
              for (var i = 0; i < labels.length; i++)
                NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
            ]));
  }
}
