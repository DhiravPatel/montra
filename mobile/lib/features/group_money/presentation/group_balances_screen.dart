import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';

/// Who owes whom in a group, from the server: each member's paid, share,
/// confirmed settlements and net (removed members keep their balance), the
/// debts as recorded or simplified to the fewest payments, and suggested
/// payments with "Record payment". Montra never moves money.
class GroupBalancesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupBalancesScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  ConsumerState<GroupBalancesScreen> createState() =>
      _GroupBalancesScreenState();
}

class _GroupBalancesScreenState extends ConsumerState<GroupBalancesScreen> {
  bool? _simplified;
  bool _mine = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(groupBalancesProvider(widget.groupId))
      ..invalidate(
        groupSuggestionsProvider((groupId: widget.groupId, mine: _mine)),
      );
    try {
      await ref.read(groupBalancesProvider(widget.groupId).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxBalancesTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<GroupBalancesDto> balances = ref.watch(
          groupBalancesProvider(widget.groupId),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.gxBalancesTitle),
            actions: <Widget>[
              GroupMoneyMenu(
                groupId: widget.groupId,
                current: GroupMoneyPage.balances,
              ),
            ],
          ),
          floatingActionButton: people.canWrite
              ? FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () => context.push(
                    AppRoutes.newGroupSettlement(widget.groupId),
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(l10n.gxRecordPayment),
                )
              : null,
          body: AsyncValueView<GroupBalancesDto>(
            value: balances,
            onRetry: () =>
                ref.invalidate(groupBalancesProvider(widget.groupId)),
            data: (GroupBalancesDto b) => RefreshIndicator(
              onRefresh: _refresh,
              child: _body(context, b, people),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GroupBalancesDto b, GroupPeople people) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final bool simplified = _simplified ?? b.simplifyEnabled;
    final List<GroupTransferDto> debts = simplified
        ? b.simplified
        : b.originalDebts;
    return ScrollableContent(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    l10n.gxYourBalance,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                NetText(b.myNet, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Insets.xs),
                Text(
                  l10n.gxComputedAt(
                    formatDateTime(b.computedAt, locale: locale),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (b.disputedExpenses > 0) ...<Widget>[
          const SizedBox(height: Insets.sm),
          NoticeBanner(
            tone: NoticeTone.warning,
            message: l10n.gxDisputedCount(b.disputedExpenses),
          ),
        ],
        const SizedBox(height: Insets.md),
        _Suggestions(
          groupId: widget.groupId,
          people: people,
          mine: _mine,
          onMine: (bool v) => setState(() => _mine = v),
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxWhoOwesWhom,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: <Widget>[
                  for (final (bool value, String label) in <(bool, String)>[
                    (true, l10n.gxDebtsSimplified),
                    (false, l10n.gxDebtsOriginal),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: simplified == value,
                      onSelected: (_) => setState(() => _simplified = value),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: Text(
                simplified
                    ? l10n.gxDebtsSimplifiedHelp
                    : l10n.gxDebtsOriginalHelp,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (debts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.gxNothingOwed),
              ),
            for (final GroupTransferDto t in debts)
              _TransferTile(
                transfer: t,
                people: people,
                groupId: widget.groupId,
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxMembersSection,
          children: <Widget>[
            for (final GroupMemberBalance m in b.balances)
              _MemberBalanceTile(balance: m, people: people),
          ],
        ),
        const SizedBox(height: Insets.md),
        Text(l10n.gxNoMoneyMoves, style: theme.textTheme.bodySmall),
        const SizedBox(height: 96),
      ],
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({
    required this.groupId,
    required this.people,
    required this.mine,
    required this.onMine,
  });

  final String groupId;
  final GroupPeople people;
  final bool mine;
  final ValueChanged<bool> onMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<GroupSuggestionsDto> s = ref.watch(
      groupSuggestionsProvider((groupId: groupId, mine: mine)),
    );
    final GroupSuggestionsDto? data = s.value;
    return SectionCard(
      title: l10n.gxSuggestionsTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              label: Text(l10n.gxOnlyMine),
              selected: mine,
              onSelected: onMine,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(
            l10n.gxSuggestionsHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (data == null && s.hasError && !s.isLoading)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: TextButton.icon(
              onPressed: () => ref.invalidate(
                groupSuggestionsProvider((groupId: groupId, mine: mine)),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.actionRetry),
            ),
          )
        else if (data == null)
          const Padding(
            padding: EdgeInsets.all(Insets.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data.suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(mine ? l10n.gxNoSuggestionsMine : l10n.gxNothingOwed),
          )
        else
          for (final GroupTransferDto t in data.suggestions)
            _TransferTile(
              transfer: t,
              people: people,
              groupId: groupId,
              offerRecord: true,
            ),
      ],
    );
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({
    required this.transfer,
    required this.people,
    required this.groupId,
    this.offerRecord = false,
  });

  final GroupTransferDto transfer;
  final GroupPeople people;
  final String groupId;
  final bool offerRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final GroupTransferDto t = transfer;
    final String from = people.name(l10n, t.fromUserId, fallback: t.fromName);
    final String to = people.name(l10n, t.toUserId, fallback: t.toName);
    final String amount = formatMoney(context, ref, t.amount);
    return ListTile(
      leading: Icon(t.involvesMe ? Icons.person : Icons.swap_horiz),
      title: Text(l10n.gxPays(from, to)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoneyText(t.amount),
          if (t.involvesMe) Text(l10n.gxInvolvesYou),
        ],
      ),
      trailing: offerRecord && people.canWrite
          ? IconButton(
              tooltip: l10n.gxRecordThisPayment(from, to, amount),
              icon: const Icon(Icons.handshake_outlined),
              onPressed: () => context.push(
                AppRoutes.newGroupSettlement(
                  groupId,
                  payerId: t.fromUserId,
                  payeeId: t.toUserId,
                  amount: t.amount.amount,
                ),
              ),
            )
          : null,
    );
  }
}

class _MemberBalanceTile extends ConsumerWidget {
  const _MemberBalanceTile({required this.balance, required this.people});

  final GroupMemberBalance balance;
  final GroupPeople people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final GroupMemberBalance m = balance;
    final bool you = people.isMe(m.userId);
    final String name = people.name(l10n, m.userId, fallback: m.displayName);
    final String? status = switch (m.memberStatus) {
      GroupMemberBalanceMemberStatus.removed => l10n.gxMemberRemoved,
      GroupMemberBalanceMemberStatus.left => l10n.gxMemberLeft,
      _ => null,
    };
    String money(Money v) => formatMoney(context, ref, v);
    return ExpansionTile(
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NetText(m.net, you: you, name: name),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: StatusLabel(text: status, tone: StatusTone.neutral),
            ),
        ],
      ),
      children: <Widget>[
        DetailRow(label: l10n.gxBalancePaid, value: money(m.paid)),
        DetailRow(label: l10n.gxBalanceShare, value: money(m.share)),
        DetailRow(label: l10n.gxBalanceSent, value: money(m.settlementsSent)),
        DetailRow(
          label: l10n.gxBalanceReceived,
          value: money(m.settlementsReceived),
        ),
        if (m.pendingOut.amountMinor != 0)
          DetailRow(
            label: l10n.gxBalancePendingOut,
            value: money(m.pendingOut),
          ),
        if (m.pendingIn.amountMinor != 0)
          DetailRow(label: l10n.gxBalancePendingIn, value: money(m.pendingIn)),
        if (status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.sm,
            ),
            child: Text(
              l10n.gxFormerBalanceNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
