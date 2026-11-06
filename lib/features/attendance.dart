import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage(this.state, {super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return RemotePage<Map<String, dynamic>>(
        scope: state.scopeKey,
        load: () async {
          final results = await Future.wait([
            state.api
                .getCourse(state.course!, 'sessions',
                    sectionId: state.section?.id)
                .then((v) => (v as List)
                    .map((item) => AttendanceSession.fromJson(
                        item as Map<String, dynamic>))
                    .toList()),
            // BUG-09: fetch full-history summary, not just the capped listing.
            state.api.getCourse(state.course!, 'sessions/summary'),
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
            for (final session in sessions)
              ActionCard(
                  title: session.title,
                  detail:
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
                            editable: state.user!.role == Role.ta &&
                                session.state == 'draft');
                    await openPage(context, session.title, page);
                    reload();
                  }),
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
    return StatusRow(label, text);
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
    return Form(
        key: form,
        child: PageContent(children: [
          StatusRow(state.course!.name, state.section?.label ?? 'جميع السكاشن'),
          TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'عنوان الجلسة'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'اكتب عنوان الجلسة.' : null),
          if (lecture)
            TextFormField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'مدة فتح الحضور بالدقائق'),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number < 1 || number > 180
                      ? 'اختر مدة من 1 إلى 180 دقيقة.'
                      : null;
                }),
          AsyncButton(
              label: lecture ? 'فتح الجلسة وعرض الرمز' : 'إنشاء كشف الحضور',
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final data =
                    await state.api.writeCourse(state.course!, 'sessions', {
                  'kind': lecture ? 'lecture' : 'section',
                  'title': title.text.trim(),
                  'section_id': state.section?.id,
                  'duration_minutes': lecture ? int.parse(duration.text) : 60,
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
        ]));
  }
}

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage(this.api, this.course, this.sessionId,
      {super.key, this.editable = false});
  final AttendanceApi api;
  final CourseOffering course;
  final int sessionId;
  final bool editable;
  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final marks = <int, String>{};
  final search = TextEditingController();
  Map<String, dynamic>? loaded;
  bool pendingOnly = false;
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
      !hasChanges ||
      await confirm(context, 'حالات حضور غير محفوظة',
          'لم يُعتمد الكشف بعد. المغادرة أو التحديث سيفقد الحالات المحددة. هل تريد المتابعة؟');

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await confirmDiscard() || !context.mounted) return;
        Navigator.pop(context);
      },
      child: RemotePage<dynamic>(
          beforeRefresh: confirmDiscard,
          load: () => widget.api
              .getCourse(widget.course, 'sessions/${widget.sessionId}'),
          builder: (data, reload) {
            final rows = data['rows'] as List?;
            final editable = widget.editable && data['state'] == 'draft';
            if (rows == null) {
              return PageContent(children: [
                StatusRow(data['title'] as String,
                    '${markLabel(data['record']?['status'] as String?)} · ${localTime(data['starts_at'])}')
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
                      if (editable)
                        AsyncButton(
                            label: 'مراجعة واعتماد الكشف',
                            enabled:
                                rows.isNotEmpty && marks.length == rows.length,
                            onPressed: () async {
                              if (!await confirm(context, 'اعتماد كشف الحضور',
                                  'سيتم حفظ حالات جميع الطلاب في سجل الجلسة.')) {
                                return;
                              }
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
                            }),
                    ]),
                children: [
                  StatusRow(data['title'] as String,
                      '${rows.length} طالب · ${data['state'] == 'finalized' ? 'كشف معتمد' : 'كشف حضور'}'),
                  Text(
                      'حاضر ${marks.values.where((m) => m == 'present').length} · غائب ${marks.values.where((m) => m == 'absent').length} · '
                      'بعذر ${marks.values.where((m) => m == 'excused').length} · غير محدد ${rows.length - marks.length}'),
                  if (editable)
                    const NoticeBanner(
                        'اختيارات الحضور تبقى في هذه الشاشة حتى اعتماد الكشف. راجع الحالات قبل المغادرة.'),
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
                          if (await confirm(context, 'تحديد الجميع غائب',
                              'يمكنك تعديل الطلاب الحاضرين بعد هذه الخطوة.')) {
                            setState(() {
                              for (final row in rows) {
                                marks[row['enrollment_id'] as int] = 'absent';
                              }
                            });
                          }
                        },
                        child: const Text('تحديد الجميع غائب')),
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
                                            onSelected: (_) => setState(() =>
                                                marks[row['enrollment_id']
                                                    as int] = mark)),
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
            title: const Text('عرض الرمز للإدخال اليدوي'),
            children: [SelectableText(qr!['payload'] as String)]),
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

class _ScanPageState extends State<ScanPage> {
  final camera =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final manual = TextEditingController();
  bool manualExpanded = false;
  bool busy = false;
  @override
  void dispose() {
    unawaited(camera.dispose());
    manual.dispose();
    super.dispose();
  }

  Future<void> submit(String payload) async {
    if (busy || payload.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.request('POST', '/attendance/check-ins',
          body: {'payload': payload}) as Map<String, dynamic>;
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
                  title: Text(response['duplicate'] == true
                      ? 'حضورك مسجل بالفعل'
                      : 'تم تسجيل حضورك'),
                  content: Text(
                      'الجلسة ${response['session_id']} · ${localTime(response['recorded_at'])}\nرقم الإيصال: ${response['receipt_id']}'),
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
  Widget build(BuildContext context) => PageContent(children: [
        Text('مسح رمز حضور المحاضرة',
            style: Theme.of(context).textTheme.headlineSmall),
        const Text('وجّه الكاميرا إلى الرمز الذي يعرضه دكتور المحاضرة.'),
        SizedBox(
            height: 280,
            child: MobileScanner(
                controller: camera,
                errorBuilder: (context, error) => const Center(
                    child: Text(
                        'تعذر فتح الكاميرا. تحقق من الإذن أو أدخل الرمز أدناه.')),
                onDetect: (capture) {
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw != null && !busy) submit(raw);
                })),
        SizedBox(
            height: 4,
            child: busy
                ? const LinearProgressIndicator()
                : const SizedBox.shrink()),
        ExpansionTile(
            key: const PageStorageKey('manual_qr_tile'),
            initiallyExpanded: manualExpanded,
            onExpansionChanged: (v) => manualExpanded = v,
            title: const Text('إدخال الرمز يدوياً'),
            children: [
              TextField(
                  controller: manual,
                  decoration: const InputDecoration(labelText: 'رمز الحضور')),
              const SizedBox(height: 12),
              AsyncButton(
                  label: 'تأكيد الحضور',
                  enabled: !busy,
                  onPressed: () => submit(manual.text)),
            ]),
      ]);
}
