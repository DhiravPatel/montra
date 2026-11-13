import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';

/// Describes a saved filter's content for its list row, or returns null
/// when this screen cannot apply it.
typedef SavedFilterDescriber = String? Function(Map<String, Object?> filter);

/// A saved filter the person chose to apply.
typedef AppliedSavedFilter = ({String name, Map<String, Object?> filter});

/// Opens the saved filters of [scope]: save [current] under a name (null
/// when there is nothing to save yet), apply one, or delete one after a
/// confirmation. Returns the filter to apply, or null.
Future<AppliedSavedFilter?> showSavedFiltersSheet(
  BuildContext context, {
  required SavedFilterScope scope,
  required Map<String, Object?>? current,
  required SavedFilterDescriber describe,
}) => showModalBottomSheet<AppliedSavedFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => FractionallySizedBox(
    heightFactor: 0.85,
    child: SavedFiltersSheet(
      scope: scope,
      current: current,
      describe: describe,
    ),
  ),
);

/// The body of [showSavedFiltersSheet].
class SavedFiltersSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const SavedFiltersSheet({
    required this.scope,
    required this.current,
    required this.describe,
    super.key,
  });

  /// Which saved filters.
  final SavedFilterScope scope;

  /// The filter on screen, or null when there is nothing to save.
  final Map<String, Object?>? current;

  /// Row descriptions (null: not applicable here).
  final SavedFilterDescriber describe;

  @override
  ConsumerState<SavedFiltersSheet> createState() => _SavedFiltersSheetState();
}

class _SavedFiltersSheetState extends ConsumerState<SavedFiltersSheet> {
  final Set<String> _deleting = <String>{};

  bool get _search => widget.scope == SavedFilterScope.search;

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final Map<String, Object?>? current = widget.current;
    if (current == null) {
      return;
    }
    final SavedFilterDto? saved = await showDialog<SavedFilterDto>(
      context: context,
      builder: (BuildContext context) =>
          SaveFilterDialog(scope: widget.scope, filter: current),
    );
    if (saved == null || !mounted) {
      return;
    }
    ref.invalidate(savedFiltersProvider(widget.scope));
    showSnack(context, l10n.savedFiltersSaved(saved.name));
  }

  Future<void> _delete(SavedFilterDto saved) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.savedFiltersDeleteTitle(saved.name),
      body: l10n.savedFiltersDeleteBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting.add(saved.id));
    String message;
    try {
      await ref.read(savedFiltersApiProvider).delete(saved.id);
      message = l10n.savedFiltersDeleted(saved.name);
    } on ApiException catch (error) {
      // Deleted elsewhere (another device or the web): it is gone either way.
      message = error.code == ErrorObjectCode.notFound
          ? l10n.savedFiltersAlreadyGone(saved.name)
          : describeError(l10n, error);
    } on Object catch (error) {
      message = describeError(l10n, error);
    }
    if (!mounted) {
      return;
    }
    setState(() => _deleting.remove(saved.id));
    ref.invalidate(savedFiltersProvider(widget.scope));
    showSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<SavedFilterDto>> saved = ref.watch(
      savedFiltersProvider(widget.scope),
    );
    final bool canSave = widget.current != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              _search ? l10n.savedSearchesTitle : l10n.savedFiltersTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: FilledButton.tonalIcon(
            onPressed: canSave ? _save : null,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(
              _search
                  ? l10n.savedSearchesSaveCurrent
                  : l10n.savedFiltersSaveCurrent,
            ),
          ),
        ),
        if (!canSave)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              0,
            ),
            child: Text(
              _search
                  ? l10n.savedSearchesNothingToSave
                  : l10n.savedFiltersNothingToSave,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: Insets.sm),
        const Divider(height: 1),
        Expanded(
          child: AsyncValueView<List<SavedFilterDto>>(
            value: saved,
            onRetry: () => ref.invalidate(savedFiltersProvider(widget.scope)),
            isEmpty: (List<SavedFilterDto> list) => list.isEmpty,
            empty: MessageStateView(
              icon: Icons.bookmarks_outlined,
              title: _search ? l10n.savedSearchesTitle : l10n.savedFiltersTitle,
              body: l10n.savedFiltersEmpty,
            ),
            data: (List<SavedFilterDto> list) => ListView(
              children: <Widget>[
                for (final SavedFilterDto item in list) _row(context, item),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, SavedFilterDto item) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, Object?>? filter = savedFilterObject(item);
    final String? summary = filter == null ? null : widget.describe(filter);
    final bool usable = summary != null;
    final bool busy = _deleting.contains(item.id);
    return ListTile(
      leading: const Icon(Icons.bookmark_outline),
      title: Text(item.name),
      subtitle: Text(summary ?? l10n.savedFiltersUnusable),
      enabled: usable && !busy,
      onTap: usable
          ? () => Navigator.of(context).pop((name: item.name, filter: filter!))
          : null,
      trailing: busy
          ? const SizedBox.square(
              dimension: 48,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              tooltip: l10n.savedFiltersDeleteTooltip(item.name),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(item),
            ),
    );
  }
}

/// Asks for a name and saves [filter]. Pops the created saved filter.
class SaveFilterDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const SaveFilterDialog({
    required this.scope,
    required this.filter,
    super.key,
  });

  /// Where the filter applies.
  final SavedFilterScope scope;

  /// The filter to save (the server's query shape).
  final Map<String, Object?> filter;

  @override
  ConsumerState<SaveFilterDialog> createState() => _SaveFilterDialogState();
}

class _SaveFilterDialogState extends ConsumerState<SaveFilterDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  String? _nameError;
  String? _general;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _nameError = null;
      _general = null;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final SavedFilterDto saved = await ref
          .read(savedFiltersApiProvider)
          .create(widget.scope, _name.text, widget.filter);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (error is ApiException && error.code == ErrorObjectCode.conflict) {
          _nameError = l10n.savedFiltersNameTaken;
          return;
        }
        final ServerFormErrors errors = ServerFormErrors.from(
          l10n,
          error,
          fieldMap: const <String, String>{'name': 'name', 'filter': 'filter'},
        );
        _nameError = errors.fields['name'];
        _general = errors.fields.containsKey('filter')
            ? l10n.savedFiltersFilterInvalid
            : errors.general;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool search = widget.scope == SavedFilterScope.search;
    return AlertDialog(
      title: Text(
        search ? l10n.savedSearchesSaveTitle : l10n.savedFiltersSaveTitle,
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_busy,
              maxLength: SavedFilterName.maxLength,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.savedFiltersNameLabel,
                helperText: l10n.savedFiltersNameHelp,
                helperMaxLines: 3,
                errorText: _nameError,
                errorMaxLines: 3,
              ),
              validator: (String? value) =>
                  SavedFilterName.validate(l10n, value),
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_general != null)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _general!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.savedFiltersSaveAction),
        ),
      ],
    );
  }
}
