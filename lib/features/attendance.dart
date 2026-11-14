import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/scanner_media.dart';
import '../widgets/common.dart';
import '../widgets/edit_conflicts.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage(this.state,
      {super.key, this.initialPendingOnly = false});
  final AppState state;
  final bool initialPendingOnly;
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  AppState get state => widget.state;
  int offset = 0;
  late bool pendingOnly;
  String? lastScope;
  @override
  void initState() {
    super.initState();
    pendingOnly = widget.initialPendingOnly;
  }

  @override
  Widget build(BuildContext context) {
    if (lastScope != state.scopeKey) {
      lastScope = state.scopeKey;
      offset = 0;
    }
    return RemotePage<Map<String, dynamic>>(
        scope: '${state.scopeKey}:$offset:$pendingOnly',
        load: () async {
          final results = await Future.wait([
            state.api.getCourse(state.course!, 'sessions',
                sectionId: state.section?.id,
                query: {
                  'limit': 51,
                  'offset': offset,
                  if (state.user!.role == Role.ta && pendingOnly)
                    'state': 'draft'
                }).then((v) => (v as List)
                .map((item) =>
                    AttendanceSession.fromJson(item as Map<String, dynamic>))
                .toList()),
            // BUG-09: fetch full-history summary, not just the capped listing.
            state.api.getCourse(state.course!, 'sessions/summary',
                sectionId: state.section?.id),
          ]);
          return {'sessions': results[0], 'summary': results[1]};
        },
        builder: (data, reload) {
          final sessions = data['sessions'] as List<AttendanceSession>;
          // summary: {'lecture': {'present': N, 'eligible': M}, 'section': ...}
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          return PageContent(children: [
            Text('سجل الحضور',
                style: Theme.of(context).textTheme.headlineSmall),
            if (state.user!.role == Role.student)
              ActionCard(
                  title: 'مسح رمز الحضور',
                  detail: 'تسجيل حضور المحاضرة بالرمز أو الإدخال اليدوي',
                  icon: Icons.qr_code_scanner,
                  onTap: () async {
                    await openPage(
                        context, 'تسجيل الحضور', ScanPage(state.api));
                    reload();
                  }),
            if (state.user!.role != Role.student)
              AsyncButton(
                  label: state.user!.role == Role.doctor
                      ? 'فتح جلسة محاضرة'
                      : 'إنشاء كشف حضور السكشن',
                  icon: Icons.add,
                  onPressed: () async {
                    await openPage(
                        context, 'جلسة حضور جديدة', CreateSessionPage(state));
                    reload();
                  }),
            if (state.user!.role == Role.ta)
              FilterChip(
                label: const Text('المسودات فقط'),
                selected: pendingOnly,
                onSelected: (value) => setState(() {
                  pendingOnly = value;
                  offset = 0;
                }),
              ),
            if (state.user!.role == Role.student) ...[
              for (final kind in ['lecture', 'section'])
                _AttendanceRateRow(
                  label: kind == 'lecture' ? 'حضور المحاضرات' : 'حضور السكاشن',
                  kindSummary: summary[kind] as Map<String, dynamic>?,
                ),
            ],
            if (sessions.isEmpty)
              const EmptyPanel(
                  'لا توجد جلسات حضور', 'ستظهر الجلسات هنا بعد إنشائها.'),
            for (final session in sessions.take(50))
              ActionCard(
                  title: session.title,
                  detail:
                      '${session.kind == 'lecture' && state.user!.role == Role.ta ? 'محاضرة · للاطلاع فقط · ' : ''}'
                      '${localTime(session.startsAt.toIso8601String())} · ${session.stateLabel} · '
                      '${state.user!.role == Role.student ? markLabel(session.ownStatus) : '${session.presentCount} حاضر من ${session.eligibleCount}'}',
                  icon: session.kind == 'lecture'
                      ? Icons.school_outlined
                      : Icons.groups_outlined,
                  onTap: () async {
                    final Widget page = state.user!.role == Role.doctor &&
                            session.kind == 'lecture'
                        ? LecturePage(state.api, state.course!, session.id)
                        : SessionDetailPage(
                            state.api, state.course!, session.id,
                            sectionId: state.section?.id,
                            editable: state.user!.role == Role.ta &&
                                session.state == 'draft');
                    await openPage(context, session.title, page);
                    reload();
                  }),
            if (offset > 0 || sessions.length > 50)
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: offset == 0
                            ? null
                            : () => setState(() => offset -= 50),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('السابق'))),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('صفحة ${offset ~/ 50 + 1}')),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: sessions.length <= 50
                            ? null
                            : () => setState(() => offset += 50),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('التالي'))),
              ]),
          ]);
        });
  }
}

