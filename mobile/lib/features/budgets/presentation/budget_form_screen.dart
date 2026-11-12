import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/budgets/presentation/allocation_editor.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_widgets.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// Creates a budget or edits one.
///
/// Edits send only what changed (`PATCH` with [BudgetPatch]: emptied text
/// fields as `""`, changed lists in full) with the `version` that was
/// loaded; the server applies the change from the current period on and a
/// concurrent change reloads the form and says so. Group budgets track all
/// of a group's expenses in the group's currency: as one total, or split
/// between current members (envelopes or zero-based); they take no
/// account, category or merchant filters. Personal budgets never split by
/// member, list merchants only as merchant budgets and accounts are
/// required for account budgets. The group is fixed once the budget
/// exists.
class BudgetFormScreen extends ConsumerWidget {
  /// Creates the form; [budgetId] switches to edit mode.
  const BudgetFormScreen({this.budgetId, super.key});

  /// Budget to edit, or null to create one.
  final String? budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = budgetId;
    if (id == null) {
      return const _BudgetForm();
    }
    final AppLocalizations l10n = context.l10n;
    return ref
        .watch(budgetDetailProvider(id))
        .when(
          skipLoadingOnReload: true,
          data: (BudgetDto b) => _BudgetForm(original: b),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.budgetEditTitle)),
            body: const LoadingStateView(),
          ),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: Text(l10n.budgetEditTitle)),
            body: ErrorStateView(
              error: error,
              onRetry: () => ref.invalidate(budgetDetailProvider(id)),
            ),
          ),
        );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({this.original});

  final BudgetDto? original;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _limit = TextEditingController();
  final TextEditingController _cap = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  BudgetInputBudgetType? _type = BudgetInputBudgetType.total;
  BudgetInputPeriod? _period = BudgetInputPeriod.monthly;
  String? _startsOn;
  String? _endsOn;
  String? _currency;
  String? _groupId;
  String? _groupName;
  List<String> _merchantIds = <String>[];
  final Map<String, String> _merchantNames = <String, String>{};
  Set<String> _accountIds = <String>{};
  Set<String> _excludedIds = <String>{};
  bool _includePending = false;
  bool _refundsRestore = true;
  bool _countGroupShares = true;
  bool _alertForecast = true;
  List<int> _thresholds = List<int>.of(budgetDefaultThresholds);
  BudgetInputRolloverPolicy _rollover = BudgetInputRolloverPolicy.none;
  BudgetInputVisibility _visibility = BudgetInputVisibility.private;
  List<AllocationDraft> _allocations = <AllocationDraft>[];
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  /// Bumped on reload so dropdowns show the reloaded values.
  int _generation = 0;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'budget_type': 'type',
    'period': 'period',
    'currency': 'currency',
    'limit': 'limit',
    'starts_on': 'startsOn',
    'ends_on': 'endsOn',
    'rollover_policy': 'rollover',
    'rollover_cap': 'cap',
    'included_account_ids': 'accounts',
    'excluded_category_ids': 'excluded',
    'merchant_ids': 'merchants',
    'alert_thresholds': 'thresholds',
    'allocations': 'allocations',
    'notes': 'notes',
    'group_id': 'group',
    'visibility': 'visibility',
  };

  bool get _editing => widget.original != null;

  bool get _group => _groupId != null;

  @override
  void initState() {
    super.initState();
    final BudgetDto? original = widget.original;
    if (original != null) {
      _load(original);
    } else {
      final AuthState auth = ref.read(authControllerProvider);
      _currency = auth is SignedIn ? auth.user.baseCurrency : null;
    }
  }

  @override
  void didUpdateWidget(covariant _BudgetForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final BudgetDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _load(next);
    }
  }

  void _load(BudgetDto b) {
    final BudgetInputBudgetType type = budgetInputType(b.budgetType);
    final BudgetInputPeriod period = budgetInputPeriod(b.period);
    final BudgetInputRolloverPolicy rollover = budgetInputRollover(
      b.rolloverPolicy,
    );
    _name.text = b.name;
    _limit.text = b.limit.amount;
    _cap.text = b.rolloverCap?.amount ?? '';
    _notes.text = b.notes ?? '';
    _type = type == BudgetInputBudgetType.unrecognized ? null : type;
    _period = period == BudgetInputPeriod.unrecognized ? null : period;
    _startsOn = b.startsOn;
    _endsOn = b.endsOn;
    _currency = b.currency;
    _groupId = b.groupId;
    _merchantIds = List<String>.of(b.merchantIds);
    _accountIds = <String>{...b.includedAccountIds};
    _excludedIds = <String>{...b.excludedCategoryIds};
    _includePending = b.includePending;
    _refundsRestore = b.refundsRestore;
    _countGroupShares = b.countGroupShares;
    _alertForecast = b.alertForecast;
    // An empty list means threshold alerts are off.
    _thresholds = List<int>.of(b.alertThresholds)..sort();
    _rollover = rollover == BudgetInputRolloverPolicy.unrecognized
        ? BudgetInputRolloverPolicy.none
        : rollover;
    _visibility = b.visibility == BudgetDtoVisibility.members
        ? BudgetInputVisibility.members
        : BudgetInputVisibility.private;
    _allocations = <AllocationDraft>[
      for (final AllocationDto a in b.allocations) AllocationDraft.fromDto(a),
    ];
    _generation++;
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _cap.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickGroup() async {
    final Picked<GroupDto>? picked = await showGroupPicker(
      context,
      selectedId: _groupId,
    );
    if (picked == null || !mounted) {
      return;
    }
    final GroupDto? group = picked.value;
    setState(() {
      _groupId = group?.id;
      _groupName = group?.name;
      if (group != null) {
        // Group budgets count all of the group's expenses in its currency:
        // as one total or split between members.
        if (!groupBudgetTypes.contains(_type)) {
          _type = BudgetInputBudgetType.total;
        }
        _currency = group.baseCurrency;
        _visibility = BudgetInputVisibility.members;
      } else {
        _visibility = BudgetInputVisibility.private;
      }
      _keepAllowedAllocations();
      _generation++;
    });
  }

  Future<void> _pickCurrency() async {
    final String? code = await showCurrencyPicker(context, selected: _currency);
    if (code != null && mounted) {
      setState(() => _currency = code);
    }
  }

  Future<void> _addMerchant() async {
    final Picked<MerchantChoice>? picked = await showMerchantPicker(
      context,
      allowCreate: false,
      allowNone: false,
    );
    final MerchantChoice? choice = picked?.value;
    final String? id = choice?.id;
    if (choice == null || id == null || !mounted) {
      return;
    }
    setState(() {
      _merchantNames[id] = choice.name;
      if (!_merchantIds.contains(id)) {
        _merchantIds = <String>[..._merchantIds, id];
      }
    });
  }

  Future<void> _pickAccounts() async {
    final Set<String>? ids = await showAccountMultiPicker(
      context,
      selectedIds: _accountIds,
    );
    if (ids != null && mounted) {
      setState(() => _accountIds = ids);
    }
  }

  Future<void> _pickExcluded() async {
    final Set<String>? ids = await showCategoryMultiPicker(
      context,
      selectedIds: _excludedIds,
    );
    if (ids != null && mounted) {
      setState(() => _excludedIds = ids);
    }
  }

  List<AllocationTarget> get _targets =>
      allocationTargetsFor(group: _group, type: _type);

  /// Drops allocations the budget's type (or group) no longer allows.
  void _keepAllowedAllocations() {
    final List<AllocationTarget> allowed = _targets;
    _allocations = <AllocationDraft>[
      for (final AllocationDraft a in _allocations)
        if (allowed.contains(a.target)) a,
    ];
  }

  Map<String, String> _memberNames() {
    final String? group = _groupId;
    return <String, String>{
      for (final MemberDto m in widget.original?.members ?? const <MemberDto>[])
        m.userId: m.displayName,
      if (group != null)
        for (final GroupMemberDto m
            in ref.watch(groupMembersProvider(group)).value ??
                const <GroupMemberDto>[])
          m.userId: m.displayName,
    };
  }

  Future<void> _editAllocation([int? index]) async {
    final AllocationDraft? draft = await showAllocationEditor(
      context,
      targets: _targets,
      currency: _currency,
      groupId: _groupId,
      initial: index == null ? null : _allocations[index],
      memberNames: _memberNames(),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      final List<AllocationDraft> next = List<AllocationDraft>.of(_allocations);
      if (index == null) {
        next.add(draft);
      } else {
        next[index] = draft;
      }
      _allocations = next;
    });
  }

  /// Checks what the server would reject anyway, so the user sees it next
  /// to the field without a round trip.
  Map<String, String> _localErrors(AppLocalizations l10n) {
    final BudgetInputBudgetType? type = _type;
    return <String, String>{
      if (_currency == null) 'currency': l10n.validationCurrencyRequired,
      if (_period == BudgetInputPeriod.custom && _endsOn == null)
        'endsOn': l10n.budgetEndsOnRequired,
      if (!_group &&
          type == BudgetInputBudgetType.merchant &&
          _merchantIds.isEmpty)
        'merchants': l10n.budgetMerchantsNeeded,
      if (!_group &&
          type == BudgetInputBudgetType.account &&
          _accountIds.isEmpty)
        'accounts': l10n.budgetAccountsNeeded,
      if (type != null && budgetNeedsAllocations(type) && _allocations.isEmpty)
        'allocations': l10n.budgetAllocationsNeeded,
    };
  }

  BudgetInput? _input(AppLocalizations l10n) {
    final String? currency = _currency;
    final BudgetInputBudgetType? type = _type;
    final BudgetInputPeriod? period = _period;
    if (currency == null || type == null || period == null) {
      return null;
    }
    final String? limit = readAmount(
      context,
      ref,
      _limit.text,
      currency: currency,
    ).value;
    if (limit == null) {
      return null;
    }
    final bool custom = period == BudgetInputPeriod.custom;
    final BudgetInputRolloverPolicy rollover = custom
        ? BudgetInputRolloverPolicy.none
        : _rollover;
    String? cap;
    if (rollover != BudgetInputRolloverPolicy.none &&
        _cap.text.trim().isNotEmpty) {
      cap = readAmount(
        context,
        ref,
        _cap.text,
        currency: currency,
        allowZero: true,
      ).value;
      if (cap == null) {
        return null;
      }
    }
    final String notes = _notes.text.trim();
    final BudgetDto? original = widget.original;
    // The whole form; edits send only the fields that differ from the
    // stored budget (see [_submit]).
    return BudgetInput(
      name: _name.text.trim(),
      budgetType: type,
      period: period,
      currency: currency,
      limit: limit,
      startsOn: _startsOn,
      endsOn: custom ? _endsOn : null,
      timezone: original?.timezone,
      rolloverPolicy: rollover,
      rolloverCap: cap,
      includePending: !_group && _includePending,
      refundsRestore: _refundsRestore,
      countGroupShares: _countGroupShares,
      includedAccountIds: _group ? <String>[] : _accountIds.toList(),
      excludedCategoryIds: _group ? <String>[] : _excludedIds.toList(),
      merchantIds: !_group && type == BudgetInputBudgetType.merchant
          ? _merchantIds
          : <String>[],
      alertThresholds: List<int>.of(_thresholds)..sort(),
      alertForecast: _alertForecast,
      visibility: _group ? _visibility : BudgetInputVisibility.private,
      notes: notes.isEmpty ? null : notes,
      groupId: _groupId,
      allocations: <AllocInput>[
        for (final AllocationDraft a in _allocations) a.toInput(),
      ],
      version: original?.version,
    );
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final BudgetRevision revision = ref.read(budgetRevisionProvider.notifier);
    final GoRouter router = GoRouter.of(context);
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    final bool valid = _form.currentState?.validate() ?? false;
    final Map<String, String> local = _localErrors(l10n);
    if (local.isNotEmpty) {
      setState(() => _errors = ServerFormErrors(fields: local));
    }
    if (!valid || local.isNotEmpty) {
      return;
    }
    final BudgetInput? input = _input(l10n);
    if (input == null) {
      return;
    }
    final BudgetsApi api = ref.read(budgetsApiProvider);
    final BudgetDto? original = widget.original;
    BudgetPatch? patch;
    if (original != null) {
      final Map<String, Object?> body = partialPatch(
        before: budgetInputOf(original).toJson(),
        after: input.toJson(),
        textFields: const <String>{'notes', 'ends_on', 'rollover_cap'},
      );
      if (!patchHasChanges(body)) {
        showSnack(context, l10n.budgetNothingChanged);
        router.pop(original);
        return;
      }
      patch = BudgetPatch.fromJson(body);
    }
    try {
      final BudgetDto saved = original == null || patch == null
          ? await api.create(input)
          : await api.update(original.id, patch);
      revision.bump();
      if (!mounted) {
        return;
      }
      if (original == null) {
        showSnack(context, l10n.budgetCreated);
        unawaited(
          router.pushReplacement<Object?>(AppRoutes.budgetDetail(saved.id)),
        );
      } else {
        ref.read(budgetDetailProvider(original.id).notifier).show(saved);
        showSnack(context, l10n.budgetSaved);
        router.pop(saved);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(budgetDetailProvider(original.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      final bool unallocated =
          error.code == ErrorObjectCode.domainRuleViolation &&
          error.details.any((Detail d) => d.code == 'zero_based_unallocated');
      setState(
        () => _errors = unallocated
            ? ServerFormErrors(
                fields: <String, String>{
                  'allocations': l10n.budgetZeroBasedUnallocated,
                },
              )
            : ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  String _moneyText(String amount) {
    final String? currency = _currency;
    if (currency == null) {
      return amount;
    }
    try {
      return MoneyFormatter.formatAmount(
        amount,
        currency,
        locale: numberLocaleOf(context, ref),
      );
    } on FormatException {
      return '$amount $currency';
    }
  }

  String _allocationsHelp(AppLocalizations l10n, BudgetInputBudgetType? type) =>
      switch (type) {
        BudgetInputBudgetType.zeroBased => l10n.budgetZeroBasedHelp,
        _ when _group => l10n.budgetAllocationsGroupHelp,
        final BudgetInputBudgetType t when budgetNeedsAllocations(t) =>
          budgetTypeHelp(l10n, t),
        BudgetInputBudgetType.merchant => l10n.budgetAllocationsMerchantHelp,
        BudgetInputBudgetType.account => l10n.budgetAllocationsAccountHelp,
        _ => l10n.budgetAllocationsHelp,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String? general = _errors.general;
    final BudgetInputBudgetType? type = _type;
    final BudgetInputPeriod? period = _period;
    final bool custom = period == BudgetInputPeriod.custom;
    final String? groupId = _groupId;
    final String? groupName = groupId == null
        ? null
        : _groupName ?? ref.watch(groupIndexProvider)[groupId]?.name;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final Map<String, String> memberNames = _memberNames();
    final bool envelopes =
        type == BudgetInputBudgetType.envelope ||
        type == BudgetInputBudgetType.zeroBased;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.budgetEditTitle : l10n.budgetNewTitle),
      ),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (_conflictReloaded) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.warning,
                message: l10n.versionConflictReloaded,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (_editing) ...<Widget>[
              NoticeBanner(message: l10n.budgetEditAppliesNote),
              const SizedBox(height: Insets.md),
            ],
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              maxLength: BudgetInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.budgetNameLabel,
                helperText: l10n.budgetNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.budgetGroupField),
              value: groupId == null
                  ? null
                  : (groupName ?? l10n.budgetGroupUnknown),
              placeholder: l10n.groupNone,
              icon: Icons.groups_outlined,
              helperText: _editing && groupId != null
                  ? l10n.budgetGroupFixed
                  : l10n.budgetGroupHelp,
              errorText: _errors['group'],
              enabled: !_editing,
              onTap: _editing ? null : _pickGroup,
            ),
            const SizedBox(height: Insets.md),
            if (type == null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.warning,
                message: l10n.budgetTypeUnknownNote,
              ),
              const SizedBox(height: Insets.sm),
            ],
            DropdownButtonFormField<BudgetInputBudgetType>(
              key: ValueKey<String>('type-$_generation'),
              initialValue: type,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.budgetTypeLabel,
                helperText: _group
                    ? l10n.budgetTypeGroupChoiceHelp
                    : (type == null ? null : budgetTypeHelp(l10n, type)),
                helperMaxLines: 3,
                errorText: _errors['type'],
              ),
              items: <DropdownMenuItem<BudgetInputBudgetType>>[
                for (final BudgetInputBudgetType t
                    in _group
                        ? <BudgetInputBudgetType>{...groupBudgetTypes, ?type}
                        : budgetTypeOrder)
                  DropdownMenuItem<BudgetInputBudgetType>(
                    value: t,
                    child: Row(
                      children: <Widget>[
                        Icon(budgetTypeIcon(t), size: 20),
                        const SizedBox(width: Insets.sm),
                        Flexible(child: Text(budgetTypeLabel(l10n, t))),
                      ],
                    ),
                  ),
              ],
              validator: (BudgetInputBudgetType? t) =>
                  t == null ? l10n.validationRequired : null,
              onChanged: (BudgetInputBudgetType? t) {
                if (t == null) {
                  return;
                }
                setState(() {
                  _type = t;
                  _keepAllowedAllocations();
                });
              },
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<BudgetInputPeriod>(
              key: ValueKey<String>('period-$_generation'),
              initialValue: period,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.budgetPeriodLabel,
                errorText: _errors['period'],
              ),
              items: <DropdownMenuItem<BudgetInputPeriod>>[
                for (final BudgetInputPeriod p in budgetPeriodOrder)
                  DropdownMenuItem<BudgetInputPeriod>(
                    value: p,
                    child: Text(budgetPeriodLabel(l10n, p)),
                  ),
              ],
              validator: (BudgetInputPeriod? p) =>
                  p == null ? l10n.validationRequired : null,
              onChanged: (BudgetInputPeriod? p) => setState(() => _period = p),
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.budgetStartsOnLabel,
              value: _startsOn,
              emptyLabel: l10n.dateToday,
              clearable: !_editing,
              errorText: _errors['startsOn'],
              onChanged: (String? d) => setState(() => _startsOn = d),
            ),
            if (custom) ...<Widget>[
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.budgetEndsOnLabel,
                value: _endsOn,
                clearable: true,
                errorText: _errors['endsOn'],
                onChanged: (String? d) => setState(() => _endsOn = d),
              ),
            ],
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.currencyFieldLabel,
              value: _currency,
              icon: Icons.currency_exchange,
              errorText: _errors['currency'],
              helperText: _group ? l10n.budgetCurrencyFromGroup : null,
              enabled: !_group,
              onTap: _group ? null : _pickCurrency,
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _limit,
              label: l10n.budgetLimitLabel,
              currency: _currency,
              helperText: l10n.budgetLimitHelp,
              errorText: _errors['limit'],
            ),
            if (!_group) ...<Widget>[
              FormSectionHeader(l10n.budgetScopeSection),
              if (type == BudgetInputBudgetType.merchant) ...<Widget>[
                _MerchantChips(
                  ids: _merchantIds,
                  names: _merchantNames,
                  errorText: _errors['merchants'],
                  onAdd: _addMerchant,
                  onRemove: (String id) => setState(
                    () => _merchantIds = <String>[
                      for (final String m in _merchantIds)
                        if (m != id) m,
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
              ],
              SelectorField(
                label: l10n.budgetAccountsLabel,
                value: _accountIds.isEmpty
                    ? null
                    : <String>[
                        for (final String id in _accountIds)
                          accounts[id]?.name ?? l10n.budgetAllocationRemoved,
                      ].join(', '),
                placeholder: l10n.budgetAccountsAll,
                icon: Icons.account_balance_outlined,
                errorText: _errors['accounts'],
                onTap: _pickAccounts,
                onClear: _accountIds.isEmpty
                    ? null
                    : () => setState(() => _accountIds = <String>{}),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.budgetExcludedLabel,
                value: _excludedIds.isEmpty
                    ? null
                    : <String>[
                        for (final String id in _excludedIds)
                          if (categories[id] case final CategoryDto c)
                            categoryName(l10n, c)
                          else
                            l10n.budgetAllocationRemoved,
                      ].join(', '),
                placeholder: l10n.budgetNothingExcluded,
                icon: Icons.filter_alt_off_outlined,
                errorText: _errors['excluded'],
                onTap: _pickExcluded,
                onClear: _excludedIds.isEmpty
                    ? null
                    : () => setState(() => _excludedIds = <String>{}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.budgetIncludePending),
                value: _includePending,
                onChanged: (bool v) => setState(() => _includePending = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.budgetRefundsRestore),
                value: _refundsRestore,
                onChanged: (bool v) => setState(() => _refundsRestore = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.budgetCountGroupShares),
                value: _countGroupShares,
                onChanged: (bool v) => setState(() => _countGroupShares = v),
              ),
            ],
            FormSectionHeader(
              envelopes
                  ? l10n.budgetEnvelopesTitle
                  : l10n.budgetAllocationsTitle,
            ),
            Text(_allocationsHelp(l10n, type), style: text.bodySmall),
            for (int i = 0; i < _allocations.length; i++)
              _AllocationRow(
                draft: _allocations[i],
                limitText: _moneyText(_allocations[i].limit),
                memberNames: memberNames,
                onEdit: () => _editAllocation(i),
                onRemove: () => setState(
                  () => _allocations = <AllocationDraft>[
                    for (int j = 0; j < _allocations.length; j++)
                      if (j != i) _allocations[j],
                  ],
                ),
              ),
            if (_errors['allocations'] case final String error)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  error,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: Insets.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: type == null ? null : _editAllocation,
                icon: const Icon(Icons.add),
                label: Text(l10n.budgetAllocationAdd),
              ),
            ),
            FormSectionHeader(l10n.budgetRolloverSection),
            if (custom)
              Text(l10n.budgetRolloverCustomNote, style: text.bodyMedium)
            else ...<Widget>[
              DropdownButtonFormField<BudgetInputRolloverPolicy>(
                key: ValueKey<String>('rollover-$_generation'),
                initialValue: _rollover,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.budgetRolloverLabel,
                  errorText: _errors['rollover'],
                ),
                items: <DropdownMenuItem<BudgetInputRolloverPolicy>>[
                  for (final BudgetInputRolloverPolicy r in rolloverOrder)
                    DropdownMenuItem<BudgetInputRolloverPolicy>(
                      value: r,
                      child: Text(budgetRolloverLabel(l10n, r)),
                    ),
                ],
                onChanged: (BudgetInputRolloverPolicy? r) {
                  if (r != null) {
                    setState(() => _rollover = r);
                  }
                },
              ),
              if (_rollover != BudgetInputRolloverPolicy.none) ...<Widget>[
                const SizedBox(height: Insets.md),
                AmountField(
                  controller: _cap,
                  label: l10n.optionalLabel(l10n.budgetRolloverCapLabel),
                  currency: _currency,
                  isRequired: false,
                  allowZero: true,
                  helperText: l10n.budgetRolloverCapHelp,
                  errorText: _errors['cap'],
                ),
              ],
            ],
            FormSectionHeader(l10n.budgetAlertsSection),
            _ThresholdChips(
              value: _thresholds,
              errorText: _errors['thresholds'],
              onChanged: (List<int> v) => setState(() => _thresholds = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.budgetForecastAlert),
              subtitle: Text(l10n.budgetForecastHelp),
              value: _alertForecast,
              onChanged: (bool v) => setState(() => _alertForecast = v),
            ),
            if (_group) ...<Widget>[
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<BudgetInputVisibility>(
                key: ValueKey<String>('visibility-$_generation'),
                initialValue: _visibility,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.budgetVisibilityLabel,
                  errorText: _errors['visibility'],
                ),
                items: <DropdownMenuItem<BudgetInputVisibility>>[
                  DropdownMenuItem<BudgetInputVisibility>(
                    value: BudgetInputVisibility.members,
                    child: Text(l10n.budgetVisibilityMembers),
                  ),
                  DropdownMenuItem<BudgetInputVisibility>(
                    value: BudgetInputVisibility.private,
                    child: Text(l10n.budgetVisibilityPrivate),
                  ),
                ],
                onChanged: (BudgetInputVisibility? v) {
                  if (v != null) {
                    setState(() => _visibility = v);
                  }
                },
              ),
            ],
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              maxLength: BudgetInput.notesMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.budgetCreateButton,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.draft,
    required this.limitText,
    required this.memberNames,
    required this.onEdit,
    required this.onRemove,
  });

  final AllocationDraft draft;
  final String limitText;
  final Map<String, String> memberNames;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (BuildContext context, WidgetRef ref, Widget? _) {
      final AppLocalizations l10n = context.l10n;
      final String name = allocationName(
        context,
        ref,
        label: draft.label,
        knownName: draft.targetName,
        categoryId: draft.target == AllocationTarget.category
            ? draft.targetId
            : null,
        merchantId: draft.target == AllocationTarget.merchant
            ? draft.targetId
            : null,
        accountId: draft.target == AllocationTarget.account
            ? draft.targetId
            : null,
        memberUserId: draft.target == AllocationTarget.member
            ? draft.targetId
            : null,
        memberNames: memberNames,
      );
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(name),
        subtitle: Text(limitText),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: l10n.budgetEditItem(name),
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: l10n.budgetRemoveItem(name),
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ],
        ),
      );
    },
  );
}

