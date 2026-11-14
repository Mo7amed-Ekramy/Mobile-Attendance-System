import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/edit_conflicts.dart';
import 'quizzes.dart';

class GradesPage extends StatelessWidget {
  const GradesPage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => RemotePage<dynamic>(
      scope: state.scopeKey,
      load: () async => {
            'policy': await state.api.getCourse(state.course!, 'policy'),
            'assessments': await state.api.getCourse(
                state.course!, 'assessments',
                sectionId: state.section?.id),
            if (state.user!.role == Role.student)
              'grades': await state.api.getCourse(state.course!, 'grades'),
          },
      builder: (data, reload) {
        final policy = data['policy'] as Map<String, dynamic>?;
        final assessments = data['assessments'] as List;
        final student = state.user!.role == Role.student;
        return PageContent(children: [
          Text(student ? 'درجاتي المنشورة' : 'الدرجات والتقييمات',
              style: Theme.of(context).textTheme.headlineSmall),
          if (state.user!.role == Role.ta) ...[
            Text('${state.course!.code} · ${state.section?.label ?? ''}'),
            const NoticeBanner(
                'رصد أعمال السكشن: الكويزات والتكليفات والمشاريع. حفظ الدرجات لا ينشرها؛ يعتمد الدكتور نشر النتائج.'),
          ],
          if (student) ...[
            if (policy == null)
              const EmptyPanel('لم تنشر لائحة الدرجات بعد',
                  'ستظهر نتائجك بعد اعتماد اللائحة ونشر التقييمات.'),
            if (policy != null) ...[
              StatusRow('الدرجات المحققة حتى الآن',
                  pointRatio(data['grades']['earned'], policy['total_points'])),
              StatusRow(
                  'المجموع النهائي',
                  data['grades']['official_total'] == null
                      ? 'غير مكتمل: توجد بنود لم يكتمل رصدها.'
                      : points(data['grades']['official_total'])),
              for (final category in data['grades']['categories'] as List)
                StatusRow(category['name'] as String,
                    '${pointRatio(category['earned'], category['max_points'])}${category['complete'] == true ? '' : ' · غير مكتمل'}'),
            ],
          ] else ...[
            ActionCard(
                title: 'لائحة توزيع الدرجات',
                detail: policy == null
                    ? 'لم تنشأ لائحة للمقرر.'
                    : '${policy['state'] == 'published' ? 'معتمدة' : 'مسودة'} · ${points(policy['total_points'])} درجة',
                icon: Icons.tune,
                onTap: () async {
                  await openPage(
                      context,
                      'لائحة توزيع الدرجات',
                      PolicyPage(state.api, state.course!,
                          editable: state.user!.role == Role.doctor));
                  reload();
                }),
            if (policy != null)
              AsyncButton(
                  label: 'إضافة تقييم',
                  icon: Icons.add,
                  enabled: (policy['categories'] as List)
                      .any((category) => category['kind'] == 'assessment'),
                  onPressed: () async {
                    await openPage(
                        context,
                        'إضافة تقييم',
                        AssessmentPage(state.api, state.course!, policy,
                            sectionId: state.section?.id,
                            allowExams: state.user!.role == Role.doctor));
                    reload();
                  }),
          ],
          ActionCard(
              title: student ? 'كويزات السكشن' : 'بنك الأسئلة وكويزات السكشن',
              detail: 'الأسئلة والمحاولات والنتائج المحفوظة',
              icon: Icons.quiz_outlined,
              onTap: () async {
                await openPage(context, 'كويزات السكشن', QuizzesPage(state));
                reload();
              }),
          if (assessments.isEmpty)
            const EmptyPanel('لا توجد تقييمات',
                'ستظهر التقييمات المنشأة والمنشورة وفق صلاحية الحساب.'),
          for (final assessment in assessments)
            if (student)
              StatusRow(
                  assessment['title'] as String,
                  '${assessment['category']} · ${assessment['state'] == 'excused' ? 'بعذر' : assessment['score'] == null ? 'لم ترصد النتيجة' : pointRatio(assessment['score'], assessment['max_points'])}')
            else
              ActionCard(
                  title: assessment['title'] as String,
                  detail:
                      '${assessment['category']} · ${points(assessment['max_points'])} درجة',
                  icon: Icons.grading,
                  onTap: () async {
                    await openPage(
                        context,
                        assessment['title'] as String,
                        GradebookPage(state.api, state.course!, assessment,
                            sectionId: state.section?.id,
                            canPublish: state.user!.role == Role.doctor));
                    reload();
                  }),
        ]);
      });
}

