import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'grading.dart';

String quizSummary(Map<String, dynamic> quiz, bool student) {
  if (!student) {
    if (quiz['state'] == 'closed') return 'مغلق';
    return '${quiz['submitted_count']} محاولة مسلمة';
  }
  final attempt = quiz['attempt'] as Map<String, dynamic>?;
  final state = attempt == null ? null : attempt['state'];
  if (state == 'submitted' || state == 'timed_out') return 'تم التسليم';
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
                detail: '${(data['questions'] as List).length} سؤال محفوظ',
                icon: Icons.library_books_outlined,
                onTap: () async {
                  await openPage(context, 'بنك الأسئلة',
                      QuestionBankPage(state.api, state.course!));
                  reload();
                }),
            if (data['policy'] == null)
              const EmptyPanel('لائحة المقرر مطلوبة',
                  'يجب أن ينشئ الدكتور لائحة للمقرر قبل إضافة كويز مرتبط بالدرجات.')
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
                  onTap: student && !quizCanOpen(quiz)
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
              // ADD-06: Close-quiz button for staff on active quizzes only.
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
        const Text(
            'سيتم سحب الأسئلة عشوائياً وإرسال إشعار لطلاب السكشن المحدد.'),
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
        AsyncButton(
            label: 'فتح الكويز وإشعار الطلاب',
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
              await widget.state.api
                  .writeCourse(widget.state.course!, 'quizzes', {
                'title': title.text.trim(),
                'section_id': section,
                'category_id': category,
                'question_count': quantity,
                'duration_minutes': minutes
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
  final answers = <int, int>{};
  Timer? timer;
  Duration clockOffset = Duration.zero;
  String? error;
  int index = 0;
  bool busy = false, autoTried = false;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || attempt == null) return;
      setState(() {});
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
  }

  Future<void> load() async {
    if (busy) return;
    setState(() => busy = true);
    try {
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
    if (busy || completed) return;
    setState(() => busy = true);
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
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit({bool automatic = false}) async {
    if (busy || completed) return;
    if (!automatic &&
        !await confirm(context, 'تسليم الكويز',
            'سيتم تسليم الإجابات المحفوظة وإنهاء المحاولة.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final data = await widget.api
          .request('POST', '/quizzes/${widget.quizId}/submit', body: {
        'answers': [
          for (final entry in answers.entries)
            {'question_id': entry.key, 'option_id': entry.value},
        ]
      }) as Map<String, dynamic>;
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
              ? 'تم التسليم'
              : 'الوقت المتبقي: ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'),
      if (completed)
        StatusRow(
            'النتيجة',
            attempt!['score'] == null
                ? 'في انتظار نشر النتيجة.'
                : '${points(attempt!['score'])} / ${points(attempt!['max_points'])}'),
      if (completed)
        OutlinedButton.icon(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث النتيجة')),
      if (busy) const LinearProgressIndicator(),
      Text('السؤال ${index + 1} من ${questions.length}'),
      Text(question['prompt'] as String,
          style: Theme.of(context).textTheme.titleLarge),
      for (final option in question['options'] as List)
        Card(
            child: ListTile(
                leading: Icon(answers[question['id']] == option['id']
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(option['text'] as String),
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
