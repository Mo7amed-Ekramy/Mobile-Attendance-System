import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'reports.dart';
import 'teaching_assignments.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => PageContent(children: [
        const PageHeading(
            'حسابك الجامعي', 'بياناتك وتفضيلاتك وتحديثات مقرراتك'),
        StatusRow(state.user!.name,
            '${state.user!.roleLabel} · ${state.user!.universityId ?? state.user!.username}'),
        if (state.user!.department != null)
          StatusRow('القسم والسكشن',
              '${state.user!.department} · سكشن ${state.user!.sectionNumber}'),
        if (state.user!.email != null)
          StatusRow('البريد الإلكتروني', state.user!.email!),
        ActionCard(
            title: 'الإشعارات',
            detail: 'التقييمات المنشورة وكويزات السكشن',
            icon: Icons.notifications_outlined,
            onTap: () => openPage(
                context,
                'الإشعارات',
                RemotePage<dynamic>(
                    load: () => state.api.request('GET', '/notifications'),
                    builder: (items, reload) => PageContent(children: [
                          if ((items as List).isEmpty)
                            const EmptyPanel(
                                'لا توجد إشعارات', 'ستظهر تحديثات المقرر هنا.'),
                          for (final item in items)
                            ActionCard(
                                title: item['title'] as String,
                                detail:
                                    '${item['message'] ?? ''} · ${localTime(item['created_at'])}',
                                icon: item['read_at'] == null
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_none,
                                onTap: () async {
                                  await state.api.request('POST',
                                      '/notifications/${item['id']}/read');
                                  reload();
                                }),
                        ])))),
        // ADD-01: Password change card.
        ActionCard(
            title: 'تغيير كلمة المرور',
            detail: 'تحديث كلمة المرور وإلغاء الجلسات الأخرى',
            icon: Icons.lock_outline,
            onTap: () => openPage(
                context, 'تغيير كلمة المرور', _ChangePasswordPage(state.api))),
        if (state.course != null && state.user!.role != Role.student) ...[
          if (state.user!.role == Role.doctor)
            ActionCard(
                title: 'معيدو المقرر',
                detail: 'أسماء المعيدين وتوزيع سكاشنهم حسب القسم',
                icon: Icons.badge_outlined,
                onTap: () => openPage(context, 'معيدو المقرر',
                    TeachingAssignmentsPage(state.api, state.course!))),
          // ADD-07: Enhanced report card.
          ActionCard(
              title:
                  state.user!.role == Role.ta ? 'تقرير السكشن' : 'تقرير المقرر',
              detail: 'إحصائيات الحضور والتسجيل والتقييمات',
              icon: Icons.analytics_outlined,
              onTap: () => openPage(
                  context,
                  state.user!.role == Role.ta ? 'تقرير السكشن' : 'تقرير المقرر',
                  CourseReportPage(state))),
        ],
        MergeSemantics(
            child: ListTile(
                title: const Text('الوضع الداكن'),
                trailing: Switch(
                    value: state.darkMode, onChanged: state.toggleTheme))),
        AsyncButton(
            label: 'تسجيل الخروج',
            icon: Icons.logout,
            onPressed: () async {
              if (await confirm(context, 'تسجيل الخروج',
                  'سيتم إنهاء الجلسة ومسح بيانات الحساب من التطبيق.')) {
                await state.signOut();
              }
            }),
      ]);
}

// ─── ADD-01: Change Password Page ────────────────────────────────────────────

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage(this.api);
  final AttendanceApi api;
  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool obscureCurrent = true, obscureNext = true, obscureConfirm = true;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: PageContent(children: [
        const StatusRow(
            'تغيير كلمة المرور', 'ستُلغى جميع الجلسات الأخرى فور التغيير.'),
        // Current password field.
        TextFormField(
            controller: current,
            obscureText: obscureCurrent,
            decoration: InputDecoration(
                labelText: 'كلمة المرور الحالية',
                suffixIcon: IconButton(
                    icon: Icon(obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscureCurrent = !obscureCurrent))),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'أدخل كلمة المرور الحالية.' : null),
        // New password field — min 8 chars.
        TextFormField(
            controller: next,
            obscureText: obscureNext,
            decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة (8 أحرف على الأقل)',
                suffixIcon: IconButton(
                    icon: Icon(obscureNext
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscureNext = !obscureNext))),
            validator: (v) {
              if ((v ?? '').trim().length < 8) {
                return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
              }
              if (v == current.text) {
                return 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.';
              }
              return null;
            }),
        // Confirm new password field.
        TextFormField(
            controller: confirm,
            obscureText: obscureConfirm,
            decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور الجديدة',
                suffixIcon: IconButton(
                    icon: Icon(obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm))),
            validator: (v) =>
                v != next.text ? 'كلمة المرور غير متطابقة.' : null),
        AsyncButton(
            label: 'تغيير كلمة المرور',
            icon: Icons.lock_reset,
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              await widget.api.request('POST', '/auth/change-password', body: {
                'current_password': current.text,
                'new_password': next.text,
              });
              if (context.mounted) {
                notice(context, 'تم تغيير كلمة المرور وإلغاء الجلسات الأخرى.');
                Navigator.pop(context);
              }
            }),
      ]));
}

