import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// Loads the people of [groupId] (members, roles, currency) and builds
/// [builder] with them; loading and error states fill [title]'s page.
class GroupPeopleScope extends ConsumerWidget {
  /// Creates the scope.
  const GroupPeopleScope({
    required this.groupId,
    required this.title,
    required this.builder,
    super.key,
  });

  /// The group.
  final String groupId;

  /// App bar title while the group loads.
  final String title;

  /// Builds the page once the group is known.
  final Widget Function(BuildContext context, GroupPeople people) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GroupPeople> people = ref.watch(
      groupPeopleProvider(groupId),
    );
    final GroupPeople? loaded = people.value;
    if (loaded != null) {
      return builder(context, loaded);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: people.hasError && !people.isLoading
          ? ErrorStateView(
              error: people.error!,
              onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
            )
          : const LoadingStateView(),
    );
  }
}

/// Links between the group money screens of [groupId], for app bars.
class GroupMoneyMenu extends StatelessWidget {
  /// Creates the menu; [current] is left out.
  const GroupMoneyMenu({
    required this.groupId,
    required this.current,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The screen showing the menu.
  final GroupMoneyPage current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PopupMenuButton<GroupMoneyPage>(
      tooltip: l10n.gxMoreScreens,
      onSelected: (GroupMoneyPage page) => context.push(page.location(groupId)),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<GroupMoneyPage>>[
        for (final GroupMoneyPage page in GroupMoneyPage.values)
          if (page != current)
            PopupMenuItem<GroupMoneyPage>(
              value: page,
              child: Text(page.label(l10n)),
            ),
      ],
    );
  }
}

/// The group money screens.
enum GroupMoneyPage {
  /// The expense list.
  expenses,

  /// Balances and suggestions.
  balances,

  /// Settlements.
  settlements,

  /// Recurring shared expenses.
  recurring,

  /// Reports and the CSV export.
  reports;

  /// The screen's location for [groupId].
  String location(String groupId) => switch (this) {
    GroupMoneyPage.expenses => AppRoutes.groupExpenses(groupId),
    GroupMoneyPage.balances => AppRoutes.groupBalances(groupId),
    GroupMoneyPage.settlements => AppRoutes.groupSettlements(groupId),
    GroupMoneyPage.recurring => AppRoutes.groupRecurring(groupId),
    GroupMoneyPage.reports => AppRoutes.groupReports(groupId),
  };

  /// The screen's name.
  String label(AppLocalizations l10n) => switch (this) {
    GroupMoneyPage.expenses => l10n.gxExpensesTitle,
    GroupMoneyPage.balances => l10n.gxBalancesTitle,
    GroupMoneyPage.settlements => l10n.gxSettlementsTitle,
    GroupMoneyPage.recurring => l10n.gxRecurringTitle,
    GroupMoneyPage.reports => l10n.gxReportsTitle,
  };
}

/// A member row: avatar, name (or "You") and an optional status word for
/// people who left or were removed.
class MemberLabel extends StatelessWidget {
  /// Creates the label.
  const MemberLabel({
    required this.people,
    required this.userId,
    this.fallbackName,
    super.key,
  });

  /// The group's people.
  final GroupPeople people;

  /// The member.
  final String? userId;

  /// A name the record itself carries (e.g. `payer_name`).
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String name = people.name(l10n, userId, fallback: fallbackName);
    final GroupMemberDto? m = people.member(userId);
    final String? status = switch (m?.status) {
      GroupMemberDtoStatus.left => l10n.gxMemberLeft,
      GroupMemberDtoStatus.removed => l10n.gxMemberRemoved,
      _ => null,
    };
    return Text(status == null ? name : '$name · $status');
  }
}

/// "You are owed ₹…", "You owe ₹…" or "All settled" for [net] (positive:
/// is owed), spelled out so the meaning never depends on color.
String netSentence(
  AppLocalizations l10n,
  Money net,
  String formatted, {
  required bool you,
  String? name,
}) => switch (netDirection(net)) {
  NetDirection.owed =>
    you ? l10n.gxYouAreOwed(formatted) : l10n.gxIsOwed(name ?? '', formatted),
  NetDirection.owes =>
    you ? l10n.gxYouOwe(formatted) : l10n.gxOwes(name ?? '', formatted),
  NetDirection.settled => you ? l10n.gxYouSettled : l10n.gxSettled(name ?? ''),
};