class _CategoryForm {
  _CategoryForm({Map<String, dynamic>? source, required int index})
      : code = source?['code'] as String? ??
            'category_${DateTime.now().microsecondsSinceEpoch}_$index',
        name = TextEditingController(text: source?['name'] as String? ?? ''),
        maximum = TextEditingController(
            text: source?['max_points']?.toString() ?? '0'),
        kind = source?['kind'] as String? ?? 'assessment',
        mode = source?['allocation_mode'] as String? ?? 'fixed';
  final String code;
  final TextEditingController name, maximum;
  String kind, mode;
  void dispose() {
    name.dispose();
    maximum.dispose();
  }

  Map<String, dynamic> json() => {
        'code': code,
        'name': name.text.trim(),
        'kind': kind,
        'max_points': maximum.text,
        'allocation_mode': mode
      };
}

class PolicyPage extends StatefulWidget {
  const PolicyPage(this.api, this.course, {super.key, required this.editable});
  final AttendanceApi api;
  final CourseOffering course;
  final bool editable;
  @override
  State<PolicyPage> createState() => _PolicyPageState();
}

class _PolicyPageState extends State<PolicyPage> {
  final total = TextEditingController(text: '100');
  final categories = <_CategoryForm>[];
  Map<String, dynamic>? policy;
  bool initialized = false;
  Object? loadedPolicy;
  String? baseline;
  bool saving = false;
  String get snapshot => jsonEncode({
        'total_points': total.text,
        'categories': categories.map((c) => c.json()).toList()
      });
  bool get hasChanges =>
      initialized &&
      widget.editable &&
      policy?['state'] != 'published' &&
      snapshot != baseline;

