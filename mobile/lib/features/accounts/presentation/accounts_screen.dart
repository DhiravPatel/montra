import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';
import 'package:montra_mobile/features/accounts/presentation/account_widgets.dart';

/// Accounts list: grouped by type with ledger balances, server totals per
/// currency, and an option to include archived and closed accounts.
class AccountsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(accountsProvider(_showArchived))
      ..invalidate(accountTotalsProvider);
    try {
      await ref.read(accountsProvider(_showArchived).future);
    } on Object {
      // Shown by the list state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<AccountDto>> accounts = ref.watch(
      accountsProvider(_showArchived),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountsTitle),
        bottom: accounts.isLoading && accounts.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newAccount),
        icon: const Icon(Icons.add),
        label: Text(l10n.accountAdd),
      ),
      body: AsyncValueView<List<AccountDto>>(
        value: accounts,
        onRetry: _refresh,
        data: (List<AccountDto> list) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              SwitchListTile(
                title: Text(l10n.accountsShowArchived),
                value: _showArchived,
                onChanged: (bool value) =>
                    setState(() => _showArchived = value),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.lg),
                  child: MessageStateView(
                    icon: Icons.account_balance_wallet_outlined,
                    title: l10n.accountsEmptyTitle,
                    body: l10n.accountsEmptyBody,
                    action: FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.newAccount),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.accountAddFirst),
                    ),
                  ),
                )
              else ...<Widget>[
                const _TotalsCard(),
                for (final AccountGroup group in groupAccounts(
                  list,
                )) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.md,
                      Insets.md,
                      Insets.xs,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.accountGroupHeading(
                          accountTypeLabel(l10n, group.type),
                          group.accounts.length,
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  for (final AccountDto account in group.accounts)
                    AccountTile(
                      account: account,
                      onTap: () =>
                          context.push(AppRoutes.accountDetail(account.id)),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalsCard extends ConsumerWidget {
  const _TotalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<BalanceTotals>> totals = ref.watch(
      accountTotalsProvider,
    );
    final List<BalanceTotals>? data = totals.value;
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: SectionCard(
        title: l10n.accountsTotalsTitle,
        children: <Widget>[
          for (final BalanceTotals t in data) ...<Widget>[
            if (data.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.md,
                  0,
                ),
                child: Text(
                  l10n.currencyHeading(t.currency),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            DetailRow(
              label: l10n.netWorthLabel,
              semanticsValue: formatMoney(context, ref, t.netWorth),
              child: MoneyText(t.netWorth),
            ),
            DetailRow(
              label: l10n.assetsLabel,
              semanticsValue: formatMoney(context, ref, t.assets),
              child: MoneyText(t.assets),
            ),
            DetailRow(
              label: l10n.liabilitiesLabel,
              semanticsValue: formatMoney(context, ref, t.liabilities),
              child: MoneyText(t.liabilities),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              Insets.sm,
            ),
            child: Text(
              l10n.trackedBalanceNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
