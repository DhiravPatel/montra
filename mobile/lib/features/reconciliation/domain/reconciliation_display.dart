import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';

/// Statement balance checks of an account, page by page.
final AsyncNotifierProviderFamily<
  ReconBalancesController,
  PagedList<ReconBalanceDto>,
  String
>
reconBalancesProvider = AsyncNotifierProvider.autoDispose
    .family<ReconBalancesController, PagedList<ReconBalanceDto>, String>(
      ReconBalancesController.new,
    );

/// See [reconBalancesProvider].
class ReconBalancesController extends PagedListController<ReconBalanceDto> {
  /// Creates the controller for [accountId].
  ReconBalancesController(this.accountId);

  /// The account.
  final String accountId;

  @override
  Future<PagedList<ReconBalanceDto>> build() {
    ref.watch(financeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<ReconBalanceDto>> fetchPage(String? cursor) =>
      ref.read(reconciliationApiProvider).balances(accountId, cursor: cursor);

  @override
  String keyOf(ReconBalanceDto item) => item.id;
}

/// Suggested matches of an account.
final FutureProviderFamily<List<ReconCandidate>, String>
reconCandidatesProvider = FutureProvider.autoDispose
    .family<List<ReconCandidate>, String>((Ref ref, String accountId) {
      ref.watch(financeRevisionProvider);
      return ref.read(reconciliationApiProvider).candidates(accountId);
    });

/// Matches of an account, page by page.
final AsyncNotifierProviderFamily<
  ReconMatchesController,
  PagedList<ReconMatchDto>,
  String
>
reconMatchesProvider = AsyncNotifierProvider.autoDispose
    .family<ReconMatchesController, PagedList<ReconMatchDto>, String>(
      ReconMatchesController.new,
    );

/// See [reconMatchesProvider].
class ReconMatchesController extends PagedListController<ReconMatchDto> {
  /// Creates the controller for [accountId].
  ReconMatchesController(this.accountId);

  /// The account.
  final String accountId;

  @override
  Future<PagedList<ReconMatchDto>> build() {
    ref.watch(financeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<ReconMatchDto>> fetchPage(String? cursor) =>
      ref.read(reconciliationApiProvider).matches(accountId, cursor: cursor);

  @override
  String keyOf(ReconMatchDto item) => item.id;
}

/// Which statement lines to list: an account and unmatched or matched.
typedef StatementLinesQuery = ({String accountId, bool matched});

/// Statement lines of an account (not imported and not matched, or matched
/// by hand), page by page.
final AsyncNotifierProviderFamily<
  StatementLinesController,
  PagedList<StatementLineDto>,
  StatementLinesQuery
>
statementLinesProvider = AsyncNotifierProvider.autoDispose
    .family<
      StatementLinesController,
      PagedList<StatementLineDto>,
      StatementLinesQuery
    >(StatementLinesController.new);

/// See [statementLinesProvider].
class StatementLinesController extends PagedListController<StatementLineDto> {
  /// Creates the controller for [query].
  StatementLinesController(this.query);

  /// The account and which lines.
  final StatementLinesQuery query;

  @override
  Future<PagedList<StatementLineDto>> build() {
    ref.watch(financeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<StatementLineDto>> fetchPage(String? cursor) => ref
      .read(reconciliationApiProvider)
      .statementLines(query.accountId, matched: query.matched, cursor: cursor);

  @override
  String keyOf(StatementLineDto item) => item.importRowId;
}

/// The kind of a suggested or confirmed match (wire value).
String reconKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'statement_to_ledger' => l10n.reconKindStatement,
  'pending_to_posted' => l10n.reconKindPending,
  'manual_to_imported' => l10n.reconKindDuplicate,
  _ => l10n.reconKindOther,
};

/// What confirming a match of [kind] does.
String reconKindHelp(AppLocalizations l10n, String kind) => switch (kind) {
  'statement_to_ledger' => l10n.reconKindStatementHelp,
  'pending_to_posted' => l10n.reconKindPendingHelp,
  'manual_to_imported' => l10n.reconKindDuplicateHelp,
  _ => '',
};

/// A match's status.
String reconMatchStatusLabel(AppLocalizations l10n, ReconMatchDtoStatus s) =>
    switch (s) {
      ReconMatchDtoStatus.confirmed => l10n.reconMatchConfirmed,
      ReconMatchDtoStatus.unmatched => l10n.reconMatchUndone,
      ReconMatchDtoStatus.suggested => l10n.reconMatchSuggested,
      ReconMatchDtoStatus.rejected => l10n.reconMatchRejected,
      ReconMatchDtoStatus.unrecognized => l10n.reconMatchOther,
    };

/// What a match did to one record.
String? reconEffectLabel(AppLocalizations l10n, ReconMatchItemDtoEffect e) =>
    switch (e) {
      ReconMatchItemDtoEffect.voided => l10n.reconEffectVoided,
      ReconMatchItemDtoEffect.rowSkipped => l10n.reconEffectRowSkipped,
      ReconMatchItemDtoEffect.none ||
      ReconMatchItemDtoEffect.unrecognized => null,
    };

/// A match reason by its stable code (`reason_codes` of candidates,
/// matches and duplicate import rows share one list), or null for a code
/// this app does not know. [params] are the `reason_params`; [money]
/// formats an amount parameter (a decimal string in a currency).
String? reconReasonCodeText(
  AppLocalizations l10n,
  String code, {
  Map<String, String> params = const <String, String>{},
  String Function(String amount, String currency)? money,
}) {
  final String currency = params['currency'] ?? '';
  String amount(String? value) => value == null
      ? ''
      : (money == null || currency.isEmpty ? value : money(value, currency));
  return switch (ReconMatchDtoReasonCodesItem.fromJson(code)) {
    ReconMatchDtoReasonCodesItem.sameAmountDirection =>
      l10n.reconReasonSameAmount,
    ReconMatchDtoReasonCodesItem.sameDate => l10n.reconReasonSameDate,
    ReconMatchDtoReasonCodesItem.oneDayApart => l10n.reconReasonOneDay,
    ReconMatchDtoReasonCodesItem.within3Days => l10n.reconReasonThreeDays,
    ReconMatchDtoReasonCodesItem.withinAWeek => l10n.reconReasonWeek,
    ReconMatchDtoReasonCodesItem.sameReference => l10n.reconReasonReference,
    ReconMatchDtoReasonCodesItem.similarDescription =>
      l10n.reconReasonDescription,
    ReconMatchDtoReasonCodesItem.amountsAddUp => l10n.reconReasonAddsUp,
    ReconMatchDtoReasonCodesItem.allWithinAWeek => l10n.reconReasonAllWeek,
    ReconMatchDtoReasonCodesItem.datesFarApart => switch (int.tryParse(
      params['days_apart'] ?? '',
    )) {
      final int days => l10n.reconReasonFarApartDays(days),
      null => l10n.reconReasonFarApart,
    },
    ReconMatchDtoReasonCodesItem.pendingReplacedByPosted =>
      l10n.reconReasonPendingReplaced,
    ReconMatchDtoReasonCodesItem.pendingAmountDiffers =>
      l10n.reconReasonAmountsDiffer(
        amount(params['pending_amount']),
        amount(params['posted_amount']),
      ),
    ReconMatchDtoReasonCodesItem.enteredManuallyAndImported =>
      l10n.reconReasonEnteredTwice,
    ReconMatchDtoReasonCodesItem.unrecognized => null,
  };
}

/// The reasons of a suggestion or match in the user's language: by code
/// ([codes], in the order of the English [reasons]); a code this app does
/// not know falls back to the English reason at the same position.
List<String> reconReasons(
  AppLocalizations l10n, {
  required List<String> codes,
  required List<String> reasons,
  Map<String, String> params = const <String, String>{},
  String Function(String amount, String currency)? money,
}) {
  if (codes.isEmpty) {
    return reasons;
  }
  return <String>[
    for (int i = 0; i < codes.length; i++)
      reconReasonCodeText(l10n, codes[i], params: params, money: money) ??
          (i < reasons.length ? reasons[i] : codes[i].replaceAll('_', ' ')),
  ];
}

/// A 0–1 confidence ("0.950") as a whole percentage (95), for display only.
int? confidencePercent(String? confidence) {
  final double? value = double.tryParse(confidence ?? '');
  if (value == null || value.isNaN) {
    return null;
  }
  return (value.clamp(0, 1) * 100).round();
}

/// The body that confirms [candidate]; for duplicates, [keepTransactionId]
/// is the record to keep (the other one is removed).
ReconMatchInput confirmInput(
  String accountId,
  ReconCandidate candidate, {
  String? keepTransactionId,
}) {
  final List<ReconCandidateItem> items = <ReconCandidateItem>[
    candidate.left,
    ...candidate.right,
  ];
  final List<String> rows = <String>[
    for (final ReconCandidateItem i in items)
      if (i.side == ReconCandidateItemSide.statement && i.importRowId != null)
        i.importRowId!,
  ];
  return ReconMatchInput(
    accountId: accountId,
    kind: ReconMatchInputKind.fromJson(candidate.kind.json),
    statementRowIds: rows.isEmpty ? null : rows,
    transactionIds: <String>[
      for (final ReconCandidateItem i in items)
        if (i.side == ReconCandidateItemSide.ledger && i.transactionId != null)
          i.transactionId!,
    ],
    keepTransactionId: keepTransactionId,
  );
}

/// The body that matches a statement [line] by hand with transactions of
/// the account ([transactionIds]); the amounts must add up (the server
/// checks, `sums_differ`).
ReconMatchInput manualMatchInput(
  String accountId,
  StatementLineDto line,
  List<String> transactionIds,
) => ReconMatchInput(
  accountId: accountId,
  kind: ReconMatchInputKind.statementToLedger,
  statementRowIds: <String>[line.importRowId],
  transactionIds: transactionIds,
);

/// What happened to a statement line on import, in words.
String statementLineStatusLabel(
  AppLocalizations l10n,
  StatementLineDtoRecordStatus status,
) => switch (status) {
  StatementLineDtoRecordStatus.duplicate => l10n.reconLineDuplicate,
  StatementLineDtoRecordStatus.skipped => l10n.reconLineSkipped,
  StatementLineDtoRecordStatus.ready => l10n.reconLineNotImported,
  StatementLineDtoRecordStatus.failed => l10n.reconLineFailed,
  StatementLineDtoRecordStatus.unrecognized => l10n.reconLineNotImported,
};

/// Whether a candidate item is a transaction that came from a statement
/// import (`source`).
bool reconItemImported(ReconCandidateItem item) =>
    item.source == ReconCandidateItemSource.importValue;

/// "On the statement", "Pending", "Imported" or "In Montra" for one side
/// of a suggestion (`record_status` and `source`).
String reconItemRole(AppLocalizations l10n, ReconCandidateItem item) {
  if (item.side == ReconCandidateItemSide.statement) {
    return l10n.reconSideStatement;
  }
  if (item.recordStatus == ReconCandidateItemRecordStatus.pending) {
    return l10n.reconSidePending;
  }
  return reconItemImported(item)
      ? l10n.reconSideImported
      : l10n.reconSideLedger;
}

/// The same for one side of a confirmed match.
String reconMatchItemRole(AppLocalizations l10n, ReconMatchItemDto item) {
  if (item.side == ReconMatchItemDtoSide.statement) {
    return l10n.reconSideStatement;
  }
  if (item.recordStatus == ReconMatchItemDtoRecordStatus.pending) {
    return l10n.reconSidePending;
  }
  return item.source == ReconMatchItemDtoSource.importValue
      ? l10n.reconSideImported
      : l10n.reconSideLedger;
}

/// A decimal [amount] in [currency] (a coded reason's value) in the user's
/// notation; the raw value when it cannot be formatted.
String formatMoneyAmount(
  BuildContext context,
  WidgetRef ref,
  String amount,
  String currency,
) {
  try {
    return MoneyFormatter.formatAmount(
      amount,
      currency,
      locale: numberLocaleOf(context, ref),
    );
  } on FormatException {
    return '$amount $currency';
  }
}
