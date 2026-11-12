import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';

/// Starter category keys a group expense can use (`category_key`), in the
/// order offered. Income-only keys are left out.
const List<String> groupCategoryKeys = <String>[
  'food_dining',
  'groceries',
  'transport',
  'fuel',
  'housing_rent',
  'utilities',
  'shopping',
  'healthcare',
  'education',
  'entertainment',
  'travel',
  'personal_care',
  'insurance',
  'taxes_fees',
  'gifts_donations',
  'family',
  'work_expenses',
  'other',
];

/// The localized name of a group `category_key` (`uncategorized` or none
/// reads "Uncategorized"; unknown keys are shown with spaces).
String groupCategoryLabel(AppLocalizations l10n, String? key) {
  if (key == null || key.isEmpty || key == 'uncategorized') {
    return l10n.categoryUncategorized;
  }
  return starterCategoryLabel(l10n, key) ?? key.replaceAll('_', ' ');
}

/// Split methods offered for a one-off expense, in order.
const List<String> expenseSplitMethods = <String>[
  'equal',
  'exact',
  'percentage',
  'shares',
  'itemized',
];

/// Split methods a recurring shared expense can use (no itemized split).
const List<String> recurringSplitMethods = <String>[
  'equal',
  'exact',
  'percentage',
  'shares',
];

/// Name of a split method (wire value).
String splitMethodLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'equal' => l10n.gxSplitEqual,
      'exact' => l10n.gxSplitExact,
      'percentage' => l10n.gxSplitPercentage,
      'shares' => l10n.gxSplitShares,
      'itemized' => l10n.gxSplitItemized,
      _ => l10n.gxSplitOther,
    };

/// What a split method means.
String splitMethodHelp(AppLocalizations l10n, String method) =>
    switch (method) {
      'equal' => l10n.gxSplitEqualHelp,
      'exact' => l10n.gxSplitExactHelp,
      'percentage' => l10n.gxSplitPercentageHelp,
      'shares' => l10n.gxSplitSharesHelp,
      'itemized' => l10n.gxSplitItemizedHelp,
      _ => '',
    };

/// A participant's split value as entered (`input_value`) for reading:
/// "33.33 %", "2 shares"; null when the method has none.
String? splitValueText(AppLocalizations l10n, String method, String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return switch (method) {
    'percentage' => l10n.gxPercentValue(value),
    'shares' => l10n.gxSharesValue(value),
    _ => null,
  };
}

/// Text and tone of an expense status.
(String, StatusTone) expenseStatusLabel(
  AppLocalizations l10n,
  GroupExpenseDtoStatus status,
) => switch (status) {
  GroupExpenseDtoStatus.active => (l10n.gxStatusActive, StatusTone.positive),
  GroupExpenseDtoStatus.disputed => (l10n.gxStatusDisputed, StatusTone.caution),
  GroupExpenseDtoStatus.deleted => (l10n.gxStatusDeleted, StatusTone.neutral),
  GroupExpenseDtoStatus.unrecognized => (
    l10n.gxStatusOther,
    StatusTone.neutral,
  ),
};

/// Text, tone and icon of a settlement status.
(String, StatusTone, IconData) settlementStatusLabel(
  AppLocalizations l10n,
  SettlementDtoStatus status,
) => switch (status) {
  SettlementDtoStatus.proposed => (
    l10n.gxSettlementProposed,
    StatusTone.neutral,
    Icons.schedule,
  ),
  SettlementDtoStatus.userReportedPaid => (
    l10n.gxSettlementReported,
    StatusTone.caution,
    Icons.hourglass_bottom,
  ),
  SettlementDtoStatus.confirmed => (
    l10n.gxSettlementConfirmed,
    StatusTone.positive,
    Icons.check_circle_outline,
  ),
  SettlementDtoStatus.disputed => (
    l10n.gxSettlementDisputed,
    StatusTone.caution,
    Icons.report_outlined,
  ),
  SettlementDtoStatus.voided => (
    l10n.gxSettlementVoided,
    StatusTone.neutral,
    Icons.block,
  ),
  SettlementDtoStatus.unrecognized => (
    l10n.gxStatusOther,
    StatusTone.neutral,
    Icons.help_outline,
  ),
};

/// A settlement status named in a coded conflict (`params.status`).
String settlementStatusWord(AppLocalizations l10n, String? status) =>
    switch (status) {
      'proposed' => l10n.gxSettlementProposed,
      'user_reported_paid' => l10n.gxSettlementReported,
      'confirmed' => l10n.gxSettlementConfirmed,
      'disputed' => l10n.gxSettlementDisputed,
      'voided' => l10n.gxSettlementVoided,
      _ => l10n.gxStatusOther,
    };

