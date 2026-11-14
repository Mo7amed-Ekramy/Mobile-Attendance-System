import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'grading.dart';

String quizSummary(Map<String, dynamic> quiz, bool student) {
  if (quiz['state'] == 'cancelled') return 'ملغى';
  if (quiz['state'] == 'draft') return 'مسودة · لم تُفتح للطلاب';
  if (quiz['state'] == 'scheduled') {
    return 'مجدول · يبدأ ${localTime(quiz['starts_at'])}';
  }
  if (!student) {
    if (quiz['state'] == 'closed') return 'مغلق';
    return '${quiz['submitted_count']} محاولة مسلمة · ينتهي ${localTime(quiz['ends_at'])}';
  }
  final attempt = quiz['attempt'] as Map<String, dynamic>?;
  final state = attempt == null ? null : attempt['state'];
  if (state == 'submitted') return 'تم التسليم يدويًا';
  if (state == 'timed_out') return 'تم إنهاء المحاولة تلقائيًا';
  if (quiz['state'] == 'closed') return 'الكويز مغلق';
  if (date(quiz['ends_at']).isBefore(DateTime.now().toUtc())) {
    return 'انتهت المدة';
  }
  if (date(quiz['starts_at']).isAfter(DateTime.now().toUtc())) {
    return 'لم يبدأ بعد';
  }
  if (state == 'in_progress') return 'محاولة محفوظة · تابع الحل';
  return 'ينتهي ${localTime(quiz['ends_at'])}';
}

bool quizHasCompletedAttempt(Map<String, dynamic> quiz) =>
    ['submitted', 'timed_out'].contains((quiz['attempt'] as Map?)?['state']);

bool quizAvailable(Map<String, dynamic> quiz) {
  final now = DateTime.now().toUtc();
  return !quizHasCompletedAttempt(quiz) &&
      quiz['state'] == 'active' &&
      !date(quiz['starts_at']).isAfter(now) &&
      date(quiz['ends_at']).isAfter(now);
}

bool quizCanOpen(Map<String, dynamic> quiz) =>
    quizAvailable(quiz) || quiz['attempt'] != null;

class QuizActionCard extends StatelessWidget {
  const QuizActionCard(this.quiz,
      {super.key, required this.student, required this.onOpen});
  final Map<String, dynamic> quiz;
  final bool student;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(quiz['title'] as String,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
                '${quiz['duration_minutes']} دقيقة · ${quizSummary(quiz, student)}'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
                onPressed: !student || quizCanOpen(quiz) ? onOpen : null,
                icon: Icon(quizHasCompletedAttempt(quiz)
                    ? Icons.fact_check_outlined
                    : Icons.play_arrow),
                label: Text(quizHasCompletedAttempt(quiz)
                    ? 'عرض النتيجة'
                    : quiz['attempt'] != null
                        ? 'متابعة المحاولة'
                        : 'ابدأ الكويز')),
          ])));
}

