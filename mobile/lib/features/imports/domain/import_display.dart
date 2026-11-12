import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/reconciliation/domain/reconciliation_display.dart';

/// Statuses in which the server is still working on an import (the detail
/// screen re-reads it until it settles).
const Set<ImportBatchDtoStatus> workingImportStatuses = <ImportBatchDtoStatus>{
  ImportBatchDtoStatus.awaitingUpload,
  ImportBatchDtoStatus.uploaded,
  ImportBatchDtoStatus.parsing,
  ImportBatchDtoStatus.confirmed,
  ImportBatchDtoStatus.processing,
};

/// Whether the server is still working on [batch].
bool importIsWorking(ImportBatchDto batch) =>
    workingImportStatuses.contains(batch.status);

/// An import status in words.
String importStatusLabel(AppLocalizations l10n, ImportBatchDtoStatus status) =>
    switch (status) {
      ImportBatchDtoStatus.awaitingUpload ||
      ImportBatchDtoStatus.uploaded ||
      ImportBatchDtoStatus.parsing => l10n.importStatusReading,
      ImportBatchDtoStatus.needsMapping => l10n.importStatusNeedsMapping,
      ImportBatchDtoStatus.previewReady => l10n.importStatusPreviewReady,
      ImportBatchDtoStatus.confirmed ||
      ImportBatchDtoStatus.processing => l10n.importStatusImporting,
      ImportBatchDtoStatus.completed => l10n.importStatusCompleted,
      ImportBatchDtoStatus.completedWithErrors =>
        l10n.importStatusCompletedWithErrors,
      ImportBatchDtoStatus.failed => l10n.importStatusFailed,
      ImportBatchDtoStatus.cancelled => l10n.importStatusCancelled,
      ImportBatchDtoStatus.unrecognized => l10n.importStatusOther,
    };

/// Tone of an import status (shown with an icon and words).
StatusTone importStatusTone(ImportBatchDtoStatus status) => switch (status) {
  ImportBatchDtoStatus.completed => StatusTone.positive,
  ImportBatchDtoStatus.needsMapping ||
  ImportBatchDtoStatus.previewReady ||
  ImportBatchDtoStatus.completedWithErrors => StatusTone.caution,
  ImportBatchDtoStatus.failed => StatusTone.caution,
  _ => StatusTone.neutral,
};

/// Icon of an import status.
IconData importStatusIcon(ImportBatchDtoStatus status) => switch (status) {
  ImportBatchDtoStatus.awaitingUpload ||
  ImportBatchDtoStatus.uploaded ||
  ImportBatchDtoStatus.parsing ||
  ImportBatchDtoStatus.confirmed ||
  ImportBatchDtoStatus.processing => Icons.hourglass_top,
  ImportBatchDtoStatus.needsMapping => Icons.view_column_outlined,
  ImportBatchDtoStatus.previewReady => Icons.fact_check_outlined,
  ImportBatchDtoStatus.completed => Icons.check_circle_outline,
  ImportBatchDtoStatus.completedWithErrors => Icons.error_outline,
  ImportBatchDtoStatus.failed => Icons.cancel_outlined,
  ImportBatchDtoStatus.cancelled => Icons.block,
  ImportBatchDtoStatus.unrecognized => Icons.help_outline,
};

/// What happens next for an import in [status].
String importStatusHelp(AppLocalizations l10n, ImportBatchDtoStatus status) =>
    switch (status) {
      ImportBatchDtoStatus.awaitingUpload ||
      ImportBatchDtoStatus.uploaded ||
      ImportBatchDtoStatus.parsing => l10n.importHelpReading,
      ImportBatchDtoStatus.needsMapping => l10n.importHelpNeedsMapping,
      ImportBatchDtoStatus.previewReady => l10n.importHelpPreviewReady,
      ImportBatchDtoStatus.confirmed ||
      ImportBatchDtoStatus.processing => l10n.importHelpImporting,
      ImportBatchDtoStatus.completed => l10n.importHelpCompleted,
      ImportBatchDtoStatus.completedWithErrors =>
        l10n.importHelpCompletedWithErrors,
      ImportBatchDtoStatus.failed => l10n.importHelpFailed,
      ImportBatchDtoStatus.cancelled => l10n.importHelpCancelled,
      ImportBatchDtoStatus.unrecognized => l10n.importHelpReading,
    };

