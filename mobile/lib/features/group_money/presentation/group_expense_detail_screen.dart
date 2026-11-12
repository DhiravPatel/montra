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
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// One shared expense: amount (and the original currency with the rate
/// the server used), who paid, each person's share as the server computed
/// it, items, the receipt, the caller's own account record, disputes and
/// comments. Members can edit; the creator or an admin can delete.
class GroupExpenseDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupExpenseDetailScreen({
    required this.groupId,
    required this.expenseId,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The expense.
  final String expenseId;

  @override
  ConsumerState<GroupExpenseDetailScreen> createState() =>
      _GroupExpenseDetailScreenState();
}

class _GroupExpenseDetailScreenState
    extends ConsumerState<GroupExpenseDetailScreen> {
  final TextEditingController _comment = TextEditingController();
  bool _busy = false;

  GroupRecord get _record => (groupId: widget.groupId, id: widget.expenseId);
  GroupMoneyApi get _api => ref.read(groupMoneyApiProvider);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<bool> _guard(
    Future<void> Function() action, {
    required String done,
  }) async {
    if (_busy) {
      return false;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return true;
      }
      groupMoneyChanged(ref, widget.groupId);
      showSnack(context, done);
      return true;
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.conflict ||
          error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(groupExpenseProvider(_record));
      }
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(GroupExpenseDetail e) async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.gxDeleteTitle,
      body: l10n.gxDeleteBody(e.description),
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    final bool done = await _guard(
      () => _api.deleteExpense(widget.groupId, e.id),
      done: l10n.gxExpenseDeleted,
    );
    if (done && mounted) {
      leaveTo(router, AppRoutes.groupExpenses(widget.groupId));
    }
  }

  Future<void> _dispute(GroupExpenseDetail e) async {
    final AppLocalizations l10n = context.l10n;
    final String? reason = await askGroupMoneyText(
      context,
      title: l10n.gxDisputeTitle,
      body: l10n.gxDisputeBody,
      label: l10n.gxDisputeReason,
      confirm: l10n.gxDisputeSend,
      maxLength: GroupDisputeInput.reasonMaxLength,
    );
    if (reason == null || !mounted) {
      return;
    }
    await _guard(
      () => _api.dispute(widget.groupId, e.id, reason),
      done: l10n.gxDisputeSent,
    );
  }

  Future<void> _resolve(GroupDisputeDto d, {required bool withdraw}) async {
    final AppLocalizations l10n = context.l10n;
    if (withdraw) {
      final bool ok = await showConfirmDialog(
        context,
        title: l10n.gxWithdrawTitle,
        body: l10n.gxWithdrawBody,
        confirmLabel: l10n.gxWithdraw,
      );
      if (!ok || !mounted) {
        return;
      }
      await _guard(
        () => _api.resolveDispute(widget.groupId, d.id, withdraw: true),
        done: l10n.gxWithdrawn,
      );
      return;
    }
    final String? resolution = await askGroupMoneyText(
      context,
      title: l10n.gxResolveTitle,
      body: l10n.gxResolveBody,
      label: l10n.gxResolution,
      confirm: l10n.gxResolve,
      maxLength: ResolveDisputeInput.resolutionMaxLength,
    );
    if (resolution == null || !mounted) {
      return;
    }
    await _guard(
      () => _api.resolveDispute(widget.groupId, d.id, resolution: resolution),
      done: l10n.gxResolved,
    );
  }

  Future<void> _sendComment(GroupExpenseDetail e) async {
    final AppLocalizations l10n = context.l10n;
    final String text = _comment.text.trim();
    if (text.isEmpty) {
      return;
    }
    final bool done = await _guard(
      () => _api.comment(widget.groupId, e.id, text),
      done: l10n.gxCommentSent,
    );
    if (done) {
      _comment.clear();
    }
  }

  Future<void> _link(GroupExpenseDetail e, String currency) async {
    final AppLocalizations l10n = context.l10n;
    final AccountDto? account = await showAccountPicker(
      context,
      currency: currency,
      title: l10n.gxRecordInAccount,
    );
    if (account == null || !mounted) {
      return;
    }
    await _guard(
      () => _api.myRecord(widget.groupId, e.id, accountId: account.id),
      done: l10n.gxRecorded,
    );
  }

  Future<void> _unlink(GroupExpenseDetail e) async {
    final AppLocalizations l10n = context.l10n;
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.gxUnlinkTitle,
      body: l10n.gxUnlinkBody,
      confirmLabel: l10n.gxUnlink,
    );
    if (!ok || !mounted) {
      return;
    }
    await _guard(
      () => _api.myRecord(widget.groupId, e.id),
      done: l10n.gxUnlinked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxExpenseTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<GroupExpenseDetail> expense = ref.watch(
          groupExpenseProvider(_record),
        );
        final GroupExpenseDetail? loaded = expense.value;
        return Scaffold(
          appBar: AppBar(
            title: Text(loaded?.description ?? l10n.gxExpenseTitle),
            bottom: _busy || (expense.isLoading && expense.hasValue)
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
            actions: <Widget>[
              if (loaded != null && canEditExpense(loaded, people))
                IconButton(
                  tooltip: l10n.actionEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy
                      ? null
                      : () => context.push(
                          AppRoutes.editGroupExpense(widget.groupId, loaded.id),
                        ),
                ),
              if (loaded != null && canDeleteExpense(loaded, people))
                IconButton(
                  tooltip: l10n.actionDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : () => _delete(loaded),
                ),
            ],
          ),
          body: AsyncValueView<GroupExpenseDetail>(
            value: expense,
            onRetry: () => ref.invalidate(groupExpenseProvider(_record)),
            data: (GroupExpenseDetail e) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(groupExpenseProvider(_record));
                try {
                  await ref.read(groupExpenseProvider(_record).future);
                } on Object {
                  // Shown by the screen state.
                }
              },
              child: _body(context, e, people),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GroupExpenseDetail e, GroupPeople people) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final (String statusText, StatusTone tone) = expenseStatusLabel(
      l10n,
      GroupExpenseDtoStatus.fromJson(e.status.json),
    );
    final bool deleted = e.status == GroupExpenseDetailStatus.deleted;
    final Money? original = e.originalAmount;
    final String? transactionId = e.myTransactionId;
    final String? receipt = e.receiptFileId;
    final List<GroupDisputeDto> open = e.disputes
        .where((GroupDisputeDto d) => d.status == GroupDisputeDtoStatus.open)
        .toList();
    return ScrollableContent(
      children: <Widget>[
        MoneyText(e.amount, style: theme.textTheme.headlineMedium),
        const SizedBox(height: Insets.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusLabel(text: statusText, tone: tone),
        ),
        if (deleted) ...<Widget>[
          const SizedBox(height: Insets.sm),
          NoticeBanner(message: l10n.gxDeletedNotice),
        ],
        if (open.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.sm),
          NoticeBanner(
            tone: NoticeTone.warning,
            message: l10n.gxDisputedNotice,
          ),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          children: <Widget>[
            DetailRow(
              label: l10n.dateLabel,
              value: LocalDates.display(e.expenseDate, locale: locale),
            ),
            DetailRow(
              label: l10n.categoryFieldLabel,
              value: groupCategoryLabel(l10n, e.categoryKey),
            ),
            DetailRow(
              label: l10n.gxSplitSection,
              value: splitMethodLabel(l10n, e.splitMethod),
            ),
            DetailRow(
              label: l10n.gxYourShare,
              semanticsValue: formatMoney(context, ref, e.myShare),
              child: MoneyText(e.myShare),
            ),
            DetailRow(
              label: l10n.gxYouPaid,
              semanticsValue: formatMoney(context, ref, e.myPaid),
              child: MoneyText(e.myPaid),
            ),
            if (e.revisions > 1)
              DetailRow(
                label: l10n.gxHistory,
                value: l10n.gxEditedTimes(e.revisions - 1),
              ),
            if (e.notes case final String notes when notes.isNotEmpty)
              DetailRow(label: l10n.notesLabel, value: notes),
          ],
        ),
        if (original != null) ...<Widget>[
          const SizedBox(height: Insets.md),
          SectionCard(
            title: l10n.gxForeignTitle,
            children: <Widget>[
              DetailRow(
                label: l10n.gxOriginalAmount,
                semanticsValue: formatMoney(context, ref, original),
                child: MoneyText(original),
              ),
              if (e.fxRate case final String rate)
                DetailRow(
                  label: l10n.gxRateUsed,
                  value: l10n.gxRateValue(
                    original.currency,
                    rate,
                    e.amount.currency,
                  ),
                ),
              DetailRow(
                label: l10n.gxRateSource,
                value: fxSourceLabel(l10n, e.fxRateSource?.json),
              ),
              if (e.fxRateAt case final DateTime at)
                DetailRow(
                  label: l10n.gxRateTime,
                  value: formatDateTime(at, locale: locale),
                ),
              DetailRow(
                label: l10n.gxConverted,
                semanticsValue: formatMoney(context, ref, e.amount),
                child: MoneyText(e.amount),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxPaidBySection,
          children: <Widget>[
            for (final ExpensePayerDto p in e.payers)
              DetailRow(
                label: people.name(l10n, p.userId),
                semanticsValue: formatMoney(context, ref, p.paid),
                child: MoneyText(p.paid),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxSharesSection,
          children: <Widget>[
            for (final ExpenseShareDto s in e.shares)
              DetailRow(
                label: <String>[
                  people.name(l10n, s.userId),
                  ?splitValueText(l10n, e.splitMethod, s.inputValue),
                ].join(' · '),
                semanticsValue: formatMoney(context, ref, s.share),
                child: MoneyText(s.share),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(
                l10n.gxSharesByServer,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (e.items.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.md),
          SectionCard(
            title: l10n.gxItemsSection,
            children: <Widget>[
              for (final ExpenseItemDto item in e.items) ...<Widget>[
                DetailRow(
                  label: item.description,
                  semanticsValue: formatMoney(context, ref, item.amount),
                  child: MoneyText(item.amount),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    0,
                    Insets.md,
                    Insets.sm,
                  ),
                  child: Text(
                    item.shares
                        .map(
                          (ExpenseShareDto s) =>
                              '${people.name(l10n, s.userId)} '
                              '${formatMoney(context, ref, s.share)}',
                        )
                        .join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (receipt != null) ...<Widget>[
          const SizedBox(height: Insets.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(l10n.gxReceipt),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openPrivateFile(
                context,
                fileId: receipt,
                name: l10n.gxReceipt,
              ),
            ),
          ),
        ],
        const SizedBox(height: Insets.md),
        _myRecordCard(context, e, people, transactionId),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxDisputesSection,
          children: <Widget>[
            if (e.disputes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: Text(l10n.gxNoDisputes),
              ),
            for (final GroupDisputeDto d in e.disputes)
              _DisputeTile(
                dispute: d,
                people: people,
                busy: _busy,
                onWithdraw: () => _resolve(d, withdraw: true),
                onResolve: () => _resolve(d, withdraw: false),
              ),
            if (!deleted && people.canWrite)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _dispute(e),
                  icon: const Icon(Icons.report_outlined),
                  label: Text(l10n.gxDispute),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxCommentsSection,
          children: <Widget>[
            if (e.comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: Text(l10n.gxNoComments),
              ),
            for (final GroupCommentDto c in e.comments)
              ListTile(
                title: Text(c.body),
                subtitle: Text(
                  '${people.name(l10n, c.authorId)} · '
                  '${formatDateTime(c.createdAt, locale: locale)}',
                ),
              ),
            if (people.canWrite && !deleted)
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    TextField(
                      controller: _comment,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: GroupCommentInput.bodyMaxLength,
                      decoration: InputDecoration(
                        labelText: l10n.gxCommentLabel,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _sendComment(e),
                      icon: const Icon(Icons.send),
                      label: Text(l10n.gxCommentSend),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }

  Widget _myRecordCard(
    BuildContext context,
    GroupExpenseDetail e,
    GroupPeople people,
    String? transactionId,
  ) {
    final AppLocalizations l10n = context.l10n;
    if (transactionId != null) {
      return Card(
        child: Column(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l10n.gxRecordedInAccount),
              subtitle: Text(l10n.gxRecordedInAccountHelp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push(AppRoutes.transactionDetail(transactionId)),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _busy ? null : () => _unlink(e),
                child: Text(l10n.gxUnlink),
              ),
            ),
          ],
        ),
      );
    }
    if (e.status == GroupExpenseDetailStatus.deleted || !isPayer(e, people)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(l10n.gxRecordInAccount),
        subtitle: Text(l10n.gxRecordInAccountHelp),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : () => _link(e, people.currency),
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  const _DisputeTile({
    required this.dispute,
    required this.people,
    required this.busy,
    required this.onWithdraw,
    required this.onResolve,
  });

  final GroupDisputeDto dispute;
  final GroupPeople people;
  final bool busy;
  final VoidCallback onWithdraw;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final GroupDisputeDto d = dispute;
    final bool open = d.status == GroupDisputeDtoStatus.open;
    final bool mine = people.isMe(d.raisedBy);
    final String status = switch (d.status) {
      GroupDisputeDtoStatus.open => l10n.gxDisputeOpen,
      GroupDisputeDtoStatus.resolved => l10n.gxDisputeResolved,
      GroupDisputeDtoStatus.withdrawn => l10n.gxDisputeWithdrawn,
      GroupDisputeDtoStatus.unrecognized => l10n.gxStatusOther,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatusLabel(
            text: status,
            tone: open ? StatusTone.caution : StatusTone.neutral,
          ),
          const SizedBox(height: Insets.xs),
          Text(d.reason),
          Text(
            l10n.gxRaisedBy(people.name(l10n, d.raisedBy)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (d.resolution case final String r when r.isNotEmpty)
            Text(
              l10n.gxResolutionText(r),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (open && people.canWrite)
            Wrap(
              spacing: Insets.sm,
              children: <Widget>[
                if (mine)
                  TextButton(
                    onPressed: busy ? null : onWithdraw,
                    child: Text(l10n.gxWithdraw),
                  ),
                if (people.isAdmin)
                  TextButton(
                    onPressed: busy ? null : onResolve,
                    child: Text(l10n.gxResolve),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A dialog asking for one required text (a reason or a resolution).
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.confirm,
    this.body,
    this.maxLength,
  });

  final String title;
  final String label;
  final String confirm;
  final String? body;
  final int? maxLength;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final TextEditingController _text = TextEditingController();
  bool _empty = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.body != null) ...<Widget>[
              Text(widget.body!),
              const SizedBox(height: Insets.sm),
            ],
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: widget.maxLength,
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: _empty ? l10n.validationRequired : null,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final String v = _text.text.trim();
            if (v.isEmpty) {
              setState(() => _empty = true);
              return;
            }
            Navigator.of(context).pop(v);
          },
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// Asks for one required text; returns it, or null when cancelled.
Future<String?> askGroupMoneyText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  String? body,
  int? maxLength,
}) => showDialog<String>(
  context: context,
  builder: (BuildContext dialogContext) => _TextDialog(
    title: title,
    label: label,
    confirm: confirm,
    body: body,
    maxLength: maxLength,
  ),
);
