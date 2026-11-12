import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/reminder_days_field.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/recurring/presentation/schedule_editor.dart';

/// Sets up a recurring shared expense (with an `Idempotency-Key`) or edits
/// its name, amount and split (with its `version`; the schedule is fixed
/// once created: stop it and add a new one to change it).
class GroupRecurringFormScreen extends ConsumerWidget {
  /// Creates the form; [ruleId] switches to edit mode.
  const GroupRecurringFormScreen({
    required this.groupId,
    this.ruleId,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The rule to edit, or null to add one.
  final String? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String title = ruleId == null
        ? l10n.gxRecurringAdd
        : l10n.gxRecurringEdit;
    return GroupPeopleScope(
      groupId: groupId,
      title: title,
      builder: (BuildContext context, GroupPeople people) {
        final String? id = ruleId;
        if (id == null) {
          return _RecurringForm(people: people);
        }
        final GroupRecord record = (groupId: groupId, id: id);
        final AsyncValue<GroupRecurringDto> rule = ref.watch(
          groupRecurringProvider(record),
        );
        final GroupRecurringDto? loaded = rule.value;
        if (loaded != null) {
          return _RecurringForm(people: people, original: loaded);
        }
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: rule.hasError && !rule.isLoading
              ? ErrorStateView(
                  error: rule.error!,
                  onRetry: () => ref.invalidate(groupRecurringProvider(record)),
                )
              : const LoadingStateView(),
        );
      },
    );
  }
}

enum _Payers { adder, one, several }

class _RecurringForm extends ConsumerStatefulWidget {
  const _RecurringForm({required this.people, this.original});

  final GroupPeople people;
  final GroupRecurringDto? original;