/// How a settlement was paid.
String settlementMethodLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'cash' => l10n.gxMethodCash,
      'bank_transfer' => l10n.gxMethodBank,
      'upi' => l10n.gxMethodUpi,
      'other' => l10n.gxMethodOther,
      _ => l10n.gxMethodOther,
    };

/// Where an expense's exchange rate came from.
String fxSourceLabel(AppLocalizations l10n, String? source) => switch (source) {
  'manual' => l10n.gxFxSourceManual,
  'ecb' => l10n.gxFxSourceEcb,
  'provider' => l10n.gxFxSourceProvider,
  _ => l10n.gxFxSourceOther,
};

/// The people of a group as the signed-in user sees them: names for the
/// IDs in expenses and settlements (former members included), the
/// caller's role, and who may do what.
@immutable
class GroupPeople {
  /// Creates the view of [group] for user [me].
  GroupPeople(this.group, this.me)
    : _byId = <String, GroupMemberDto>{
        for (final GroupMemberDto m in group.members) m.userId: m,
      };

  /// The group with its members.
  final GroupDetail group;

  /// The signed-in user's ID.
  final String? me;

  final Map<String, GroupMemberDto> _byId;

  /// The group currency.
  String get currency => group.baseCurrency;

  /// Whether the caller is the owner or an admin.
  bool get isAdmin =>
      group.myRole == GroupDetailMyRole.owner ||
      group.myRole == GroupDetailMyRole.admin;

  /// Whether the group takes changes (archived groups are read-only).
  bool get isActive => group.status == GroupDetailStatus.active;

  /// Whether the caller is an active member who may add things.
  bool get canWrite =>
      isActive &&
      group.myRole != GroupDetailMyRole.none &&
      group.myRole != GroupDetailMyRole.unrecognized;

  /// Current members, the caller first, then by name.
  List<GroupMemberDto> get activeMembers =>
      group.members
          .where((GroupMemberDto m) => m.status == GroupMemberDtoStatus.active)
          .toList()
        ..sort(_mineFirst);

  /// Everyone who ever belonged (settlements can involve former members).
  List<GroupMemberDto> get everyone =>
      List<GroupMemberDto>.of(group.members)..sort(_mineFirst);