  Future<void> saveDraft() async {
    if (categories.isEmpty ||
        categories.any((c) => c.name.text.trim().isEmpty)) {
      throw const ApiException('أضف بنود اللائحة واكتب اسم كل بند.');
    }
    setState(() => saving = true);
    try {
      final saved = await widget.api.writeCourse(
          widget.course,
          'policy',
          {
            'total_points': total.text,
            'categories': categories.map((c) => c.json()).toList(),
          },
          method: 'PUT') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          policy = saved;
          baseline = snapshot;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> confirmLeave() async {
    if (saving) return false;
    if (!hasChanges) return true;
    final choice = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('تعديلات اللائحة غير محفوظة'),
              content:
                  const Text('احفظ التعديلات للاحتفاظ بها أو اختر تجاهلها.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('إلغاء')),
                TextButton(
                    onPressed: () => Navigator.pop(dialog, 'discard'),
                    child: const Text('تجاهل التعديلات')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, 'save'),
                    child: const Text('حفظ ومتابعة')),
              ],
            ));
    if (choice == null || !mounted) return false;
    if (choice == 'save') {
      try {
        await saveDraft();
      } catch (error) {
        if (mounted) notice(context, '$error');
        return false;
      }
    } else {
      initialized = false;
    }
    return true;
  }

  @override
  void dispose() {
    total.dispose();
    for (final category in categories) {
      category.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !hasChanges && !saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await confirmLeave() || !context.mounted) return;
        Navigator.pop(context);
      },
      child: RemotePage<dynamic>(
          beforeRefresh: confirmLeave,
          load: () => widget.api.getCourse(widget.course, 'policy'),
          builder: (value, reload) {
            final incoming = value as Map<String, dynamic>?;
            if (!initialized || !identical(loadedPolicy, incoming)) {
              loadedPolicy = incoming;
              initialized = true;
              policy = incoming;
              total.text = policy?['total_points']?.toString() ?? '100';
              for (final category in categories) {
                category.dispose();
              }
              categories.clear();
              for (final category in policy?['categories'] as List? ?? []) {
                categories.add(_CategoryForm(
                    source: category as Map<String, dynamic>,
                    index: categories.length));
              }
              baseline = snapshot;
            }
            final editable =
                widget.editable && policy?['state'] != 'published' && !saving;
            final allocated = categories.fold<double>(
                0,
                (sum, category) =>
                    sum + (double.tryParse(category.maximum.text) ?? 0));
            return PageContent(children: [
              StatusRow(
                  'لائحة المقرر',
                  policy?['state'] == 'published'
                      ? 'لائحة منشورة ومقفلة'
                      : 'مسودة: احفظ البنود ثم أضف التقييمات قبل الاعتماد.'),
              if (hasChanges)
                const NoticeBanner('لديك تعديلات غير محفوظة في اللائحة.'),
              const NoticeBanner(
                  'مثال: تقييمان درجتاهما 8/10 و16/20. الدرجات الثابتة تجمعهما إلى 24 من 30. التجميع النسبي لبند مخصص له 10 درجات يعطي 10 × 24 ÷ 30 = 8 درجات.'),
              TextField(
                  controller: total,
                  enabled: editable,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المجموع الكلي'),
                  onChanged: (_) => setState(() {})),
              Text(
                  'المجموع الموزع: ${ltrValue('${allocated.toStringAsFixed(2)} / ${total.text}')}'),
              for (var i = 0; i < categories.length; i++)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          TextField(
                              controller: categories[i].name,
                              onChanged: (_) => setState(() {}),
                              enabled: editable,
                              decoration: const InputDecoration(
                                  labelText: 'اسم البند')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: categories[i].maximum,
                              enabled: editable,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'الدرجات المخصصة'),
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                              initialValue: categories[i].kind,
                              decoration:
                                  const InputDecoration(labelText: 'نوع البند'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'assessment',
                                    child: Text('تقييمات واختبارات')),
                                DropdownMenuItem(
                                    value: 'lecture_attendance',
                                    child: Text('حضور المحاضرات')),
                                DropdownMenuItem(
                                    value: 'section_attendance',
                                    child: Text('حضور السكاشن'))
                              ],
                              onChanged: !editable
                                  ? null
                                  : (value) => setState(() {
                                        categories[i].kind = value!;
                                        categories[i].mode =
                                            value == 'assessment'
                                                ? 'fixed'
                                                : 'proportional';
                                      })),
                          if (categories[i].kind == 'assessment') ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                                key: ValueKey(
                                    '${categories[i].code}:${categories[i].kind}'),
                                initialValue: categories[i].mode,
                                decoration: const InputDecoration(
                                    labelText: 'طريقة احتساب الدرجة'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'fixed',
                                      child: Text('درجات ثابتة')),
                                  DropdownMenuItem(
                                      value: 'normalized',
                                      child: Text('تجميع نسبي'))
                                ],
                                onChanged: !editable
                                    ? null
                                    : (value) => setState(
                                        () => categories[i].mode = value!)),
                          ],
                          if (editable)
                            TextButton.icon(
                                onPressed: () => setState(() {
                                      categories.removeAt(i).dispose();
                                    }),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('حذف البند')),
                        ]))),
              if (categories.isEmpty)
                const EmptyPanel('لا توجد بنود تقييم',
                    'أضف بنود اللائحة وحدد درجات كل بند.'),
              if (editable) ...[
                OutlinedButton.icon(
                    onPressed: () => setState(() => categories
                        .add(_CategoryForm(index: categories.length))),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة بند')),
                AsyncButton(
                    label: 'حفظ مسودة اللائحة',
                    enabled: categories.isNotEmpty,
                    onPressed: () async {
                      await saveDraft();
                      if (context.mounted) {
                        notice(context, 'تم حفظ مسودة اللائحة.');
                      }
                    }),
                if (policy != null)
                  AsyncButton(
                      label: 'اعتماد اللائحة',
                      icon: Icons.publish,
                      onPressed: () async {
                        if (!await confirm(context, 'اعتماد لائحة الدرجات',
                            'ستصبح اللائحة مقفلة بعد الاعتماد. احفظ أي تغييرات أولاً.')) {
                          return;
                        }
                        await saveDraft();
                        if (!mounted) return;
                        setState(() => saving = true);
                        try {
                          final published = await widget.api.writeCourse(
                                  widget.course, 'policy/publish', null)
                              as Map<String, dynamic>;
                          if (mounted) setState(() => policy = published);
                          if (context.mounted) {
                            notice(context, 'تم اعتماد اللائحة.');
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      }),
              ],
            ]);
          }));
}

