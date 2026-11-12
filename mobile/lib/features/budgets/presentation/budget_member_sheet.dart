import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';

/// What the member sheet asks for: the role, an optional share of the
/// limit (exact decimal string), or removal.
@immutable
class BudgetMemberChoice {
  /// Creates the choice.
  const BudgetMemberChoice({
    required this.role,
    this.allocation,
    this.remove = false,
  });

  /// A request to remove the member.
  const BudgetMemberChoice.remove()
    : role = MemberInputRole.viewer,
      allocation = null,
      remove = true;

  /// Edit or view only.
  final MemberInputRole role;

  /// Their share of the limit, if any.
  final String? allocation;

  /// Whether the member should be removed instead.
  final bool remove;
}

/// Asks how [name] may use the budget. [existing] members can also be
/// removed. Returns null when dismissed.
Future<BudgetMemberChoice?> showBudgetMemberSheet(
  BuildContext context, {
  required String name,
  required String currency,
  bool existing = false,
  MemberDtoRole role = MemberDtoRole.viewer,
  Money? allocation,
}) => showModalBottomSheet<BudgetMemberChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => BudgetMemberSheet(
    name: name,
    currency: currency,
    existing: existing,
    role: role,
    allocation: allocation,
  ),
);

/// The sheet behind [showBudgetMemberSheet].
class BudgetMemberSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const BudgetMemberSheet({
    required this.name,
    required this.currency,
    this.existing = false,
    this.role = MemberDtoRole.viewer,
    this.allocation,
    super.key,
  });

  /// The person's name.
  final String name;

  /// The budget's currency.
  final String currency;

  /// Whether they are already a member.
  final bool existing;

  /// Current role.
  final MemberDtoRole role;

  /// Current share of the limit.
  final Money? allocation;

  @override
  ConsumerState<BudgetMemberSheet> createState() => _BudgetMemberSheetState();
}

class _BudgetMemberSheetState extends ConsumerState<BudgetMemberSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _allocation = TextEditingController();
  late MemberInputRole _role;

  @override
  void initState() {
    super.initState();
    _role = widget.role == MemberDtoRole.editor
        ? MemberInputRole.editor
        : MemberInputRole.viewer;
    _allocation.text = widget.allocation?.amount ?? '';
  }

  @override
  void dispose() {
    _allocation.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    String? allocation;
    if (_allocation.text.trim().isNotEmpty) {
      allocation = readAmount(
        context,
        ref,
        _allocation.text,
        currency: widget.currency,
        allowZero: true,
      ).value;
      if (allocation == null) {
        return;
      }
    }
    Navigator.of(context)
        .pop(BudgetMemberChoice(role: _role, allocation: allocation));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
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
                  widget.existing
                      ? l10n.budgetMemberEditTitle(widget.name)
                      : l10n.budgetMemberShareTitle(widget.name),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<MemberInputRole>(
                initialValue: _role,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.budgetRoleLabel),
                items: <DropdownMenuItem<MemberInputRole>>[
                  DropdownMenuItem<MemberInputRole>(
                    value: MemberInputRole.viewer,
                    child: Text(l10n.budgetRoleViewer),
                  ),
                  DropdownMenuItem<MemberInputRole>(
                    value: MemberInputRole.editor,
                    child: Text(l10n.budgetRoleEditor),
                  ),
                ],
                onChanged: (MemberInputRole? r) {
                  if (r != null) {
                    setState(() => _role = r);
                  }
                },
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _allocation,
                label: l10n.optionalLabel(l10n.budgetMemberAllocationLabel),
                currency: widget.currency,
                isRequired: false,
                allowZero: true,
                helperText: l10n.budgetMemberAllocationHelp,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  widget.existing
                      ? l10n.actionSave
                      : l10n.budgetMemberShareButton,
                ),
              ),
              if (widget.existing) ...<Widget>[
                const SizedBox(height: Insets.sm),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(const BudgetMemberChoice.remove()),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(l10n.budgetMemberRemove),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
