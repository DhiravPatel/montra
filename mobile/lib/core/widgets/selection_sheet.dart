import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';

/// The result of a picker: `null` means dismissed, `Picked(null)` means
/// "none" was chosen (the value is cleared).
@immutable
class Picked<T> {
  /// Wraps [value].
  const Picked(this.value);

  /// The chosen value, or null for "none".
  final T? value;
}

/// One row of a [SelectionSheet].
@immutable
class SelectionItem<T> {
  /// Creates the item.
  const SelectionItem({
    required this.id,
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.indent = 0,
    this.searchText,
    this.semanticsLabel,
  });

  /// Stable ID (used for multi-select).
  final String id;

  /// The value returned when chosen.
  final T value;

  /// Main text.
  final String label;

  /// Second line.
  final String? subtitle;

  /// Leading widget (decorative; excluded from semantics by the tile).
  final Widget? leading;

  /// Nesting level (subcategories).
  final int indent;

  /// Extra text matched by the search box.
  final String? searchText;

  /// Fuller label for screen readers.
  final String? semanticsLabel;
}

/// Options for [SelectionSheet.create]: offer "Create “query”" when the
/// typed text matches nothing.
@immutable
class CreateOption<T> {
  /// Creates the option.
  const CreateOption({required this.label, required this.build});

  /// Button text for a query, e.g. `Create tag “trip”`.
  final String Function(String query) label;

  /// The value to return for a query.
  final T Function(String query) build;
}

/// Opens a searchable single-choice sheet over [source]. Returns null when
/// dismissed and `Picked(null)` when [noneLabel] is chosen.
Future<Picked<T>?> showSingleSelection<D, T>(
  BuildContext context, {
  required String title,
  required ProviderListenable<AsyncValue<List<D>>> source,
  required void Function(WidgetRef ref) onRetry,
  required List<SelectionItem<T>> Function(BuildContext context, List<D> data)
  items,
  String? selectedId,
  String? noneLabel,
  String? emptyText,
  CreateOption<T>? create,
}) => showModalBottomSheet<Picked<T>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => SelectionSheet<D, T>(
    title: title,
    source: source,
    onRetry: onRetry,
    items: items,
    selectedIds: <String>{?selectedId},
    noneLabel: noneLabel,
    emptyText: emptyText,
    create: create,
    multiple: false,
  ),
);

/// Opens a searchable multi-choice sheet. Returns the chosen IDs, or null
/// when dismissed.
Future<Set<String>?> showMultiSelection<D, T>(
  BuildContext context, {
  required String title,
  required ProviderListenable<AsyncValue<List<D>>> source,
  required void Function(WidgetRef ref) onRetry,
  required List<SelectionItem<T>> Function(BuildContext context, List<D> data)
  items,
  Set<String> selectedIds = const <String>{},
  String? emptyText,
}) async {
  final Picked<Set<String>>? result =
      await showModalBottomSheet<Picked<Set<String>>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (BuildContext context) => SelectionSheet<D, T>(
          title: title,
          source: source,
          onRetry: onRetry,
          items: items,
          selectedIds: selectedIds,
          emptyText: emptyText,
          multiple: true,
        ),
      );
  return result?.value;
}

/// The sheet behind [showSingleSelection] and [showMultiSelection]
/// (public for tests).
class SelectionSheet<D, T> extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const SelectionSheet({
    required this.title,
    required this.source,
    required this.onRetry,
    required this.items,
    required this.multiple,
    this.selectedIds = const <String>{},
    this.noneLabel,
    this.emptyText,
    this.create,
    super.key,
  });

  /// Heading.
  final String title;

  /// Data source.
  final ProviderListenable<AsyncValue<List<D>>> source;

  /// Retries loading.
  final void Function(WidgetRef ref) onRetry;

  /// Maps data to rows.
  final List<SelectionItem<T>> Function(BuildContext context, List<D> data)
  items;

  /// Initially selected IDs.
  final Set<String> selectedIds;

  /// Label of a "none" choice (single mode only).
  final String? noneLabel;

  /// Text when there is nothing to choose.
  final String? emptyText;

  /// Offer to create a value from the query (single mode only).
  final CreateOption<T>? create;

  /// Multi-select mode.
  final bool multiple;

  @override
  ConsumerState<SelectionSheet<D, T>> createState() =>
      _SelectionSheetState<D, T>();
}