class QuizzesPage extends StatelessWidget {
  const QuizzesPage(this.state, {super.key});
  final AppState state;
  @override
  Widget build(BuildContext context) => RemotePage<dynamic>(
      scope: state.scopeKey,
      refreshInterval: const Duration(seconds: 10),
      load: () async => {
            'quizzes': await state.api.getCourse(state.course!, 'quizzes',
                sectionId: state.section?.id),
            if (state.user!.role != Role.student)
              'questions':
                  await state.api.getCourse(state.course!, 'questions'),
            if (state.user!.role != Role.student)
              'policy': await state.api.getCourse(state.course!, 'policy'),
          },
      builder: (data, reload) {
        final student = state.user!.role == Role.student;
        final quizzes = data['quizzes'] as List;
        return PageContent(children: [
          Text('كويزات السكشن',
              style: Theme.of(context).textTheme.headlineSmall),
          if (!student) ...[
            ActionCard(
                title: 'بنك أسئلة المقرر',
                detail:
                    '${(data['questions'] as List).length} سؤال · بنك مشترك للمقرر',
                icon: Icons.library_books_outlined,
                onTap: () async {
                  await openPage(context, 'بنك الأسئلة',
                      QuestionBankPage(state.api, state.course!));
                  reload();
                }),
            if (data['policy'] == null)
              const EmptyPanel('لائحة المقرر مطلوبة',
                  'يجب أن ينشئ الدكتور لائحة للمقرر قبل إضافة كويز مرتبط بالدرجات.')
            else if (!(data['policy']['categories'] as List)
                .any((category) => category['kind'] == 'assessment'))
              const EmptyPanel('لا يوجد بند للكويزات',
                  'يحتاج الدكتور إلى إضافة بند تقييم في لائحة المقرر أولاً.')
            else
              AsyncButton(
                  label: 'إنشاء كويز للسكشن',
                  icon: Icons.add,
                  enabled: (data['questions'] as List).isNotEmpty,
                  onPressed: () async {
                    await openPage(
                        context,
                        'إنشاء كويز',
                        QuizCreatorPage(
                            state,
                            data['policy'] as Map<String, dynamic>,
                            (data['questions'] as List).length));
                    reload();
                  }),
          ],
          if (quizzes.isEmpty)
            const EmptyPanel(
                'لا توجد كويزات', 'ستظهر الكويزات الخاصة بالسكشن عند إنشائها.'),
          for (final quiz in quizzes)
            Card(
                child: Column(children: [
              ListTile(
                  leading: const Icon(Icons.quiz_outlined),
                  title: Text(quiz['title'] as String),
                  subtitle: Text(
                      'سكشن ${quiz['section_number']} (${quiz['department_code']}) · '
                      '${quiz['duration_minutes']} دقيقة · '
                      '${quizSummary(quiz as Map<String, dynamic>, student)}'),
                  onTap: (student && !quizCanOpen(quiz)) ||
                          (!student &&
                              ['draft', 'scheduled', 'cancelled']
                                  .contains(quiz['state']))
                      ? null
                      : () async {
                          await openPage(
                              context,
                              quiz['title'] as String,
                              student
                                  ? QuizRunnerPage(state.api, quiz['id'] as int)
                                  : GradebookPage(
                                      state.api,
                                      state.course!,
                                      {
                                        'id': quiz['assessment_id'],
                                        'title': quiz['title'],
                                        'max_points': quiz['max_points']
                                      },
                                      sectionId:
                                          quiz['course_section_id'] as int,
                                      canPublish:
                                          state.user!.role == Role.doctor));
                          reload();
                        }),
              if (!student && quiz['state'] == 'draft')
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: AsyncButton(
                        label: 'فتح المسودة للطلاب',
                        icon: Icons.play_arrow,
                        onPressed: () async {
                          if (!await confirm(context, 'فتح الكويز',
                              'سيبدأ الكويز الآن ويُرسل إشعار للطلاب.')) {
                            return;
                          }
                          await state.api.writeCourse(state.course!,
                              'quizzes/${quiz['id']}/launch', {});
                          reload();
                        })),
              if (!student &&
                  ['draft', 'scheduled', 'active'].contains(quiz['state']))
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('إلغاء الكويز'),
                        onPressed: () async {
                          if (!await confirm(context, 'إلغاء الكويز',
                              'يُلغى الكويز إذا لم تبدأ أي محاولة. ولن يحتسب في الدرجات.')) {
                            return;
                          }
                          try {
                            await state.api.writeCourse(state.course!,
                                'quizzes/${quiz['id']}/cancel', null);
                            reload();
                          } catch (error) {
                            if (context.mounted) notice(context, '$error');
                          }
                        })),
              // Staff can close an active quiz while preserving saved answers.
              if (!student && quiz['state'] == 'active')
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: AsyncButton(
                        label: 'إغلاق الكويز مبكراً',
                        icon: Icons.stop_circle_outlined,
                        onPressed: () async {
                          if (!await confirm(context, 'إغلاق الكويز',
                              'سيتم إنهاء الكويز وتسجيل نتائج جميع المحاولات الجارية فوراً.')) {
                            return;
                          }
                          final result = await state.api.writeCourse(
                              state.course!,
                              'quizzes/${quiz['id']}/close',
                              null) as Map<String, dynamic>;
                          final finalized = result['finalized'] as int? ?? 0;
                          if (context.mounted) {
                            notice(context,
                                'تم إغلاق الكويز. تم تسجيل $finalized محاولة تلقائياً.');
                          }
                          reload();
                        })),
            ])),
        ]);
      });
}