  int _mineFirst(GroupMemberDto a, GroupMemberDto b) {
    if (a.userId == me) {
      return -1;
    }
    if (b.userId == me) {
      return 1;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  /// The member with [userId], if known.
  GroupMemberDto? member(String? userId) =>
      userId == null ? null : _byId[userId];

  /// Whether [userId] is the caller.
  bool isMe(String? userId) => userId != null && userId == me;

  /// Whether [userId] is a current member.
  bool isActiveMember(String? userId) =>
      member(userId)?.status == GroupMemberDtoStatus.active;

  /// A name for [userId]: "You", the member's name, or "Former member".
  String name(AppLocalizations l10n, String? userId, {String? fallback}) {
    if (isMe(userId)) {
      return l10n.gxYou;
    }
    final GroupMemberDto? m = member(userId);
    final String? known = m?.displayName.trim();
    if (known != null && known.isNotEmpty) {
      return known;
    }
    final String? other = fallback?.trim();
    return other == null || other.isEmpty ? l10n.gxFormerMember : other;
  }
}

/// Whether the caller may delete [expense] (its creator or an admin).
bool canDeleteExpense(GroupExpenseDetail expense, GroupPeople people) =>
    people.canWrite &&
    expense.status != GroupExpenseDetailStatus.deleted &&
    (people.isAdmin || people.isMe(expense.createdBy));

/// Whether the caller may edit [expense] (any current member while the
/// group is active).
bool canEditExpense(GroupExpenseDetail expense, GroupPeople people) =>
    people.canWrite && expense.status != GroupExpenseDetailStatus.deleted;

/// Whether the caller paid part of [expense].
bool isPayer(GroupExpenseDetail expense, GroupPeople people) =>
    expense.payers.any((ExpensePayerDto p) => people.isMe(p.userId));

/// The lifecycle actions the caller can take on [s], in the order offered
/// (the server checks again; a refused move reloads the settlement).
List<SettlementAction> settlementActionsFor(
  SettlementDto s,
  GroupPeople people,
) {
  final bool payer = people.isMe(s.payerUserId);
  final bool payee = people.isMe(s.payeeUserId);
  final bool party = payer || payee;
  final SettlementDtoStatus st = s.status;
  if (st == SettlementDtoStatus.voided ||
      st == SettlementDtoStatus.unrecognized) {
    return <SettlementAction>[
      if (s.myTransactionId != null) SettlementAction.unlink,
    ];
  }
  final bool confirmable =
      st == SettlementDtoStatus.proposed ||
      st == SettlementDtoStatus.userReportedPaid ||
      st == SettlementDtoStatus.disputed;
  final bool onBehalf =
      !payee && people.isAdmin && !people.isActiveMember(s.payeeUserId);
  final bool recordable =
      s.myTransactionId == null &&
      ((payer &&
              (st == SettlementDtoStatus.userReportedPaid ||
                  st == SettlementDtoStatus.confirmed ||
                  st == SettlementDtoStatus.disputed)) ||
          (payee && st == SettlementDtoStatus.confirmed));
  return <SettlementAction>[
    if (payer && st == SettlementDtoStatus.proposed) SettlementAction.markPaid,
    if (confirmable && (payee || onBehalf)) SettlementAction.confirm,
    if (party &&
        (st == SettlementDtoStatus.userReportedPaid ||
            st == SettlementDtoStatus.confirmed))
      SettlementAction.dispute,
    if (recordable) SettlementAction.record,
    if (s.myTransactionId != null) SettlementAction.unlink,
    if (party ||
        people.isAdmin ||
        (s.proposedBy != null && people.isMe(s.proposedBy)))
      SettlementAction.voidIt,
  ];
}

/// Whether the caller may correct [s] (a party or an admin; not voided).
bool canCorrectSettlement(SettlementDto s, GroupPeople people) =>
    s.status != SettlementDtoStatus.voided &&
    (people.isMe(s.payerUserId) ||
        people.isMe(s.payeeUserId) ||
        people.isAdmin);

/// Whether the caller may pause, resume, stop, edit or skip occurrences of
/// [rule] (its creator or an admin).
bool canManageRecurring(GroupRecurringDto rule, GroupPeople people) =>
    people.canWrite && (people.isAdmin || people.isMe(rule.createdBy));

/// Which way a balance goes.
enum NetDirection {
  /// Others owe this person.
  owed,

  /// This person owes others.
  owes,

  /// Nothing is open.
  settled,
}

/// The direction of a net balance (positive: is owed).
NetDirection netDirection(Money net) => net.amountMinor > 0
    ? NetDirection.owed
    : net.amountMinor < 0
    ? NetDirection.owes
    : NetDirection.settled;

/// [money] without its sign (for "You owe ₹…" sentences); the server's
/// exact digits are kept.
Money absMoney(Money money) => money.amountMinor >= 0
    ? money
    : Money(
        amount: money.amount.startsWith('-')
            ? money.amount.substring(1)
            : money.amount,
        amountMinor: -money.amountMinor,
        currency: money.currency,
      );

/// Minor units of a canonical decimal [value] (`"1234.50"`, as produced by
/// the amount input) with [exponent] digits; null when it does not fit.
/// Used only to guide form input (a preview of what is left to assign),
/// never for figures the app shows as facts.
int? minorOf(String value, int exponent) {
  final RegExpMatch? m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value);
  if (m == null) {
    return null;
  }
  final String fraction = (m.group(3) ?? '').padRight(exponent, '0');
  if (fraction.length > exponent) {
    return null;
  }
  final int? whole = int.tryParse('${m.group(2)}$fraction');
  if (whole == null) {
    return null;
  }
  return m.group(1) == '-' ? -whole : whole;
}

/// A [Money] for [minor] units of [currency] (form previews only).
Money moneyOfMinor(int minor, String currency) => Money(
  amount: MoneyFormatter.decimalFromMinorUnits(minor, currency),
  amountMinor: minor,
  currency: currency,
);

/// Hundredths of a percent in [text] (`33.33` → 3333); null when it is not
/// a percentage with up to two decimals.
int? hundredthsOfPercent(String text) {
  final RegExpMatch? m = RegExp(r'^(\d{1,3})(?:[.,](\d{1,2}))?$')
      .firstMatch(text.trim());
  if (m == null) {
    return null;
  }
  return int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
}

/// The canonical percentage text for the API (`33,3` → `33.3`).
String percentWire(String text) => text.trim().replaceAll(',', '.');

/// Whether [text] is a positive whole number of shares.
bool isWholeShares(String text) {
  final int? v = int.tryParse(text.trim());
  return v != null && v > 0;
}

/// Whether [text] is a positive exact exchange rate (up to 12 decimals).
bool isValidRate(String text) {
  final RegExpMatch? m = RegExp(r'^(\d{1,9})(?:[.,](\d{1,12}))?$')
      .firstMatch(text.trim());
  if (m == null) {
    return false;
  }
  return RegExp('[1-9]').hasMatch('${m.group(1)}${m.group(2) ?? ''}');
}
