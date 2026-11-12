import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';

/// A transaction row: what it was, the category and account, the date, and
/// the amount with an explicit direction sign. Status (pending, draft,
/// deleted) and refunds are spelled out as text.
class TransactionTile extends ConsumerWidget {
  /// Creates the tile.
  const TransactionTile({
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.showAccount = true,
    this.showDate = true,
    this.selected,
    super.key,
  });

  /// The transaction.
  final TransactionDto transaction;

  /// Opens the transaction.
  final VoidCallback? onTap;

  /// Starts selection.
  final VoidCallback? onLongPress;

  /// Show the account name.
  final bool showAccount;

  /// Show the date.
  final bool showDate;

  /// Selection state in multi-select mode (null when not selecting).
  final bool? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final TransactionDto t = transaction;
    final CategoryRef? category = t.category;
    final String? categoryLabel = category == null
        ? null
        : categoryRefDisplay(l10n, category);
    final String title = transactionTitle(l10n, t, categoryName: categoryLabel);
    final bool voided = t.status == TransactionDtoStatus.voided;
    final List<String> lineParts = <String>[
      if (categoryLabel != null && categoryLabel != title) categoryLabel,
      if (category == null &&
          (t.typeValue == TransactionDtoType.expense ||
              t.typeValue == TransactionDtoType.income))
        l10n.categoryUncategorized,
      if (t.typeValue != TransactionDtoType.expense &&
          t.typeValue != TransactionDtoType.income)
        transactionTypeLabel(l10n, t.typeValue),
      if (showAccount) t.accountName,
      if (showDate) LocalDates.display(t.localDate, locale: locale),
    ];
    final bool hasRefund = t.refundedTotal.amountMinor > 0;
    final Widget leading = selected == null
        ? CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            child: Icon(
              category != null &&
                      (t.typeValue == TransactionDtoType.expense ||
                          t.typeValue == TransactionDtoType.income ||
                          t.typeValue == TransactionDtoType.refund)
                  ? categoryIcon(category.icon)
                  : transactionTypeIcon(t.typeValue),
            ),
          )
        : Checkbox(
            value: selected,
            onChanged: onTap == null ? null : (_) => onTap!(),
          );
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected ?? false,
      leading: selected == null ? ExcludeSemantics(child: leading) : leading,
      title: Text(
        title,
        style: voided
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (lineParts.isNotEmpty) Text(lineParts.join(' · ')),
          if (t.status != TransactionDtoStatus.posted || hasRefund)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: <Widget>[
                  if (t.status != TransactionDtoStatus.posted)
                    StatusLabel(
                      text: transactionStatusLabel(l10n, t.status),
                      tone: voided ? StatusTone.caution : StatusTone.neutral,
                      icon: voided
                          ? Icons.delete_outline
                          : Icons.schedule_outlined,
                    ),
                  if (hasRefund) _RefundedLabel(money: t.refundedTotal),
                ],
              ),
            ),
        ],
      ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.4,
        ),
        child: MoneyText(
          t.amount,
          flow: flowOf(t),
          colored: true,
          textAlign: TextAlign.end,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _RefundedLabel extends ConsumerWidget {
  const _RefundedLabel({required this.money});

  final Money money;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StatusLabel(
    text: context.l10n.txRefundedAmount(formatMoney(context, ref, money)),
    icon: Icons.undo,
  );
}
