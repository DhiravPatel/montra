import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';

/// Payments between members (settlements), newest first. Each is a
/// two-sided record of money paid outside Montra: one side reports it, the
/// other confirms it, and only confirmed payments count in balances.
class GroupSettlementsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupSettlementsScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  ConsumerState<GroupSettlementsScreen> createState() =>
      _GroupSettlementsScreenState();
}

class _GroupSettlementsScreenState
    extends ConsumerState<GroupSettlementsScreen> {
  bool _voided = false;

  SettlementsQuery get _query =>
      (groupId: widget.groupId, includeVoided: _voided);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxSettlementsTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<List<SettlementDto>> list = ref.watch(
          groupSettlementsProvider(_query),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.gxSettlementsTitle),
            actions: <Widget>[
              GroupMoneyMenu(
                groupId: widget.groupId,
                current: GroupMoneyPage.settlements,
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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.xs,
                  Insets.md,
                  0,
                ),
                child: Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilterChip(
                      label: Text(l10n.gxShowVoided),
                      selected: _voided,
                      onSelected: (bool v) => setState(() => _voided = v),
                    ),
                    Text(
                      l10n.gxSettlementsHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncValueView<List<SettlementDto>>(
                  value: list,
                  onRetry: () =>
                      ref.invalidate(groupSettlementsProvider(_query)),
                  isEmpty: (List<SettlementDto> l) => l.isEmpty,
                  empty: MessageStateView(
                    icon: Icons.handshake_outlined,
                    title: l10n.gxSettlementsEmptyTitle,
                    body: l10n.gxSettlementsEmptyBody,
                  ),
                  data: (List<SettlementDto> l) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(groupSettlementsProvider(_query));
                      try {
                        await ref.read(groupSettlementsProvider(_query).future);
                      } on Object {
                        // Shown by the list state.
                      }
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: l.length,
                      separatorBuilder: (BuildContext context, int i) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) =>
                          SettlementTile(settlement: l[i], people: people),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One settlement in a list: who paid whom, how much, when and its state.
class SettlementTile extends ConsumerWidget {
  /// Creates the tile.
  const SettlementTile({
    required this.settlement,
    required this.people,
    super.key,
  });

  /// The settlement.
  final SettlementDto settlement;

  /// The group's people.
  final GroupPeople people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final SettlementDto s = settlement;
    final (String status, StatusTone tone, IconData icon) =
        settlementStatusLabel(l10n, s.status);
    final String from = people.name(l10n, s.payerUserId, fallback: s.payerName);
    final String to = people.name(l10n, s.payeeUserId, fallback: s.payeeName);
    return ListTile(
      leading: Icon(icon),
      title: Text(l10n.gxPaid(from, to)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoneyText(s.amount),
          Text(
            '${LocalDates.display(s.settledOn, locale: locale)} · '
            '${settlementMethodLabel(l10n, s.method.json)}',
          ),
          const SizedBox(height: Insets.xs),
          StatusLabel(text: status, tone: tone),
        ],
      ),
      isThreeLine: true,
      onTap: () =>
          context.push(AppRoutes.groupSettlementDetail(s.groupId, s.id)),
    );
  }
}