/// BUG-09: Displays the attendance rate derived from the full-history summary
/// endpoint instead of the capped session listing.
class _AttendanceRateRow extends StatelessWidget {
  const _AttendanceRateRow({required this.label, required this.kindSummary});
  final String label;
  final Map<String, dynamic>? kindSummary;

  @override
  Widget build(BuildContext context) {
    final eligible = (kindSummary?['eligible'] as int?) ?? 0;
    final present = (kindSummary?['present'] as int?) ?? 0;
    final text = eligible == 0
        ? 'لا توجد جلسات معتمدة محتسبة.'
        : '${(present / eligible * 100).toStringAsFixed(1)}% ($present / $eligible)';
    return StatusRow(label, text,
        detailDirection: eligible == 0 ? null : TextDirection.ltr);
  }
}

class CreateSessionPage extends StatefulWidget {
  const CreateSessionPage(this.state, {super.key});
  final AppState state;
  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final duration = TextEditingController(text: '30');
  @override
  void dispose() {
    title.dispose();
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final lecture = state.user!.role == Role.doctor;
    return RemotePage<dynamic>(
        load: () => state.api.getCourse(state.course!, 'roster',
            sectionId: state.section?.id, query: {'limit': 1}),
        builder: (roster, reload) => Form(
            key: form,
            child: PageContent(children: [
              StatusRow(
                  state.course!.name, state.section?.label ?? 'جميع السكاشن'),
              NoticeBanner(roster['total'] == 0 && !lecture
                  ? 'لا يوجد طلاب مسجلون في هذا السكشن. اختر سكشناً به طلاب لإنشاء كشف الحضور.'
                  : 'هذه الجلسة تخص ${state.section?.label ?? 'جميع سكاشن المقرر'} · ${roster['total']} طالب مؤهل.'),
              TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'عنوان الجلسة'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'اكتب عنوان الجلسة.'
                      : null),
              if (lecture)
                TextFormField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'مدة فتح الحضور بالدقائق'),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      return number == null || number < 1 || number > 180
                          ? 'اختر مدة من 1 إلى 180 دقيقة.'
                          : null;
                    }),
              AsyncButton(
                  label: lecture ? 'فتح الجلسة وعرض الرمز' : 'إنشاء كشف الحضور',
                  enabled: lecture || roster['total'] > 0,
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    final data =
                        await state.api.writeCourse(state.course!, 'sessions', {
                      'kind': lecture ? 'lecture' : 'section',
                      'title': title.text.trim(),
                      'section_id': state.section?.id,
                      'duration_minutes':
                          lecture ? int.parse(duration.text) : 60,
                    }) as Map<String, dynamic>;
                    if (!context.mounted) return;
                    await openPage(
                        context,
                        title.text,
                        lecture
                            ? LecturePage(
                                state.api, state.course!, data['id'] as int)
                            : SessionDetailPage(
                                state.api, state.course!, data['id'] as int,
                                editable: true));
                    if (context.mounted) Navigator.pop(context);
                  }),
            ])));
  }
}

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage(this.api, this.course, this.sessionId,
      {super.key, this.editable = false, this.sectionId});
  final AttendanceApi api;
  final CourseOffering course;
  final int sessionId;
  final bool editable;
  final int? sectionId;
  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final marks = <int, String>{};
  final search = TextEditingController();
  Map<String, dynamic>? loaded;
  bool pendingOnly = false;
  bool saving = false;
  Set<int>? undoAbsentIds;
  bool conflicted = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool get hasChanges =>
      widget.editable &&
      loaded?['state'] == 'draft' &&
      (loaded?['rows'] as List? ?? [])
          .any((row) => marks[row['enrollment_id']] != row['status']);

  Future<bool> confirmDiscard() async =>
      !saving &&
      (!hasChanges ||
          await confirm(context, 'حالات حضور غير محفوظة',
              'لديك تعديلات لم تُحفظ. احفظ المسودة للاحتفاظ بها أو أكّد تجاهل التعديلات.'));

  String sessionScope(Map<String, dynamic> data) {
    final section = widget.course.sections
        .where((s) => s.id == (widget.sectionId ?? data['course_section_id']))
        .firstOrNull;
    return '${widget.course.code} · ${section?.label ?? 'جميع السكاشن'} · ${widget.course.termLabel}';
  }

  Future<void> resolveConflict(Map<String, dynamic> data) async {
    setState(() => conflicted = true);
    final local = Map<int, String>.from(marks);
    final oldRows = data['rows'] as List;
    final changed = {
      for (final row in oldRows)
        if (local[row['enrollment_id']] != row['status'])
          row['enrollment_id'] as int
    };
    final latest = await widget.api.getCourse(
        widget.course, 'sessions/${widget.sessionId}') as Map<String, dynamic>;
    if (!mounted) return;
    final choice = await reviewEditConflict(context,
        canReapply: latest['state'] == 'draft',
        differences: [
          for (final row in latest['rows'] as List)
            if (changed.contains(row['enrollment_id']))
              '${row['full_name']} · ${row['university_id']}\nتعديلي: ${markLabel(local[row['enrollment_id']])}\nالخادم: ${markLabel(row['status'] as String?)}'
        ]);
    if (choice == null || !mounted) return;
    setState(() {
      data
        ..clear()
        ..addAll(latest);
      marks.clear();
      for (final row in latest['rows'] as List) {
        final id = row['enrollment_id'] as int;
        final status = choice == ConflictChoice.local && changed.contains(id)
            ? local[id]
            : row['status'] as String?;
        if (status != null) marks[id] = status;
      }
      conflicted = false;
      undoAbsentIds = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !hasChanges && !saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await confirmDiscard() || !context.mounted) return;
        Navigator.pop(context);
      },
      child: RemotePage<dynamic>(
          beforeRefresh: confirmDiscard,
          load: () => widget.api.getCourse(
              widget.course, 'sessions/${widget.sessionId}',
              sectionId: widget.sectionId),
          builder: (data, reload) {
            final rows = data['rows'] as List?;
            final editable = widget.editable && data['state'] == 'draft';
            if (rows == null) {
              return PageContent(children: [
                StatusRow(data['title'] as String,
                    '${markLabel(data['record']?['status'] as String?)} · ${localTime(data['starts_at'])}'),
                if (data['record'] != null)
                  AttendanceReceipt({
                    ...data['record'] as Map<String, dynamic>,
                    'course_code': data['course_code'],
                    'course_name': data['course_name'],
                    'session_title': data['title']
                  }),
              ]);
            }
            if (!identical(loaded, data)) {
              loaded = data as Map<String, dynamic>;
              marks.clear();
              for (final row in rows) {
                if (row['status'] != null) {
                  marks[row['enrollment_id'] as int] = row['status'] as String;
                }
              }
            }
            final visible = rows
                .where((row) =>
                    ('${row['full_name']} ${row['university_id']}')
                        .toLowerCase()
                        .contains(search.text.trim().toLowerCase()) &&
                    (!pendingOnly || !marks.containsKey(row['enrollment_id'])))
                .toList();
            return PageContent(
                footer: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (editable) ...[
                        AsyncButton(
                            label: saving
                                ? 'جار حفظ المسودة...'
                                : 'حفظ مسودة الحضور',
                            icon: Icons.save_outlined,
                            enabled: !saving && hasChanges,
                            onPressed: () async {
                              final saved = Map<int, String>.from(marks);
                              setState(() => saving = true);
                              try {
                                final result = await widget.api.writeCourse(
                                    widget.course,
                                    'sessions/${widget.sessionId}/draft',
                                    {
                                      'revision': data['revision'],
                                      'rows': [
                                        for (final entry in saved.entries)
                                          {
                                            'enrollment_id': entry.key,
                                            'status': entry.value
                                          }
                                      ],
                                    },
                                    method: 'PUT') as Map<String, dynamic>;
                                if (!mounted) return;
                                setState(() {
                                  data['revision'] = result['revision'];
                                  for (final row in rows) {
                                    row['status'] = saved[row['enrollment_id']];
                                  }
                                  undoAbsentIds = null;
                                  conflicted = false;
                                });
                                if (context.mounted) {
                                  notice(context,
                                      'تم حفظ المسودة. يمكنك استكمالها لاحقاً.');
                                }
                              } on ApiException catch (error) {
                                if (error.status != 409) rethrow;
                                await resolveConflict(data);
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            }),
                        const SizedBox(height: 8),
                        AsyncButton(
                            label: 'مراجعة واعتماد الكشف',
                            enabled: !saving &&
                                rows.isNotEmpty &&
                                marks.length == rows.length,
                            onPressed: () async {
                              if (!await confirm(
                                  context,
                                  'اعتماد كشف الحضور',
                                  '${sessionScope(data)}\n${data['title']} · ${localTime(data['starts_at'])}\n'
                                      'جميع طلاب الكشف: ${rows.length}\n'
                                      'حاضر: ${marks.values.where((m) => m == 'present').length} · '
                                      'غائب: ${marks.values.where((m) => m == 'absent').length} · '
                                      'بعذر: ${marks.values.where((m) => m == 'excused').length}\n'
                                      'سيصبح الكشف رسميًا ومقفلًا. تصحيح الحضور بعد الاعتماد غير متاح حاليًا داخل التطبيق.')) {
                                return;
                              }
                              setState(() => saving = true);
                              try {
                                await widget.api.writeCourse(widget.course,
                                    'sessions/${widget.sessionId}/finalize', {
                                  'revision': data['revision'],
                                  'rows': [
                                    for (final row in rows)
                                      {
                                        'enrollment_id': row['enrollment_id'],
                                        'status': marks[row['enrollment_id']]
                                      }
                                  ],
                                });
                                if (context.mounted) {
                                  notice(context, 'تم اعتماد كشف الحضور.');
                                }
                                reload();
                              } on ApiException catch (error) {
                                if (error.status != 409) rethrow;
                                await resolveConflict(data);
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            }),
                      ],
                    ]),
                children: [
                  StatusRow(
                      data['title'] as String,
                      '${rows.length} طالب · ${data['kind'] == 'lecture' ? 'محاضرة · للاطلاع فقط' : data['state'] == 'finalized' ? 'كشف معتمد' : 'مسودة كشف حضور'}'),
                  Text(sessionScope(data)),
                  if (conflicted)
                    const NoticeBanner(
                        'تعذر الحفظ بسبب تعارض. تعديلاتك المحلية لم تُحذف. أعد الحفظ لفتح مراجعة القيم.',
                        isError: true),
                  Text(
                      'حاضر ${marks.values.where((m) => m == 'present').length} · غائب ${marks.values.where((m) => m == 'absent').length} · '
                      'بعذر ${marks.values.where((m) => m == 'excused').length} · غير محدد ${rows.length - marks.length}'),
                  if (editable)
                    NoticeBanner(hasChanges
                        ? 'لديك تعديلات غير محفوظة. احفظ المسودة أو أكمل الحالات لاعتماد الكشف.'
                        : marks.isEmpty
                            ? 'حدّد حالات الطلاب. يمكنك حفظ كشف جزئي واستكماله لاحقاً.'
                            : 'المسودة محفوظة. أكمل الحالات ثم راجع واعتمد الكشف.'),
                  TextField(
                      controller: search,
                      decoration: const InputDecoration(
                          labelText: 'البحث في الكشف',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (_) => setState(() {})),
                  if (editable)
                    SwitchListTile(
                        title: const Text('غير المحدد فقط'),
                        value: pendingOnly,
                        onChanged: (value) =>
                            setState(() => pendingOnly = value)),
                  if (editable)
                    OutlinedButton(
                        onPressed: () async {
                          final pending = rows
                              .where((row) =>
                                  !marks.containsKey(row['enrollment_id']))
                              .toList();
                          if (pending.isEmpty || saving) return;
                          if (await confirm(context, 'تحديد غير المحدد غائب',
                              'سيتم تحديد ${pending.length} طالب غير محدد في الكشف كاملًا، بما في ذلك خارج نتائج البحث. ستبقى حالات الحاضر والمعذور والغائب كما هي.')) {
                            setState(() {
                              undoAbsentIds = {
                                for (final row in pending)
                                  row['enrollment_id'] as int
                              };
                              for (final row in pending) {
                                marks[row['enrollment_id'] as int] = 'absent';
                              }
                            });
                          }
                        },
                        child: const Text('تحديد غير المحدد غائب')),
                  if (editable && undoAbsentIds != null)
                    TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                  for (final id in undoAbsentIds!) {
                                    marks.remove(id);
                                  }
                                  undoAbsentIds = null;
                                }),
                        icon: const Icon(Icons.undo),
                        label: const Text('تراجع عن التحديد الجماعي')),
                  if (visible.isEmpty)
                    const EmptyPanel('لا توجد حالات مطابقة',
                        'غيّر البحث أو أوقف فلتر غير المحدد.'),
                  for (final row in visible)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row['full_name'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(row['university_id'] as String),
                                  if (editable)
                                    Wrap(spacing: 8, children: [
                                      for (final mark in [
                                        'present',
                                        'absent',
                                        'excused'
                                      ])
                                        ChoiceChip(
                                            label: Text(markLabel(mark)),
                                            selected:
                                                marks[row['enrollment_id']] ==
                                                    mark,
                                            onSelected: saving
                                                ? null
                                                : (_) => setState(() {
                                                      final id =
                                                          row['enrollment_id']
                                                              as int;
                                                      marks[id] = mark;
                                                      undoAbsentIds?.remove(id);
                                                      if (undoAbsentIds
                                                              ?.isEmpty ==
                                                          true) {
                                                        undoAbsentIds = null;
                                                      }
                                                    })),
                                    ])
                                  else
                                    Text(markLabel(row['status'] as String?)),
                                ]))),
                ]);
          }));
}

