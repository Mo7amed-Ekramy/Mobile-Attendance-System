import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class TeachingAssignmentsPage extends StatelessWidget {
  const TeachingAssignmentsPage(this.api, this.course, {super.key});

  final AttendanceApi api;
  final CourseOffering course;

  @override
  Widget build(BuildContext context) => RemotePage<List<_AssistantAssignments>>(
        scope: '${course.id}',
        load: () async {
          final rows = await api.getCourse(course, 'assignments') as List;
          final assistants = <int, _AssistantAssignments>{};
          for (final row in rows) {
            final item = row as Map<String, dynamic>;
            final id = item['ta_user_id'] as int;
            final assistant = assistants.putIfAbsent(
                id, () => _AssistantAssignments(id, item['ta_name'] as String));
            final section = CourseSection.fromJson(item);
            assistant.sections[section.id] = section;
          }
          return assistants.values.toList()
            ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        },
        builder: (assistants, reload) => PageContent(children: [
          PageHeading('${course.code} · ${course.name}',
              'عدد المعيدين: ${assistants.length}'),
          if (assistants.isEmpty)
            const EmptyPanel('لم يُسند معيدون لهذا المقرر',
                'ستظهر أسماء المعيدين وسكاشنهم بعد إسنادهم للمقرر.'),
          for (final assistant in assistants)
            _AssistantCard(assistant,
                key: ValueKey('teaching-assistant-${assistant.id}')),
        ]),
      );
}

class _AssistantAssignments {
  _AssistantAssignments(this.id, this.name);

  final int id;
  final String name;
  final sections = <int, CourseSection>{};
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard(this.assistant, {super.key});

  final _AssistantAssignments assistant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byDepartment = <String, List<CourseSection>>{};
    for (final section in assistant.sections.values) {
      byDepartment.putIfAbsent(section.department, () => []).add(section);
    }
    final departments = byDepartment.keys.toList()..sort();
    final students = assistant.sections.values
        .fold(0, (total, section) => total + section.studentCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: .08),
                foregroundColor: scheme.primary,
                child: const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assistant.name, style: theme.textTheme.titleMedium),
                    Text('معيد المقرر',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 16, runSpacing: 6, children: [
              Text('عدد السكاشن: ${assistant.sections.length}',
                  style: theme.textTheme.labelLarge),
              Text('إجمالي الطلاب المسجّلين: $students',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            for (var index = 0; index < departments.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _DepartmentSections(
                  departments[index], byDepartment[departments[index]]!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DepartmentSections extends StatelessWidget {
  const _DepartmentSections(this.department, this.sections);

  final String department;
  final List<CourseSection> sections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final numbers = sections.map((section) => section.number).toList()..sort();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: 'قسم $department',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, maxWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(department,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.primary)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${numbers.length == 1 ? 'سكشن' : 'السكاشن'}: '
              '${numbers.join('، ')}'),
        ),
      ),
    ]);
  }
}
