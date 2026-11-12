import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';
import 'package:montra_mobile/features/payment_methods/presentation/payment_method_picker.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

/// Types offered as filters.
const List<TransactionDtoType> filterTypes = <TransactionDtoType>[
  TransactionDtoType.expense,
  TransactionDtoType.income,
  TransactionDtoType.transfer,
  TransactionDtoType.refund,
  TransactionDtoType.reimbursement,
  TransactionDtoType.adjustment,
  TransactionDtoType.openingBalance,
  TransactionDtoType.groupExpense,
  TransactionDtoType.settlement,
];

/// Opens the filter editor; returns the new filter or null when cancelled.
Future<TransactionFilter?> showTransactionFilters(
  BuildContext context,
  TransactionFilter current, {
  String? merchantName,
}) => Navigator.of(context).push<TransactionFilter>(
  MaterialPageRoute<TransactionFilter>(
    fullscreenDialog: true,
    builder: (BuildContext context) =>
        TransactionFilterScreen(initial: current, merchantName: merchantName),
  ),
);

/// Localized sort order.
String sortLabel(AppLocalizations l10n, String sort) => switch (sort) {
  'date_asc' => l10n.sortDateAsc,
  'amount_desc' => l10n.sortAmountDesc,
  'amount_asc' => l10n.sortAmountAsc,
  _ => l10n.sortDateDesc,
};

/// Localized status filter.
String statusFilterLabel(AppLocalizations l10n, String? status) =>
    switch (status) {
      'posted' => l10n.txStatusPosted,
      'pending' => l10n.txStatusPending,
      'draft' => l10n.txStatusDraft,
      'voided' => l10n.filterStatusDeleted,
      'all' => l10n.filterStatusAll,
      _ => l10n.filterStatusActive,
    };

/// The filter editor (public for tests).
class TransactionFilterScreen extends ConsumerStatefulWidget {
  /// Creates the editor starting from [initial].
  const TransactionFilterScreen({
    required this.initial,
    this.merchantName,
    super.key,
  });

  /// Filter being edited.
  final TransactionFilter initial;

  /// Name of the filtered merchant, when known.
  final String? merchantName;

  @override
  ConsumerState<TransactionFilterScreen> createState() =>
      _TransactionFilterScreenState();
}