class AssessmentPage extends StatefulWidget {
  const AssessmentPage(this.api, this.course, this.policy,
      {super.key, this.sectionId, this.allowExams = true});
  final AttendanceApi api;
  final CourseOffering course;
  final Map<String, dynamic> policy;
  final int? sectionId;
  final bool allowExams;
  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final title = TextEditingController();
  final maximum = TextEditingController();
  int? category;
  String kind = 'quiz';
  @override
  void dispose() {
    title.dispose();
    maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = (widget.policy['categories'] as List)
        .where((c) => c['kind'] == 'assessment')
        .toList();
    return PageContent(children: [
      TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'عنوان التقييم')),
      DropdownButtonFormField<int>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'بند اللائحة'),
          items: [
            for (final c in categories)
              DropdownMenuItem(
                  value: c['id'] as int, child: Text(c['name'] as String))
          ],
          onChanged: (value) => category = value),
      DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'نوع التقييم'),
          items: [
            const DropdownMenuItem(value: 'quiz', child: Text('كويز ورقي')),
            const DropdownMenuItem(value: 'project', child: Text('مشروع')),
            const DropdownMenuItem(value: 'assignment', child: Text('تكليف')),
            if (widget.allowExams) ...[
              const DropdownMenuItem(value: 'midterm', child: Text('ميدتيرم')),
              const DropdownMenuItem(value: 'final', child: Text('فاينال')),
            ],
          ],
          onChanged: (value) => kind = value!),
      TextField(
          controller: maximum,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'الدرجة العظمى')),
      AsyncButton(
          label: 'إنشاء التقييم',
          onPressed: () async {
            if (title.text.trim().isEmpty ||
                category == null ||
                (double.tryParse(maximum.text) ?? 0) <= 0) {
              throw const ApiException(
                  'اكتب عنواناً واختر بنداً ودرجة عظمى صحيحة.');
            }
            await widget.api.writeCourse(widget.course, 'assessments', {
              'category_id': category,
              'section_id': widget.sectionId,
              'title': title.text.trim(),
              'kind': kind,
              'max_points': maximum.text
            });
            if (context.mounted) Navigator.pop(context, true);
          }),
    ]);
  }
}