/// A net balance as a sentence with the absolute amount.
class NetText extends ConsumerWidget {
  /// Creates the text.
  const NetText(this.net, {this.you = true, this.name, this.style, super.key});

  /// The balance (positive: is owed).
  final Money net;

  /// Whether it is the caller's balance.
  final bool you;

  /// The member's name when not [you].
  final String? name;

  /// Text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String formatted = formatMoney(context, ref, absMoney(net));
    return Text(
      netSentence(l10n, net, formatted, you: you, name: name),
      style: style,
    );
  }
}

/// One editable participant of a split.
class SplitRowState {
  /// Creates the row for [userId].
  SplitRowState(this.userId, {this.included = true, String value = ''})
    : value = TextEditingController(text: value);

  /// The member.
  final String userId;

  /// Whether the member shares the expense.
  bool included;

  /// The member's value: an amount (exact), a percentage or shares.
  final TextEditingController value;

  /// Frees the controller.
  void dispose() => value.dispose();
}

/// Who shares an expense and, for exact, percentage and shares splits,
/// each person's value. Only current members are listed; the server checks
/// the split and the form shows its answer. The preview line under the
/// list is guidance only.
class SplitEditor extends ConsumerWidget {
  /// Creates the editor.
  const SplitEditor({
    required this.people,
    required this.method,
    required this.rows,
    required this.onChanged,
    this.amountText,
    this.currency,
    this.fieldErrors = const <String, String>{},
    this.errorText,
    super.key,
  });

  /// The group's people.
  final GroupPeople people;

  /// The split method (wire value).
  final String method;

  /// One row per current member.
  final List<SplitRowState> rows;

  /// Called after any change.
  final VoidCallback onChanged;

  /// The total as typed (for the exact-split preview), if known.
  final String? amountText;

  /// The currency of exact amounts (the group's).
  final String? currency;

  /// Errors per member ID.
  final Map<String, String> fieldErrors;

  /// An error for the whole split.
  final String? errorText;

  bool get _hasValue =>
      method == 'exact' || method == 'percentage' || method == 'shares';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? preview = _preview(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final SplitRowState row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.xs),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: row.included,
                    title: Text(people.name(l10n, row.userId)),
                    onChanged: (bool? v) {
                      row.included = v ?? false;
                      onChanged();
                    },
                  ),
                ),
                if (_hasValue && row.included)
                  SizedBox(width: 200, child: _valueField(context, l10n, row)),
              ],
            ),
          ),
        if (preview != null)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.gxPreview(preview),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _valueField(
    BuildContext context,
    AppLocalizations l10n,
    SplitRowState row,
  ) {
    final String name = people.name(l10n, row.userId);
    final String? error = fieldErrors[row.userId];
    if (method == 'exact') {
      return AmountField(
        controller: row.value,
        label: l10n.gxValueAmountFor(name),
        currency: currency,
        allowZero: true,
        errorText: error,
        onChanged: (_) => onChanged(),
      );
    }
    final bool percent = method == 'percentage';
    return TextFormField(
      controller: row.value,
      keyboardType: TextInputType.numberWithOptions(decimal: percent),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          percent ? RegExp(r'[0-9.,]') : RegExp('[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: percent
            ? l10n.gxValuePercentFor(name)
            : l10n.gxValueSharesFor(name),
        suffixText: percent ? '%' : null,
        errorText: error,
      ),
      onChanged: (_) => onChanged(),
      validator: (String? v) {
        final String text = (v ?? '').trim();
        if (text.isEmpty) {
          return l10n.validationRequired;
        }
        if (percent) {
          final int? h = hundredthsOfPercent(text);
          return h == null || h > 10000 ? l10n.gxPercentInvalid : null;
        }
        return isWholeShares(text) ? null : l10n.gxSharesInvalid;
      },
    );
  }

  String? _preview(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<SplitRowState> included = rows
        .where((SplitRowState r) => r.included)
        .toList();
    switch (method) {
      case 'equal':
      case 'itemized':
        return l10n.gxPreviewPeople(included.length);
      case 'percentage':
        int total = 0;
        for (final SplitRowState r in included) {
          total += hundredthsOfPercent(r.value.text) ?? 0;
        }
        final String shown = (total / 100).toStringAsFixed(
          total % 100 == 0 ? 0 : 2,
        );
        return total == 10000
            ? l10n.gxPreviewPercentOk
            : l10n.gxPreviewPercentTotal(shown);
      case 'shares':
        int total = 0;
        for (final SplitRowState r in included) {
          total += int.tryParse(r.value.text.trim()) ?? 0;
        }
        return l10n.gxPreviewShares(total);
      case 'exact':
        final String? code = currency;
        if (code == null) {
          return null;
        }
        final int exponent = exponentFor(code);
        final String locale = numberLocaleOf(context, ref);
        int assigned = 0;
        for (final SplitRowState r in included) {
          final String? v = readAmount(
            context,
            ref,
            r.value.text,
            currency: code,
            allowZero: true,
          ).value;
          assigned += v == null ? 0 : (minorOf(v, exponent) ?? 0);
        }
        final String assignedText = formatMoneyText(
          moneyOfMinor(assigned, code),
          locale,
        );
        final String? totalValue = amountText == null
            ? null
            : readAmount(context, ref, amountText!, currency: code).value;
        final int? total = totalValue == null
            ? null
            : minorOf(totalValue, exponent);
        if (total == null) {
          return l10n.gxPreviewAssigned(assignedText);
        }
        final int left = total - assigned;
        if (left == 0) {
          return l10n.gxPreviewExactOk;
        }
        final String diff = formatMoneyText(
          moneyOfMinor(left.abs(), code),
          locale,
        );
        return left > 0
            ? l10n.gxPreviewLeft(assignedText, diff)
            : l10n.gxPreviewTooMuch(assignedText, diff);
    }
    return null;
  }
}