/// Why an import failed or ended, in the user's language when the code is
/// known (with the values in `error_params`); otherwise the server's
/// message.
String? importErrorText(AppLocalizations l10n, ImportBatchDto batch) {
  final String? code = batch.errorCode;
  final String message = batch.errorMessage ?? '';
  final Map<String, String> p = batch.errorParams ?? const <String, String>{};
  if (code == null) {
    return message.isEmpty ? null : message;
  }
  return switch (code) {
    'empty' => l10n.importErrorEmpty,
    'unsupported_format' ||
    'pdf_needs_ai' ||
    'pdf_unreadable' => l10n.importErrorUnsupported,
    'malformed' => l10n.importErrorMalformed,
    'too_large' => l10n.importErrorTooLarge,
    'too_many_rows' => l10n.importErrorTooManyRows,
    'too_many_columns' => l10n.importErrorTooManyColumns,
    'currency_mismatch'
        when p['statement_currency'] != null && p['account_currency'] != null =>
      l10n.importErrorCurrencyNamed(
        p['statement_currency']!,
        p['account_currency']!,
      ),
    'currency_mismatch' => l10n.importErrorCurrency,
    'file_unavailable' => l10n.importErrorFileUnavailable,
    'rolled_back' => switch ((
      int.tryParse(p['voided'] ?? ''),
      int.tryParse(p['kept'] ?? ''),
    )) {
      (final int voided, final int kept) => l10n.importRolledBackCounts(
        voided,
        kept,
      ),
      _ => l10n.importRolledBack,
    },
    _ => message.isEmpty ? l10n.importErrorGeneric : message,
  };
}

/// What to check in the suggested column choices, in the user's language:
/// by `mapping_note_codes` (in the order of the English `mapping_notes`),
/// with the date formats from `mapping_note_params`; a code this app does
/// not know keeps the English note.
List<String> importMappingNotes(AppLocalizations l10n, ImportBatchDto batch) {
  final List<String> english = batch.mappingNotes;
  final List<ImportBatchDtoMappingNoteCodesItem> codes = batch.mappingNoteCodes;
  final Map<String, String> p = batch.mappingNoteParams;
  String? coded(ImportBatchDtoMappingNoteCodesItem code) => switch (code) {
    ImportBatchDtoMappingNoteCodesItem.noHeaderRow => l10n.importNoteNoHeader,
    ImportBatchDtoMappingNoteCodesItem.ambiguousDateOrder
        when p['assumed_date_format'] != null &&
            p['alternative_date_format'] != null =>
      l10n.importNoteAmbiguousDate(
        p['assumed_date_format']!,
        p['alternative_date_format']!,
      ),
    ImportBatchDtoMappingNoteCodesItem.ambiguousDateOrder =>
      l10n.importNoteAmbiguousDateGeneric,
    ImportBatchDtoMappingNoteCodesItem.unknownDateFormat =>
      l10n.importNoteUnknownDateFormat,
    ImportBatchDtoMappingNoteCodesItem.decimalComma =>
      l10n.importNoteDecimalComma,
    ImportBatchDtoMappingNoteCodesItem.mappingIncomplete =>
      l10n.importNoteMappingIncomplete,
    ImportBatchDtoMappingNoteCodesItem.checkSignConvention =>
      l10n.importNoteCheckSign,
    ImportBatchDtoMappingNoteCodesItem.pdfReadByAi => l10n.importNotePdfRead,
    ImportBatchDtoMappingNoteCodesItem.unrecognized => null,
  };
  if (codes.isEmpty) {
    return english;
  }
  return <String>[
    for (int i = 0; i < codes.length; i++)
      coded(codes[i]) ?? (i < english.length ? english[i] : ''),
  ].where((String n) => n.isNotEmpty).toList();
}

/// Row filters of the preview (`GET /imports/{id}/rows?status=`); `''`
/// lists every row.
const List<String> importRowFilters = <String>[
  '',
  'ready',
  'duplicate',
  'invalid',
  'skipped',
  'imported',
  'failed',
];

/// Name of a row filter.
String importRowFilterLabel(AppLocalizations l10n, String filter) =>
    switch (filter) {
      'ready' => l10n.importRowsReady,
      'duplicate' => l10n.importRowsDuplicate,
      'invalid' => l10n.importRowsInvalid,
      'skipped' => l10n.importRowsSkipped,
      'imported' => l10n.importRowsImported,
      'failed' => l10n.importRowsFailed,
      _ => l10n.importRowsAll,
    };

/// A row status in words.
String importRowStatusLabel(AppLocalizations l10n, ImportRowDtoStatus status) =>
    switch (status) {
      ImportRowDtoStatus.parsed => l10n.importRowStatusParsed,
      ImportRowDtoStatus.ready => l10n.importRowStatusReady,
      ImportRowDtoStatus.duplicate => l10n.importRowStatusDuplicate,
      ImportRowDtoStatus.invalid => l10n.importRowStatusInvalid,
      ImportRowDtoStatus.skipped => l10n.importRowStatusSkipped,
      ImportRowDtoStatus.imported => l10n.importRowStatusImported,
      ImportRowDtoStatus.failed => l10n.importRowStatusFailed,
      ImportRowDtoStatus.unrecognized => l10n.importStatusOther,
    };

/// Tone of a row status.
StatusTone importRowStatusTone(ImportRowDtoStatus status) => switch (status) {
  ImportRowDtoStatus.imported ||
  ImportRowDtoStatus.ready => StatusTone.positive,
  ImportRowDtoStatus.duplicate ||
  ImportRowDtoStatus.invalid => StatusTone.caution,
  ImportRowDtoStatus.failed => StatusTone.caution,
  _ => StatusTone.neutral,
};

