import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/imports/application/imports_providers.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/imports/domain/import_display.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';

enum _RowAction { include, skip, category, correct, open }

/// An import's rows by status (`GET /imports/{id}/rows`, page by page) with
/// the reason for each status. Before confirming (and for failed rows after
/// an import with errors) a row can be imported or skipped, categorized,
/// or corrected (`PATCH /imports/{id}/rows/{rowId}`).
class ImportRowsScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [importId], optionally filtered by [status].
  const ImportRowsScreen({required this.importId, this.status, super.key});

  /// The import.
  final String importId;

  /// Initial row status filter.
  final String? status;

  @override
  ConsumerState<ImportRowsScreen> createState() => _ImportRowsScreenState();
}

class _ImportRowsScreenState extends ConsumerState<ImportRowsScreen> {
  late String _filter = importRowFilters.contains(widget.status)
      ? widget.status!
      : '';
  String? _busyRow;

  ImportRowsQuery get _query =>
      (importId: widget.importId, status: _filter.isEmpty ? null : _filter);

  Future<void> _update(ImportRowDto row, ImportRowUpdate update) async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _busyRow = row.id);
    try {
      final ImportRowDto changed = await ref
          .read(importsApiProvider)
          .updateRow(widget.importId, row.id, update);
      ref.read(importRowsProvider(_query).notifier).replace(changed);
      ref.invalidate(importProvider(widget.importId));
      if (mounted) {
        showSnack(context, l10n.importRowSaved);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyRow = null);
      }
    }
  }

  Future<void> _onTap(ImportBatchDto batch, ImportRowDto row) async {
    final AppLocalizations l10n = context.l10n;
    final bool editable = importRowsEditable(batch, row);
    final String? linked = row.transactionId ?? row.duplicateOfTransactionId;
    final bool importing = willImport(row);
    final List<SheetOption<_RowAction>> options = <SheetOption<_RowAction>>[
      if (editable && !importing && importRowCanImport(row))
        SheetOption<_RowAction>(
          value: _RowAction.include,
          label: l10n.importRowInclude,
          icon: Icons.download_done,
        ),
      if (editable && importing)
        SheetOption<_RowAction>(
          value: _RowAction.skip,
          label: l10n.importRowSkip,
          icon: Icons.redo,
        ),
      if (editable &&
          (row.status != ImportRowDtoStatus.invalid ||
              row.errorField == ImportRowDtoErrorField.categoryId))
        SheetOption<_RowAction>(
          value: _RowAction.category,
          label: l10n.importRowCategory,
          subtitle: row.errorField == ImportRowDtoErrorField.categoryId
              ? importRowReason(l10n, row)
              : null,
          icon: Icons.category_outlined,
        ),
      if (editable && row.errorField != ImportRowDtoErrorField.categoryId)
        SheetOption<_RowAction>(
          value: _RowAction.correct,
          label: l10n.importRowCorrect,
          subtitle: switch (row.errorField) {
            ImportRowDtoErrorField.postedDate => l10n.importFixDate,
            ImportRowDtoErrorField.amount => l10n.importFixAmount,
            ImportRowDtoErrorField.description => l10n.importFixDescription,
            _ => null,
          },
          icon: Icons.edit_outlined,
        ),
      if (linked != null)
        SheetOption<_RowAction>(
          value: _RowAction.open,
          label: row.transactionId != null
              ? l10n.importRowOpenTransaction
              : l10n.importRowOpenExisting,
          icon: Icons.open_in_new,
        ),
    ];
    if (options.isEmpty) {
      return;
    }
    final _RowAction? action = await showOptionSheet<_RowAction>(
      context,
      title: rowTitle(l10n, row),
      options: options,
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _RowAction.include:
        await _update(
          row,
          const ImportRowUpdate(decision: ImportRowUpdateDecision.importValue),
        );
      case _RowAction.skip:
        await _update(
          row,
          const ImportRowUpdate(decision: ImportRowUpdateDecision.skip),
        );
      case _RowAction.category:
        final Picked<CategoryDto>? picked = await showCategoryPicker(
          context,
          kind: row.direction == ImportRowDtoDirection.inflow
              ? CategoryKindFilter.income
              : CategoryKindFilter.spending,
          selectedId: row.categoryId,
          allowNone: false,
        );
        final String? categoryId = picked?.value?.id;
        if (categoryId != null && mounted) {
          await _update(row, ImportRowUpdate(categoryId: categoryId));
        }
      case _RowAction.correct:
        final ImportRowUpdate? update =
            await showModalBottomSheet<ImportRowUpdate>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (BuildContext context) => _CorrectionSheet(
                row: row,
                currency: batch.currency,
                problem: importRowReason(context.l10n, row),
              ),
            );
        if (update != null && mounted) {
          await _update(row, update);
        }
      case _RowAction.open:
        if (linked != null) {
          await context.push(AppRoutes.transactionDetail(linked));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ImportBatchDto> batch = ref.watch(
      importProvider(widget.importId),
    );
    final AsyncValue<ImportRowsState> rows = ref.watch(
      importRowsProvider(_query),
    );
    final ImportBatchDto? b = batch.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importRowsTitle),
        bottom: _busyRow != null || (rows.isLoading && rows.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              Insets.xs,
            ),
            child: Row(
              children: <Widget>[
                for (final String f in importRowFilters)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Insets.sm),
                    child: ChoiceChip(
                      label: Text(importRowFilterLabel(l10n, f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          if (b != null && b.status == ImportBatchDtoStatus.previewReady)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(
                l10n.importRowsHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: b == null
                ? AsyncValueView<ImportBatchDto>(
                    value: batch,
                    onRetry: () =>
                        ref.invalidate(importProvider(widget.importId)),
                    data: (_) => const SizedBox.shrink(),
                  )
                : AsyncValueView<ImportRowsState>(
                    value: rows,
                    onRetry: () => ref.invalidate(importRowsProvider(_query)),
                    isEmpty: (ImportRowsState s) => s.rows.isEmpty,
                    empty: MessageStateView(
                      icon: Icons.inbox_outlined,
                      title: l10n.importRowsEmpty,
                    ),
                    data: (ImportRowsState s) => ListView.separated(
                      padding: const EdgeInsets.only(bottom: Insets.lg),
                      itemCount: s.rows.length + 1,
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == s.rows.length) {
                          return _LoadMore(
                            state: s,
                            onLoadMore: () => ref
                                .read(importRowsProvider(_query).notifier)
                                .loadMore(),
                          );
                        }
                        final ImportRowDto row = s.rows[index];
                        return ImportRowTile(
                          row: row,
                          busy: _busyRow == row.id,
                          onTap: _busyRow == null ? () => _onTap(b, row) : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Whether [row] will be imported when the import is confirmed (ready rows
/// unless skipped; possible duplicates only when the user chose them).
bool willImport(ImportRowDto row) => switch (row.status) {
  ImportRowDtoStatus.ready || ImportRowDtoStatus.failed =>
    row.userDecision != ImportRowDtoUserDecision.skip,
  ImportRowDtoStatus.duplicate =>
    row.userDecision == ImportRowDtoUserDecision.importValue,
  _ => false,
};

/// A row's title: its description, or "Row 7".
String rowTitle(AppLocalizations l10n, ImportRowDto row) {
  final String d = (row.description ?? '').trim();
  return d.isEmpty ? l10n.importRowNumber(row.rowNumber) : d;
}

/// One statement row: description, date, amount and direction, status with
/// its reason and what will happen to it.
class ImportRowTile extends ConsumerWidget {
  /// Creates the tile.
  const ImportRowTile({
    required this.row,
    this.busy = false,
    this.onTap,
    super.key,
  });

  /// The row.
  final ImportRowDto row;

  /// Whether a change is being saved.
  final bool busy;

  /// Opens the row's actions.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final String? reason = importRowReason(l10n, row);
    final CategoryDto? category = row.categoryId == null
        ? null
        : categories[row.categoryId];
    final bool skippedLine =
        row.errorCode == 'header' || row.errorCode == 'preamble';
    final String? decision = switch (row.status) {
      ImportRowDtoStatus.ready ||
      ImportRowDtoStatus.duplicate ||
      ImportRowDtoStatus.failed =>
        willImport(row) ? l10n.importRowWillImport : l10n.importRowWillSkip,
      _ => null,
    };
    return ListTile(
      onTap: onTap,
      title: Text(
        skippedLine
            ? row.raw.where((String c) => c.trim().isNotEmpty).join(' · ')
            : rowTitle(l10n, row),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              l10n.importRowNumber(row.rowNumber),
              if (row.postedDate case final String d)
                LocalDates.display(d, locale: locale),
              if (category != null) categoryName(l10n, category),
            ].join(' · '),
          ),
          if (row.amount case final Money amount)
            MoneyText(
              amount,
              flow: switch (row.direction) {
                ImportRowDtoDirection.inflow => MoneyFlow.inflow,
                ImportRowDtoDirection.outflow => MoneyFlow.outflow,
                _ => MoneyFlow.none,
              },
            ),
          if (reason != null && reason.isNotEmpty) Text(reason),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              StatusLabel(
                text: importRowStatusLabel(l10n, row.status),
                tone: importRowStatusTone(row.status),
                icon: importRowStatusIcon(row.status),
              ),
              if (decision != null)
                StatusLabel(
                  text: decision,
                  icon: willImport(row) ? Icons.download_done : Icons.redo,
                ),
            ],
          ),
        ],
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (onTap == null ? null : const Icon(Icons.more_vert)),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.state, required this.onLoadMore});

  final ImportRowsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(Insets.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final Object? error = state.loadMoreError;
    if (!state.hasMore && error == null) {
      return const SizedBox(height: Insets.md);
    }
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        children: <Widget>[
          if (error != null)
            Text(describeError(l10n, error), textAlign: TextAlign.center),
          OutlinedButton(
            onPressed: onLoadMore,
            child: Text(l10n.actionLoadMore),
          ),
        ],
      ),
    );
  }
}

/// Corrects a row's date, amount, direction and description (the server
/// needs all three of date, amount and direction for a corrected row).
class _CorrectionSheet extends ConsumerStatefulWidget {
  const _CorrectionSheet({
    required this.row,
    required this.currency,
    this.problem,
  });

  final ImportRowDto row;
  final String currency;

  /// Why the row needs a correction (shown under the value to correct,
  /// `error_field`).
  final String? problem;

  @override
  ConsumerState<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends ConsumerState<_CorrectionSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.row.amount?.amount ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.row.description ?? '',
  );
  late String? _date = widget.row.postedDate;
  late ImportRowUpdateDirection? _direction = switch (widget.row.direction) {
    ImportRowDtoDirection.inflow => ImportRowUpdateDirection.inflow,
    ImportRowDtoDirection.outflow => ImportRowUpdateDirection.outflow,
    _ => null,
  };
  String? _dateError;
  String? _directionError;

  /// The row's problem, under the value the server named in `error_field`.
  String? _problemFor(ImportRowDtoErrorField field) =>
      widget.row.errorField == field ? widget.problem : null;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _dateError = _date == null ? l10n.importRowDateRequired : null;
      _directionError = _direction == null
          ? l10n.importRowDirectionRequired
          : null;
    });
    final bool valid = _form.currentState?.validate() ?? false;
    if (!valid || _date == null || _direction == null) {
      return;
    }
    final String? amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: widget.currency,
    ).value;
    if (amount == null) {
      return;
    }
    final String description = _description.text.trim();
    Navigator.of(context).pop(
      ImportRowUpdate(
        postedDate: _date,
        amount: amount,
        direction: _direction,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> raw = widget.row.raw;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.md),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.importRowCorrectTitle(widget.row.rowNumber),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Insets.sm),
              if (raw.isNotEmpty)
                NoticeBanner(
                  message: l10n.importRowAsRead(
                    raw.where((String c) => c.trim().isNotEmpty).join(' · '),
                  ),
                ),
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.importRowDate,
                value: _date,
                emptyLabel: l10n.receiptDateChoose,
                errorText:
                    _dateError ??
                    _problemFor(ImportRowDtoErrorField.postedDate),
                onChanged: (String? d) => setState(() {
                  _date = d;
                  _dateError = null;
                }),
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _amount,
                label: l10n.importRowAmount,
                currency: widget.currency,
                autofocus:
                    widget.row.errorField == ImportRowDtoErrorField.amount,
                errorText: _problemFor(ImportRowDtoErrorField.amount),
              ),
              const SizedBox(height: Insets.md),
              SegmentedButton<ImportRowUpdateDirection>(
                emptySelectionAllowed: true,
                segments: <ButtonSegment<ImportRowUpdateDirection>>[
                  ButtonSegment<ImportRowUpdateDirection>(
                    value: ImportRowUpdateDirection.outflow,
                    label: Text(l10n.importRowMoneyOut),
                  ),
                  ButtonSegment<ImportRowUpdateDirection>(
                    value: ImportRowUpdateDirection.inflow,
                    label: Text(l10n.importRowMoneyIn),
                  ),
                ],
                selected: <ImportRowUpdateDirection>{?_direction},
                onSelectionChanged: (Set<ImportRowUpdateDirection> s) =>
                    setState(() {
                      _direction = s.isEmpty ? null : s.first;
                      _directionError = null;
                    }),
              ),
              if (_directionError case final String e)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xs),
                  child: Text(
                    e,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _description,
                autofocus:
                    widget.row.errorField == ImportRowDtoErrorField.description,
                maxLength: ImportRowUpdate.descriptionMaxLength,
                decoration: InputDecoration(
                  labelText: l10n.importRowDescription,
                  errorText: _problemFor(ImportRowDtoErrorField.description),
                ),
              ),
              const SizedBox(height: Insets.md),
              SubmitButton(
                label: l10n.importRowSaveCorrection,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
