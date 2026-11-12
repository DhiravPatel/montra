import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_expense_detail_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_paths.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// One settlement with its lifecycle: the payer marks a planned payment
/// paid, the payee confirms it (an admin confirms for a former member),
/// either side disputes or voids it with a reason, it can be corrected, and
/// each side can record it in their own account. Every action sends the
/// displayed `version`; a change made elsewhere reloads it.
class SettlementDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SettlementDetailScreen({
    required this.groupId,
    required this.settlementId,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The settlement.
  final String settlementId;

  @override
  ConsumerState<SettlementDetailScreen> createState() =>
      _SettlementDetailScreenState();
}

class _SettlementDetailScreenState
    extends ConsumerState<SettlementDetailScreen> {
  bool _busy = false;

  GroupRecord get _record => (groupId: widget.groupId, id: widget.settlementId);

  Future<void> _act(
    SettlementDto s,
    SettlementAction action,
    GroupPeople people,
  ) async {
    final AppLocalizations l10n = context.l10n;
    String? reason;
    String? accountId;
    switch (action) {
      case SettlementAction.dispute:
      case SettlementAction.voidIt:
        reason = await askGroupMoneyText(
          context,
          title: action == SettlementAction.dispute
              ? l10n.gxSettlementDisputeTitle
              : l10n.gxSettlementVoidTitle,
          body: action == SettlementAction.dispute
              ? l10n.gxSettlementDisputeBody
              : l10n.gxSettlementVoidBody,
          label: l10n.gxReasonLabel,
          confirm: action == SettlementAction.dispute
              ? l10n.gxSettlementDispute
              : l10n.gxSettlementVoid,
          maxLength: SettlementActionBody.reasonMaxLength,
        );
        if (reason == null) {
          return;
        }
      case SettlementAction.record:
        final AccountDto? account = await showAccountPicker(
          context,
          currency: people.currency,
          title: l10n.gxRecordInAccount,
        );
        if (account == null) {
          return;
        }
        accountId = account.id;
      case SettlementAction.confirm:
        final bool self = people.isMe(s.payeeUserId);
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.gxConfirmTitle,
          body: self
              ? l10n.gxConfirmBody(formatMoney(context, ref, s.amount))
              : l10n.gxConfirmOnBehalfBody,
          confirmLabel: l10n.gxSettlementConfirm,
        );
        if (!ok) {
          return;
        }
      case SettlementAction.markPaid:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.gxMarkPaidTitle,
          body: l10n.gxMarkPaidBody,
          confirmLabel: l10n.gxSettlementMarkPaid,
        );
        if (!ok) {
          return;
        }
      case SettlementAction.unlink:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.gxUnlinkTitle,
          body: l10n.gxUnlinkSettlementBody,
          confirmLabel: l10n.gxUnlink,
        );
        if (!ok) {
          return;
        }
    }
    if (!mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(groupMoneyApiProvider)
          .settlementAction(
            widget.groupId,
            s.id,
            action,
            version: s.version,
            accountId: accountId,
            reason: reason,
          );
      if (!mounted) {
        return;
      }
      groupMoneyChanged(ref, widget.groupId);
      showSnack(context, _done(l10n, action));
    } on ApiException catch (error) {
      final bool conflict = error.code == ErrorObjectCode.versionConflict;
      if (conflict || error.code == ErrorObjectCode.conflict) {
        ref.invalidate(groupSettlementProvider(_record));
      }
      if (mounted) {
        showSnack(
          context,
          conflict ? l10n.versionConflictReloaded : describeError(l10n, error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  static String _done(AppLocalizations l10n, SettlementAction a) => switch (a) {
    SettlementAction.markPaid => l10n.gxMarkedPaid,
    SettlementAction.confirm => l10n.gxConfirmed,
    SettlementAction.dispute => l10n.gxDisputed,
    SettlementAction.voidIt => l10n.gxVoided,
    SettlementAction.record => l10n.gxRecorded,
    SettlementAction.unlink => l10n.gxUnlinked,
  };

  static String _label(AppLocalizations l10n, SettlementAction a) =>
      switch (a) {
        SettlementAction.markPaid => l10n.gxSettlementMarkPaid,
        SettlementAction.confirm => l10n.gxSettlementConfirm,
        SettlementAction.dispute => l10n.gxSettlementDispute,
        SettlementAction.voidIt => l10n.gxSettlementVoid,
        SettlementAction.record => l10n.gxRecordInAccount,
        SettlementAction.unlink => l10n.gxUnlink,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxSettlementTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<SettlementDto> s = ref.watch(
          groupSettlementProvider(_record),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.gxSettlementTitle),
            bottom: _busy || (s.isLoading && s.hasValue)
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: AsyncValueView<SettlementDto>(
            value: s,
            onRetry: () => ref.invalidate(groupSettlementProvider(_record)),
            data: (SettlementDto settlement) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(groupSettlementProvider(_record));
                try {
                  await ref.read(groupSettlementProvider(_record).future);
                } on Object {
                  // Shown by the screen state.
                }
              },
              child: _body(context, settlement, people),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, SettlementDto s, GroupPeople people) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final (String status, StatusTone tone, IconData _) = settlementStatusLabel(
      l10n,
      s.status,
    );
    final String from = people.name(l10n, s.payerUserId, fallback: s.payerName);
    final String to = people.name(l10n, s.payeeUserId, fallback: s.payeeName);
    final List<SettlementAction> actions = people.canWrite
        ? settlementActionsFor(s, people)
        : <SettlementAction>[
            if (s.myTransactionId != null) SettlementAction.unlink,
          ];
    final String? proof = s.receiptFileId;
    final String? transactionId = s.myTransactionId;
    return ScrollableContent(
      children: <Widget>[
        Text(l10n.gxPaid(from, to), style: theme.textTheme.titleLarge),
        const SizedBox(height: Insets.xs),
        MoneyText(s.amount, style: theme.textTheme.headlineMedium),
        const SizedBox(height: Insets.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusLabel(text: status, tone: tone),
        ),
        const SizedBox(height: Insets.sm),
        Text(_statusHelp(l10n, s), style: theme.textTheme.bodyMedium),
        const SizedBox(height: Insets.md),
        SectionCard(
          children: <Widget>[
            DetailRow(
              label: l10n.dateLabel,
              value: LocalDates.display(s.settledOn, locale: locale),
            ),
            DetailRow(
              label: l10n.gxMethodLabel,
              value: settlementMethodLabel(l10n, s.method.json),
            ),
            DetailRow(
              label: l10n.gxVerification,
              value:
                  s.verification == SettlementDtoVerification.providerVerified
                  ? l10n.gxVerifiedByProvider
                  : l10n.gxReportedByMembers,
            ),
            DetailRow(
              label: l10n.gxCounts,
              value: s.counted ? l10n.gxCountsYes : l10n.gxCountsNo,
            ),
            if (s.proposedBy case final String by)
              DetailRow(label: l10n.gxRecordedBy, value: people.name(l10n, by)),
            if (s.confirmedAt case final DateTime at)
              DetailRow(
                label: l10n.gxConfirmedBy,
                value:
                    '${people.name(l10n, s.confirmedBy)} · '
                    '${formatDateTime(at, locale: locale)}',
              ),
            if (s.note case final String note when note.isNotEmpty)
              DetailRow(label: l10n.notesLabel, value: note),
            if (s.disputeReason case final String r when r.isNotEmpty)
              DetailRow(label: l10n.gxDisputeReasonLabel, value: r),
            if (s.voidReason case final String r when r.isNotEmpty)
              DetailRow(
                label: l10n.gxVoidReasonLabel,
                value: '$r · ${people.name(l10n, s.voidedBy)}',
              ),
          ],
        ),
        if (s.correctsSettlementId case final String id) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.gxCorrectsOriginal),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                AppRoutes.groupSettlementDetail(widget.groupId, id),
              ),
            ),
          ),
        ],
        if (s.correctedBySettlementId case final String id) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.update),
              title: Text(l10n.gxCorrectedBy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                AppRoutes.groupSettlementDetail(widget.groupId, id),
              ),
            ),
          ),
        ],
        if (proof != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(l10n.gxProof),
              trailing: const Icon(Icons.open_in_new),
              onTap: () =>
                  openPrivateFile(context, fileId: proof, name: l10n.gxProof),
            ),
          ),
        ],
        if (transactionId != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l10n.gxRecordedInAccount),
              subtitle: Text(l10n.gxSettlementRecordedHelp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push(AppRoutes.transactionDetail(transactionId)),
            ),
          ),
        ],
        const SizedBox(height: Insets.md),
        if (actions.isNotEmpty || canCorrectSettlement(s, people))
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              for (final SettlementAction a in actions)
                a == SettlementAction.voidIt
                    ? OutlinedButton(
                        onPressed: _busy ? null : () => _act(s, a, people),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        child: Text(_label(l10n, a)),
                      )
                    : FilledButton.tonal(
                        onPressed: _busy ? null : () => _act(s, a, people),
                        child: Text(_label(l10n, a)),
                      ),
              if (people.canWrite && canCorrectSettlement(s, people))
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => context.push(
                          GroupMoneyPaths.correctSettlement(
                            widget.groupId,
                            s.id,
                          ),
                        ),
                  child: Text(l10n.gxCorrect),
                ),
            ],
          ),
        const SizedBox(height: Insets.md),
        NoticeBanner(message: l10n.gxNoMoneyMoves),
        const SizedBox(height: Insets.lg),
      ],
    );
  }

  String _statusHelp(AppLocalizations l10n, SettlementDto s) =>
      switch (s.status) {
        SettlementDtoStatus.proposed => l10n.gxProposedStatusHelp,
        SettlementDtoStatus.userReportedPaid => l10n.gxReportedStatusHelp,
        SettlementDtoStatus.confirmed => l10n.gxConfirmedStatusHelp,
        SettlementDtoStatus.disputed => l10n.gxDisputedStatusHelp,
        SettlementDtoStatus.voided => l10n.gxVoidedStatusHelp,
        SettlementDtoStatus.unrecognized => '',
      };
}