class QuestionBankPage extends StatelessWidget {
  const QuestionBankPage(this.api, this.course, {super.key});
  final AttendanceApi api;
  final CourseOffering course;
  @override
  Widget build(BuildContext context) => RemotePage<dynamic>(
      load: () => api.getCourse(course, 'questions'),
      builder: (questions, reload) => PageContent(children: [
            const NoticeBanner(
                'هذا البنك مشترك بين أعضاء تدريس المقرر. الأسئلة المضافة يمكن استخدامها في كويزات سكاشن المقرر.'),
            AsyncButton(
                label: 'إضافة سؤال',
                icon: Icons.add,
                onPressed: () async {
                  await openPage(
                      context, 'سؤال جديد', QuestionEditorPage(api, course));
                  reload();
                }),
            if ((questions as List).isEmpty)
              const EmptyPanel(
                  'بنك الأسئلة فارغ', 'أضف أسئلة المقرر قبل إنشاء كويز.'),
            for (final question in questions)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(question['prompt'] as String,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('${points(question['points'])} درجة'),
                            for (final option in question['options'] as List)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(option['is_correct'] == true
                                      ? Icons.check_circle_outline
                                      : Icons.circle_outlined),
                                  title: Text(option['text'] as String)),
                          ]))),
          ]));
}

class QuestionEditorPage extends StatefulWidget {
  const QuestionEditorPage(this.api, this.course, {super.key});
  final AttendanceApi api;
  final CourseOffering course;
  @override
  State<QuestionEditorPage> createState() => _QuestionEditorPageState();
}

class _QuestionEditorPageState extends State<QuestionEditorPage> {
  final prompt = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  final maximum = TextEditingController(text: '1');
  int correct = 0;
  @override
  void dispose() {
    prompt.dispose();
    maximum.dispose();
    for (final option in options) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageContent(children: [
        TextField(
            controller: prompt,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'نص السؤال')),
        for (var i = 0; i < options.length; i++)
          TextField(
              controller: options[i],
              decoration: InputDecoration(labelText: 'الاختيار ${i + 1}')),
        DropdownButtonFormField<int>(
            initialValue: correct,
            decoration: const InputDecoration(labelText: 'الإجابة الصحيحة'),
            items: [
              for (var i = 0; i < options.length; i++)
                DropdownMenuItem(value: i, child: Text('الاختيار ${i + 1}'))
            ],
            onChanged: (value) => correct = value!),
        TextField(
            controller: maximum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'درجة السؤال')),
        AsyncButton(
            label: 'حفظ السؤال',
            onPressed: () async {
              if (prompt.text.trim().isEmpty ||
                  options.any((o) => o.text.trim().isEmpty)) {
                throw const ApiException('اكتب السؤال وجميع الاختيارات.');
              }
              await widget.api.writeCourse(widget.course, 'questions', {
                'prompt': prompt.text.trim(),
                'options': options.map((o) => o.text.trim()).toList(),
                'correct_index': correct,
                'points': maximum.text
              });
              if (context.mounted) Navigator.pop(context, true);
            }),
      ]);
}

class QuizCreatorPage extends StatefulWidget {
  const QuizCreatorPage(this.state, this.policy, this.questionCount,
      {super.key});
  final AppState state;
  final Map<String, dynamic> policy;
  final int questionCount;
  @override
  State<QuizCreatorPage> createState() => _QuizCreatorPageState();
}

class _QuizCreatorPageState extends State<QuizCreatorPage> {
  final title = TextEditingController();
  final count = TextEditingController(text: '1');
  final duration = TextEditingController(text: '20');
  int? section, category;
  String launchMode = 'now';
  DateTime? scheduledStart;
  @override
  void initState() {
    super.initState();
    section = widget.state.section?.id;
  }

