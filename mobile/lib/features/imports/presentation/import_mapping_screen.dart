import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/imports/application/imports_providers.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/imports/domain/import_display.dart';

/// Chooses which column of the statement holds each value
/// (`PATCH /imports/{id}/mapping`), starting from the server's suggestion.
/// The first rows of the file are shown, and columns are offered by their
/// header name with an example value, so nothing has to be guessed.
class ImportMappingScreen extends ConsumerWidget {
  /// Creates the screen for [importId].
  const ImportMappingScreen({required this.importId, super.key});

  /// The import.
  final String importId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ImportBatchDto> batch = ref.watch(
      importProvider(importId),
    );
    final AsyncValue<List<ImportRowDto>> sample = ref.watch(
      importSampleProvider(importId),
    );
    Widget frame(Widget body) => Scaffold(
      appBar: AppBar(title: Text(l10n.importMappingTitle)),
      body: body,
    );
    final Object? error = batch.error ?? sample.error;
    if (error != null && !batch.isLoading && !sample.isLoading) {
      return frame(
        ErrorStateView(
          error: error,
          onRetry: () => ref
            ..invalidate(importProvider(importId))
            ..invalidate(importSampleProvider(importId)),
        ),
      );
    }
    final ImportBatchDto? b = batch.value;
    final List<ImportRowDto>? rows = sample.value;
    if (b == null || rows == null) {
      return frame(const LoadingStateView());
    }
    if (b.status != ImportBatchDtoStatus.needsMapping &&
        b.status != ImportBatchDtoStatus.previewReady) {
      return frame(
        MessageStateView(
          icon: Icons.lock_outline,
          title: l10n.importMappingUnavailable,
          body: importStatusHelp(l10n, b.status),
        ),
      );
    }
    return _MappingForm(batch: b, sample: rows);
  }
}

enum _AmountLayout { single, split }

class _MappingForm extends ConsumerStatefulWidget {
  const _MappingForm({required this.batch, required this.sample});

  final ImportBatchDto batch;
  final List<ImportRowDto> sample;

  @override
  ConsumerState<_MappingForm> createState() => _MappingFormState();
}

class _MappingFormState extends ConsumerState<_MappingForm> {
  late int _headerRow;
  int? _dateColumn;
  String? _dateFormat;
  _AmountLayout _layout = _AmountLayout.single;
  int? _amountColumn;
  ColumnMappingSignConvention _sign =
      ColumnMappingSignConvention.negativeIsOutflow;
  int? _debitColumn;
  int? _creditColumn;
  int? _indicatorColumn;
  Set<int> _descriptionColumns = <int>{};
  int? _referenceColumn;
  int? _balanceColumn;
  int? _currencyColumn;
  int? _externalIdColumn;
  String _decimal = '.';
  String? _problem;
  String? _serverError;
  String? _requestId;
  bool _conflictReloaded = false;

  @override
  void initState() {
    super.initState();
    _load(widget.batch.mapping);
  }

