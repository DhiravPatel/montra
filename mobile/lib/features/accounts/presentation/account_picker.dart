import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';

List<SelectionItem<AccountDto>> _accountItems(
  BuildContext context,
  List<AccountDto> accounts, {
  Set<String> exclude = const <String>{},
  String? currency,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<SelectionItem<AccountDto>> items = <SelectionItem<AccountDto>>[];
  for (final AccountGroup group in groupAccounts(accounts)) {
    for (final AccountDto a in group.accounts) {
      if (exclude.contains(a.id) ||
          (currency != null && a.currency != currency)) {
        continue;
      }
      final String type = accountTypeLabel(l10n, group.type);
      final String? masked = maskedNumberText(a.maskedNumber);
      final List<String> parts = <String>[
        type,
        a.currency,
        ?a.institutionLabel,
        ?masked,
        if (a.status != AccountDtoStatus.active)
          accountStatusLabel(l10n, a.status),
      ];
      items.add(
        SelectionItem<AccountDto>(
          id: a.id,
          value: a,
          label: a.name,
          subtitle: parts.join(' · '),
          leading: Icon(accountTypeIcon(group.type)),
          searchText: '${a.institutionLabel ?? ''} ${a.currency}',
        ),
      );
    }
  }
  return items;
}

/// Picks one active account the user owns. [exclude] hides accounts (e.g.
/// the source of a transfer) and [currency] limits the choice to one
/// currency. Returns null when dismissed.
Future<AccountDto?> showAccountPicker(
  BuildContext context, {
  String? selectedId,
  Set<String> exclude = const <String>{},
  String? currency,
  String? title,
}) async {
  final Picked<AccountDto>? picked =
      await showSingleSelection<AccountDto, AccountDto>(
        context,
        title: title ?? context.l10n.accountPickerTitle,
        source: usableAccountsProvider,
        onRetry: (WidgetRef ref) => ref.invalidate(accountsProvider(false)),
        items: (BuildContext context, List<AccountDto> data) =>
            _accountItems(context, data, exclude: exclude, currency: currency),
        selectedId: selectedId,
        emptyText: context.l10n.accountPickerEmpty,
      );
  return picked?.value;
}

/// Picks several accounts, archived ones included (filters).
Future<Set<String>?> showAccountMultiPicker(
  BuildContext context, {
  Set<String> selectedIds = const <String>{},
}) => showMultiSelection<AccountDto, AccountDto>(
  context,
  title: context.l10n.accountPickerTitle,
  source: accountsProvider(true),
  onRetry: (WidgetRef ref) => ref.invalidate(accountsProvider(true)),
  items: _accountItems,
  selectedIds: selectedIds,
  emptyText: context.l10n.accountPickerEmpty,
);
