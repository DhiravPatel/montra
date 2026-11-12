import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Account types in display order (the create/edit vocabulary).
const List<AccountInputAccountType> accountTypeOrder =
    <AccountInputAccountType>[
      AccountInputAccountType.cash,
      AccountInputAccountType.bank,
      AccountInputAccountType.savings,
      AccountInputAccountType.debitCard,
      AccountInputAccountType.creditCard,
      AccountInputAccountType.prepaidCard,
      AccountInputAccountType.digitalWallet,
      AccountInputAccountType.upi,
      AccountInputAccountType.loan,
      AccountInputAccountType.investment,
      AccountInputAccountType.householdLedger,
      AccountInputAccountType.custom,
    ];

/// The type of [account] in the create/edit vocabulary (same wire values;
/// a type this app version does not know reads as "Other account").
AccountInputAccountType accountTypeOf(AccountDto account) =>
    switch (account.accountType) {
      AccountDtoAccountType.cash => AccountInputAccountType.cash,
      AccountDtoAccountType.bank => AccountInputAccountType.bank,
      AccountDtoAccountType.savings => AccountInputAccountType.savings,
      AccountDtoAccountType.creditCard => AccountInputAccountType.creditCard,
      AccountDtoAccountType.debitCard => AccountInputAccountType.debitCard,
      AccountDtoAccountType.prepaidCard => AccountInputAccountType.prepaidCard,
      AccountDtoAccountType.digitalWallet =>
        AccountInputAccountType.digitalWallet,
      AccountDtoAccountType.upi => AccountInputAccountType.upi,
      AccountDtoAccountType.loan => AccountInputAccountType.loan,
      AccountDtoAccountType.investment => AccountInputAccountType.investment,
      AccountDtoAccountType.householdLedger =>
        AccountInputAccountType.householdLedger,
      AccountDtoAccountType.custom ||
      AccountDtoAccountType.unrecognized => AccountInputAccountType.custom,
    };

/// Credit cards and loans: a negative balance is an amount owed.
bool isLiabilityType(AccountInputAccountType type) =>
    type == AccountInputAccountType.creditCard ||
    type == AccountInputAccountType.loan;

/// Localized name of an account type.
String accountTypeLabel(AppLocalizations l10n, AccountInputAccountType type) =>
    switch (type) {
      AccountInputAccountType.cash => l10n.accountTypeCash,
      AccountInputAccountType.bank => l10n.accountTypeBank,
      AccountInputAccountType.savings => l10n.accountTypeSavings,
      AccountInputAccountType.creditCard => l10n.accountTypeCreditCard,
      AccountInputAccountType.debitCard => l10n.accountTypeDebitCard,
      AccountInputAccountType.prepaidCard => l10n.accountTypePrepaidCard,
      AccountInputAccountType.digitalWallet => l10n.accountTypeDigitalWallet,
      AccountInputAccountType.upi => l10n.accountTypeUpi,
      AccountInputAccountType.loan => l10n.accountTypeLoan,
      AccountInputAccountType.investment => l10n.accountTypeInvestment,
      AccountInputAccountType.householdLedger =>
        l10n.accountTypeHouseholdLedger,
      AccountInputAccountType.custom ||
      AccountInputAccountType.unrecognized => l10n.accountTypeCustom,
    };

/// Icon for an account type.
IconData accountTypeIcon(AccountInputAccountType type) => switch (type) {
  AccountInputAccountType.cash => Icons.payments_outlined,
  AccountInputAccountType.bank => Icons.account_balance_outlined,
  AccountInputAccountType.savings => Icons.savings_outlined,
  AccountInputAccountType.creditCard => Icons.credit_card,
  AccountInputAccountType.debitCard => Icons.credit_card_outlined,
  AccountInputAccountType.prepaidCard => Icons.card_giftcard_outlined,
  AccountInputAccountType.digitalWallet =>
    Icons.account_balance_wallet_outlined,
  AccountInputAccountType.upi => Icons.qr_code_2,
  AccountInputAccountType.loan => Icons.request_quote_outlined,
  AccountInputAccountType.investment => Icons.trending_up,
  AccountInputAccountType.householdLedger => Icons.house_outlined,
  AccountInputAccountType.custom ||
  AccountInputAccountType.unrecognized => Icons.folder_outlined,
};

/// Localized label of where a balance comes from.
String balanceSourceLabel(
  AppLocalizations l10n,
  AccountDtoBalanceSource source,
) => switch (source) {
  AccountDtoBalanceSource.manual => l10n.balanceSourceManual,
  AccountDtoBalanceSource.calculated => l10n.balanceSourceCalculated,
  AccountDtoBalanceSource.imported => l10n.balanceSourceImported,
  AccountDtoBalanceSource.provider => l10n.balanceSourceProvider,
  AccountDtoBalanceSource.unrecognized => l10n.balanceSourceCalculated,
};

/// Localized account status.
String accountStatusLabel(AppLocalizations l10n, AccountDtoStatus status) =>
    switch (status) {
      AccountDtoStatus.active => l10n.accountStatusActive,
      AccountDtoStatus.archived => l10n.accountStatusArchived,
      AccountDtoStatus.closed => l10n.accountStatusClosed,
      AccountDtoStatus.unrecognized => l10n.accountStatusArchived,
    };

/// A group of accounts of one type, in [accountTypeOrder].
@immutable
class AccountGroup {
  /// Creates the group.
  const AccountGroup(this.type, this.accounts);

  /// Shared type.
  final AccountInputAccountType type;

  /// Accounts by display order, then name.
  final List<AccountDto> accounts;
}

/// Groups [accounts] by type in [accountTypeOrder]; active accounts first
/// inside each group, then by display order and name.
List<AccountGroup> groupAccounts(List<AccountDto> accounts) {
  final Map<AccountInputAccountType, List<AccountDto>> byType =
      <AccountInputAccountType, List<AccountDto>>{};
  for (final AccountDto a in accounts) {
    AccountInputAccountType type = accountTypeOf(a);
    if (type == AccountInputAccountType.unrecognized) {
      type = AccountInputAccountType.custom;
    }
    (byType[type] ??= <AccountDto>[]).add(a);
  }
  int rank(AccountDtoStatus s) => s == AccountDtoStatus.active ? 0 : 1;
  return <AccountGroup>[
    for (final AccountInputAccountType type in accountTypeOrder)
      if (byType[type] case final List<AccountDto> list)
        AccountGroup(
          type,
          List<AccountDto>.unmodifiable(
            list..sort((AccountDto a, AccountDto b) {
              final int status = rank(a.status).compareTo(rank(b.status));
              if (status != 0) {
                return status;
              }
              final int order = a.displayOrder.compareTo(b.displayOrder);
              return order != 0
                  ? order
                  : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }),
          ),
        ),
  ];
}

/// Whether [account] can receive new transactions.
bool isUsableAccount(AccountDto account) =>
    account.owned && account.status == AccountDtoStatus.active;

/// `•• 4821` for a masked number, or null.
String? maskedNumberText(String? masked) =>
    masked == null || masked.isEmpty ? null : '•• $masked';
