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
          constraints: const BoxConstraints(maxWidth: 760),
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
                    const SizedBox(height: 12)
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
      this.beforeRefresh});
  final Future<T> Function() load;
  final Widget Function(T data, VoidCallback reload) builder;
  final String scope;
  final Future<bool> Function()? beforeRefresh;
  @override
  State<RemotePage<T>> createState() => _RemotePageState<T>();
}

class _RemotePageState<T> extends State<RemotePage<T>> {
  late Future<T> future;
  T? lastData;
  bool hasData = false;
  Object? dismissedError;
  @override
  void initState() {
    super.initState();
    future = widget.load();
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
        if (!loading && !snapshot.hasError) {
          lastData = snapshot.data;
          hasData = true;
        }
        if (loading && !hasData) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
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
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ])));
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
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
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
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
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(detail),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap));
}

class StatusRow extends StatelessWidget {
  const StatusRow(this.title, this.detail,
      {super.key, this.icon = Icons.info_outline});
  final String title, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Icon(icon), title: Text(title), subtitle: Text(detail)));
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
        .showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirm(
        BuildContext context, String title, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (dialog) =>
            AlertDialog(title: Text(title), content: Text(message), actions: [
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
