import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';

enum _Snooze { day, threeDays, week, date }

/// Asks how long to snooze a budget alert: a day, three days, a week or
/// until a chosen date (the start of that day). Null when dismissed.
Future<DateTime?> pickAlertSnooze(
  BuildContext context, {
  DateTime Function() now = DateTime.now,
}) async {
  final AppLocalizations l10n = context.l10n;
  final _Snooze? choice = await showOptionSheet<_Snooze>(
    context,
    title: l10n.budgetSnoozeTitle,
    options: <SheetOption<_Snooze>>[
      SheetOption<_Snooze>(value: _Snooze.day, label: l10n.budgetSnoozeDay),
      SheetOption<_Snooze>(
        value: _Snooze.threeDays,
        label: l10n.budgetSnooze3Days,
      ),
      SheetOption<_Snooze>(value: _Snooze.week, label: l10n.budgetSnoozeWeek),
      SheetOption<_Snooze>(
        value: _Snooze.date,
        label: l10n.budgetSnoozePickDate,
        icon: Icons.event_outlined,
      ),
    ],
  );
  final DateTime at = now();
  switch (choice) {
    case null:
      return null;
    case _Snooze.day:
      return at.add(const Duration(days: 1));
    case _Snooze.threeDays:
      return at.add(const Duration(days: 3));
    case _Snooze.week:
      return at.add(const Duration(days: 7));
    case _Snooze.date:
      if (!context.mounted) {
        return null;
      }
      final DateTime today = LocalDates.today(at);
      final DateTime? picked = await showDatePicker(
        context: context,
        firstDate: today.add(const Duration(days: 1)),
        lastDate: today.add(const Duration(days: 90)),
        initialDate: today.add(const Duration(days: 1)),
      );
      // The alert comes back at the start of the chosen day.
      return picked == null
          ? null
          : DateTime(picked.year, picked.month, picked.day);
  }
}

/// Dismisses, snoozes (asking until when first) or reactivates [alert]
/// with `PATCH /budget-alerts/{id}`, then bumps the budget revision so
/// every list of alerts and the Home planning cards are read again. Says
/// what happened in a snack bar; returns whether the change was saved.
/// [onSending] runs once the choice is made, just before the request.
Future<bool> changeBudgetAlert(
  BuildContext context,
  WidgetRef ref,
  AlertDto alert,
  BudgetAlertsUpdateRequestStatus status, {
  VoidCallback? onSending,
}) async {
  DateTime? until;
  if (status == BudgetAlertsUpdateRequestStatus.snoozed) {
    until = await pickAlertSnooze(context);
    if (until == null || !context.mounted) {
      return false;
    }
  }
  final AppLocalizations l10n = context.l10n;
  final String locale = Localizations.localeOf(context).toString();
  final BudgetRevision revision = ref.read(budgetRevisionProvider.notifier);
  final BudgetsApi api = ref.read(budgetsApiProvider);
  onSending?.call();
  try {
    await api.updateAlert(
      alert.id,
      BudgetAlertsUpdateRequest(status: status, snoozedUntil: until?.toUtc()),
    );
    revision.bump();
    if (context.mounted) {
      showSnack(context, switch (status) {
        BudgetAlertsUpdateRequestStatus.dismissed => l10n.budgetAlertDismissed,
        BudgetAlertsUpdateRequestStatus.snoozed => l10n.budgetAlertSnoozedDone(
          formatDateTime(until!, locale: locale),
        ),
        _ => l10n.budgetAlertReactivated,
      });
    }
    return true;
  } on ApiException catch (error) {
    if (context.mounted) {
      showSnack(context, describeError(l10n, error));
    }
    return false;
  }
}