// ─── ADD-07: Enhanced Course Report Page ─────────────────────────────────────

class CourseReportPage extends StatelessWidget {
  const CourseReportPage(this.state, {super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return RemotePage<Map<String, dynamic>>(load: () async {
      final results = await Future.wait([
        state.api
            .getCourse(state.course!, 'report', sectionId: state.section?.id),
        state.api.getCourse(state.course!, 'sessions/summary',
            sectionId: state.section?.id),
        state.api.getCourse(state.course!, 'assessments',
            sectionId: state.section?.id),
      ]);
      return {
        'report': results[0],
        'summary': results[1],
        'assessments': results[2],
      };
    }, builder: (data, reload) {
      final report = data['report'] as Map<String, dynamic>;
      final summary = data['summary'] as Map<String, dynamic>? ?? {};
      final assessments = data['assessments'] as List? ?? [];
      final policy = report['policy'] as Map<String, dynamic>?;

      return PageContent(children: [
        Text(state.user!.role == Role.ta ? 'تقرير السكشن' : 'تقرير المقرر',
            style: Theme.of(context).textTheme.headlineSmall),
        StatusRow('المقرر',
            '${state.course!.code} · ${state.section?.label ?? 'جميع السكاشن'}'),
        ActionCard(
            title: 'كشف الطلاب والطباعة',
            detail: 'حضور ودرجات كل طالب · تصدير PDF وطباعة النطاق المحدد',
            icon: Icons.print_outlined,
            onTap: () => openPage(
                context,
                'تقرير الطلاب',
                StudentReportPage(state.api, state.course!,
                    section: state.section))),

        // ── Section: Students ────────────────────────────────────────
        _ReportSection('إحصائيات الطلاب', Icons.people_outline),
        StatusRow('إجمالي الطلاب المسجلين', '${report['students']}'),

        // ── Section: Attendance ──────────────────────────────────────
        _ReportSection('سجل الحضور', Icons.event_note_outlined),
        StatusRow('إجمالي الجلسات', '${report['sessions']}'),
        StatusRow('الجلسات المعتمدة', '${report['finalized']}'),
        for (final kind in ['lecture', 'section']) ...[
          _attendanceSummaryRow(
              kind == 'lecture'
                  ? 'حضور المحاضرات (إجمالي)'
                  : 'حضور السكاشن (إجمالي)',
              summary[kind] as Map<String, dynamic>?),
        ],

        // ── Section: Grading Policy ──────────────────────────────────
        _ReportSection('لائحة الدرجات', Icons.grading_outlined),
        if (policy == null)
          const EmptyPanel(
              'لم تُنشر لائحة درجات', 'ستظهر التفاصيل بعد الاعتماد.')
        else ...[
          StatusRow('حالة اللائحة',
              policy['state'] == 'published' ? 'معتمدة ومنشورة' : 'مسودة'),
          StatusRow('مجموع الدرجات', '${policy['total_points']} درجة'),
          for (final cat in policy['categories'] as List)
            StatusRow(
                cat['name'] as String,
                '${cat['max_points']} درجة · '
                '${_kindLabel(cat['kind'] as String)} · '
                '${_modeLabel(cat['allocation_mode'] as String)}'),
        ],

        // ── Section: Assessments ─────────────────────────────────────
        _ReportSection('التقييمات', Icons.quiz_outlined),
        if (assessments.isEmpty)
          const EmptyPanel('لا توجد تقييمات', 'لم تُنشأ تقييمات بعد.')
        else
          for (final a in assessments)
            StatusRow(
                a['title'] as String,
                '${a['category']} · ${points(a['max_points'])} درجة'
                '${a['published_at'] != null ? ' · منشور' : ''}'),

        AsyncButton(
            label: 'تحديث التقرير',
            icon: Icons.refresh,
            onPressed: () async => reload()),
      ]);
    });
  }

  Widget _attendanceSummaryRow(
      String label, Map<String, dynamic>? kindSummary) {
    final eligible = (kindSummary?['eligible'] as int?) ?? 0;
    final present = (kindSummary?['present'] as int?) ?? 0;
    final text = eligible == 0
        ? 'لا توجد جلسات معتمدة'
        : '${(present / eligible * 100).toStringAsFixed(1)}% · $present حاضر / $eligible مؤهل';
    return StatusRow(label, text);
  }

  static String _kindLabel(String kind) => switch (kind) {
        'lecture_attendance' => 'حضور محاضرات',
        'section_attendance' => 'حضور سكاشن',
        _ => 'تقييمات',
      };

  static String _modeLabel(String mode) => switch (mode) {
        'fixed' => 'درجات ثابتة',
        'normalized' => 'تجميع نسبي',
        _ => 'نسبي',
      };
}

// Compact section header widget used in the report.
class _ReportSection extends StatelessWidget {
  const _ReportSection(this.title, this.icon);
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      ]));
}