  @override
  void dispose() {
    title.dispose();
    count.dispose();
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageContent(children: [
        const PageHeading('كويز جديد',
            'اختر السكشن وعدد الأسئلة. يختار النظام الأسئلة عشوائيًا من بنك المقرر ويحفظ نسختها عند إنشاء الكويز.'),
        TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'عنوان الكويز')),
        DropdownButtonFormField<int>(
            initialValue: section,
            decoration: const InputDecoration(labelText: 'السكشن المستهدف'),
            items: [
              for (final item in widget.state.course!.sections)
                DropdownMenuItem(value: item.id, child: Text(item.label))
            ],
            onChanged: (value) => section = value),
        DropdownButtonFormField<int>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'بند اللائحة'),
            items: [
              for (final item in (widget.policy['categories'] as List)
                  .where((c) => c['kind'] == 'assessment'))
                DropdownMenuItem(
                    value: item['id'] as int,
                    child: Text(item['name'] as String))
            ],
            onChanged: (value) => category = value),
        TextField(
            controller: count,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'عدد الأسئلة، متاح ${widget.questionCount}')),
        TextField(
            controller: duration,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'مدة الكويز بالدقائق')),
        Text('موعد إتاحة الكويز',
            style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final mode in {
            'now': 'فتح الآن',
            'scheduled': 'جدولة موعد',
            'draft': 'حفظ مسودة'
          }.entries)
            ChoiceChip(
                label: Text(mode.value),
                selected: launchMode == mode.key,
                onSelected: (_) => setState(() => launchMode = mode.key)),
        ]),
        if (launchMode == 'scheduled')
          OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(scheduledStart == null
                  ? 'اختيار التاريخ والوقت'
                  : localTime(scheduledStart!.toIso8601String())),
              onPressed: () async {
                final now = DateTime.now();
                final day = await showDatePicker(
                    context: context,
                    initialDate: scheduledStart ?? now,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 365)));
                if (day == null || !context.mounted) return;
                final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                        scheduledStart ?? now.add(const Duration(hours: 1))));
                if (time == null || !mounted) return;
                setState(() => scheduledStart = DateTime(
                    day.year, day.month, day.day, time.hour, time.minute));
              }),
        NoticeBanner(launchMode == 'draft'
            ? 'لن تظهر المسودة للطلاب حتى تفتحها. تُحفظ نسخة ثابتة من الأسئلة.'
            : launchMode == 'scheduled'
                ? 'يبدأ الكويز تلقائياً في الموعد المحدد. الوقت المعروض هو توقيت جهازك.'
                : 'يبدأ الكويز فور الحفظ وتُرسل إشعارات لطلاب السكشن.'),
        AsyncButton(
            label: launchMode == 'draft'
                ? 'حفظ مسودة الكويز'
                : launchMode == 'scheduled'
                    ? 'جدولة الكويز'
                    : 'فتح الكويز وإشعار الطلاب',
            icon: Icons.send,
            onPressed: () async {
              final quantity = int.tryParse(count.text);
              final minutes = int.tryParse(duration.text);
              if (title.text.trim().isEmpty ||
                  section == null ||
                  category == null ||
                  quantity == null ||
                  quantity < 1 ||
                  quantity > widget.questionCount ||
                  minutes == null ||
                  minutes < 1 ||
                  minutes > 120) {
                throw const ApiException(
                    'راجع عنوان الكويز والسكشن والبند وعدد الأسئلة والمدة.');
              }
              if (launchMode == 'scheduled' &&
                  (scheduledStart == null ||
                      !scheduledStart!.isAfter(DateTime.now()))) {
                throw const ApiException('اختر تاريخاً ووقتاً في المستقبل.');
              }
              await widget.state.api
                  .writeCourse(widget.state.course!, 'quizzes', {
                'title': title.text.trim(),
                'section_id': section,
                'category_id': category,
                'question_count': quantity,
                'duration_minutes': minutes,
                'prepare_only': launchMode == 'draft',
                if (launchMode == 'scheduled')
                  'starts_at': scheduledStart!.toUtc().toIso8601String(),
              });
              if (context.mounted) Navigator.pop(context, true);
            }),
      ]);
}

class QuizRunnerPage extends StatefulWidget {
  const QuizRunnerPage(this.api, this.quizId, {super.key});
  final AttendanceApi api;
  final int quizId;
  @override
  State<QuizRunnerPage> createState() => _QuizRunnerPageState();
}