/// Icon of a row status.
IconData importRowStatusIcon(ImportRowDtoStatus status) => switch (status) {
  ImportRowDtoStatus.ready => Icons.check,
  ImportRowDtoStatus.imported => Icons.check_circle_outline,
  ImportRowDtoStatus.duplicate => Icons.content_copy_outlined,
  ImportRowDtoStatus.invalid => Icons.edit_note,
  ImportRowDtoStatus.skipped => Icons.redo,
  ImportRowDtoStatus.failed => Icons.error_outline,
  _ => Icons.description_outlined,
};

/// Why a row has its status, in the user's language for known codes
/// (with the values in `error_params` and, for possible duplicates, the
/// `duplicate_reason_codes`); otherwise the server's message. Domain rule
/// codes of failed rows are localized like any coded error.
String? importRowReason(AppLocalizations l10n, ImportRowDto row) {
  final String? code = row.errorCode;
  final String? message = row.errorMessage;
  final Map<String, String> p = row.errorParams ?? const <String, String>{};
  if (code == null) {
    return message;
  }
  return switch (code) {
    'header' => l10n.importReasonHeader,
    'preamble' => l10n.importReasonPreamble,
    'missing_date' => l10n.importReasonMissingDate,
    'bad_date' when (p['format'] ?? '').isNotEmpty =>
      l10n.importReasonBadDateFormat(p['format']!),
    'bad_date' => l10n.importReasonBadDate,
    'currency_mismatch'
        when p['currency'] != null && p['account_currency'] != null =>
      l10n.importReasonCurrencyNamed(p['currency']!, p['account_currency']!),
    'currency_mismatch' => l10n.importReasonCurrency,
    'bad_amount' when (p['currency'] ?? '').isNotEmpty =>
      l10n.importReasonBadAmountIn(p['currency']!),
    'bad_amount' => l10n.importReasonBadAmount,
    'zero_amount' => l10n.importReasonZeroAmount,
    'both_debit_credit' => l10n.importReasonBothColumns,
    'possible_duplicate' => _duplicateReason(l10n, row),
    'already_imported' when p['matched_by'] == 'external_id' =>
      l10n.importReasonAlreadyImportedReference,
    'already_imported' => l10n.importReasonAlreadyImported,
    'invalid_date' => l10n.importReasonInvalidDate,
    'invalid_amount' => l10n.importReasonInvalidAmount,
    'invalid_category' => l10n.importReasonInvalidCategory,
    'invalid_description' => l10n.importReasonInvalidDescription,
    'invalid_reference' => l10n.importReasonInvalidReference,
    'invalid_row' => l10n.importReasonInvalidRow,
    'rejected' => l10n.importReasonRejected,
    'reconciled' => l10n.importReasonReconciled,
    'rolled_back' => l10n.importReasonRolledBack,
    _ => detailMessage(
      l10n,
      Detail(code: code, message: message ?? '', params: p),
    ),
  };
}

String _duplicateReason(AppLocalizations l10n, ImportRowDto row) {
  final List<String> why = <String>[
    for (final ImportRowDtoDuplicateReasonCodesItem c
        in row.duplicateReasonCodes ??
            const <ImportRowDtoDuplicateReasonCodesItem>[])
      ?reconReasonCodeText(l10n, c.json),
  ];
  return why.isEmpty
      ? l10n.importReasonPossibleDuplicate
      : l10n.importReasonPossibleDuplicateWhy(why.join(', '));
}

/// Whether the user may still change rows of [batch] (before confirming,
/// or failed rows after an import with errors).
bool importRowsEditable(ImportBatchDto batch, ImportRowDto row) {
  if (row.status == ImportRowDtoStatus.imported) {
    return false;
  }
  if (row.errorCode == 'header' || row.errorCode == 'preamble') {
    return false;
  }
  return switch (batch.status) {
    ImportBatchDtoStatus.previewReady => true,
    ImportBatchDtoStatus.completedWithErrors =>
      row.status == ImportRowDtoStatus.failed,
    _ => false,
  };
}

/// Whether a row can be marked for import (rows already imported into the
/// account cannot be forced in again).
bool importRowCanImport(ImportRowDto row) =>
    row.errorCode != 'already_imported' &&
    row.status != ImportRowDtoStatus.invalid;

/// The date formats the server reads (`ColumnMapping.date_format`).
const List<String> importDateFormats = <String>[
  'YYYY-MM-DD',
  'DD/MM/YYYY',
  'MM/DD/YYYY',
  'DD-MM-YYYY',
  'MM-DD-YYYY',
  'DD.MM.YYYY',
  'YYYY/MM/DD',
  'DD/MM/YY',
  'MM/DD/YY',
  'DD-MM-YY',
  'DD-MMM-YYYY',
  'DD MMM YYYY',
  'DD-MMM-YY',
  'DD MMM YY',
  'MMM DD, YYYY',
  'YYYYMMDD',
];

/// A column's name for pickers: its header cell, or "Column 3".
String importColumnName(AppLocalizations l10n, int index, List<String> header) {
  final String name = index < header.length ? header[index].trim() : '';
  return name.isEmpty ? l10n.importColumnNumber(index + 1) : name;
}
