import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

/// The first page of transactions matching a filter (picker results).
final FutureProviderFamily<List<TransactionDto>, TransactionFilter>
transactionPickerResultsProvider = FutureProvider.autoDispose
    .family<List<TransactionDto>, TransactionFilter>((
      Ref ref,
      TransactionFilter filter,
    ) async {
      ref.watch(financeRevisionProvider);
      final CursorPage<TransactionDto> page = await ref
          .read(transactionsApiProvider)
          .list(filter, limit: 50);
      return page.items;
    });

/// Picks one transaction, searching as the user types. [filter] narrows the
/// choices (for example to expenses); [excludeIds] are left out. Returns
/// null when dismissed.
Future<TransactionDto?> showTransactionPicker(
  BuildContext context, {
  TransactionFilter filter = const TransactionFilter(),
  Set<String> excludeIds = const <String>{},
  String? title,
}) => showModalBottomSheet<TransactionDto>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => TransactionPickerSheet(
    filter: filter,
    excludeIds: excludeIds,
    title: title ?? context.l10n.transactionPickerTitle,
  ),
);

/// The sheet behind [showTransactionPicker].
class TransactionPickerSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const TransactionPickerSheet({
    required this.filter,
    required this.title,
    this.excludeIds = const <String>{},
    super.key,
  });

  /// Base filter for the choices.
  final TransactionFilter filter;

  /// Sheet title.
  final String title;

  /// Transactions not offered.
  final Set<String> excludeIds;

  @override
  ConsumerState<TransactionPickerSheet> createState() =>
      _TransactionPickerSheetState();
}

class _TransactionPickerSheetState
    extends ConsumerState<TransactionPickerSheet> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _search = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TransactionFilter filter = widget.filter.copyWith(
      query: _search.isEmpty ? null : _search,
      clearQuery: _search.isEmpty,
    );
    final AsyncValue<List<TransactionDto>> results = ref.watch(
      transactionPickerResultsProvider(filter),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: TextField(
              controller: _query,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.transactionPickerSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: results.when(
              skipLoadingOnReload: true,
              loading: () => const LoadingStateView(),
              error: (Object error, StackTrace _) => ErrorStateView(
                error: error,
                onRetry: () =>
                    ref.invalidate(transactionPickerResultsProvider(filter)),
              ),
              data: (List<TransactionDto> data) {
                final List<TransactionDto> shown = data
                    .where(
                      (TransactionDto t) => !widget.excludeIds.contains(t.id),
                    )
                    .toList();
                if (shown.isEmpty) {
                  return MessageStateView(
                    icon: Icons.search_off,
                    title: l10n.transactionPickerEmpty,
                  );
                }
                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (BuildContext context, int i) => TransactionTile(
                    transaction: shown[i],
                    onTap: () => Navigator.of(context).pop(shown[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