class _QuizRunnerPageState extends State<QuizRunnerPage> {
  Map<String, dynamic>? attempt;
  Map<String, dynamic>? readiness;
  final answers = <int, int>{};
  final pendingAnswers = <int, int>{};
  final failedAnswers = <int>{};
  Timer? timer;
  Duration clockOffset = Duration.zero;
  String? error;
  int index = 0;
  int ticks = 0;
  bool busy = false, autoTried = false;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || (attempt == null && readiness == null)) return;
      setState(() {});
      if (attempt == null) return;
      ticks++;
      if (ticks % 10 == 0 && !busy && !completed && remaining > 0) load();
      if (remaining <= 0 && !completed && !busy && !autoTried) {
        autoTried = true;
        submit(automatic: true);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  bool get completed => attempt?['state'] != 'in_progress';
  int get remaining => attempt == null
      ? 0
      : date(attempt!['deadline_at'])
          .difference(DateTime.now().toUtc().add(clockOffset))
          .inSeconds
          .clamp(0, 7200);
  void apply(Map<String, dynamic> data) {
    attempt = data;
    clockOffset = date(data['server_now']).difference(DateTime.now().toUtc());
    answers.clear();
    for (final answer in data['answers'] as List) {
      answers[answer['question_id'] as int] = answer['option_id'] as int;
    }
    pendingAnswers.removeWhere((id, value) => answers[id] == value);
    failedAnswers.removeWhere((id) => !pendingAnswers.containsKey(id));
  }

  Future<void> load({bool start = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (attempt == null && !start) {
        final info = await widget.api
                .request('GET', '/quizzes/${widget.quizId}/readiness')
            as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          readiness = info;
          clockOffset =
              date(info['server_now']).difference(DateTime.now().toUtc());
          error = null;
        });
        if (info['attempt'] == null) return;
      }
      final data =
          await widget.api.request('POST', '/quizzes/${widget.quizId}/start')
              as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          apply(data);
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> select(int questionId, int optionId) async {
    if (busy || completed || remaining == 0) return;
    var expired = false;
    setState(() {
      busy = true;
      pendingAnswers[questionId] = optionId;
      failedAnswers.remove(questionId);
    });
    try {
      await widget.api
          .request('PATCH', '/quizzes/${widget.quizId}/answers', body: {
        'answers': [
          {'question_id': questionId, 'option_id': optionId}
        ]
      });
      if (mounted) {
        setState(() {
          answers[questionId] = optionId;
          pendingAnswers.remove(questionId);
          failedAnswers.remove(questionId);
          error = null;
        });
      }
    } catch (failure) {
      expired = failure is ApiException && failure.status == 409;
      if (mounted) {
        setState(() {
          error = '$failure';
          failedAnswers.add(questionId);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (expired && mounted) await load();
  }

  Future<void> submit({bool automatic = false}) async {
    if (busy || completed) return;
    if (!automatic &&
        !await confirm(
            context,
            'تسليم الكويز',
            'إجابات مؤكدة الحفظ: ${answers.length} من ${(attempt!['questions'] as List).length}.\n'
                'أسئلة بلا إجابة مؤكدة: ${(attempt!['questions'] as List).length - answers.length}.\n'
                '${pendingAnswers.isEmpty ? '' : 'توجد اختيارات لم يتأكد حفظها. يمكنك الرجوع وإعادة حفظها قبل انتهاء الوقت.\n'}'
                'سيتم تسليم الإجابات المحفوظة على الخادم فقط وإنهاء المحاولة.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final data = await widget.api.request(
          'POST', '/quizzes/${widget.quizId}/submit',
          body: {'answers': <Map<String, dynamic>>[]}) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          apply(data);
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (attempt == null) {
      if (readiness != null) {
        final now = DateTime.now().toUtc().add(clockOffset);
        final available = date(readiness!['ends_at'])
            .difference(now)
            .inSeconds
            .clamp(0, (readiness!['duration_minutes'] as int) * 60);
        final canStart = readiness!['state'] != 'closed' &&
            !date(readiness!['starts_at']).isAfter(now) &&
            available > 0;
        return PageContent(children: [
          PageHeading('قبل بدء الكويز', readiness!['title'] as String),
          Text('${readiness!['course_code']} · ${readiness!['course_name']}\n'
              'سكشن ${readiness!['section_number']} (${readiness!['department_code']})'),
          StatusRow('مدة المحاولة', '${readiness!['duration_minutes']} دقيقة'),
          StatusRow('موعد الإغلاق', localTime(readiness!['ends_at'])),
          StatusRow('الوقت المتاح الآن',
              '${available ~/ 60}:${(available % 60).toString().padLeft(2, '0')}'),
          NoticeBanner(available < (readiness!['duration_minutes'] as int) * 60
              ? 'تنبيه: الوقت المتبقي حتى الإغلاق أقل من مدة المحاولة. تنتهي محاولتك عند موعد الإغلاق.'
              : 'عرض هذه الصفحة لا يبدأ المحاولة. يبدأ الوقت عند تأكيد البدء، ولن يتوقف عند مغادرة الشاشة.'),
          if (error != null) EmptyPanel('تعذر بدء الكويز', error!),
          AsyncButton(
              label: 'ابدأ المحاولة الآن',
              enabled: canStart && !busy,
              onPressed: () => load(start: true)),
          OutlinedButton(
              onPressed: busy ? null : () => Navigator.maybePop(context),
              child: const Text('الرجوع دون بدء')),
        ]);
      }
      return error == null
          ? const Center(child: CircularProgressIndicator())
          : PageContent(children: [
              EmptyPanel('تعذر فتح الكويز', error!),
              AsyncButton(label: 'إعادة المحاولة', onPressed: load)
            ]);
    }
    final questions = attempt!['questions'] as List;
    final question = questions[index] as Map<String, dynamic>;
    return PageContent(children: [
      if (error != null) EmptyPanel('تعذر إكمال الطلب', error!),
      StatusRow(
          attempt!['title'] as String,
          completed
              ? attempt!['state'] == 'timed_out'
                  ? 'تم إنهاء المحاولة تلقائيًا'
                  : 'تم التسليم يدويًا'
              : 'الوقت المتبقي: ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'),
      if (completed)
        NoticeBanner(
            'تم اعتماد الإجابات المحفوظة على الخادم. ${pendingAnswers.isEmpty ? '' : 'توجد اختيارات لم يتأكد حفظها قبل الإنهاء ولم تُرسل بعد انتهاء المحاولة.'}'),
      if (completed)
        StatusRow(
            'النتيجة',
            attempt!['score'] == null
                ? 'في انتظار نشر النتيجة.'
                : pointRatio(attempt!['score'], attempt!['max_points'])),
      if (completed)
        OutlinedButton.icon(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث النتيجة')),
      if (busy) const LinearProgressIndicator(),
      Text('الإجابات المؤكدة: ${answers.length} من ${questions.length}'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < questions.length; i++)
          ActionChip(
              label: Text(
                  '${i + 1} ${answers.containsKey(questions[i]['id']) ? '✓' : '—'}'),
              onPressed: () => setState(() => index = i)),
      ]),
      Text('السؤال ${index + 1} من ${questions.length}'),
      Text(question['prompt'] as String,
          style: Theme.of(context).textTheme.titleLarge),
      if (pendingAnswers.containsKey(question['id'])) ...[
        NoticeBanner(
            failedAnswers.contains(question['id'])
                ? 'تعذر حفظ الاختيار المعلّق. الإجابة المؤكدة السابقة لم تُستبدل في العرض.'
                : 'جارٍ حفظ الإجابة…',
            isError: failedAnswers.contains(question['id'])),
        if (failedAnswers.contains(question['id']) && !completed)
          AsyncButton(
              label: 'إعادة حفظ الاختيار المعلّق',
              enabled: !busy && remaining > 0,
              onPressed: () => select(
                  question['id'] as int, pendingAnswers[question['id']]!)),
      ] else if (answers.containsKey(question['id']))
        const Text('تم الحفظ على الخادم'),
      for (final option in question['options'] as List)
        Card(
            child: ListTile(
                leading: Icon(answers[question['id']] == option['id']
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(option['text'] as String),
                subtitle: pendingAnswers[question['id']] == option['id']
                    ? const Text('اختيار معلّق · لم يتأكد حفظه')
                    : null,
                onTap: busy || completed || remaining == 0
                    ? null
                    : () =>
                        select(question['id'] as int, option['id'] as int))),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: index == 0 ? null : () => setState(() => index--),
                child: const Text('السابق'))),
        const SizedBox(width: 12),
        Expanded(
            child: OutlinedButton(
                onPressed: index + 1 >= questions.length
                    ? null
                    : () => setState(() => index++),
                child: const Text('التالي')))
      ]),
      if (!completed)
        AsyncButton(
            label: remaining == 0 ? 'إعادة محاولة التسليم' : 'تسليم الكويز',
            enabled: !busy,
            onPressed: () => submit(automatic: remaining == 0)),
    ]);
  }
}
