import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';

/// Dashboard layout: show or hide each widget and change the order with
/// explicit "move up/down" buttons (screen-reader friendly; no dragging
/// needed). Saving never touches finance records; "Reset" restores the
/// default layout after confirmation.
class WidgetSettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<DashboardWidget>> layout = ref.watch(
      dashboardLayoutProvider,
    );
    return layout.when(
      skipLoadingOnReload: true,
      data: (List<DashboardWidget> widgets) => _Editor(widgets: widgets),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.widgetSettingsTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.widgetSettingsTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(dashboardLayoutProvider),
        ),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.widgets});

  final List<DashboardWidget> widgets;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late List<DashboardWidget> _items = List<DashboardWidget>.of(widget.widgets);

  @override
  void didUpdateWidget(covariant _Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.widgets, widget.widgets)) {
      _items = List<DashboardWidget>.of(widget.widgets);
    }
  }

  bool get _changed {
    if (_items.length != widget.widgets.length) {
      return true;
    }
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].key != widget.widgets[i].key ||
          _items[i].visible != widget.widgets[i].visible) {
        return true;
      }
    }
    return false;
  }

  void _move(int from, int to) => setState(() {
    final DashboardWidget item = _items.removeAt(from);
    _items.insert(to, item);
  });

  void _toggle(int index, bool visible) => setState(() {
    _items[index] = _items[index].copyWith(visible: visible);
  });

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    try {
      await ref.read(dashboardLayoutProvider.notifier).save(_items);
      if (mounted) {
        showSnack(context, l10n.widgetSettingsSaved);
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _reset() async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.widgetSettingsResetTitle,
      body: l10n.widgetSettingsResetBody,
      confirmLabel: l10n.actionReset,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(dashboardLayoutProvider.notifier).reset();
      if (mounted) {
        showSnack(context, l10n.widgetSettingsResetDone);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.widgetSettingsTitle),
        actions: <Widget>[
          TextButton(onPressed: _reset, child: Text(l10n.actionReset)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: SubmitButton(
            label: l10n.actionSave,
            onPressed: _changed ? _save : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.sm,
            ),
            child: Text(l10n.widgetSettingsIntro),
          ),
          for (int i = 0; i < _items.length; i++)
            _Row(
              item: _items[i],
              position: i + 1,
              total: _items.length,
              onToggle: (bool v) => _toggle(i, v),
              onUp: i == 0 ? null : () => _move(i, i - 1),
              onDown: i == _items.length - 1 ? null : () => _move(i, i + 1),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.position,
    required this.total,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
  });

  final DashboardWidget item;
  final int position;
  final int total;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widgetTitle(l10n, item.kind);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: Column(
        children: <Widget>[
          SwitchListTile(
            secondary: ExcludeSemantics(child: Icon(widgetIcon(item.kind))),
            title: Text(title),
            subtitle: Text(
              '${widgetDescription(l10n, item.kind)}\n'
              '${l10n.widgetPosition(position, total)}',
            ),
            value: item.visible,
            onChanged: onToggle,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: l10n.widgetMoveUp(title),
                icon: const Icon(Icons.arrow_upward),
                onPressed: onUp,
              ),
              IconButton(
                tooltip: l10n.widgetMoveDown(title),
                icon: const Icon(Icons.arrow_downward),
                onPressed: onDown,
              ),
              const SizedBox(width: Insets.sm),
            ],
          ),
        ],
      ),
    );
  }
}
