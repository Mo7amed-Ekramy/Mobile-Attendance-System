import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'attendance.dart';
import 'courses.dart';
import 'grading.dart';
import 'quizzes.dart';
import 'settings.dart';

class HomePage extends StatelessWidget {
  const HomePage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final role = state.user!.role;
    final student = role == Role.student;
    return RemotePage<Map<String, dynamic>>(
        scope: state.scopeKey,
        load: () async {
          final results = await Future.wait([
            state.api.getCourse(state.course!, 'quizzes',
                sectionId: state.section?.id),
            state.api.getCourse(state.course!, student ? 'grades' : 'report',
                sectionId: state.section?.id),
            if (!student)
              state.api.getCourse(state.course!, 'sessions',
                  sectionId: state.section?.id),
          ]);
          return {
            'quizzes': results[0],
            'summary': results[1],
            if (!student) 'sessions': results[2]
          };
        },
        builder: (data, reload) {
          final quizzes =
              (data['quizzes'] as List).cast<Map<String, dynamic>>();
          final pending = quizzes
              .where((q) => quizAvailable(q) || quizHasCompletedAttempt(q))
              .toList();
          final sessions = data['sessions'] as List? ?? [];
          final summary = data['summary'] as Map<String, dynamic>;
          Future<void> open(String title, Widget page) async {
            await openPage(context, title, page);
            reload();
          }

          return PageContent(children: [
            PageHeading(
                switch (role) {
                  Role.doctor => 'لوحة متابعة المقرر',
                  Role.ta => 'مهام السكشن',
                  Role.student => 'يومي الدراسي',
                },
                'مرحباً، ${state.user!.name} · ${state.user!.roleLabel}'),
            StatusRow('${state.course!.code} · ${state.course!.name}',
                '${state.section?.label ?? 'جميع السكاشن'} · ${state.course!.term}'),
            Text('ابدأ من هنا', style: Theme.of(context).textTheme.titleLarge),
            if (student)
              ActionCard(
                  title: 'مسح رمز الحضور',
                  detail: 'سجّل حضور المحاضرة وأظهر إيصال التسجيل',
                  icon: Icons.qr_code_scanner,
                  onTap: () => open('تسجيل الحضور', ScanPage(state.api))),
            if (role == Role.doctor)
              ActionCard(
                  title: 'فتح محاضرة',
                  detail: 'أنشئ جلسة وأظهر رمز الحضور للطلاب',
                  icon: Icons.add_circle_outline,
                  onTap: () => open('فتح محاضرة', CreateSessionPage(state))),
            if (role == Role.ta)
              ActionCard(
                  title: 'إنشاء كشف حضور السكشن',
                  detail: 'حدّد الحالات ثم راجع الكشف واعتمده',
                  icon: Icons.playlist_add_check,
                  onTap: () => open('كشف جديد', CreateSessionPage(state))),
            ActionCard(
                title: student ? 'درجاتي' : 'الدرجات والتقييمات',
                detail: student
                    ? 'النتائج المنشورة والبنود التي تنتظر الاكتمال'
                    : 'رصد الدرجات ومراجعة الحفظ والنشر',
                icon: Icons.grade_outlined,
                onTap: () => open('الدرجات', GradesPage(state))),
            MetricGrid(
                children: student
                    ? [
                        MetricCard(
                            'كويزات متاحة الآن',
                            '${quizzes.where(quizAvailable).length}',
                            Icons.timer_outlined),
                        MetricCard(
                            'المجموع النهائي',
                            summary['policy'] == null
                                ? 'لم يُنشر'
                                : summary['official_total'] == null
                                    ? 'غير مكتمل'
                                    : points(summary['official_total']),
                            Icons.grade_outlined),
                      ]
                    : [
                        MetricCard('الطلاب', '${summary['students']}',
                            Icons.groups_outlined),
                        MetricCard(
                            'الجلسات المعتمدة',
                            '${summary['finalized']}',
                            Icons.fact_check_outlined),
                        MetricCard(
                            role == Role.ta
                                ? 'كشوف حديثة لم تُعتمد'
                                : 'محاضرات حديثة مفتوحة',
                            '${sessions.where((s) => s['state'] == (role == Role.ta ? 'draft' : 'open')).length}',
                            Icons.pending_actions_outlined),
                      ]),
            if (!student && summary['policy'] == null)
              NoticeBanner(role == Role.doctor
                  ? 'ابدأ بحفظ لائحة الدرجات لإنشاء التقييمات والكويزات.'
                  : 'لائحة الدرجات لم تُجهّز بعد. تابع حضور السكشن حتى يضيفها الدكتور.'),
            if (student &&
                summary['policy'] != null &&
                summary['official_total'] == null)
              const NoticeBanner(
                  'المجموع النهائي ينتظر اكتمال الرصد والنشر. افتح درجاتي لمعرفة البنود غير المكتملة.'),
            if (role == Role.doctor && summary['policy'] == null)
              ActionCard(
                  title: 'إعداد لائحة الدرجات',
                  detail: 'وزّع المجموع واحفظ المسودة قبل الاعتماد',
                  icon: Icons.tune,
                  onTap: () => open('لائحة الدرجات',
                      PolicyPage(state.api, state.course!, editable: true))),
            Text(student ? 'كويزاتك' : 'متابعة العمل',
                style: Theme.of(context).textTheme.titleLarge),
            if (student) ...[
              if (pending.isEmpty)
                const EmptyPanel('لا يوجد كويز متاح الآن',
                    'ستظهر الكويزات الجديدة عند فتحها لسكشنك.'),
              for (final quiz in pending.take(3))
                QuizActionCard(quiz,
                    student: true,
                    onOpen: () => open(quiz['title'] as String,
                        QuizRunnerPage(state.api, quiz['id'] as int))),
              ActionCard(
                  title: 'كل كويزات السكشن',
                  detail: 'المتاح والمغلق والمحاولات السابقة',
                  icon: Icons.quiz_outlined,
                  onTap: () => open('الكويزات', QuizzesPage(state))),
            ] else ...[
              for (final session in sessions
                  .where((s) => s['state'] == 'open' || s['state'] == 'draft')
                  .take(3))
                ActionCard(
                    title: session['title'] as String,
                    detail: session['kind'] == 'lecture'
                        ? 'محاضرة مفتوحة · متابعة الرمز والإغلاق'
                        : 'كشف لم يُعتمد · متابعة الحالات',
                    icon: Icons.pending_actions_outlined,
                    onTap: () => open(
                        session['title'] as String,
                        role == Role.doctor && session['kind'] == 'lecture'
                            ? LecturePage(
                                state.api, state.course!, session['id'] as int)
                            : SessionDetailPage(
                                state.api, state.course!, session['id'] as int,
                                editable: role == Role.ta))),
              ActionCard(
                  title: 'بنك الأسئلة وكويزات السكشن',
                  detail: 'الأسئلة والكويزات والمحاولات المسلّمة',
                  icon: Icons.quiz_outlined,
                  onTap: () => open('الكويزات', QuizzesPage(state))),
              ActionCard(
                  title: 'كشف الطلاب',
                  detail: 'بحث ضمن النطاق المحدد',
                  icon: Icons.groups_outlined,
                  onTap: () => open(
                      'كشف الطلاب',
                      RosterPage(state.api, state.course!,
                          sectionId: state.section?.id))),
              ActionCard(
                  title: 'تقرير المقرر',
                  detail: 'إحصائيات النطاق المحدد والحضور والتقييمات',
                  icon: Icons.analytics_outlined,
                  onTap: () => open('التقرير', CourseReportPage(state))),
            ],
            ActionCard(
                title: student ? 'سجل الحضور' : 'كل جلسات الحضور',
                detail: 'المحاضرات والسكاشن والحالات المحفوظة',
                icon: Icons.event_note_outlined,
                onTap: () => open('الحضور', AttendancePage(state))),
          ]);
        });
  }
}
