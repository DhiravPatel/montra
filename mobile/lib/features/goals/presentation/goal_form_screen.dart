import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
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
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// Most milestones a goal can have (contract `maxItems`).
const int goalMaxMilestones = 10;

/// The server's default milestones, offered when a goal is created.
const List<int> goalDefaultMilestones = <int>[25, 50, 75, 100];

/// Creates a goal (with an `Idempotency-Key`, so a retry never creates a
/// second one), or edits one when [goalId] is given. Edits send only what
/// changed ([GoalPatch]: emptied text as `""`, a removed account or group
/// in `clear`) with the loaded `version`; a concurrent change reloads the
/// form. The currency can't change once the goal exists.
class GoalFormScreen extends ConsumerWidget {
  /// Creates the form.
  const GoalFormScreen({this.goalId, super.key});

  /// Goal to edit, or null to create one.
  final String? goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = goalId;
    if (id == null) {
      return const _GoalForm();
    }
    final AppLocalizations l10n = context.l10n;
    return ref
        .watch(goalDetailProvider(id))
        .when(
          skipLoadingOnReload: true,
          data: (GoalDto goal) => _GoalForm(original: goal),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.goalEditTitle)),
            body: const LoadingStateView(),
          ),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: Text(l10n.goalEditTitle)),
            body: ErrorStateView(
              error: error,
              onRetry: () => ref.invalidate(goalDetailProvider(id)),
            ),
          ),
        );
  }
}

/// Editable milestone: percent of the target and an optional label.
class _MilestoneRow {
  _MilestoneRow({int? percent, String? label})
    : percent = TextEditingController(text: percent?.toString() ?? ''),
      label = TextEditingController(text: label ?? '');

  final TextEditingController percent;
  final TextEditingController label;
  final Key key = UniqueKey();

