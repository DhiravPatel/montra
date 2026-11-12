import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';

/// The user's balance in a group as words with the server's amount: "You
/// are owed ₹200.00", "You owe ₹50.00" or "Settled up" (status by icon and
/// text, never by color alone).
class GroupNetLabel extends ConsumerWidget {
  /// Creates the label for [net].
  const GroupNetLabel(this.net, {super.key});

  /// `my_net` (positive: others owe the user).
  final Money net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String formatted = formatMoney(context, ref, unsignedNet(net));
    final ({String text, StatusTone tone}) wording = netBalanceWording(
      l10n,
      net,
      formatted,
    );
    return StatusLabel(
      text: wording.text,
      tone: wording.tone,
      icon: switch (wording.tone) {
        StatusTone.positive => Icons.call_received,
        StatusTone.caution => Icons.call_made,
        StatusTone.neutral => Icons.check_circle_outline,
      },
    );
  }
}

/// Runs a group write with a busy guard owned by the caller: shows
/// [success] or the localized error, and re-reads group [groupId] (or the
/// lists) afterwards. Conflicts (`VERSION_CONFLICT`, coded `CONFLICT`)
/// also reload. Returns the result, or null on failure.
Future<T?> runGroupAction<T>(
  BuildContext context,
  WidgetRef ref, {
  required Future<T> Function(GroupsApi api) action,
  required String Function(T result) success,
  String? groupId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final GroupsApi api = ref.read(groupsApiProvider);
  final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
  void refresh() {
    if (groupId != null) {
      refreshGroup(ref, groupId);
    } else {
      refreshGroupLists(ref);
    }
  }

  try {
    final T result = await action(api);
    refresh();
    // Membership changes move group expenses in and out of personal
    // totals; let finance screens re-read.
    finance.bump();
    if (context.mounted) {
      showSnack(context, success(result));
    }
    return result;
  } on ApiException catch (error) {
    if (error.code == ErrorObjectCode.versionConflict ||
        error.code == ErrorObjectCode.conflict ||
        error.code == ErrorObjectCode.notFound) {
      refresh();
    }
    if (context.mounted) {
      showSnack(
        context,
        error.code == ErrorObjectCode.versionConflict
            ? l10n.versionConflictReloaded
            : describeError(l10n, error),
      );
    }
    return null;
  }
}