class _MerchantChips extends ConsumerWidget {
  const _MerchantChips({
    required this.ids,
    required this.names,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
  });

  final List<String> ids;
  final Map<String, String> names;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.budgetMerchantsLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String id in ids)
              Builder(
                builder: (BuildContext context) {
                  final String name =
                      names[id] ??
                      ref.watch(budgetMerchantProvider(id)).value?.name ??
                      l10n.loadingLabel;
                  return InputChip(
                    label: Text(name),
                    onDeleted: () => onRemove(id),
                    deleteButtonTooltipMessage: l10n.budgetRemoveItem(name),
                  );
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.budgetAddMerchant),
              onPressed: onAdd,
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _ThresholdChips extends StatelessWidget {
  const _ThresholdChips({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final List<int> value;
  final ValueChanged<List<int>> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Set<int> selected = value.toSet();
    final List<int> shown = <int>{
      ...budgetThresholdOptions,
      ...selected,
    }.toList()..sort();
    final bool full = selected.length >= budgetMaxThresholds;
    final String? error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.budgetThresholdsLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final int level in shown)
              FilterChip(
                label: Text(l10n.budgetThresholdValue(level)),
                selected: selected.contains(level),
                onSelected: full && !selected.contains(level)
                    ? null
                    : (bool on) {
                        final Set<int> next = <int>{...selected};
                        if (on) {
                          next.add(level);
                        } else {
                          next.remove(level);
                        }
                        onChanged(next.toList()..sort());
                      },
              ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        if (selected.isEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.budgetThresholdsNone,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => onChanged(const <int>[]),
              icon: const Icon(Icons.notifications_off_outlined),
              label: Text(l10n.budgetThresholdsClear),
            ),
          ),
        Text(
          error ?? l10n.budgetThresholdsChooseHelp(budgetMaxThresholds),
          style: theme.textTheme.bodySmall?.copyWith(
            color: error == null ? null : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