class GradebookPage extends StatefulWidget {
  const GradebookPage(this.api, this.course, this.assessment,
      {super.key, this.sectionId, required this.canPublish});
  final AttendanceApi api;
  final CourseOffering course;
  final Map<String, dynamic> assessment;
  final int? sectionId;
  final bool canPublish;
  @override
  State<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends State<GradebookPage> {
  final fields = <int, TextEditingController>{};
  final states = <int, String>{};
  final reason = TextEditingController();
  Object? loadedData;
  int offset = 0;
  bool saving = false;
  bool conflicted = false;

  Future<void> resolveConflict(Map<String, dynamic> data) async {
    setState(() => conflicted = true);
    final edits = <int, Map<String, dynamic>>{};
    for (final row in data['rows'] as List) {
      final id = row['enrollment_id'] as int;
      if (double.tryParse(fields[id]!.text.trim()) != amount(row['score']) ||
          states[id] != row['state']) {
        edits[id] = {'score': fields[id]!.text, 'state': states[id]};
      }
    }
    final latest = await widget.api.getCourse(
        widget.course, 'assessments/${widget.assessment['id']}/results',
        sectionId: widget.sectionId,
        query: {'offset': offset, 'limit': 50}) as Map<String, dynamic>;
    if (!mounted) return;
    String value(dynamic score, dynamic state) => state == 'excused'
        ? 'بعذر'
        : score == null || '$score'.isEmpty
            ? 'غير مرصود'
            : '$score';
    final choice =
        await reviewEditConflict(context, canReapply: true, differences: [
      for (final row in latest['rows'] as List)
        if (edits.containsKey(row['enrollment_id']))
          '${row['full_name']} · ${row['university_id']}\n'
              'تعديلي: ${value(edits[row['enrollment_id']]!['score'], edits[row['enrollment_id']]!['state'])}\n'
              'الخادم: ${value(row['score'], row['state'])}'
    ]);
    if (choice == null || !mounted) return;
    setState(() {
      data
        ..clear()
        ..addAll(latest);
      for (final row in latest['rows'] as List) {
        final id = row['enrollment_id'] as int;
        final edit = choice == ConflictChoice.local ? edits[id] : null;
        fields.putIfAbsent(id, TextEditingController.new).text =
            edit?['score'] as String? ?? row['score']?.toString() ?? '';
        states[id] = edit?['state'] as String? ?? row['state'] as String;
      }
      conflicted = false;
    });
  }

  Future<bool> publish() async {
    final preview = await widget.api.getCourse(widget.course,
            'assessments/${widget.assessment['id']}/publication-preview')
        as Map<String, dynamic>;
    if (!mounted ||
        !await confirm(
            context,
            preview['republication'] == true
                ? 'مراجعة إعادة النشر'
                : 'مراجعة نشر النتائج',
            '${widget.course.code} · ${preview['title']}\nالنطاق: ${preview['scope']}\n'
            'جميع الطلاب المؤهلين: ${preview['eligible']}\n'
            'مرصود: ${preview['recorded']} · بعذر: ${preview['excused']} · غير مرصود: ${preview['unrecorded']}\n'
            'نتائج محفوظة تنتظر النشر: ${preview['pending_changes']}\n'
            'سيتم نشر ${preview['saved_results']} نتيجة محفوظة للتقييم كاملًا، بما فيها السجلات التاريخية المحفوظة. النشر لا يقتصر على الصفحة أو السكشن المعروض.\n'
            'النتائج غير المرصودة ستظل غير مكتملة.')) {
      return false;
    }
    await widget.api.writeCourse(
        widget.course,
        'assessments/${widget.assessment['id']}/publish',
        {'fingerprint': preview['fingerprint']});
    return true;
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    reason.dispose();
    super.dispose();
  }

  bool get _hasUnsaved {
    // ADD-04: True when any in-page field differs from the last loaded server data.
    if (loadedData == null) return false;
    final rows = (loadedData as Map<String, dynamic>)['rows'] as List? ?? [];
    for (final row in rows) {
      final id = row['enrollment_id'] as int;
      final text = fields[id]?.text.trim() ?? '';
      final score = double.tryParse(text);
      if (text.isNotEmpty && (score == null || !score.isFinite)) return true;
      final loadedScore = amount(row['score']);
      final loadedState = row['state'] as String;
      final currentState = states[id] ?? loadedState;
      if (score != loadedScore || currentState != loadedState) return true;
    }
    return false;
  }

  Future<bool> _confirmDiscard() async =>
      !saving &&
      (!_hasUnsaved ||
          await confirm(context, 'تغييرات غير محفوظة',
              'الانتقال أو التحديث سيستبدل درجات الصفحة غير المحفوظة. هل تريد المتابعة؟'));

  Future<void> _changePage(int next) async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => offset = next);
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || saving) return;
        if (_hasUnsaved) {
          final leave = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                      title: const Text('توجد تغييرات غير محفوظة'),
                      content: const Text(
                          'هل تريد الخروج وتجاهل التغييرات غير المحفوظة؟'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: const Text('تراجع')),
                        FilledButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('خروج بدون حفظ')),
                      ]));
          if (leave != true) return;
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: RemotePage<dynamic>(
          beforeRefresh: _confirmDiscard,
          refreshInterval: const Duration(seconds: 10),
          canAutoRefresh: () => !saving && !conflicted && !_hasUnsaved,
          scope: '$offset',
          load: () => widget.api.getCourse(
              widget.course, 'assessments/${widget.assessment['id']}/results',
              sectionId: widget.sectionId,
              query: {'offset': offset, 'limit': 50}),
          builder: (data, reload) {
            final rows = data['rows'] as List;
            final canEdit = data['editable'] != false;
            if (!identical(data, loadedData)) {
              loadedData = data;
              for (final row in rows) {
                final id = row['enrollment_id'] as int;
                fields.putIfAbsent(id, TextEditingController.new).text =
                    row['score']?.toString() ?? '';
                states[id] = row['state'] as String;
              }
            }
            return PageContent(
                footer: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (canEdit)
                        AsyncButton(
                            label: 'حفظ درجات الصفحة',
                            enabled: rows.isNotEmpty && !saving,
                            onPressed: () async {
                              final changed = <Map<String, dynamic>>[];
                              for (final row in rows) {
                                final text =
                                    fields[row['enrollment_id']]!.text.trim();
                                final score =
                                    text.isEmpty ? null : double.tryParse(text);
                                if (text.isNotEmpty &&
                                    (score == null ||
                                        !score.isFinite ||
                                        score < 0 ||
                                        score >
                                            amount(widget
                                                .assessment['max_points'])!)) {
                                  throw const ApiException(
                                      'توجد درجة خارج الحدود المسموحة.');
                                }
                                if (score != amount(row['score']) ||
                                    states[row['enrollment_id']] !=
                                        row['state']) {
                                  changed.add({
                                    'enrollment_id': row['enrollment_id'],
                                    'score': text.isEmpty ? null : text,
                                    'state': states[row['enrollment_id']],
                                    'revision': row['revision'],
                                  });
                                }
                              }
                              if (changed.isEmpty) {
                                notice(context, 'لا توجد تغييرات لحفظها.');
                                return;
                              }
                              setState(() => saving = true);
                              try {
                                await widget.api.writeCourse(
                                    widget.course,
                                    'assessments/${widget.assessment['id']}/results',
                                    {
                                      'rows': changed,
                                      'reason': reason.text.trim()
                                    },
                                    method: 'PATCH');
                              } on ApiException catch (error) {
                                if (error.status == 409) {
                                  await resolveConflict(
                                      data as Map<String, dynamic>);
                                  return;
                                }
                                rethrow;
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                              if (context.mounted) {
                                notice(context, 'تم حفظ الدرجات.');
                              }
                              reload();
                            }),
                      if (widget.canPublish && canEdit)
                        AsyncButton(
                            label: 'نشر نتائج التقييم',
                            enabled: !_hasUnsaved && !saving,
                            icon: Icons.publish,
                            onPressed: () async {
                              setState(() => saving = true);
                              try {
                                if (!await publish()) return;
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                              if (context.mounted) {
                                notice(context, 'تم نشر النتائج.');
                              }
                              reload();
                            }),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: offset == 0
                                    ? null
                                    : () => _changePage(offset - 50),
                                child: const Text('السابق'))),
                        const SizedBox(width: 8),
                        Text(
                            '${rows.isEmpty ? 0 : offset + 1}–${offset + rows.length} / ${data['total']}'),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: offset + 50 >= (data['total'] as int)
                                    ? null
                                    : () => _changePage(offset + 50),
                                child: const Text('التالي')))
                      ]),
                    ]),
                children: [
                  StatusRow(widget.assessment['title'] as String,
                      'الدرجة العظمى ${points(widget.assessment['max_points'])}'),
                  if (canEdit)
                    const Text(
                        'الصفر نتيجة مسجلة، والحقل الفارغ نتيجة لم ترصد.')
                  else
                    NoticeBanner(
                        data['editing_unavailable_reason'] as String? ??
                            'هذا السجل متاح للاطلاع فقط.'),
                  if (conflicted)
                    const NoticeBanner(
                        'تعارض في الحفظ. تعديلاتك المحلية لم تُحذف؛ أعد الحفظ لمراجعة القيم.',
                        isError: true),
                  if (_hasUnsaved)
                    const NoticeBanner(
                        'تغييرات غير محفوظة · احفظ درجات الصفحة قبل الانتقال أو النشر.',
                        icon: Icons.edit_outlined),
                  if (!_hasUnsaved &&
                      data['assessment']?['published_at'] != null &&
                      rows.any((row) =>
                          row['visibility'] == 'draft' && row['revision'] > 0))
                    const NoticeBanner(
                        'توجد درجات محفوظة تنتظر إعادة النشر. النتائج السابقة ما زالت ظاهرة للطلاب.'),
                  OutlinedButton.icon(
                      onPressed: () async {
                        if (await _confirmDiscard()) reload();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث الدرجات')),
                  if (canEdit)
                    TextField(
                        controller: reason,
                        enabled: !saving,
                        decoration: const InputDecoration(
                            labelText: 'سبب تصحيح درجة منشورة، عند الحاجة')),
                  for (final row in rows)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row['full_name'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(row['university_id'] as String),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: fields[row['enrollment_id']],
                                      enabled: !saving && canEdit,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'الدرجة'),
                                      onChanged: saving || !canEdit
                                          ? null
                                          : (value) => setState(() {
                                                states[row['enrollment_id']
                                                        as int] =
                                                    value.trim().isEmpty
                                                        ? 'unrecorded'
                                                        : 'recorded';
                                              })),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('بعذر'),
                                      value: states[row['enrollment_id']] ==
                                          'excused',
                                      onChanged: saving || !canEdit
                                          ? null
                                          : (value) => setState(() {
                                                states[row['enrollment_id']
                                                        as int] =
                                                    value!
                                                        ? 'excused'
                                                        : 'unrecorded';
                                                fields[row['enrollment_id']]!
                                                    .clear();
                                              })),
                                ]))),
                  if (rows.isEmpty)
                    const EmptyPanel(
                        'لا يوجد طلاب', 'لا توجد تسجيلات ضمن السكشن المحدد.'),
                ]);
          }));
}