class _SelectionSheetState<D, T> extends ConsumerState<SelectionSheet<D, T>> {
  final TextEditingController _query = TextEditingController();
  late final Set<String> _selected = Set<String>.of(widget.selectedIds);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<SelectionItem<T>> _filter(List<SelectionItem<T>> all) {
    final String q = _query.text.trim().toLowerCase();
    if (q.isEmpty) {
      return all;
    }
    return <SelectionItem<T>>[
      for (final SelectionItem<T> item in all)
        if (item.label.toLowerCase().contains(q) ||
            (item.subtitle?.toLowerCase().contains(q) ?? false) ||
            (item.searchText?.toLowerCase().contains(q) ?? false))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<D>> data = ref.watch(widget.source);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    if (widget.multiple)
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(Picked<Set<String>>(_selected)),
                        child: Text(l10n.actionDone),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<D>>(
              value: data,
              onRetry: () => widget.onRetry(ref),
              data: (List<D> loaded) => _list(context, loaded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<D> loaded) {
    final AppLocalizations l10n = context.l10n;
    final List<SelectionItem<T>> matches = _filter(
      widget.items(context, loaded),
    );
    final String query = _query.text.trim();
    final CreateOption<T>? create = widget.create;
    final bool exact = matches.any(
      (SelectionItem<T> i) => i.label.toLowerCase() == query.toLowerCase(),
    );
    final bool showCreate =
        !widget.multiple && create != null && query.isNotEmpty && !exact;
    final bool showNone =
        !widget.multiple && widget.noneLabel != null && query.isEmpty;
    if (matches.isEmpty && !showCreate && !showNone) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text(
            query.isEmpty
                ? (widget.emptyText ?? l10n.selectionEmpty)
                : l10n.selectionNoMatches(query),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      children: <Widget>[
        if (showCreate)
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(create.label(query)),
            onTap: () =>
                Navigator.of(context).pop(Picked<T>(create.build(query))),
          ),
        if (showNone)
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(widget.noneLabel!),
            selected: _selected.isEmpty,
            onTap: () => Navigator.of(context).pop(Picked<T>(null)),
          ),
        for (final SelectionItem<T> item in matches) _tile(context, item),
      ],
    );
  }

  Widget _tile(BuildContext context, SelectionItem<T> item) {
    final AppLocalizations l10n = context.l10n;
    final bool selected = _selected.contains(item.id);
    final EdgeInsetsGeometry padding = EdgeInsetsDirectional.only(
      start: Insets.md + item.indent * Insets.lg,
      end: Insets.md,
    );
    final Widget? leading = item.leading == null
        ? null
        : ExcludeSemantics(child: item.leading);
    if (widget.multiple) {
      return CheckboxListTile(
        contentPadding: padding,
        value: selected,
        secondary: leading,
        title: Text(item.label, semanticsLabel: item.semanticsLabel),
        subtitle: item.subtitle == null ? null : Text(item.subtitle!),
        onChanged: (bool? on) => setState(() {
          if (on ?? false) {
            _selected.add(item.id);
          } else {
            _selected.remove(item.id);
          }
        }),
      );
    }
    return ListTile(
      contentPadding: padding,
      leading: leading,
      selected: selected,
      title: Text(item.label, semanticsLabel: item.semanticsLabel),
      subtitle: item.subtitle == null ? null : Text(item.subtitle!),
      trailing: selected
          ? Icon(Icons.check, semanticLabel: l10n.selectedLabel)
          : null,
      onTap: () => Navigator.of(context).pop(Picked<T>(item.value)),
    );
  }
}