class LecturePage extends StatefulWidget {
  const LecturePage(this.api, this.course, this.sessionId, {super.key});
  final AttendanceApi api;
  final CourseOffering course;
  final int sessionId;
  @override
  State<LecturePage> createState() => _LecturePageState();
}

class _LecturePageState extends State<LecturePage> {
  Timer? timer;
  Map<String, dynamic>? session;
  Map<String, dynamic>? qr;
  String? error;
  DateTime? updatedAt;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    try {
      final data = await widget.api
              .getCourse(widget.course, 'sessions/${widget.sessionId}')
          as Map<String, dynamic>;
      Map<String, dynamic>? nextQr = qr;
      if (data['state'] == 'open' &&
          DateTime.now().toUtc().isBefore(date(data['ends_at']))) {
        if (qr == null ||
            DateTime.now().toUtc().isAfter(date(qr!['valid_until'])
                .subtract(const Duration(seconds: 15)))) {
          nextQr = await widget.api
                  .getCourse(widget.course, 'sessions/${widget.sessionId}/qr')
              as Map<String, dynamic>;
        }
      } else {
        nextQr = null;
      }
      if (mounted) {
        setState(() {
          session = data;
          qr = nextQr;
          error = null;
          updatedAt = DateTime.now();
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (session == null && error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = session?['rows'] as List? ?? [];
    final isOpen = session?['state'] == 'open';
    final valid =
        qr != null && DateTime.now().toUtc().isBefore(date(qr!['valid_until']));
    return PageContent(children: [
      if (error != null) EmptyPanel('تعذر تحديث الجلسة', error!),
      StatusRow(session?['title'] as String? ?? 'جلسة الحضور',
          '${rows.where((r) => r['status'] == 'present').length} حاضر من ${rows.length} طالب'),
      if (valid)
        Center(
            child: QrImageView(
                data: qr!['payload'] as String,
                size: 260,
                backgroundColor: Colors.white))
      else
        const EmptyPanel('لا يوجد رمز نشط',
            'الجلسة مغلقة أو انتهت مدة الرمز. حدّث الصفحة عند توفر الاتصال.'),
      if (valid) ...[
        Text('صالح حتى ${localTime(qr!['valid_until'])}',
            textAlign: TextAlign.center),
        ExpansionTile(
            // Expansion state is a bool; the page and selectable text each
            // persist a double scroll offset, so give all three distinct keys.
            key: PageStorageKey(
                'lecture-manual-qr-${widget.course.id}-${widget.sessionId}'),
            title: const Text('عرض الرمز للإدخال اليدوي'),
            children: [
              SelectableText(qr!['payload'] as String,
                  key: PageStorageKey(
                      'lecture-manual-qr-text-${widget.course.id}-${widget.sessionId}')),
            ]),
      ],
      if (updatedAt != null)
        Text('آخر تحديث: ${localTime(updatedAt!.toIso8601String())}'),
      AsyncButton(
          label: 'تحديث الجلسة', icon: Icons.refresh, onPressed: refresh),
      if (isOpen)
        AsyncButton(
            label: 'إغلاق جلسة الحضور',
            icon: Icons.stop_circle_outlined,
            onPressed: () async {
              if (!await confirm(context, 'إغلاق جلسة الحضور',
                  'سيتم تثبيت الغياب للطلاب الذين لم يسجلوا حضورهم.')) {
                return;
              }
              await widget.api.writeCourse(
                  widget.course, 'sessions/${widget.sessionId}/close', null);
              await refresh();
            }),
      for (final row in rows)
        StatusRow(
            row['full_name'] as String, markLabel(row['status'] as String?)),
    ]);
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage(this.api, {super.key});
  final AttendanceApi api;
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  // A late permission response may still be cleaning up an earlier route.
  // Its platform disposal must finish before the next scanner starts.
  static Future<void> lastCameraCleanup = Future.value();
  final camera = MobileScannerController(
      autoStart: false, detectionSpeed: DetectionSpeed.noDuplicates);
  final manual = TextEditingController();
  ScannerMediaLease? media;
  Future<void>? starting;
  bool closing = false;
  bool allowPop = false;
  bool appActive = true;
  bool manualExpanded = false;
  bool busy = false;
  bool scanPaused = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(startCamera());
    });
  }

  Future<void> startCamera() {
    if (closing || !mounted || !appActive) return Future.value();
    if (camera.value.isRunning) return Future.value();
    if (starting != null) {
      return starting!.then((_) async {
        if (mounted &&
            !closing &&
            appActive &&
            !scanPaused &&
            media?.released == true) {
          await startCamera();
        }
      });
    }
    final lease = ScannerMediaLease();
    media = lease;
    return starting = openCamera(lease, lastCameraCleanup);
  }

  Future<void> openCamera(
      ScannerMediaLease lease, Future<void> previousCleanup) async {
    try {
      await previousCleanup;
      if (!mounted || closing || !appActive || scanPaused) {
        lease.release();
        return;
      }
      await lease.captureWhile(() => camera.start());
      if (!mounted || closing || !appActive || scanPaused) {
        lease.release();
        await camera.stop();
      }
    } catch (_) {
      lease.release();
      // The scanner's errorBuilder offers the manual-entry fallback.
    } finally {
      starting = null;
    }
  }

  Future<void> stopCamera() async {
    media?.release();
    await camera.stop();
  }

  Future<void> leaveScanner() async {
    if (closing) return;
    closing = true;
    try {
      await stopCamera();
    } finally {
      if (mounted) {
        setState(() => allowPop = true);
        Navigator.pop(context);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appActive = true;
      if (!scanPaused && !closing) unawaited(startCamera());
    } else if (state != AppLifecycleState.inactive || camera.value.isRunning) {
      // An initial web permission dialog can report inactive before startup.
      appActive = false;
      unawaited(stopCamera());
    }
  }

  Future<void> disposeCamera(Future<void> previousCleanup) async {
    try {
      await previousCleanup;
      await starting;
      await stopCamera();
    } finally {
      await camera.dispose();
    }
  }

  @override
  void dispose() {
    closing = true;
    media?.release();
    WidgetsBinding.instance.removeObserver(this);
    lastCameraCleanup = disposeCamera(lastCameraCleanup).catchError((Object _) {
      // Browser tracks have already been released synchronously above.
      // A platform disposal failure must not block every future scanner route.
    });
    manual.dispose();
    super.dispose();
  }

  Future<void> submit(String payload) async {
    if (busy || payload.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.request('POST', '/attendance/check-ins',
          body: {'payload': payload}) as Map<String, dynamic>;
      if (!mounted || closing) return;
      // Web readers can emit the same QR repeatedly despite noDuplicates.
      // Stop after a confirmed receipt; only an explicit action resumes scanning.
      setState(() => scanPaused = true);
      try {
        await stopCamera();
      } catch (_) {
        // The attendance is already saved; a preview-stop error must not hide it.
      }
      if (!mounted || closing) return;
      await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
                  title: Text(response['duplicate'] == true
                      ? 'حضورك مسجل بالفعل'
                      : 'تم تسجيل حضورك'),
                  content:
                      SingleChildScrollView(child: AttendanceReceipt(response)),
                  actions: [
                    FilledButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('تم'))
                  ]));
    } catch (error) {
      if (mounted) notice(context, '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(leaveScanner());
      },
      child: PageContent(children: [
        Text('مسح رمز حضور المحاضرة',
            style: Theme.of(context).textTheme.headlineSmall),
        const Text('وجّه الكاميرا إلى الرمز الذي يعرضه دكتور المحاضرة.'),
        SizedBox(
            height: 280,
            child: scanPaused
                ? const Center(
                    child: Text(
                        'توقف المسح بعد تسجيل الحضور. اضغط «مسح رمز آخر» للمتابعة.'))
                : MobileScanner(
                    controller: camera,
                    errorBuilder: (context, error) => const Center(
                        child: Text(
                            'تعذر فتح الكاميرا. تحقق من الإذن أو أدخل الرمز أدناه.')),
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null && !busy && !scanPaused) submit(raw);
                    })),
        SizedBox(
            height: 4,
            child: busy
                ? const LinearProgressIndicator()
                : const SizedBox.shrink()),
        if (scanPaused)
          AsyncButton(
              label: 'مسح رمز آخر',
              icon: Icons.qr_code_scanner,
              enabled: !busy,
              onPressed: () async {
                setState(() => scanPaused = false);
                await WidgetsBinding.instance.endOfFrame;
                if (mounted) await startCamera();
              }),
        ExpansionTile(
            key: const PageStorageKey('manual_qr_tile'),
            initiallyExpanded: manualExpanded,
            onExpansionChanged: (v) => manualExpanded = v,
            title: const Text('إدخال الرمز يدوياً'),
            children: [
              TextField(
                  // ExpansionTile stores a bool; EditableText's scroll offset
                  // must use a different PageStorage identifier (a double).
                  key: const PageStorageKey('manual_qr_input'),
                  controller: manual,
                  decoration: const InputDecoration(labelText: 'رمز الحضور')),
              const SizedBox(height: 12),
              AsyncButton(
                  label: 'تأكيد الحضور',
                  enabled: !busy,
                  onPressed: () => submit(manual.text)),
            ]),
      ]));
}

class AttendanceReceipt extends StatelessWidget {
  const AttendanceReceipt(this.receipt, {super.key});
  final Map<String, dynamic> receipt;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${receipt['course_code']} · ${receipt['course_name']}'),
            Text('${receipt['session_title']}'),
            Text('الحالة: ${markLabel(receipt['status'] as String?)}'),
            Text('وقت التسجيل: ${localTime(receipt['recorded_at'])}'),
            SelectableText('رقم الإيصال: ${receipt['receipt_id']}'),
            TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text:
                          '${receipt['course_code']} · ${receipt['course_name']}\n${receipt['session_title']}\n'
                          '${markLabel(receipt['status'] as String?)} · ${localTime(receipt['recorded_at'])}\nرقم الإيصال: ${receipt['receipt_id']}'));
                  if (context.mounted) notice(context, 'تم نسخ إيصال الحضور.');
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ إيصال الحضور')),
          ]);
}