  void dispose() {
    percent.dispose();
    label.dispose();
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.original});

  final GoalDto? original;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _starting = TextEditingController();
  final TextEditingController _planned = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  List<_MilestoneRow> _milestones = <_MilestoneRow>[];

  GoalInputGoalType? _type;
  String? _currency;
  String? _startDate;
  String? _targetDate;
  GoalInputContributionSchedule _schedule = GoalInputContributionSchedule.none;
  int _priority = 3;
  String? _accountId;
  bool _reminders = false;
  GoalInputVisibility _visibility = GoalInputVisibility.private;
  String? _groupId;
  String? _groupName;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;
  final IdempotentSubmission _submission = IdempotentSubmission();

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'goal_type': 'type',
    'target_amount': 'target',
    'currency': 'currency',
    'starting_amount': 'starting',
    'start_date': 'startDate',
    'target_date': 'targetDate',
    'contribution_schedule': 'schedule',
    'planned_contribution': 'planned',
    'priority': 'priority',
    'linked_account_id': 'account',
    'milestones': 'milestones',
    'reminders_enabled': 'reminders',
    'visibility': 'visibility',
    'group_id': 'group',
    'description': 'description',
    'notes': 'notes',
  };

  bool get _editing => widget.original != null;

  @override
  void initState() {
    super.initState();
    final GoalDto? original = widget.original;
    if (original != null) {
      _load(original);
    } else {
      final AuthState auth = ref.read(authControllerProvider);
      _currency = auth is SignedIn ? auth.user.baseCurrency : null;
      _milestones = <_MilestoneRow>[
        for (final int p in goalDefaultMilestones) _MilestoneRow(percent: p),
      ];
    }
  }

  @override
  void didUpdateWidget(covariant _GoalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final GoalDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _load(next);
    }
  }

  void _load(GoalDto g) {
    _name.text = g.name;
    _type = goalTypeOf(g);
    _currency = g.target.currency;
    _target.text = g.target.amount;
    _starting.text = g.starting.amountMinor == 0 ? '' : g.starting.amount;
    _startDate = g.startDate;
    _targetDate = g.targetDate;
    _schedule = goalScheduleOf(g);
    _planned.text = g.plannedContribution?.amount ?? '';
    _priority = g.priority.clamp(1, 5);
    _accountId = g.linkedAccountId;
    _reminders = g.remindersEnabled;
    _visibility = g.visibility == GoalDtoVisibility.members
        ? GoalInputVisibility.members
        : GoalInputVisibility.private;
    _groupId = g.groupId;
    _groupName = null;
    _description.text = g.description ?? '';
    _notes.text = g.notes ?? '';
    // The old fields leave the tree on the next build; dispose after it.
    final List<_MilestoneRow> old = _milestones;
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final _MilestoneRow row in old) {
          row.dispose();
        }
      });
    }
    _milestones = <_MilestoneRow>[
      for (final GoalMilestone m
          in <GoalMilestone>[...g.milestones]..sort(
            (GoalMilestone a, GoalMilestone b) =>
                a.percent.compareTo(b.percent),
          ))
        _MilestoneRow(percent: m.percent, label: m.label),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _starting.dispose();
    _planned.dispose();
    _description.dispose();
    _notes.dispose();
    for (final _MilestoneRow row in _milestones) {
      row.dispose();
    }
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickCurrency() async {
    final String? code = await showCurrencyPicker(context, selected: _currency);
    if (code != null && mounted) {
      setState(() => _currency = code);
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? account = await showAccountPicker(
      context,
      selectedId: _accountId,
    );
    if (account != null && mounted) {
      setState(() => _accountId = account.id);
    }
  }

  Future<void> _pickGroup() async {
    final Picked<GroupDto>? picked = await showGroupPicker(
      context,
      selectedId: _groupId,
    );
    if (picked != null && mounted) {
      setState(() {
        _groupId = picked.value?.id;
        _groupName = picked.value?.name;
      });
    }
  }

  void _addMilestone() {
    if (_milestones.length >= goalMaxMilestones) {
      return;
    }
    setState(
      () => _milestones = <_MilestoneRow>[..._milestones, _MilestoneRow()],
    );
  }

  void _removeMilestone(_MilestoneRow row) {
    setState(
      () => _milestones = <_MilestoneRow>[
        for (final _MilestoneRow r in _milestones)
          if (r != row) r,
      ],
    );
    // Dispose after the field has left the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  String? _validatePercent(AppLocalizations l10n, _MilestoneRow row) {
    final int? value = int.tryParse(row.percent.text.trim());
    if (value == null || value < 1 || value > 100) {
      return l10n.milestonePercentInvalid;
    }
    final int same = _milestones
        .where(
          (_MilestoneRow r) => int.tryParse(r.percent.text.trim()) == value,
        )
        .length;
    return same > 1 ? l10n.milestoneDuplicate : null;
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String? currency = _currency;
    final GoalInputGoalType? type = _type;
    if (currency == null || type == null) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{
            if (currency == null) 'currency': l10n.validationCurrencyRequired,
            if (type == null) 'type': l10n.goalTypeRequired,
          },
        ),
      );
      return;
    }
    final String? target = readAmount(
      context,
      ref,
      _target.text,
      currency: currency,
    ).value;
    if (target == null) {
      return;
    }
    final String? starting = _starting.text.trim().isEmpty
        ? null
        : readAmount(
            context,
            ref,
            _starting.text,
            currency: currency,
            allowZero: true,
          ).value;
    final bool scheduled = _schedule != GoalInputContributionSchedule.none;
    final String? planned = !scheduled || _planned.text.trim().isEmpty
        ? null
        : readAmount(context, ref, _planned.text, currency: currency).value;
    final GoalDto? original = widget.original;
    final GoalInput input = GoalInput(
      name: _name.text.trim(),
      goalType: type,
      targetAmount: target,
      currency: currency,
      startingAmount: starting,
      startDate: _startDate,
      targetDate: _targetDate,
      contributionSchedule: _schedule,
      plannedContribution: planned,
      priority: _priority,
      linkedAccountId: _accountId,
      // On create the list replaces the default milestones; edits send it
      // only when it changed ([] removes them all).
      milestones:
          <GoalMilestoneInput>[
            for (final _MilestoneRow row in _milestones)
              GoalMilestoneInput(
                percent: int.parse(row.percent.text.trim()),
                label: _trimmed(row.label),
              ),
          ]..sort(
            (GoalMilestoneInput a, GoalMilestoneInput b) =>
                a.percent.compareTo(b.percent),
          ),
      remindersEnabled: _reminders,
      visibility: _visibility,
      groupId: _groupId,
      description: _trimmed(_description),
      notes: _trimmed(_notes),
      version: original?.version,
    );
    final GoalsApi api = ref.read(goalsApiProvider);
    final GoalsRevision revision = ref.read(goalsRevisionProvider.notifier);
    GoalPatch? patch;
    if (original != null) {
      final Map<String, Object?> body = partialPatch(
        before: goalInputOf(original).toJson(),
        after: input.toJson(),
        clearable: const <String>{'linked_account_id', 'group_id'},
        textFields: const <String>{
          'description',
          'notes',
          'target_date',
          'planned_contribution',
          'starting_amount',
        },
      );
      if (!patchHasChanges(body)) {
        showSnack(context, l10n.goalNothingChanged);
        context.pop(original);
        return;
      }
      patch = GoalPatch.fromJson(body);
    }
    try {
      final GoalDto saved = original == null || patch == null
          ? await api.create(input, key: _submission.keyFor(input.toJson()))
          : await api.update(original.id, patch);
      _submission.reset();
      revision.bump();
      if (!mounted) {
        return;
      }
      showSnack(
        context,
        original == null ? l10n.goalCreatedDone : l10n.goalSavedDone,
      );
      if (original == null) {
        context.pushReplacement(AppRoutes.goalDetail(saved.id));
      } else {
        context.pop(saved);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(goalDetailProvider(original.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? general = _errors.general;
    final String? accountId = _accountId;
    final String? accountName = accountId == null
        ? null
        : ref.watch(accountIndexProvider)[accountId]?.name;
    final String? groupId = _groupId;
    final String? groupName = groupId == null
        ? null
        : _groupName ?? ref.watch(groupIndexProvider)[groupId]?.name;
    final bool scheduled = _schedule != GoalInputContributionSchedule.none;
    final String? milestonesError = _errors['milestones'];
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l10n.goalEditTitle : l10n.goalNew)),
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
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.goalNameLabel,
                helperText: l10n.goalNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<GoalInputGoalType>(
              key: ValueKey<String>('type-${widget.original?.version}'),
              initialValue: _type,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.goalTypeLabel,
                errorText: _errors['type'],
              ),
              items: <DropdownMenuItem<GoalInputGoalType>>[
                for (final GoalInputGoalType t in goalTypeOrder)
                  DropdownMenuItem<GoalInputGoalType>(
                    value: t,
                    child: Row(
                      children: <Widget>[
                        Icon(goalTypeIcon(t), size: 20),
                        const SizedBox(width: Insets.sm),
                        Flexible(child: Text(goalTypeLabel(l10n, t))),
                      ],
                    ),
                  ),
              ],
              validator: (GoalInputGoalType? t) =>
                  t == null ? l10n.goalTypeRequired : null,
              onChanged: (GoalInputGoalType? t) => setState(() => _type = t),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.currencyFieldLabel,
              value: _currency,
              icon: Icons.currency_exchange,
              helperText: _editing ? l10n.goalCurrencyFixed : null,
              errorText: _errors['currency'],
              enabled: !_editing,
              onTap: _editing ? null : _pickCurrency,
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _target,
              label: l10n.goalTargetAmountLabel,
              currency: _currency,
              errorText: _errors['target'],
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _starting,
              label: l10n.optionalLabel(l10n.goalStartingAmountLabel),
              currency: _currency,
              isRequired: false,
              allowZero: true,
              helperText: l10n.goalStartingAmountHelp,
              errorText: _errors['starting'],
            ),
            FormSectionHeader(l10n.goalDatesSection),
            DateSelectorField(
              label: l10n.goalStartDateLabel,
              value: _startDate,
              emptyLabel: l10n.dateToday,
              clearable: true,
              errorText: _errors['startDate'],
              onChanged: (String? d) => setState(() => _startDate = d),
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.optionalLabel(l10n.goalTargetDateLabel),
              value: _targetDate,
              emptyLabel: l10n.notSetLabel,
              clearable: true,
              helperText: l10n.goalTargetDateHelp,
              errorText: _errors['targetDate'],
              onChanged: (String? d) => setState(() => _targetDate = d),
            ),
            FormSectionHeader(l10n.goalPlanSection),
            DropdownButtonFormField<GoalInputContributionSchedule>(
              key: ValueKey<String>('schedule-${widget.original?.version}'),
              initialValue: _schedule,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.goalScheduleLabel,
                errorText: _errors['schedule'],
              ),
              items: <DropdownMenuItem<GoalInputContributionSchedule>>[
                for (final GoalInputContributionSchedule s in goalScheduleOrder)
                  DropdownMenuItem<GoalInputContributionSchedule>(
                    value: s,
                    child: Text(goalScheduleLabel(l10n, s)),
                  ),
              ],
              onChanged: (GoalInputContributionSchedule? s) => setState(
                () => _schedule = s ?? GoalInputContributionSchedule.none,
              ),
            ),
            if (scheduled) ...<Widget>[
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _planned,
                label: l10n.optionalLabel(l10n.goalPlannedContributionLabel),
                currency: _currency,
                isRequired: false,
                errorText: _errors['planned'],
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.goalRemindersLabel),
              value: _reminders,
              onChanged: (bool v) => setState(() => _reminders = v),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<int>(
              key: ValueKey<String>('priority-${widget.original?.version}'),
              initialValue: _priority,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.goalPriorityLabel,
                helperText: l10n.goalPriorityHelp,
                errorText: _errors['priority'],
              ),
              items: <DropdownMenuItem<int>>[
                for (int p = 1; p <= 5; p++)
                  DropdownMenuItem<int>(
                    value: p,
                    child: Text(goalPriorityLabel(l10n, p)),
                  ),
              ],
              onChanged: (int? p) => setState(() => _priority = p ?? 3),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.goalLinkedAccountLabel),
              value: accountName,
              placeholder: l10n.goalLinkedAccountNone,
              icon: Icons.account_balance_outlined,
              helperText: l10n.goalLinkedAccountHelp,
              errorText: _errors['account'],
              onTap: _pickAccount,
              onClear: accountId == null
                  ? null
                  : () => setState(() => _accountId = null),
            ),
            FormSectionHeader(l10n.milestonesTitle),
            Text(l10n.milestonesHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: Insets.sm),
            for (final _MilestoneRow row in _milestones)
              _MilestoneEditor(
                key: row.key,
                row: row,
                validatePercent: () => _validatePercent(l10n, row),
                onRemove: () => _removeMilestone(row),
              ),
            if (milestonesError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  milestonesError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_milestones.length < goalMaxMilestones)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addMilestone,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.milestoneAdd),
                ),
              ),
            FormSectionHeader(l10n.goalSharingSection),
            SegmentedButton<GoalInputVisibility>(
              segments: <ButtonSegment<GoalInputVisibility>>[
                ButtonSegment<GoalInputVisibility>(
                  value: GoalInputVisibility.private,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(l10n.goalVisibilityPrivate),
                ),
                ButtonSegment<GoalInputVisibility>(
                  value: GoalInputVisibility.members,
                  icon: const Icon(Icons.group_outlined),
                  label: Text(l10n.goalVisibilityMembers),
                ),
              ],
              selected: <GoalInputVisibility>{_visibility},
              onSelectionChanged: (Set<GoalInputVisibility> s) =>
                  setState(() => _visibility = s.first),
            ),
            const SizedBox(height: Insets.xs),
            Text(l10n.goalVisibilityHelp, style: theme.textTheme.bodySmall),
            if (_errors['visibility'] case final String e)
              Text(
                e,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.goalGroupLabel),
              value: groupName,
              placeholder: l10n.groupNone,
              icon: Icons.groups_outlined,
              helperText: l10n.goalGroupHelp,
              errorText: _errors['group'],
              onTap: _pickGroup,
              onClear: groupId == null
                  ? null
                  : () => setState(() {
                      _groupId = null;
                      _groupName = null;
                    }),
            ),
            FormSectionHeader(l10n.goalMoreSection),
            TextFormField(
              controller: _description,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.descriptionLabel),
                errorText: _errors['description'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.goalCreate,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneEditor extends StatelessWidget {
  const _MilestoneEditor({
    required this.row,
    required this.validatePercent,
    required this.onRemove,
    super.key,
  });

  final _MilestoneRow row;
  final String? Function() validatePercent;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: row.percent,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.milestonePercentLabel,
                    suffixText: '%',
                  ),
                  validator: (_) => validatePercent(),
                ),
                const SizedBox(height: Insets.xs),
                TextFormField(
                  controller: row.label,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: l10n.optionalLabel(l10n.milestoneNameLabel),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.milestoneRemove,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
