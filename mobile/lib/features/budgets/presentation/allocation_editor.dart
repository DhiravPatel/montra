import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/amount_input.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_widgets.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// What a budget allocation applies to (the contract allows one of a
/// category, merchant, account or group member, or just a name).
enum AllocationTarget {
  /// A category and its subcategories.
  category,

  /// A merchant.
  merchant,

  /// An account.
  account,

  /// A group member's share (group budgets).
  member,

  /// A named part of the limit without a target.
  name,
}

/// An allocation being edited in the budget form.
@immutable
class AllocationDraft {
  /// Creates a draft; [limit] is the API's decimal string.
  const AllocationDraft({
    required this.target,
    required this.limit,
    this.targetId,
    this.targetName,
    this.label,
  });

  /// A draft of a saved allocation.
  factory AllocationDraft.fromDto(AllocationDto a) => AllocationDraft(
    target: switch (a) {
      AllocationDto(categoryId: String()) => AllocationTarget.category,
      AllocationDto(merchantId: String()) => AllocationTarget.merchant,
      AllocationDto(accountId: String()) => AllocationTarget.account,
      AllocationDto(memberUserId: String()) => AllocationTarget.member,
      _ => AllocationTarget.name,
    },
    targetId: a.categoryId ?? a.merchantId ?? a.accountId ?? a.memberUserId,
    label: a.label,
    limit: a.limit.amount,
  );

  /// What it applies to.
  final AllocationTarget target;

  /// The category, merchant, account or member ID.
  final String? targetId;

  /// The target's name when it was just chosen (display only).
  final String? targetName;

  /// Its own name, if any.
  final String? label;

  /// The limit as an exact decimal string.
  final String limit;

  /// The request body item.
  AllocInput toInput() {
    final String? name = label?.trim();
    return AllocInput(
      limit: limit,
      label: name == null || name.isEmpty ? null : name,
      categoryId: target == AllocationTarget.category ? targetId : null,
      merchantId: target == AllocationTarget.merchant ? targetId : null,
      accountId: target == AllocationTarget.account ? targetId : null,
      memberUserId: target == AllocationTarget.member ? targetId : null,
    );
  }

  /// The [AllocationTitle] for this draft.
  AllocationTitle title({
    Map<String, String> memberNames = const <String, String>{},
    TextStyle? style,
  }) => AllocationTitle(
    label: label,
    knownName: targetName,
    categoryId: target == AllocationTarget.category ? targetId : null,
    merchantId: target == AllocationTarget.merchant ? targetId : null,
    accountId: target == AllocationTarget.account ? targetId : null,
    memberUserId: target == AllocationTarget.member ? targetId : null,
    memberNames: memberNames,
    style: style,
  );
}

/// The allocation targets allowed for a budget: group budgets are split
/// between current members only; personal budgets never by member, by
/// merchant only in merchant budgets and by account only in account
/// budgets (category, envelope and zero-based budgets by category only).
List<AllocationTarget> allocationTargetsFor({
  required bool group,
  required BudgetInputBudgetType? type,
}) {
  if (group) {
    return const <AllocationTarget>[AllocationTarget.member];
  }
  if (type != null && budgetCategoryAllocations(type)) {
    return const <AllocationTarget>[AllocationTarget.category];
  }
  return <AllocationTarget>[
    AllocationTarget.category,
    if (type == BudgetInputBudgetType.merchant) AllocationTarget.merchant,
    if (type == BudgetInputBudgetType.account) AllocationTarget.account,
    AllocationTarget.name,
  ];
}

String _targetLabel(AppLocalizations l10n, AllocationTarget t) => switch (t) {
  AllocationTarget.category => l10n.budgetAllocationTargetCategory,
  AllocationTarget.merchant => l10n.budgetAllocationTargetMerchant,
  AllocationTarget.account => l10n.budgetAllocationTargetAccount,
  AllocationTarget.member => l10n.budgetAllocationTargetMember,
  AllocationTarget.name => l10n.budgetAllocationTargetName,
};

/// Opens the allocation editor. [targets] are the kinds allowed for the
/// budget; [groupId] lets member shares pick from the group. Returns the
/// edited draft, or null when dismissed.
Future<AllocationDraft?> showAllocationEditor(
  BuildContext context, {
  required List<AllocationTarget> targets,
  required String? currency,
  String? groupId,
  AllocationDraft? initial,
  Map<String, String> memberNames = const <String, String>{},
}) => showModalBottomSheet<AllocationDraft>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => AllocationEditorSheet(
    targets: targets,
    currency: currency,
    groupId: groupId,
    initial: initial,
    memberNames: memberNames,
  ),
);

/// The sheet behind [showAllocationEditor].
class AllocationEditorSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const AllocationEditorSheet({
    required this.targets,
    required this.currency,
    this.groupId,
    this.initial,
    this.memberNames = const <String, String>{},
    super.key,
  });

  /// Allowed kinds of target.
  final List<AllocationTarget> targets;

  /// The budget's currency.
  final String? currency;

  /// The budget's group, for member shares.
  final String? groupId;

  /// The allocation being edited.
  final AllocationDraft? initial;

  /// Member names by user ID.
  final Map<String, String> memberNames;

  @override
  ConsumerState<AllocationEditorSheet> createState() =>
      _AllocationEditorSheetState();
}

