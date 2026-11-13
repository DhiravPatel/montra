import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';

/// The optional goals step of onboarding: a first goal (name, kind, target
/// in the main currency and an optional date) created with
/// `POST /goals` and an `Idempotency-Key`, so retrying after a lost
/// connection never creates a second goal. Plans, milestones and sharing
/// are left for the goal screens.
class OnboardingGoalStep extends ConsumerStatefulWidget {
  /// Creates the step.
  const OnboardingGoalStep({
    required this.currency,
    required this.created,
    required this.onCreated,
    required this.onContinue,
    required this.onSkip,
    super.key,
  });

  /// The main currency (goal amounts are in it).
  final String currency;

  /// The goal created in this step, if any.
  final GoalDto? created;

  /// Called with the goal once the server created it.
  final ValueChanged<GoalDto> onCreated;

  /// Moves on after a goal was created.
  final VoidCallback onContinue;

  /// Moves on without creating a goal (recorded as skipped).
  final VoidCallback onSkip;

  @override
  ConsumerState<OnboardingGoalStep> createState() => _OnboardingGoalStepState();
}

class _OnboardingGoalStepState extends ConsumerState<OnboardingGoalStep> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  GoalInputGoalType? _type;
  String? _targetDate;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'goal_type': 'type',
    'target_amount': 'target',
    'currency': 'target',
    'target_date': 'targetDate',
  };

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final GoalInputGoalType? type = _type;
    final String? target = readAmount(
      context,
      ref,
      _target.text,
      currency: widget.currency,
    ).value;
    if (type == null || target == null) {
      return;
    }
    final GoalInput input = GoalInput(
      name: _name.text.trim(),
      goalType: type,
      targetAmount: target,
      currency: widget.currency,
      targetDate: _targetDate,
    );
    final GoalsRevision revision = ref.read(goalsRevisionProvider.notifier);
    try {
      final GoalDto goal = await ref
          .read(goalsApiProvider)
          .create(input, key: _submission.keyFor(input.toJson()));
      _submission.reset();
      revision.bump();
      if (mounted) {
        widget.onCreated(goal);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final GoalDto? goal = widget.created;
    final String? general = _errors.general;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(l10n.onboardingGoalsTitle, large: true),
        const SizedBox(height: Insets.sm),
        Text(l10n.onboardingGoalsBody),
        const SizedBox(height: Insets.md),
        if (goal != null) ...<Widget>[
          _CreatedGoal(goal: goal),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.actionContinue,
            onPressed: () async => widget.onContinue(),
          ),
        ] else ...<Widget>[
          if (general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: general,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                            ExcludeSemantics(
                              child: Icon(goalTypeIcon(t), size: 20),
                            ),
                            const SizedBox(width: Insets.sm),
                            Flexible(child: Text(goalTypeLabel(l10n, t))),
                          ],
                        ),
                      ),
                  ],
                  validator: (GoalInputGoalType? t) =>
                      t == null ? l10n.goalTypeRequired : null,
                  onChanged: (GoalInputGoalType? t) =>
                      setState(() => _type = t),
                ),
                const SizedBox(height: Insets.md),
                AmountField(
                  controller: _target,
                  label: l10n.goalTargetAmountLabel,
                  currency: widget.currency,
                  errorText: _errors['target'],
                ),
                const SizedBox(height: Insets.md),
                DateSelectorField(
                  label: l10n.optionalLabel(l10n.goalTargetDateLabel),
                  value: _targetDate,
                  emptyLabel: l10n.notSetLabel,
                  clearable: true,
                  firstDate: LocalDates.today(),
                  helperText: l10n.goalTargetDateHelp,
                  errorText: _errors['targetDate'],
                  onChanged: (String? d) => setState(() => _targetDate = d),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.onboardingGoalCreate, onPressed: _create),
          const SizedBox(height: Insets.sm),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: widget.onSkip,
            child: Text(l10n.onboardingSkipStep),
          ),
        ],
      ],
    );
  }
}

/// The goal just created: its name, kind and target, in words.
class _CreatedGoal extends ConsumerWidget {
  const _CreatedGoal({required this.goal});

  final GoalDto goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String numbers = numberLocaleOf(context, ref);
    final String locale = Localizations.localeOf(context).toString();
    final String? date = goal.targetDate;
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        l10n.onboardingGoalCreated,
                        style: text.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Text(goal.name, style: text.titleMedium),
                Text(
                  l10n.onboardingGoalTarget(
                    formatMoneyText(goal.target, numbers),
                  ),
                  semanticsLabel: l10n.onboardingGoalTarget(
                    moneySemantics(l10n, goal.target, numbers),
                  ),
                ),
                if (date != null)
                  Text(
                    l10n.goalTargetDateShort(
                      LocalDates.display(date, locale: locale),
                    ),
                  ),
                const SizedBox(height: Insets.xs),
                Text(l10n.onboardingGoalLater, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