/// Picks one member of a group (current members by default, everyone with
/// [includeFormer]). Returns the user ID or null when dismissed.
Future<String?> showMemberPicker(
  BuildContext context, {
  required GroupPeople people,
  required String title,
  bool includeFormer = false,
  Set<String> exclude = const <String>{},
}) {
  final AppLocalizations l10n = context.l10n;
  final List<GroupMemberDto> members = includeFormer
      ? people.everyone
      : people.activeMembers;
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                title,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
          ),
          for (final GroupMemberDto m in members)
            if (!exclude.contains(m.userId))
              ListTile(
                leading: InitialsAvatar(name: m.displayName),
                title: MemberLabel(people: people, userId: m.userId),
                onTap: () => Navigator.of(sheetContext).pop(m.userId),
              ),
          const SizedBox(height: Insets.md),
          if (members.every((GroupMemberDto m) => exclude.contains(m.userId)))
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(l10n.gxNoOneToPick),
            ),
        ],
      ),
    ),
  );
}

/// A tile that opens an expense of a group.
class ExpenseSummaryTile extends ConsumerWidget {
  /// Creates the tile.
  const ExpenseSummaryTile({
    required this.expense,
    required this.people,
    super.key,
  });

  /// The expense.
  final GroupExpenseDto expense;

  /// The group's people.
  final GroupPeople people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final GroupExpenseDto e = expense;
    final (String statusText, _) = expenseStatusLabel(l10n, e.status);
    final Money? original = e.originalAmount;
    final List<String> lines = <String>[
      l10n.gxExpenseLine(
        localDate(e.expenseDate, locale),
        groupCategoryLabel(l10n, e.categoryKey),
      ),
      l10n.gxYouPaidShare(
        formatMoney(context, ref, e.myPaid),
        formatMoney(context, ref, e.myShare),
      ),
      if (original != null)
        l10n.gxPaidInOriginal(formatMoney(context, ref, original)),
      if (e.status != GroupExpenseDtoStatus.active) statusText,
    ];
    return ListTile(
      leading: Icon(
        e.status == GroupExpenseDtoStatus.disputed
            ? Icons.report_outlined
            : e.status == GroupExpenseDtoStatus.deleted
            ? Icons.delete_outline
            : Icons.receipt_long_outlined,
      ),
      title: Text(e.description),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoneyText(e.amount, style: theme.textTheme.titleSmall),
          Text(lines.join('\n')),
        ],
      ),
      isThreeLine: true,
      onTap: () => context.push(AppRoutes.groupExpenseDetail(e.groupId, e.id)),
    );
  }
}

/// A calendar date for display (`YYYY-MM-DD` → `Nov 4, 2026`).
String localDate(String value, String locale) =>
    LocalDates.display(value, locale: locale);

/// Leaves the current screen: back when there is a screen below, otherwise
/// (opened from a link) to [fallback].
void leaveTo(GoRouter router, String fallback) {
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}