class _AllocationEditorSheetState extends ConsumerState<AllocationEditorSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _label = TextEditingController();
  final TextEditingController _limit = TextEditingController();
  late AllocationTarget _target;
  String? _targetId;
  String? _targetName;
  bool _targetMissing = false;

  @override
  void initState() {
    super.initState();
    final AllocationDraft? a = widget.initial;
    _target = a != null && widget.targets.contains(a.target)
        ? a.target
        : widget.targets.first;
    _targetId = a?.target == _target ? a?.targetId : null;
    _targetName = a?.target == _target ? a?.targetName : null;
    _label.text = a?.label ?? '';
    _limit.text = a?.limit ?? '';
  }

  @override
  void dispose() {
    _label.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickTarget() async {
    final AppLocalizations l10n = context.l10n;
    String? id;
    String? name;
    switch (_target) {
      case AllocationTarget.category:
        final Picked<CategoryDto>? picked = await showCategoryPicker(
          context,
          kind: CategoryKindFilter.spending,
          selectedId: _targetId,
          allowNone: false,
        );
        id = picked?.value?.id;
      case AllocationTarget.merchant:
        final Picked<MerchantChoice>? picked = await showMerchantPicker(
          context,
          selectedId: _targetId,
          allowCreate: false,
          allowNone: false,
        );
        id = picked?.value?.id;
        name = picked?.value?.name;
      case AllocationTarget.account:
        final AccountDto? account = await showAccountPicker(
          context,
          selectedId: _targetId,
          currency: widget.currency,
        );
        id = account?.id;
      case AllocationTarget.member:
        final PersonChoice? person = await showPersonPicker(
          context,
          groupId: widget.groupId,
        );
        id = person?.userId;
        name = person == null
            ? null
            : l10n.budgetAllocationMember(person.displayName);
      case AllocationTarget.name:
        return;
    }
    if (id != null && mounted) {
      setState(() {
        _targetId = id;
        _targetName = name;
        _targetMissing = false;
      });
    }
  }

  void _save() {
    final bool needsTarget = _target != AllocationTarget.name;
    setState(() => _targetMissing = needsTarget && _targetId == null);
    if (!(_form.currentState?.validate() ?? false) || _targetMissing) {
      return;
    }
    final AmountParseResult limit = readAmount(
      context,
      ref,
      _limit.text,
      currency: widget.currency,
      allowZero: true,
    );
    final String? value = limit.value;
    if (value == null) {
      return;
    }
    Navigator.of(context).pop(
      AllocationDraft(
        target: _target,
        targetId: needsTarget ? _targetId : null,
        targetName: needsTarget ? _targetName : null,
        label: _label.text.trim(),
        limit: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? targetId = _targetId;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.lg),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  widget.initial == null
                      ? l10n.budgetAllocationAdd
                      : l10n.budgetAllocationEdit,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Insets.md),
              if (widget.targets.length > 1) ...<Widget>[
                DropdownButtonFormField<AllocationTarget>(
                  initialValue: _target,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.budgetAllocationTargetLabel,
                  ),
                  items: <DropdownMenuItem<AllocationTarget>>[
                    for (final AllocationTarget t in widget.targets)
                      DropdownMenuItem<AllocationTarget>(
                        value: t,
                        child: Text(_targetLabel(l10n, t)),
                      ),
                  ],
                  onChanged: (AllocationTarget? t) {
                    if (t != null && t != _target) {
                      setState(() {
                        _target = t;
                        _targetId = null;
                        _targetName = null;
                        _targetMissing = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: Insets.md),
              ],
              if (_target != AllocationTarget.name) ...<Widget>[
                SelectorField(
                  label: _targetLabel(l10n, _target),
                  value: targetId == null
                      ? null
                      : allocationName(
                          context,
                          ref,
                          knownName: _targetName,
                          categoryId: _target == AllocationTarget.category
                              ? targetId
                              : null,
                          merchantId: _target == AllocationTarget.merchant
                              ? targetId
                              : null,
                          accountId: _target == AllocationTarget.account
                              ? targetId
                              : null,
                          memberUserId: _target == AllocationTarget.member
                              ? targetId
                              : null,
                          memberNames: widget.memberNames,
                        ),
                  placeholder: l10n.budgetAllocationChoose,
                  errorText: _targetMissing
                      ? l10n.budgetAllocationTargetRequired
                      : null,
                  onTap: _pickTarget,
                ),
                const SizedBox(height: Insets.md),
              ],
              TextFormField(
                controller: _label,
                maxLength: AllocInput.labelMaxLength,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _target == AllocationTarget.name
                      ? l10n.budgetAllocationNameLabel
                      : l10n.optionalLabel(l10n.budgetAllocationNameLabel),
                  counterText: '',
                ),
                validator: (String? v) =>
                    _target == AllocationTarget.name && (v ?? '').trim().isEmpty
                    ? l10n.validationRequired
                    : null,
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _limit,
                label: l10n.budgetLimitLabel,
                currency: widget.currency,
                allowZero: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
