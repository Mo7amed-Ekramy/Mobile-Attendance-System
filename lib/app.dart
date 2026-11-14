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
import 'features/quizzes.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/scope_switcher.dart';

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

  Future<void> refreshCourses() async {
    try {
      await state.refreshCourses();
    } catch (error) {
      if (mounted) notice(context, '$error');
    }
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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final compact = width < 600;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: compact ? 12 : 20,
        title: Row(children: [
          Tooltip(
              message: 'جامعة أسيوط الأهلية',
              child:
                  Image.asset('assets/images/logo.png', width: 34, height: 34)),
          const SizedBox(width: 10),
          if (!compact || state.course == null)
            const Flexible(
                child: Text('جامعة أسيوط الأهلية',
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (state.course != null) ...[
            if (!compact) const SizedBox(width: 20),
            Flexible(child: ScopeSwitcher(state, compact: compact)),
          ],
        ]),
        actions: [
          if (compact)
            PopupMenuButton<String>(
                tooltip: 'خيارات الصفحة',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'refresh') {
                    refreshCourses();
                  } else {
                    openPage(context, 'الكويزات', QuizzesPage(state));
                  }
                },
                itemBuilder: (_) => [
                      if (state.course != null)
                        const PopupMenuItem(
                            value: 'quizzes', child: Text('الكويزات')),
                      const PopupMenuItem(
                          value: 'refresh', child: Text('تحديث البيانات')),
                    ])
          else ...[
            if (state.course != null)
              IconButton(
                  tooltip: 'الكويزات',
                  icon: const Icon(Icons.quiz_outlined),
                  onPressed: () =>
                      openPage(context, 'الكويزات', QuizzesPage(state))),
            IconButton(
                tooltip: 'تحديث البيانات',
                icon: const Icon(Icons.refresh),
                onPressed: refreshCourses),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (wide) ...[
          Container(
              width: 224,
              color: scheme.surface,
              child: Column(children: [
                const SizedBox(height: 20),
                Text('مساحتك الأكاديمية',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                Expanded(
                    child: NavigationRail(
                  extended: true,
                  minExtendedWidth: 224,
                  backgroundColor: scheme.surface,
                  selectedIndex: tab,
                  onDestinationSelected: (index) => setState(() => tab = index),
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationRailDestination(
                          icon: Icon(icons[i]), label: Text(labels[i])),
                  ],
                )),
                Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(state.user!.name.characters.first,
                              style: TextStyle(color: scheme.primary))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(state.user!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge),
                            Text(state.user!.roleLabel,
                                style: Theme.of(context).textTheme.bodySmall),
                          ])),
                    ])),
              ])),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
        ],
        Expanded(
            child: KeyedSubtree(
                key: PageStorageKey(
                    'shell-${state.user!.id}-$tab-${state.course?.id}-${state.section?.id}'),
                child: body)),
      ])),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                  border:
                      Border(top: BorderSide(color: scheme.outlineVariant))),
              child: NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (index) => setState(() => tab = index),
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(
                          icon: Icon(icons[i]), label: labels[i]),
                  ])),
    );
  }
}
