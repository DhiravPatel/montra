import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

/// Voids several transactions (restorable) and refreshes finance data.
Future<int> bulkDelete(WidgetRef ref, List<String> ids) async {
  final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
  final int count = await ref.read(transactionsApiProvider).bulkDelete(ids);
  finance.bump();
  return count;
}

enum _BulkAction { setCategory, clearCategory, addTags, removeTags, move }

/// Lets the user apply one change to the selected transactions (category,
/// tags or account). The server applies it to all or none. Returns the
/// number of updated transactions, or null when nothing was changed.
Future<int?> showBulkEditSheet(BuildContext context, List<String> ids) async {
  final AppLocalizations l10n = context.l10n;
  final _BulkAction? action = await showOptionSheet<_BulkAction>(
    context,
    title: l10n.bulkEditTitleCount(ids.length),
    options: <SheetOption<_BulkAction>>[
      SheetOption<_BulkAction>(
        value: _BulkAction.setCategory,
        label: l10n.bulkSetCategory,
        icon: Icons.category_outlined,
      ),
      SheetOption<_BulkAction>(
        value: _BulkAction.clearCategory,
        label: l10n.bulkClearCategory,
        icon: Icons.label_off_outlined,
      ),
      SheetOption<_BulkAction>(
        value: _BulkAction.addTags,
        label: l10n.bulkAddTags,
        icon: Icons.sell_outlined,
      ),
      SheetOption<_BulkAction>(
        value: _BulkAction.removeTags,
        label: l10n.bulkRemoveTags,
        icon: Icons.highlight_remove_outlined,
      ),
      SheetOption<_BulkAction>(
        value: _BulkAction.move,
        label: l10n.bulkMoveAccount,
        subtitle: l10n.bulkMoveAccountHelp,
        icon: Icons.drive_file_move_outline,
      ),
    ],
  );
  if (action == null || !context.mounted) {
    return null;
  }
  BulkUpdateInput? input;
  String? summary;
  switch (action) {
    case _BulkAction.setCategory:
      final Picked<CategoryDto>? picked = await showCategoryPicker(
        context,
        kind: CategoryKindFilter.any,
        allowNone: false,
      );
      final CategoryDto? category = picked?.value;
      if (category != null && context.mounted) {
        input = BulkUpdateInput(transactionIds: ids, categoryId: category.id);
        summary = l10n.bulkSetCategoryConfirm(
          ids.length,
          categoryName(l10n, category),
        );
      }
    case _BulkAction.clearCategory:
      input = BulkUpdateInput(transactionIds: ids, clearCategory: true);
      summary = l10n.bulkClearCategoryConfirm(ids.length);
    case _BulkAction.addTags:
    case _BulkAction.removeTags:
      final Set<String>? tags = await showTagMultiPicker(context);
      if (tags != null && tags.isNotEmpty) {
        final List<String> list = tags.toList();
        input = action == _BulkAction.addTags
            ? BulkUpdateInput(transactionIds: ids, addTagIds: list)
            : BulkUpdateInput(transactionIds: ids, removeTagIds: list);
        summary = action == _BulkAction.addTags
            ? l10n.bulkAddTagsConfirm(ids.length, list.length)
            : l10n.bulkRemoveTagsConfirm(ids.length, list.length);
      }
    case _BulkAction.move:
      if (!context.mounted) {
        return null;
      }
      final AccountDto? account = await showAccountPicker(context);
      if (account != null) {
        input = BulkUpdateInput(transactionIds: ids, accountId: account.id);
        summary = l10n.bulkMoveConfirm(ids.length, account.name);
      }
  }
  if (input == null || summary == null || !context.mounted) {
    return null;
  }
  final bool confirmed = await showConfirmDialog(
    context,
    title: l10n.bulkEditTitleCount(ids.length),
    body: summary,
    confirmLabel: l10n.actionApply,
  );
  if (!confirmed || !context.mounted) {
    return null;
  }
  final ProviderContainer container = ProviderScope.containerOf(context);
  try {
    final int updated = await container
        .read(transactionsApiProvider)
        .bulkUpdate(input);
    container.read(financeRevisionProvider.notifier).bump();
    return updated;
  } on ApiException catch (error) {
    if (context.mounted) {
      showSnack(context, describeError(l10n, error));
    }
    return null;
  }
}