  @override
  void didUpdateWidget(covariant _MappingForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.batch.version != oldWidget.batch.version) {
      _load(widget.batch.mapping);
    }
  }

  void _load(ColumnMapping? m) {
    // The server's suggestion uses -1 for "not found".
    int? column(int? v) => v == null || v < 0 ? null : v;
    _headerRow = m == null
        ? (widget.batch.header.isEmpty ? -1 : 0)
        : (m.headerRow < 0 ? -1 : m.headerRow);
    _dateColumn = column(m?.dateColumn);
    _dateFormat = importDateFormats.contains(m?.dateFormat)
        ? m!.dateFormat
        : null;
    _amountColumn = column(m?.amountColumn);
    _debitColumn = column(m?.debitColumn);
    _creditColumn = column(m?.creditColumn);
    _layout =
        _amountColumn == null && (_debitColumn != null || _creditColumn != null)
        ? _AmountLayout.split
        : _AmountLayout.single;
    final ColumnMappingSignConvention? sign = m?.signConvention;
    _sign = sign == null || sign == ColumnMappingSignConvention.unrecognized
        ? ColumnMappingSignConvention.negativeIsOutflow
        : sign;
    _indicatorColumn = column(m?.indicatorColumn);
    _descriptionColumns = <int>{
      for (final int c in m?.descriptionColumns ?? const <int>[])
        if (c >= 0) c,
    };
    _referenceColumn = column(m?.referenceColumn);
    _balanceColumn = column(m?.balanceColumn);
    _currencyColumn = column(m?.currencyColumn);
    _externalIdColumn = column(m?.externalIdColumn);
    _decimal = m?.decimalSeparator == ',' ? ',' : '.';
  }

  /// Number of columns in the file.
  int get _width {
    int width = widget.batch.header.length;
    for (final ImportRowDto r in widget.sample) {
      if (r.raw.length > width) {
        width = r.raw.length;
      }
    }
    return width;
  }

  /// Header cells for the chosen header row.
  List<String> get _headerCells {
    if (_headerRow < 0) {
      return const <String>[];
    }
    if (_headerRow < widget.sample.length) {
      return widget.sample[_headerRow].raw;
    }
    return widget.batch.header;
  }

  /// The first data row after the header (for examples).
  List<String> get _example {
    final int start = _headerRow + 1;
    for (int i = start; i < widget.sample.length; i++) {
      final List<String> raw = widget.sample[i].raw;
      if (raw.where((String c) => c.trim().isNotEmpty).length > 1) {
        return raw;
      }
    }
    return const <String>[];
  }

  String _columnLabel(AppLocalizations l10n, int index) {
    final String name = importColumnName(l10n, index, _headerCells);
    final List<String> example = _example;
    final String sample = index < example.length ? example[index].trim() : '';
    return sample.isEmpty || sample == name
        ? name
        : l10n.importColumnExample(name, sample);
  }

  List<DropdownMenuItem<int?>> _columnItems(
    AppLocalizations l10n, {
    String? noneLabel,
  }) => <DropdownMenuItem<int?>>[
    if (noneLabel != null)
      DropdownMenuItem<int?>(value: null, child: Text(noneLabel)),
    for (int i = 0; i < _width; i++)
      DropdownMenuItem<int?>(
        value: i,
        child: Text(
          _columnLabel(l10n, i),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
  ];

  Widget _columnField(
    AppLocalizations l10n, {
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
    String? helper,
    bool optional = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Insets.md),
    child: DropdownButtonFormField<int?>(
      key: ValueKey<String>('$label-${widget.batch.version}'),
      initialValue: value != null && value >= 0 && value < _width
          ? value
          : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, helperText: helper),
      items: _columnItems(
        l10n,
        noneLabel: optional ? l10n.importColumnNone : null,
      ),
      onChanged: onChanged,
    ),
  );

  String? _validate(AppLocalizations l10n) {
    if (_dateColumn == null) {
      return l10n.importMappingNeedsDate;
    }
    if (_dateFormat == null) {
      return l10n.importMappingNeedsDateFormat;
    }
    if (_layout == _AmountLayout.single && _amountColumn == null) {
      return l10n.importMappingNeedsAmount;
    }
    if (_layout == _AmountLayout.split &&
        (_debitColumn == null || _creditColumn == null)) {
      return l10n.importMappingNeedsDebitCredit;
    }
    return null;
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final String? problem = _validate(l10n);
    setState(() {
      _problem = problem;
      _serverError = null;
      _requestId = null;
      _conflictReloaded = false;
    });
    if (problem != null) {
      return;
    }
    final bool single = _layout == _AmountLayout.single;
    final ColumnMapping mapping = ColumnMapping(
      headerRow: _headerRow,
      dateColumn: _dateColumn!,
      dateFormat: _dateFormat!,
      amountColumn: single ? _amountColumn : null,
      signConvention: single ? _sign : null,
      debitColumn: single ? null : _debitColumn,
      creditColumn: single ? null : _creditColumn,
      indicatorColumn: _indicatorColumn,
      decimalSeparator: _decimal,
      descriptionColumns: (_descriptionColumns.toList()..sort()),
      referenceColumn: _referenceColumn,
      balanceColumn: _balanceColumn,
      currencyColumn: _currencyColumn,
      externalIdColumn: _externalIdColumn,
    );
    final ImportBatchDto b = widget.batch;
    try {
      await ref
          .read(importsApiProvider)
          .setMapping(b.id, mapping, version: b.version);
      ref.invalidate(importProvider(b.id));
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.importMappingSaved);
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict) {
        ref
          ..invalidate(importProvider(b.id))
          ..invalidate(importSampleProvider(b.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(() {
        _serverError = error.details.isNotEmpty
            ? error.details.first.message
            : describeError(l10n, error);
        _requestId = requestIdOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ImportRowDto> sample = widget.sample;
    final String? problem = _problem ?? _serverError;
    final List<String> example = _example;
    final String? dateSample =
        _dateColumn != null && _dateColumn! < example.length
        ? example[_dateColumn!].trim()
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importMappingTitle)),
      body: ScrollableContent(
        children: <Widget>[
          Text(l10n.importMappingIntro),
          const SizedBox(height: Insets.md),
          if (_conflictReloaded) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.versionConflictReloaded,
            ),
            const SizedBox(height: Insets.md),
          ],
          if (problem != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: problem,
              requestId: _requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          FormSectionHeader(l10n.importSampleTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < sample.length && i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.xs),
                      child: Text(
                        l10n.importSampleRow(
                          i + 1,
                          sample[i].raw
                              .where((String c) => c.trim().isNotEmpty)
                              .join(' · '),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          FormSectionHeader(l10n.importHeaderSection),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('header-${widget.batch.version}'),
            initialValue: _headerRow < sample.length && _headerRow < 10
                ? _headerRow
                : -1,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.importHeaderRowLabel,
              helperText: l10n.importHeaderRowHelp,
            ),
            items: <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(
                value: -1,
                child: Text(l10n.importNoHeaderRow),
              ),
              for (int i = 0; i < sample.length && i < 10; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    l10n.importSampleRow(
                      i + 1,
                      sample[i].raw
                          .where((String c) => c.trim().isNotEmpty)
                          .join(' · '),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
            ],
            onChanged: (int? v) => setState(() => _headerRow = v ?? -1),
          ),
          const SizedBox(height: Insets.md),
          FormSectionHeader(l10n.importDateSection),
          _columnField(
            l10n,
            label: l10n.importDateColumn,
            value: _dateColumn,
            optional: false,
            onChanged: (int? v) => setState(() => _dateColumn = v),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('format-${widget.batch.version}'),
            initialValue: _dateFormat,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.importDateFormat,
              helperText: dateSample == null || dateSample.isEmpty
                  ? null
                  : l10n.importDateFormatExample(dateSample),
            ),
            items: <DropdownMenuItem<String>>[
              for (final String f in importDateFormats)
                DropdownMenuItem<String>(value: f, child: Text(f)),
            ],
            onChanged: (String? v) => setState(() => _dateFormat = v),
          ),
          const SizedBox(height: Insets.md),
          FormSectionHeader(l10n.importAmountSection),
          SegmentedButton<_AmountLayout>(
            segments: <ButtonSegment<_AmountLayout>>[
              ButtonSegment<_AmountLayout>(
                value: _AmountLayout.single,
                label: Text(l10n.importAmountSingle),
              ),
              ButtonSegment<_AmountLayout>(
                value: _AmountLayout.split,
                label: Text(l10n.importAmountSplit),
              ),
            ],
            selected: <_AmountLayout>{_layout},
            onSelectionChanged: (Set<_AmountLayout> s) =>
                setState(() => _layout = s.first),
          ),
          const SizedBox(height: Insets.md),
          if (_layout == _AmountLayout.single) ...<Widget>[
            _columnField(
              l10n,
              label: l10n.importAmountColumn,
              value: _amountColumn,
              optional: false,
              onChanged: (int? v) => setState(() => _amountColumn = v),
            ),
            RadioGroup<ColumnMappingSignConvention>(
              groupValue: _sign,
              onChanged: (ColumnMappingSignConvention? v) {
                if (v != null) {
                  setState(() => _sign = v);
                }
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<ColumnMappingSignConvention>(
                    value: ColumnMappingSignConvention.negativeIsOutflow,
                    title: Text(l10n.importSignNegativeOut),
                  ),
                  RadioListTile<ColumnMappingSignConvention>(
                    value: ColumnMappingSignConvention.positiveIsOutflow,
                    title: Text(l10n.importSignPositiveOut),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            _columnField(
              l10n,
              label: l10n.importDebitColumn,
              value: _debitColumn,
              optional: false,
              onChanged: (int? v) => setState(() => _debitColumn = v),
            ),
            _columnField(
              l10n,
              label: l10n.importCreditColumn,
              value: _creditColumn,
              optional: false,
              onChanged: (int? v) => setState(() => _creditColumn = v),
            ),
          ],
          _columnField(
            l10n,
            label: l10n.importIndicatorColumn,
            helper: l10n.importIndicatorHelp,
            value: _indicatorColumn,
            onChanged: (int? v) => setState(() => _indicatorColumn = v),
          ),
          Text(l10n.importDecimalLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Insets.xs),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: '.',
                label: Text(l10n.importDecimalPoint),
              ),
              ButtonSegment<String>(
                value: ',',
                label: Text(l10n.importDecimalComma),
              ),
            ],
            selected: <String>{_decimal},
            onSelectionChanged: (Set<String> s) =>
                setState(() => _decimal = s.first),
          ),
          const SizedBox(height: Insets.md),
          FormSectionHeader(l10n.importDescriptionSection),
          Text(l10n.importDescriptionHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (int i = 0; i < _width; i++)
                FilterChip(
                  label: Text(importColumnName(l10n, i, _headerCells)),
                  selected: _descriptionColumns.contains(i),
                  onSelected: (bool on) => setState(() {
                    _descriptionColumns = <int>{..._descriptionColumns};
                    if (on) {
                      _descriptionColumns.add(i);
                    } else {
                      _descriptionColumns.remove(i);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          FormSectionHeader(l10n.importOptionalSection),
          _columnField(
            l10n,
            label: l10n.importReferenceColumn,
            value: _referenceColumn,
            onChanged: (int? v) => setState(() => _referenceColumn = v),
          ),
          _columnField(
            l10n,
            label: l10n.importBalanceColumn,
            helper: l10n.importBalanceColumnHelp,
            value: _balanceColumn,
            onChanged: (int? v) => setState(() => _balanceColumn = v),
          ),
          _columnField(
            l10n,
            label: l10n.importCurrencyColumn,
            value: _currencyColumn,
            onChanged: (int? v) => setState(() => _currencyColumn = v),
          ),
          _columnField(
            l10n,
            label: l10n.importExternalIdColumn,
            helper: l10n.importExternalIdHelp,
            value: _externalIdColumn,
            onChanged: (int? v) => setState(() => _externalIdColumn = v),
          ),
          const SizedBox(height: Insets.md),
          SubmitButton(label: l10n.importMappingSave, onPressed: _save),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}
