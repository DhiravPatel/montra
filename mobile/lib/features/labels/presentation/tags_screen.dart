import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_style_fields.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

enum _TagAction { edit, transactions, archive, unarchive, delete }

/// Name and color entered in the tag editor.
typedef TagDraft = ({String name, String? color});

/// Opens the tag editor (new tag, or rename/recolor [original]). Returns
/// null when cancelled.
Future<TagDraft?> showTagEditor(BuildContext context, {TagDto? original}) =>
    showDialog<TagDraft>(
      context: context,
      builder: (BuildContext context) => _TagEditorDialog(original: original),
    );

/// Tags with how often each is used. Tags can be added, renamed,
/// recolored, archived (hidden from pickers, kept on transactions) and
/// deleted (removed from transactions after confirming).
class TagsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  bool _showArchived = false;
  String? _busyId;

  String _error(AppLocalizations l10n, ApiException error) =>
      switch (error.code) {
        ErrorObjectCode.versionConflict => l10n.versionConflictReloaded,
        ErrorObjectCode.conflict => l10n.tagNameTaken,
        _ => describeError(l10n, error),
      };

  Future<void> _run(
    String? busyId,
    Future<String> Function(LabelsApi api) action,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final LabelsApi api = ref.read(labelsApiProvider);
    setState(() => _busyId = busyId ?? '');
    try {
      final String done = await action(api);
      finance.bump();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.versionConflict) {
        // Changed elsewhere: show the latest tags.
        ref.invalidate(allTagsProvider);
      }
      if (mounted) {
        showSnack(context, _error(l10n, error));
      }
      if (error.code == ErrorObjectCode.versionConflict &&
          busyId != null &&
          busyId.isNotEmpty &&
          mounted) {
        // Offer the change again on the latest version of that tag.
        await _reopen(api, busyId);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  /// Reloads one tag (`GET /tags/{id}`) after a change made elsewhere and
  /// opens its actions again on the latest version.
  Future<void> _reopen(LabelsApi api, String id) async {
    try {
      final TagDto latest = await api.getTag(id);
      if (mounted) {
        setState(() => _busyId = null);
        await _act(latest);
      }
    } on ApiException {
      // The list was reloaded; nothing else to offer.
    }
  }

  Future<void> _create() async {
    final AppLocalizations l10n = context.l10n;
    final TagDraft? draft = await showTagEditor(context);
    if (draft == null || !mounted) {
      return;
    }
    await _run(null, (LabelsApi api) async {
      await api.createTag(TagBody(name: draft.name, color: draft.color));
      return l10n.tagCreated(draft.name);
    });
  }

  Future<void> _act(TagDto tag) async {
    final AppLocalizations l10n = context.l10n;
    final bool archived = tag.archivedAt != null;
    final _TagAction? action = await showOptionSheet<_TagAction>(
      context,
      title: tag.name,
      options: <SheetOption<_TagAction>>[
        SheetOption<_TagAction>(
          value: _TagAction.edit,
          label: l10n.tagEdit,
          icon: Icons.edit_outlined,
        ),
        if (tag.usageCount > 0)
          SheetOption<_TagAction>(
            value: _TagAction.transactions,
            label: l10n.tagSeeTransactions,
            icon: Icons.receipt_long_outlined,
          ),
        if (archived)
          SheetOption<_TagAction>(
            value: _TagAction.unarchive,
            label: l10n.tagUnarchive,
            icon: Icons.unarchive_outlined,
          )
        else
          SheetOption<_TagAction>(
            value: _TagAction.archive,
            label: l10n.tagArchive,
            subtitle: l10n.tagArchiveHelp,
            icon: Icons.archive_outlined,
          ),
        SheetOption<_TagAction>(
          value: _TagAction.delete,
          label: l10n.tagDelete,
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _TagAction.edit:
        final TagDraft? draft = await showTagEditor(context, original: tag);
        if (draft == null || !mounted) {
          return;
        }
        if (draft.name == tag.name && draft.color == tag.color) {
          return;
        }
        await _run(tag.id, (LabelsApi api) async {
          await api.updateTag(
            tag.id,
            TagPatch(
              name: draft.name == tag.name ? null : draft.name,
              color: draft.color == tag.color || draft.color == null
                  ? null
                  : draft.color,
              // Removing the color: the API's `clear_color`.
              clearColor: draft.color == null && tag.color != null
                  ? true
                  : null,
              version: tag.version,
            ),
          );
          return l10n.tagSaved;
        });
      case _TagAction.transactions:
        await context.push<Object?>(
          TransactionFilter(tagIds: <String>{tag.id}).toLocation(),
        );
      case _TagAction.archive:
        await _run(tag.id, (LabelsApi api) async {
          await api.updateTag(
            tag.id,
            TagPatch(archived: true, version: tag.version),
          );
          return l10n.tagArchived(tag.name);
        });
      case _TagAction.unarchive:
        await _run(tag.id, (LabelsApi api) async {
          await api.updateTag(
            tag.id,
            TagPatch(archived: false, version: tag.version),
          );
          return l10n.tagUnarchived(tag.name);
        });
      case _TagAction.delete:
        final bool confirmed = await showConfirmDialog(
          context,
          title: l10n.tagDeleteTitle(tag.name),
          body: l10n.tagDeleteBody(tag.usageCount),
          confirmLabel: l10n.tagDelete,
          destructive: true,
        );
        if (confirmed && mounted) {
          await _run(tag.id, (LabelsApi api) async {
            await api.deleteTag(tag.id);
            return l10n.tagDeleted(tag.name);
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<TagDto>> tags = ref.watch(allTagsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tagsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _busyId == null ? _create : null,
        icon: const Icon(Icons.add),
        label: Text(l10n.tagNew),
      ),
      body: tags.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingStateView(),
        error: (Object error, StackTrace _) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(allTagsProvider),
        ),
        data: (List<TagDto> all) {
          final List<TagDto> shown = <TagDto>[
            for (final TagDto t in all)
              if (_showArchived || t.archivedAt == null) t,
          ];
          final bool hasArchived = all.any((TagDto t) => t.archivedAt != null);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allTagsProvider);
              await ref.read(allTagsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.md,
                    Insets.md,
                    0,
                  ),
                  child: Text(l10n.tagsIntro),
                ),
                if (hasArchived)
                  SwitchListTile(
                    title: Text(l10n.tagsShowArchived),
                    value: _showArchived,
                    onChanged: (bool v) => setState(() => _showArchived = v),
                  ),
                if (shown.isEmpty)
                  MessageStateView(
                    icon: Icons.sell_outlined,
                    title: l10n.tagsEmptyTitle,
                    body: l10n.tagsEmptyBody,
                  )
                else
                  for (final TagDto t in shown)
                    ListTile(
                      leading: ExcludeSemantics(
                        child: CircleAvatar(
                          backgroundColor:
                              parseHexColor(t.color) ??
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.sell_outlined,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      title: Text(t.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.tagUsage(t.usageCount)),
                          if (t.archivedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Insets.xs),
                              child: StatusLabel(
                                text: l10n.tagStatusArchived,
                                icon: Icons.archive_outlined,
                              ),
                            ),
                        ],
                      ),
                      trailing: _busyId == t.id
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.more_vert),
                      onTap: _busyId == null ? () => _act(t) : null,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TagEditorDialog extends StatefulWidget {
  const _TagEditorDialog({this.original});

  final TagDto? original;

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.original?.name ?? '',
  );
  late String? _color = widget.original?.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    if (_form.currentState?.validate() ?? false) {
      Navigator.of(context).pop((name: _name.text.trim(), color: _color));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.original == null ? l10n.tagNew : l10n.tagEdit),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              decoration: InputDecoration(labelText: l10n.tagNameLabel),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.tagNameRequired : null,
              onFieldSubmitted: (_) => _done(),
            ),
            const SizedBox(height: Insets.sm),
            LabelColorField(
              value: _color,
              onChanged: (String? v) => setState(() => _color = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _done, child: Text(l10n.actionSave)),
      ],
    );
  }
}
