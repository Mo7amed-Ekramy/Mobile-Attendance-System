import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';

class ScopeSwitcher extends StatefulWidget {
  const ScopeSwitcher(this.state, {super.key, this.compact = false});

  final AppState state;
  final bool compact;

  @override
  State<ScopeSwitcher> createState() => _ScopeSwitcherState();
}

class _ScopeSwitcherState extends State<ScopeSwitcher> {
  final menu = MenuController();
  final triggerFocus = FocusNode();
  int opening = 0;
  bool isOpen = false;

  @override
  void dispose() {
    triggerFocus.dispose();
    super.dispose();
  }

  void apply(CourseOffering course, CourseSection? section) {
    if (course.id == widget.state.course?.id &&
        section?.id == widget.state.section?.id) {
      return;
    }
    widget.state.selectScope(course, selectedSection: section);
  }

  Future<void> openSheet() async {
    setState(() => isOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheet) {
        final media = MediaQuery.of(sheet);
        final available = media.size.height -
            media.viewInsets.bottom -
            media.padding.top -
            64;
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SizedBox(
            height: math.min(
                widget.state.user!.role == Role.doctor
                    ? math.min(560, 150 + widget.state.courses.length * 88)
                    : 560,
                available * .88),
            child: _ScopePicker(
              state: widget.state,
              onClose: () => Navigator.pop(sheet),
              onSelected: (course, section) {
                Navigator.pop(sheet);
                apply(course, section);
              },
            ),
          ),
        );
      },
    );
    if (mounted) {
      setState(() => isOpen = false);
      triggerFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final course = state.course!;
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final doctor = state.user!.role == Role.doctor;
    final contextLabel =
        doctor ? course.name : state.section?.label ?? 'لا يوجد سكشن';
    return MenuAnchor(
      controller: menu,
      childFocusNode: triggerFocus,
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, 8),
      onOpen: () => setState(() => isOpen = true),
      onClose: () => setState(() => isOpen = false),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant))),
      ),
      menuChildren: [
        SizedBox(
          width: math.min(doctor ? 400 : 600, size.width - 32),
          height: math.min(
              doctor ? math.min(500, 150 + state.courses.length * 88) : 500,
              size.height - 100),
          child: _ScopePicker(
            key: ValueKey(opening),
            state: state,
            onClose: menu.close,
            onSelected: (course, section) {
              menu.close();
              apply(course, section);
            },
          ),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: doctor
            ? '${course.code} · ${course.name} — تغيير المقرر'
            : '${course.name} · $contextLabel — تغيير المقرر والسكشن',
        child: TextButton(
          key: const ValueKey('scope-switcher'),
          focusNode: triggerFocus,
          style: TextButton.styleFrom(
            backgroundColor: scheme.primary.withValues(alpha: .06),
            foregroundColor: scheme.primary,
            minimumSize: const Size(44, 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (widget.compact) {
              if (!isOpen) openSheet();
            } else if (controller.isOpen) {
              controller.close();
            } else {
              setState(() => opening++);
              controller.open();
            }
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!widget.compact) ...[
              const Icon(Icons.menu_book_outlined, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: widget.compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.code,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(contextLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    )
                  : Text('${course.code} · $contextLabel',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _ScopePicker extends StatefulWidget {
  const _ScopePicker(
      {super.key,
      required this.state,
      required this.onSelected,
      required this.onClose});

  final AppState state;
  final void Function(CourseOffering course, CourseSection? section) onSelected;
  final VoidCallback onClose;

  @override
  State<_ScopePicker> createState() => _ScopePickerState();
}

class _ScopePickerState extends State<_ScopePicker> {
  final search = TextEditingController();
  late CourseOffering course;
  late bool showingSections;
  bool get doctor => widget.state.user!.role == Role.doctor;
  bool get directCourses =>
      doctor || widget.state.courses.every((item) => item.sections.length <= 1);

  @override
  void initState() {
    super.initState();
    course = widget.state.course!;
    showingSections = !directCourses;
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Widget choice(
      {required Key key,
      required String title,
      required String subtitle,
      required bool selected,
      required VoidCallback? onTap,
      bool current = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color:
            selected ? scheme.primary.withValues(alpha: .08) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: key,
          enabled: onTap != null,
          selected: selected,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          trailing: current
              ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
              : const Icon(Icons.chevron_left, size: 18),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget coursesList({required bool split}) {
    final query = search.text.trim().toLowerCase();
    final courses = widget.state.courses
        .where(
            (item) => '${item.code} ${item.name}'.toLowerCase().contains(query))
        .toList();
    if (courses.isEmpty) {
      return const Center(child: Text('لا توجد مقررات مطابقة'));
    }
    return ListView.builder(
      primary: false,
      key: const PageStorageKey('scope-courses'),
      padding: EdgeInsets.zero,
      itemCount: courses.length,
      itemBuilder: (_, index) {
        final item = courses[index];
        final hasSection = item.sections.isNotEmpty;
        return choice(
          key: ValueKey('scope-course-${item.id}'),
          title: item.name,
          subtitle: !doctor && directCourses && hasSection
              ? '${item.code} · ${item.sections.first.label}'
              : item.code,
          selected: item.id == (split ? course.id : widget.state.course?.id),
          current: item.id == widget.state.course?.id,
          onTap: !doctor && !hasSection
              ? null
              : () {
                  if (doctor) {
                    widget.onSelected(item, null);
                  } else if (item.sections.length == 1) {
                    widget.onSelected(item, item.sections.first);
                  } else {
                    setState(() {
                      course = item;
                      showingSections = true;
                      if (!split) search.clear();
                    });
                  }
                },
        );
      },
    );
  }

  Widget sectionsList({required bool split}) {
    final query = split ? '' : search.text.trim().toLowerCase();
    final sections = course.sections
        .where((item) =>
            '${item.label} ${item.taName}'.toLowerCase().contains(query))
        .toList();
    if (sections.isEmpty) {
      return const Center(child: Text('لا توجد سكاشن مطابقة'));
    }
    return ListView(
      primary: false,
      key: ValueKey('scope-sections-${course.id}'),
      padding: EdgeInsets.zero,
      children: [
        for (final section in sections)
          choice(
            key: ValueKey('scope-section-${section.id}'),
            title: section.label,
            subtitle: section.taName,
            selected: course.id == widget.state.course?.id &&
                section.id == widget.state.section?.id,
            current: course.id == widget.state.course?.id &&
                section.id == widget.state.section?.id,
            onTap: () => widget.onSelected(course, section),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final split = box.maxWidth >= 500 && !directCourses;
        final sectionsOnly = showingSections && !split && !directCourses;
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              if (sectionsOnly)
                IconButton(
                  key: const ValueKey('scope-back-to-courses'),
                  tooltip: 'تغيير المقرر',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    showingSections = false;
                    search.clear();
                  }),
                ),
              Expanded(
                  child: Text(
                      sectionsOnly
                          ? 'اختيار السكشن'
                          : directCourses
                              ? 'تغيير المقرر'
                              : 'المقرر والسكشن',
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                  tooltip: 'إغلاق',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 20)),
            ]),
            if (sectionsOnly)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${course.code} · ${course.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall)),
            TextField(
              key: const ValueKey('scope-search'),
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: sectionsOnly
                    ? 'ابحث عن سكشن أو معيد'
                    : 'اسم المقرر أو الكود',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(search.clear)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
                child: split
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: coursesList(split: true)),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: VerticalDivider(
                                  width: 1, color: scheme.outlineVariant)),
                          Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('سكاشن ${course.code}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge)),
                                  Expanded(child: sectionsList(split: true)),
                                ],
                              )),
                        ],
                      )
                    : sectionsOnly
                        ? sectionsList(split: false)
                        : coursesList(split: false)),
          ]),
        );
      });
}
