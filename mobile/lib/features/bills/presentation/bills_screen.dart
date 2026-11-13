import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/bills/application/bills_providers.dart';
import 'package:montra_mobile/features/bills/domain/bill_display.dart';

/// Bills with their payment state (overdue, due today, due soon, paid,
/// upcoming…), filtered by status.
class BillsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _status = 'active';

  Future<void> _refresh() async {
    ref.invalidate(billsProvider(_status));
    try {
      await ref.read(billsProvider(_status).future);
    } on Object {
      // Shown by the list state.
    }
  }

  String _chip(AppLocalizations l10n, String status) => switch (status) {
    'active' => l10n.billFilterActive,
    'paused' => l10n.billFilterPaused,
    'archived' => l10n.billFilterArchived,
    _ => l10n.billFilterAll,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<BillDto>> bills = ref.watch(billsProvider(_status));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billsTitle),
        bottom: bills.isLoading && bills.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          const HelpGuideButton(HelpGuide.recurring),
          IconButton(
            tooltip: l10n.calendarTitle,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(AppRoutes.calendar),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newBill),
        icon: const Icon(Icons.add),
        label: Text(l10n.billAdd),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              Insets.xs,
            ),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String s in billStatusFilters)
                  ChoiceChip(
                    label: Text(_chip(l10n, s)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<BillDto>>(
              value: bills,
              onRetry: _refresh,
              data: (List<BillDto> list) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  children: <Widget>[
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Insets.lg),
                        child: _status == 'active' || _status == 'all'
                            ? MessageStateView(
                                icon: Icons.receipt_long_outlined,
                                title: l10n.billsEmptyTitle,
                                body: l10n.billsEmptyBody,
                                action: FilledButton.icon(
                                  onPressed: () =>
                                      context.push(AppRoutes.newBill),
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.billAddFirst),
                                ),
                              )
                            : MessageStateView(
                                icon: Icons.filter_alt_off_outlined,
                                title: l10n.billsNoMatchTitle,
                              ),
                      )
                    else
                      for (final BillDto b in list)
                        BillTile(
                          bill: b,
                          onTap: () => context.push(AppRoutes.billDetail(b.id)),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One bill: name, provider, due or paid date, payment state and amount.
class BillTile extends StatelessWidget {
  /// Creates the tile.
  const BillTile({required this.bill, this.onTap, super.key});

  /// The bill.
  final BillDto bill;

  /// Opens the bill.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final (String stateText, StatusTone tone, IconData icon) = billStateLabel(
      l10n,
      bill.state.json,
    );
    final OccurrenceDto? next = bill.nextDue;
    final OccurrenceDto? last = bill.lastPaid;
    final Money? amount = next?.amount ?? bill.expectedAmount;
    final String? provider = bill.providerName;
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        child: ExcludeSemantics(child: Icon(Icons.receipt_long_outlined)),
      ),
      title: Text(bill.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (provider != null && provider.isNotEmpty) Text(provider),
          if (next != null)
            Text(
              l10n.billDueOn(
                LocalDates.display(next.effectiveDate, locale: locale),
              ),
            )
          else if (last != null)
            Text(
              l10n.billPaidOn(
                LocalDates.display(last.effectiveDate, locale: locale),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: StatusLabel(
              text: stateText,
              tone: tone,
              icon: icon,
              semanticsLabel: l10n.billStateSemantics(stateText),
            ),
          ),
        ],
      ),
      trailing: amount != null && !bill.amountIsVariable
          ? MoneyText(amount)
          : Text(l10n.billVaries),
    );
  }
}