  @override
  ConsumerState<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<_RecurringForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  late ScheduleValue _schedule;
  List<int> _reminders = const <int>[1];
  bool _autoAdd = false;
  String? _category;
  String _method = 'equal';
  List<SplitRowState> _rows = <SplitRowState>[];
  _Payers _payers = _Payers.adder;
  String? _payerId;
  final Map<String, TextEditingController> _payerAmounts =
      <String, TextEditingController>{};
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'amount': 'amount',
    'description': 'description',
    'category_key': 'category',
    'split_method': 'split',
    'participants': 'split',
    'payers': 'payers',
    'frequency': 'frequency',
    'interval_count': 'interval',
    'interval_unit': 'interval',
    'by_month_day': 'anchor',
    'by_weekday': 'anchor',
    'by_week_of_month': 'anchor',
    'start_date': 'start',
    'end_date': 'end',
    'max_occurrences': 'count',
    'local_time': 'time',
    'reminder_days_before': 'reminders',
  };

  GroupPeople get _people => widget.people;
  String get _groupId => _people.group.id;
  bool get _editing => widget.original != null;

  @override
  void initState() {
    super.initState();
    _schedule = ScheduleValue.monthly(LocalDates.format(LocalDates.today()));
    final String d = _people.group.defaultSplitMethod.json;
    _method = recurringSplitMethods.contains(d) ? d : 'equal';
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _RecurringForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final GroupRecurringDto? next = widget.original;
    if (next != null && next.rule.version != oldWidget.original?.rule.version) {
      setState(() => _load(next));
    }
  }

  void _load(GroupRecurringDto? r) {
    for (final SplitRowState row in _rows) {
      row.dispose();
    }
    for (final TextEditingController c in _payerAmounts.values) {
      c.dispose();
    }
    _payerAmounts.clear();
    final Map<String, ExpenseParticipantInput> parts =
        <String, ExpenseParticipantInput>{
          for (final ExpenseParticipantInput p
              in r?.template.participants ?? const <ExpenseParticipantInput>[])
            p.userId: p,
        };
    _rows = <SplitRowState>[
      for (final GroupMemberDto m in _people.activeMembers)
        SplitRowState(
          m.userId,
          included: r == null || parts.containsKey(m.userId),
          value: parts[m.userId]?.value ?? '',
        ),
    ];
    for (final GroupMemberDto m in _people.activeMembers) {
      _payerAmounts[m.userId] = TextEditingController();
    }
    if (r == null) {
      return;
    }
    _name.text = r.rule.name;
    _amount.text = r.rule.amount?.amount ?? '';
    _description.text = r.template.description ?? '';
    _category = r.template.categoryKey;
    final String? m = r.template.splitMethod?.json;
    _method = m != null && recurringSplitMethods.contains(m) ? m : 'equal';
    _autoAdd = r.autoAdd;
    final List<ExpensePayerInput> payers =
        r.template.payers ?? const <ExpensePayerInput>[];
    if (payers.isEmpty) {
      _payers = _Payers.adder;
    } else if (payers.length == 1) {
      _payers = _Payers.one;
      _payerId = payers.single.userId;
    } else {
      _payers = _Payers.several;
      for (final ExpensePayerInput p in payers) {
        _payerAmounts[p.userId]?.text = p.amount ?? '';
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
    for (final SplitRowState r in _rows) {
      r.dispose();
    }
    for (final TextEditingController c in _payerAmounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _amountOf(String text) =>
      readAmount(context, ref, text, currency: _people.currency).value;

  Future<void> _pickCategory() async {
    final AppLocalizations l10n = context.l10n;
    final String? picked = await showOptionSheet<String>(
      context,
      title: l10n.categoryFieldLabel,
      selected: _category,
      options: <SheetOption<String>>[
        for (final String key in groupCategoryKeys)
          SheetOption<String>(value: key, label: groupCategoryLabel(l10n, key)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  Future<void> _pickPayer() async {
    final String? picked = await showMemberPicker(
      context,
      people: _people,
      title: context.l10n.gxWhoPays,
    );
    if (picked != null && mounted) {
      setState(() => _payerId = picked);
    }
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
    final List<SplitRowState> included = _rows
        .where((SplitRowState r) => r.included)
        .toList();
    if (included.isEmpty) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'split': l10n.gxSplitNeedsPeople},
        ),
      );
      return;
    }
    if (_payers == _Payers.one && _payerId == null) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'payers': l10n.gxChoosePayer},
        ),
      );
      return;
    }
    final String amount = _amountOf(_amount.text) ?? '';
    final List<ExpenseParticipantInput> participants =
        <ExpenseParticipantInput>[
          for (final SplitRowState r in included)
            ExpenseParticipantInput(
              userId: r.userId,
              value: switch (_method) {
                'exact' => _amountOf(r.value.text),
                'percentage' => percentWire(r.value.text),
                'shares' => r.value.text.trim(),
                _ => null,
              },
            ),
        ];
    final List<ExpensePayerInput>? payers = switch (_payers) {
      _Payers.adder => null,
      _Payers.one => <ExpensePayerInput>[ExpensePayerInput(userId: _payerId!)],
      _Payers.several => <ExpensePayerInput>[
        for (final MapEntry<String, TextEditingController> p
            in _payerAmounts.entries)
          if (p.value.text.trim().isNotEmpty)
            ExpensePayerInput(
              userId: p.key,
              amount: _amountOf(p.value.text) ?? '',
            ),
      ],
    };
    final String? description = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();
    final GroupMoneyApi api = ref.read(groupMoneyApiProvider);
    final GroupRecurringDto? original = widget.original;
    final GoRouter router = GoRouter.of(context);
    try {
      if (original == null) {
        final ScheduleValue s = _schedule.normalized();
        final GroupRecurringInput input = GroupRecurringInput(
          name: _name.text.trim(),
          amount: amount,
          description: description,
          categoryKey: _category,
          frequency: GroupRecurringInputFrequency.fromJson(s.frequency),
          intervalCount: s.intervalCount,
          intervalUnit: s.intervalUnit == null
              ? null
              : GroupRecurringInputIntervalUnit.fromJson(s.intervalUnit!),
          byMonthDay: s.byMonthDay,
          byWeekday: s.byWeekday,
          byWeekOfMonth: s.byWeekOfMonth,
          startDate: s.startDate,
          endDate: s.endDate,
          maxOccurrences: s.maxOccurrences,
          localTime: s.localTime,
          timezone: _people.group.timezone,
          reminderDaysBefore: _reminders,
          autoAdd: _autoAdd,
          splitMethod: GroupRecurringInputSplitMethod.fromJson(_method),
          participants: participants,
          payers: payers,
        );
        final GroupRecurringDto saved = await api.createRecurring(
          _groupId,
          input,
          key: _submission.keyFor(input.toJson()),
        );
        _submission.reset();
        if (!mounted) {
          return;
        }
        groupMoneyChanged(ref, _groupId);
        showSnack(context, l10n.gxRecurringAdded);
        unawaited(
          router.pushReplacement(
            AppRoutes.groupRecurringDetail(_groupId, saved.rule.id),
          ),
        );
        return;
      }
      await api.updateRecurring(
        _groupId,
        original.rule.id,
        GroupRecurringUpdate(
          name: _name.text.trim(),
          amount: amount,
          version: original.rule.version,
          description: _description.text.trim(),
          categoryKey: _category,
          autoAdd: _autoAdd,
          splitMethod: GroupRecurringUpdateSplitMethod.fromJson(_method),
          participants: participants,
          payers: payers,
        ),
      );
      if (!mounted) {
        return;
      }
      groupMoneyChanged(ref, _groupId);
      showSnack(context, l10n.gxRecurringSaved);
      leaveTo(
        router,
        AppRoutes.groupRecurringDetail(_groupId, original.rule.id),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(
          groupRecurringProvider((groupId: _groupId, id: original.rule.id)),
        );
        setState(() => _conflictReloaded = true);
        return;
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
    final String locale = Localizations.localeOf(context).toString();
    final String? general = _errors.general;
    final GroupRecurringDto? original = widget.original;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.gxRecurringEdit : l10n.gxRecurringAdd),
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
            TextFormField(
              controller: _name,
              maxLength: GroupRecurringInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.gxRecurringName,
                helperText: l10n.gxRecurringNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: l10n.gxRecurringAmount,
              currency: _people.currency,
              errorText: _errors['amount'],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _description,
              maxLength: GroupRecurringInput.descriptionMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.descriptionLabel),
                helperText: l10n.gxRecurringDescriptionHelp,
                errorText: _errors['description'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.categoryFieldLabel),
              value: _category == null
                  ? null
                  : groupCategoryLabel(l10n, _category),
              icon: Icons.category_outlined,
              errorText: _errors['category'],
              onTap: _pickCategory,
              onClear: () => setState(() => _category = null),
            ),
            FormSectionHeader(l10n.gxScheduleSection),
            if (original == null) ...<Widget>[
              ScheduleEditor(
                value: _schedule,
                errors: _errors.fields,
                onChanged: (ScheduleValue v) => setState(() => _schedule = v),
              ),
              const SizedBox(height: Insets.md),
              ReminderDaysField(
                value: _reminders,
                onChanged: (List<int> v) => setState(() => _reminders = v),
              ),
            ] else ...<Widget>[
              DetailRow(
                label: l10n.gxScheduleSection,
                value: scheduleSummary(
                  l10n,
                  ScheduleValue.fromRule(original.rule),
                  locale: locale,
                ),
              ),
              Text(l10n.gxScheduleFixed, style: theme.textTheme.bodySmall),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gxAutoAddLabel),
              subtitle: Text(l10n.gxAutoAddHelp),
              value: _autoAdd,
              onChanged: (bool v) => setState(() => _autoAdd = v),
            ),
            FormSectionHeader(l10n.gxSplitSection),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String m in recurringSplitMethods)
                  ChoiceChip(
                    label: Text(splitMethodLabel(l10n, m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              splitMethodHelp(l10n, _method),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            SplitEditor(
              people: _people,
              method: _method,
              rows: _rows,
              currency: _people.currency,
              amountText: _amount.text,
              errorText: _errors['split'],
              onChanged: () => setState(() {}),
            ),
            FormSectionHeader(l10n.gxWhoPays),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final (_Payers p, String label) in <(_Payers, String)>[
                  (_Payers.adder, l10n.gxPayerAdder),
                  (_Payers.one, l10n.gxPayerOne),
                  (_Payers.several, l10n.gxPayerSeveral),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _payers == p,
                    onSelected: (_) => setState(() => _payers = p),
                  ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            if (_payers == _Payers.adder)
              Text(l10n.gxPayerAdderHelp, style: theme.textTheme.bodySmall),
            if (_payers == _Payers.one)
              SelectorField(
                label: l10n.gxWhoPays,
                value: _payerId == null ? null : _people.name(l10n, _payerId),
                icon: Icons.person_outline,
                errorText: _errors['payers'],
                onTap: _pickPayer,
              ),
            if (_payers == _Payers.several)
              for (final GroupMemberDto m in _people.activeMembers) ...<Widget>[
                AmountField(
                  controller: _payerAmounts[m.userId]!,
                  label: l10n.optionalLabel(
                    l10n.gxPaidBy(_people.name(l10n, m.userId)),
                  ),
                  currency: _people.currency,
                  isRequired: false,
                ),
                const SizedBox(height: Insets.sm),
              ],
            if (_payers != _Payers.one && _errors['payers'] != null)
              Text(
                _errors['payers']!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.gxRecurringAdd,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
