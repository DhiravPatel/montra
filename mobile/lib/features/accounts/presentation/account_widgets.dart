import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';

/// [money] without its sign, for labels that already say what the amount
/// is ("Owed ₹3,200.00"). Only the presentation changes: the exact digits
/// come from the server.
Money unsignedMoney(Money money) {
  if (!money.amount.startsWith('-')) {
    return money;
  }
  return Money(
    amount: money.amount.substring(1),
    amountMinor: -money.amountMinor,
    currency: money.currency,
  );
}

/// How a balance should be described.
enum BalanceKind {
  /// Ordinary positive (or zero) balance.
  normal,

  /// Credit card or loan with money owed.
  owed,

  /// Credit card or loan in credit (overpaid).
  inCredit,

  /// Non-liability account below zero.
  overdrawn,
}

/// Classifies [account]'s balance for display.
BalanceKind balanceKindOf(AccountDto account) {
  final bool negative = account.balance.amountMinor < 0;
  if (account.isLiability) {
    if (negative) {
      return BalanceKind.owed;
    }
    return account.balance.amountMinor > 0
        ? BalanceKind.inCredit
        : BalanceKind.normal;
  }
  return negative ? BalanceKind.overdrawn : BalanceKind.normal;
}

/// Localized caption for a balance kind, or null for a plain balance.
String? balanceCaption(AppLocalizations l10n, BalanceKind kind) =>
    switch (kind) {
      BalanceKind.normal => null,
      BalanceKind.owed => l10n.balanceOwed,
      BalanceKind.inCredit => l10n.balanceInCredit,
      BalanceKind.overdrawn => l10n.balanceOverdrawn,
    };

/// The balance amount shown for [account]: amounts owed without a sign
/// (the caption says "Owed").
Money displayedBalance(AccountDto account) =>
    balanceKindOf(account) == BalanceKind.owed
    ? unsignedMoney(account.balance)
    : account.balance;

/// The balance of an account with liability-aware wording: credit cards
/// and loans read "Owed ₹3,200.00" instead of a bare negative number.
class AccountBalanceText extends StatelessWidget {
  /// Creates the text.
  const AccountBalanceText(
    this.account, {
    this.style,
    this.textAlign = TextAlign.end,
    super.key,
  });

  /// The account.
  final AccountDto account;

  /// Amount style.
  final TextStyle? style;

  /// Alignment.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? caption = balanceCaption(l10n, balanceKindOf(account));
    final Money shown = displayedBalance(account);
    return Column(
      crossAxisAlignment: textAlign == TextAlign.end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MoneyText(
          shown,
          style: style ?? theme.textTheme.titleMedium,
          textAlign: textAlign,
          label: caption ?? l10n.accountBalanceLabel,
        ),
        if (caption != null)
          ExcludeSemantics(
            child: Text(
              caption,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// A row in the accounts list.
class AccountTile extends StatelessWidget {
  /// Creates the tile.
  const AccountTile({required this.account, this.onTap, super.key});

  /// The account.
  final AccountDto account;

  /// Opens the account.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AccountInputAccountType type = accountTypeOf(account);
    final String? masked = maskedNumberText(account.maskedNumber);
    final List<String> details = <String>[
      ?account.institutionLabel,
      ?masked,
      if (account.currency.isNotEmpty) account.currency,
    ];
    final String? caption = balanceCaption(l10n, balanceKindOf(account));
    return ListTile(
      onTap: onTap,
      leading: ExcludeSemantics(
        child: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          child: Icon(accountTypeIcon(type)),
        ),
      ),
      title: Text(account.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (details.isNotEmpty) Text(details.join(' · ')),
          if (caption != null ||
              account.status != AccountDtoStatus.active ||
              !account.owned ||
              !account.includeInOverview)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: <Widget>[
                  if (caption != null)
                    ExcludeSemantics(
                      child: StatusLabel(
                        text: caption,
                        tone: balanceKindOf(account) == BalanceKind.overdrawn
                            ? StatusTone.caution
                            : StatusTone.neutral,
                        icon: Icons.info_outline,
                      ),
                    ),
                  if (account.status != AccountDtoStatus.active)
                    StatusLabel(
                      text: accountStatusLabel(l10n, account.status),
                      icon: account.status == AccountDtoStatus.closed
                          ? Icons.lock_outline
                          : Icons.archive_outlined,
                    ),
                  if (!account.owned)
                    StatusLabel(
                      text: l10n.accountSharedReadOnly,
                      icon: Icons.group_outlined,
                    ),
                  if (!account.includeInOverview)
                    StatusLabel(
                      text: l10n.accountNotInOverview,
                      icon: Icons.visibility_off_outlined,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.42,
        ),
        child: MoneyText(
          displayedBalance(account),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.end,
          label: caption ?? l10n.accountBalanceLabel,
        ),
      ),
    );
  }
}
