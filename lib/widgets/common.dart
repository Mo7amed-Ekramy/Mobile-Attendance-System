import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api.dart';
import '../theme.dart';

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children, this.footer});
  final List<Widget> children;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(children: [
            Expanded(
                child: ListView(
                    key: const PageStorageKey('page-content'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(Brand.gutter),
                    children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: 16)
                  ],
                ])),
            if (footer != null)
              SafeArea(
                  top: false,
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                              top: BorderSide(
                                  color: Theme.of(context).dividerColor))),
                      child: footer)),
          ])));
}

class RemotePage<T> extends StatefulWidget {
  const RemotePage(
      {super.key,
      required this.load,
      required this.builder,
      this.scope = '',
      this.beforeRefresh,
      this.refreshInterval});
  final Future<T> Function() load;
  final Widget Function(T data, VoidCallback reload) builder;
  final String scope;
  final Future<bool> Function()? beforeRefresh;
  final Duration? refreshInterval;
  @override
  State<RemotePage<T>> createState() => _RemotePageState<T>();
}

class _RemotePageState<T> extends State<RemotePage<T>> {
  late Future<T> future;
  T? lastData;
  bool hasData = false;
  Object? dismissedError;
  Timer? refreshTimer;
  bool fetching = true;
  @override
  void initState() {
    super.initState();
    future = widget.load();
    if (widget.refreshInterval != null) {
      refreshTimer = Timer.periodic(widget.refreshInterval!, (_) {
        if (mounted && !fetching) reload();
      });
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RemotePage<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      lastData = null;
      hasData = false;
      future = widget.load();
    }
  }

  void reload() => setState(() {
        dismissedError = null;
        future = widget.load();
      });
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        fetching = loading;
        if (!loading && !snapshot.hasError) {
          lastData = snapshot.data;
          hasData = true;
        }
        if (loading && !hasData) {
          return const Center(
              child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3)));
        }
        final errorPanel = snapshot.hasError
            ? EmptyPanel(
                snapshot.error is ApiException &&
                        (snapshot.error as ApiException).status == 403
                    ? 'الوصول غير مسموح'
                    : 'تعذر تحديث البيانات',
                '${snapshot.error}')
            : null;
        if (snapshot.hasError && !hasData) {
          final children = <Widget>[
            EmptyPanel(
                snapshot.error is ApiException &&
                        (snapshot.error as ApiException).status == 403
                    ? 'الوصول غير مسموح'
                    : 'تعذر تحميل البيانات',
                '${snapshot.error}'),
            OutlinedButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة')),
          ];
          return LayoutBuilder(
              builder: (context, constraints) => constraints.hasBoundedHeight
                  ? PageContent(children: children)
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children)));
        }
        final content = RefreshIndicator(
            onRefresh: () async {
              if (widget.beforeRefresh != null &&
                  !await widget.beforeRefresh!()) {
                return;
              }
              if (!mounted) return;
              reload();
              try {
                await future;
              } catch (_) {}
            },
            child: AbsorbPointer(
                absorbing: loading,
                child: widget.builder(lastData as T, reload)));
        return Stack(children: [
          content,
          if (loading)
            const Positioned(
                top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
          if (errorPanel != null && !identical(dismissedError, snapshot.error))
            Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      NoticeBanner('${snapshot.error}',
                          icon: Icons.error_outline, isError: true),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton.icon(
                            onPressed: () async {
                              if (widget.beforeRefresh != null &&
                                  !await widget.beforeRefresh!()) {
                                return;
                              }
                              if (mounted) reload();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة')),
                        IconButton(
                            tooltip: 'إغلاق التنبيه',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(
                                () => dismissedError = snapshot.error)),
                      ]),
                    ]))),
        ]);
      });
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ]);
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.message,
      {super.key, this.icon = Icons.info_outline, this.isError = false});
  final String message;
  final IconData icon;
  final bool isError;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: isError
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]));
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.label, this.value, this.icon, {super.key});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconTile(icon, size: 38),
        const SizedBox(height: 14),
        Text(value, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    ));
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final desired = constraints.maxWidth >= 600 ? 3 : 2;
        final columns = children.length.clamp(1, desired);
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 48});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14)),
      child: Icon(icon,
          size: size * .48, color: Theme.of(context).colorScheme.primary));
}

class WelcomePanel extends StatelessWidget {
  const WelcomePanel(
      {super.key,
      required this.title,
      required this.name,
      required this.detail,
      required this.role});
  final String title, name, detail, role;
  @override
  Widget build(BuildContext context) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Brand.brownDark, borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        const PositionedDirectional(
            end: -32,
            bottom: -42,
            child: ExcludeSemantics(
                child: Icon(Icons.school_outlined,
                    size: 210, color: Color(0x2255AA88)))),
        Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.waving_hand_outlined,
                    color: Brand.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('مرحباً، $name',
                        style: const TextStyle(
                            color: Color(0xFFE9DCCC), fontSize: 13))),
                const SizedBox(width: 8),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(role,
                        style:
                            const TextStyle(color: Brand.gold, fontSize: 12))),
              ]),
              const SizedBox(height: 14),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text(detail,
                  style:
                      const TextStyle(color: Color(0xFFE9DCCC), height: 1.8)),
            ])),
      ]));
}

class AsyncButton extends StatefulWidget {
  const AsyncButton(
      {super.key,
      required this.onPressed,
      required this.label,
      this.icon = Icons.save,
      this.enabled = true});
  final Future<void> Function() onPressed;
  final String label;
  final IconData icon;
  final bool enabled;
  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
      onPressed: busy || !widget.enabled
          ? null
          : () async {
              setState(() => busy = true);
              try {
                await widget.onPressed();
              } catch (error) {
                if (context.mounted) notice(context, '$error');
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
      icon: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary))
          : Icon(widget.icon),
      label: Text(widget.label));
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.info_outline, size: 36),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center)
          ])));
}

class ActionCard extends StatelessWidget {
  const ActionCard(
      {super.key,
      required this.title,
      required this.detail,
      required this.icon,
      required this.onTap});
  final String title, detail;
  final IconData icon;
  final FutureOr<void> Function() onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: () async {
            try {
              await onTap();
            } catch (error) {
              if (context.mounted) notice(context, '$error');
            }
          },
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                IconTile(icon),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(detail,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ])),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20),
              ]))));
}

class StatusRow extends StatelessWidget {
  const StatusRow(this.title, this.detail,
      {super.key, this.icon = Icons.info_outline, this.detailDirection});
  final String title, detail;
  final IconData icon;
  final TextDirection? detailDirection;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: IconTile(icon, size: 40),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(detail,
              textDirection: detailDirection,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant))));
}

Future<T?> openPage<T>(BuildContext context, String title, Widget child) =>
    Navigator.push<T>(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: SafeArea(child: child))));

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirm(
        BuildContext context, String title, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(child: Text(message)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('تأكيد')),
                ])) ??
    false;

String localTime(dynamic value) {
  final date = DateTime.parse('$value').toLocal();
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String ltrValue(String value) => '\u2066$value\u2069';