class _TransactionFilterScreenState
    extends ConsumerState<TransactionFilterScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late TransactionFilter _f = widget.initial;
  late final TextEditingController _min = TextEditingController(
    text: widget.initial.minAmount ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.initial.maxAmount ?? '',
  );
  late String? _merchantName = widget.merchantName;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? get _amountCurrency {
    final String? chosen = _f.currency;
    if (chosen != null) {
      return chosen;
    }
    final AuthState auth = ref.read(authControllerProvider);
    return auth is SignedIn ? auth.user.baseCurrency : null;
  }

  void _apply() {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String? currency = _amountCurrency;
    String? read(TextEditingController c) => c.text.trim().isEmpty
        ? null
        : readAmount(
            context,
            ref,
            c.text,
            currency: currency,
            allowNegative: true,
            allowZero: true,
          ).value;
    final String? min = read(_min);
    final String? max = read(_max);
    Navigator.of(context).pop(
      _f.copyWith(
        clearAmounts: true,
        minAmount: min,
        maxAmount: max,
        currency: min != null || max != null ? currency : null,
      ),
    );
  }

  Future<void> _pickRange() async {
    final DateRangeChoice? choice = await showRangePicker(
      context,
      current: DateRangeChoice(range: _f.range, from: _f.from, to: _f.to),
      allowAny: true,
    );
    if (choice != null && mounted) {
      setState(
        () => _f = _f.copyWith(
          clearDates: true,
          range: choice.range,
          from: choice.from,
          to: choice.to,
        ),
      );
    }
  }

  String _countOrName(
    Set<String> ids,
    String Function(String id) nameOf,
    String Function(int count) many,
  ) {
    if (ids.isEmpty) {
      return context.l10n.filterAny;
    }
    if (ids.length == 1) {
      return nameOf(ids.first);
    }
    return many(ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final List<TagDto> tags = ref.watch(tagsProvider).value ?? <TagDto>[];
    final Map<String, PaymentMethodDto> methods = ref.watch(
      paymentMethodIndexProvider,
    );
    final DateRangeChoice range = DateRangeChoice(
      range: _f.range,
      from: _f.from,
      to: _f.to,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filtersTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () => setState(() {
              _f = widget.initial.cleared().copyWith(query: _f.query);
              _min.clear();
              _max.clear();
              _merchantName = null;
            }),
            child: Text(l10n.actionReset),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _apply,
            child: Text(l10n.filtersApply),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            SelectorField(
              label: l10n.filterDates,
              value: rangeChoiceLabel(l10n, range, locale: locale),
              icon: Icons.date_range_outlined,
              onTap: _pickRange,
              onClear: range.isAny
                  ? null
                  : () => setState(() => _f = _f.copyWith(clearDates: true)),
            ),
            FormSectionHeader(l10n.filterType),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                for (final TransactionDtoType type in filterTypes)
                  FilterChip(
                    label: Text(transactionTypeLabel(l10n, type)),
                    selected: _f.types.contains(type.json),
                    onSelected: (bool on) => setState(() {
                      final Set<String> next = Set<String>.of(_f.types);
                      if (on) {
                        next.add(type.json);
                      } else {
                        next.remove(type.json);
                      }
                      _f = _f.copyWith(types: next);
                    }),
                  ),
              ],
            ),
            FormSectionHeader(l10n.filterDirection),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(value: '', label: Text(l10n.filterAny)),
                ButtonSegment<String>(
                  value: 'inflow',
                  label: Text(l10n.directionIn),
                  icon: const Icon(Icons.south_west),
                ),
                ButtonSegment<String>(
                  value: 'outflow',
                  label: Text(l10n.directionOut),
                  icon: const Icon(Icons.north_east),
                ),
              ],
              selected: <String>{_f.direction ?? ''},
              onSelectionChanged: (Set<String> s) => setState(
                () => _f = s.first.isEmpty
                    ? _f.copyWith(clearDirection: true)
                    : _f.copyWith(direction: s.first),
              ),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.filterAccounts,
              icon: Icons.account_balance_wallet_outlined,
              value: _countOrName(
                _f.accountIds,
                (String id) => accounts[id]?.name ?? l10n.filterOneSelected,
                l10n.filterAccountsCount,
              ),
              onTap: () async {
                final Set<String>? ids = await showAccountMultiPicker(
                  context,
                  selectedIds: _f.accountIds,
                );
                if (ids != null && mounted) {
                  setState(() => _f = _f.copyWith(accountIds: ids));
                }
              },
              onClear: _f.accountIds.isEmpty
                  ? null
                  : () => setState(
                      () => _f = _f.copyWith(accountIds: <String>{}),
                    ),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.filterCategories,
              icon: Icons.category_outlined,
              value: _countOrName(
                _f.categoryIds,
                (String id) => categories[id] == null
                    ? l10n.filterOneSelected
                    : categoryName(l10n, categories[id]!),
                l10n.filterCategoriesCount,
              ),
              onTap: () async {
                final Set<String>? ids = await showCategoryMultiPicker(
                  context,
                  selectedIds: _f.categoryIds,
                );
                if (ids != null && mounted) {
                  setState(() => _f = _f.copyWith(categoryIds: ids));
                }
              },
              enabled: !_f.uncategorized,
              onClear: _f.categoryIds.isEmpty
                  ? null
                  : () => setState(
                      () => _f = _f.copyWith(categoryIds: <String>{}),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.filterUncategorized),
              subtitle: Text(l10n.filterUncategorizedHelp),
              value: _f.uncategorized,
              onChanged: (bool on) => setState(
                () => _f = on
                    ? _f.copyWith(uncategorized: true)
                    : _f.copyWith(uncategorized: false),
              ),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.filterTags,
              icon: Icons.sell_outlined,
              value: _countOrName(
                _f.tagIds,
                (String id) =>
                    tags.where((TagDto t) => t.id == id).firstOrNull?.name ??
                    l10n.filterOneSelected,
                l10n.filterTagsCount,
              ),
              onTap: () async {
                final Set<String>? ids = await showTagMultiPicker(
                  context,
                  selectedIds: _f.tagIds,
                );
                if (ids != null && mounted) {
                  setState(() => _f = _f.copyWith(tagIds: ids));
                }
              },
              onClear: _f.tagIds.isEmpty
                  ? null
                  : () => setState(() => _f = _f.copyWith(tagIds: <String>{})),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.filterMerchant,
              icon: Icons.storefront_outlined,
              value: _f.merchantId == null
                  ? l10n.filterAny
                  : (_merchantName ?? l10n.filterOneSelected),
              onTap: () async {
                final Picked<MerchantChoice>? picked = await showMerchantPicker(
                  context,
                  selectedId: _f.merchantId,
                  allowCreate: false,
                  allowNone: false,
                );
                final MerchantChoice? m = picked?.value;
                if (m?.id != null && mounted) {
                  setState(() {
                    _f = _f.copyWith(merchantId: m!.id);
                    _merchantName = m.name;
                  });
                }
              },
              onClear: _f.merchantId == null
                  ? null
                  : () => setState(() {
                      _f = _f.copyWith(clearMerchant: true);
                      _merchantName = null;
                    }),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.filterPaymentMethod,
              icon: Icons.credit_card_outlined,
              value: _f.paymentMethodId == null
                  ? l10n.filterAny
                  : (methods[_f.paymentMethodId]?.label ??
                        l10n.filterOneSelected),
              onTap: () async {
                final Picked<PaymentMethodDto>? picked =
                    await showPaymentMethodPicker(
                      context,
                      selectedId: _f.paymentMethodId,
                    );
                if (picked != null && mounted) {
                  setState(
                    () => _f = picked.value == null
                        ? _f.copyWith(clearPaymentMethod: true)
                        : _f.copyWith(paymentMethodId: picked.value!.id),
                  );
                }
              },
              onClear: _f.paymentMethodId == null
                  ? null
                  : () => setState(
                      () => _f = _f.copyWith(clearPaymentMethod: true),
                    ),
            ),
            FormSectionHeader(l10n.filterAmount),
            SelectorField(
              label: l10n.filterAmountCurrency,
              icon: Icons.currency_exchange,
              value: _amountCurrency,
              onTap: () async {
                final String? code = await showCurrencyPicker(
                  context,
                  selected: _amountCurrency,
                );
                if (code != null && mounted) {
                  setState(() => _f = _f.copyWith(currency: code));
                }
              },
            ),
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AmountField(
                    controller: _min,
                    label: l10n.filterMinAmount,
                    currency: _amountCurrency,
                    isRequired: false,
                    allowZero: true,
                    allowNegative: true,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: AmountField(
                    controller: _max,
                    label: l10n.filterMaxAmount,
                    currency: _amountCurrency,
                    isRequired: false,
                    allowZero: true,
                    allowNegative: true,
                  ),
                ),
              ],
            ),
            FormSectionHeader(l10n.filterMore),
            DropdownButtonFormField<String>(
              initialValue: _f.status ?? 'active',
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.filterStatus),
              items: <DropdownMenuItem<String>>[
                for (final String s in <String>[
                  'active',
                  'posted',
                  'pending',
                  'draft',
                  'voided',
                  'all',
                ])
                  DropdownMenuItem<String>(
                    value: s,
                    child: Text(statusFilterLabel(l10n, s)),
                  ),
              ],
              onChanged: (String? s) => setState(
                () => _f = s == null || s == 'active'
                    ? _f.copyWith(clearStatus: true)
                    : _f.copyWith(status: s),
              ),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String>(
              initialValue: _f.source ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.filterSource),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(l10n.filterAny),
                ),
                for (final String s in <String>[
                  'manual',
                  'import',
                  'receipt',
                  'recurring',
                  'integration',
                  'correction',
                  'group',
                  'system',
                ])
                  DropdownMenuItem<String>(
                    value: s,
                    child: Text(transactionSourceLabel(l10n, s)),
                  ),
              ],
              onChanged: (String? s) => setState(
                () => _f = s == null || s.isEmpty
                    ? _f.copyWith(clearSource: true)
                    : _f.copyWith(source: s),
              ),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String>(
              initialValue: _f.reconciliationState ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.filterReconciliation),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(l10n.filterAny),
                ),
                for (final TransactionDtoReconciliationState s
                    in TransactionDtoReconciliationState.values)
                  if (s != TransactionDtoReconciliationState.unrecognized)
                    DropdownMenuItem<String>(
                      value: s.json,
                      child: Text(reconciliationLabel(l10n, s)),
                    ),
              ],
              onChanged: (String? s) => setState(
                () => _f = s == null || s.isEmpty
                    ? _f.copyWith(clearReconciliation: true)
                    : _f.copyWith(reconciliationState: s),
              ),
            ),
            const SizedBox(height: Insets.md),
            _TriState(
              label: l10n.filterHasAttachment,
              value: _f.hasAttachment,
              onChanged: (String? v) => setState(
                () => _f = v == null
                    ? _f.copyWith(clearHasAttachment: true)
                    : _f.copyWith(hasAttachment: v),
              ),
            ),
            const SizedBox(height: Insets.md),
            _TriState(
              label: l10n.filterRecurring,
              value: _f.recurring,
              onChanged: (String? v) => setState(
                () => _f = v == null
                    ? _f.copyWith(clearRecurring: true)
                    : _f.copyWith(recurring: v),
              ),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String>(
              initialValue: _f.sort,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.filterSort),
              items: <DropdownMenuItem<String>>[
                for (final String s in transactionSorts)
                  DropdownMenuItem<String>(
                    value: s,
                    child: Text(sortLabel(l10n, s)),
                  ),
              ],
              onChanged: (String? s) =>
                  setState(() => _f = _f.copyWith(sort: s ?? 'date_desc')),
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}

class _TriState extends StatelessWidget {
  const _TriState({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DropdownButtonFormField<String>(
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(value: '', child: Text(l10n.filterAny)),
        DropdownMenuItem<String>(value: 'true', child: Text(l10n.filterYes)),
        DropdownMenuItem<String>(value: 'false', child: Text(l10n.filterNo)),
      ],
      onChanged: (String? v) => onChanged(v == null || v.isEmpty ? null : v),
    );
  }
}
