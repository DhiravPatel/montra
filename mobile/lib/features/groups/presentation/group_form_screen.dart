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
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';

/// Creates a group or, with [groupId], edits its details. Edits send only
/// what changed (`GroupPatch`, `""` clears text and dates) with the
/// group's `version`; a change made elsewhere reloads the form and says
/// so.
class GroupFormScreen extends ConsumerWidget {
  /// Creates the form (a new group without [groupId]).
  const GroupFormScreen({this.groupId, super.key});

  /// Group to edit.
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? id = groupId;
    if (id == null) {
      return const _GroupForm();
    }
    final AsyncValue<GroupDetail> group = ref.watch(groupDetailProvider(id));
    return group.when(
      skipLoadingOnReload: true,
      data: (GroupDetail g) => _GroupForm(original: g),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.groupEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.groupEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(groupDetailProvider(id)),
        ),
      ),
    );
  }
}

/// The fields the form edits, as `GroupInput`/`GroupPatch` JSON.
Map<String, Object?> _values({
  required String name,
  required String type,
  required String? currency,
  required String split,
  required String description,
  required String rules,
  required String destination,
  required String? startDate,
  required String? endDate,
  required String timezone,
  required bool simplify,
  required bool allowInvites,
  required bool requireApproval,
}) {
  final bool dated = groupTypeHasDates(type);
  return <String, Object?>{
    'name': name,
    'group_type': type,
    'base_currency': ?currency,
    'default_split_method': split,
    if (description.isNotEmpty) 'description': description,
    if (rules.isNotEmpty) 'rules': rules,
    if (dated && destination.isNotEmpty) 'destination': destination,
    if (dated) 'start_date': ?startDate,
    if (dated) 'end_date': ?endDate,
    if (timezone.isNotEmpty) 'timezone': timezone,
    'simplify_debts': simplify,
    'allow_member_invites': allowInvites,
    'require_join_approval': requireApproval,
  };
}

/// [group]'s current values in the shape of [_values].
Map<String, Object?> groupValues(GroupDetail group) => _values(
  name: group.name,
  type: group.groupType.json,
  currency: group.baseCurrency,
  split: group.defaultSplitMethod.json,
  description: group.description ?? '',
  rules: group.rules ?? '',
  destination: group.destination ?? '',
  startDate: group.startDate,
  endDate: group.endDate,
  timezone: group.timezone,
  simplify: group.simplifyDebts,
  allowInvites: group.allowMemberInvites,
  requireApproval: group.requireJoinApproval,
);

/// The partial `PATCH /groups/{id}` body for editing [original] into
/// [after] (text and dates that were emptied are sent as `""`).
Map<String, Object?> groupPatchFor(
  GroupDetail original,
  Map<String, Object?> after,
) => partialPatch(
  before: groupValues(original),
  after: <String, Object?>{...after, 'version': original.version},
  textFields: const <String>{
    'description',
    'rules',
    'destination',
    'start_date',
    'end_date',
  },
);

class _GroupForm extends ConsumerStatefulWidget {
  const _GroupForm({this.original});

  final GroupDetail? original;

  @override
  ConsumerState<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends ConsumerState<_GroupForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  GroupDetail? get _o => widget.original;
  late final TextEditingController _name = TextEditingController(
    text: _o?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: _o?.description ?? '',
  );
  late final TextEditingController _rules = TextEditingController(
    text: _o?.rules ?? '',
  );
  late final TextEditingController _destination = TextEditingController(
    text: _o?.destination ?? '',
  );
  late final TextEditingController _timezone = TextEditingController(
    text: _o?.timezone ?? '',
  );
  late String _type = _o?.groupType.json ?? 'household';
  late String? _currency = _o?.baseCurrency;
  late String _split = _o?.defaultSplitMethod.json ?? 'equal';
  late String? _start = _o?.startDate;
  late String? _end = _o?.endDate;
  late bool _simplify = _o?.simplifyDebts ?? true;
  late bool _allowInvites = _o?.allowMemberInvites ?? true;
  late bool _requireApproval = _o?.requireJoinApproval ?? false;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'group_type': 'type',
    'base_currency': 'currency',
    'default_split_method': 'split',
    'description': 'description',
    'rules': 'rules',
    'destination': 'destination',
    'start_date': 'start',
    'end_date': 'end',
    'timezone': 'timezone',
  };

  @override
  void initState() {
    super.initState();
    if (_o == null) {
      final AuthState auth = ref.read(authControllerProvider);
      if (auth is SignedIn) {
        _currency = auth.user.baseCurrency;
      }
    }
  }

  @override
  void didUpdateWidget(covariant _GroupForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final GroupDetail? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _name.text = next.name;
      _description.text = next.description ?? '';
      _rules.text = next.rules ?? '';
      _destination.text = next.destination ?? '';
      _timezone.text = next.timezone;
      _type = next.groupType.json;
      _currency = next.baseCurrency;
      _split = next.defaultSplitMethod.json;
      _start = next.startDate;
      _end = next.endDate;
      _simplify = next.simplifyDebts;
      _allowInvites = next.allowMemberInvites;
      _requireApproval = next.requireJoinApproval;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rules.dispose();
    _destination.dispose();
    _timezone.dispose();
    super.dispose();
  }

  Map<String, Object?> _current() => _values(
    name: _name.text.trim(),
    type: _type,
    currency: _currency,
    split: _split,
    description: _description.text.trim(),
    rules: _rules.text.trim(),
    destination: _destination.text.trim(),
    startDate: _start,
    endDate: _end,
    timezone: _timezone.text.trim(),
    simplify: _simplify,
    allowInvites: _allowInvites,
    requireApproval: _requireApproval,
  );

  Future<void> _pick({
    required String title,
    required List<String> options,
    required String Function(String) label,
    required String selected,
    required void Function(String) onPicked,
  }) async {
    final String? picked = await showOptionSheet<String>(
      context,
      title: title,
      selected: selected,
      options: <SheetOption<String>>[
        for (final String o in options)
          SheetOption<String>(value: o, label: label(o)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => onPicked(picked));
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
    final GroupsApi api = ref.read(groupsApiProvider);
    final GroupDetail? o = _o;
    try {
      if (o == null) {
        final GroupDetail created = await api.create(
          GroupInput.fromJson(_current()),
        );
        refreshGroupLists(ref);
        if (mounted) {
          showSnack(context, l10n.groupCreatedDone(created.name));
          context.pushReplacement(AppRoutes.groupDetail(created.id));
        }
        return;
      }
      final Map<String, Object?> patch = groupPatchFor(o, _current());
      if (!patchHasChanges(patch)) {
        showSnack(context, l10n.groupNothingChanged);
        return;
      }
      await api.update(o.id, patch);
      refreshGroup(ref, o.id);
      if (mounted) {
        showSnack(context, l10n.groupSavedDone);
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict && o != null) {
        // The new version remounts this form with the stored values.
        ref.invalidate(groupDetailProvider(o.id));
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
    final String? general = _errors.general;
    final bool dated = groupTypeHasDates(_type);
    final bool creating = _o == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(creating ? l10n.groupNew : l10n.groupEditTitle),
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
              maxLength: GroupInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.groupNameLabel,
                errorText: _errors['name'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.groupNameRequired : null,
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.groupTypeLabel,
              value: groupTypeLabel(l10n, _type),
              errorText: _errors['type'],
              onTap: () => _pick(
                title: l10n.groupTypeLabel,
                options: groupTypes,
                label: (String t) => groupTypeLabel(l10n, t),
                selected: _type,
                onPicked: (String t) => _type = t,
              ),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.groupCurrencyLabel,
              value: _currency,
              placeholder: l10n.groupCurrencyDefault,
              helperText: l10n.groupCurrencyHelp,
              errorText: _errors['currency'],
              onTap: () async {
                final String? code = await showCurrencyPicker(
                  context,
                  selected: _currency,
                );
                if (code != null && mounted) {
                  setState(() => _currency = code);
                }
              },
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.groupSplitLabel,
              value: splitMethodLabel(l10n, _split),
              helperText: l10n.groupSplitHelp,
              errorText: _errors['split'],
              onTap: () => _pick(
                title: l10n.groupSplitLabel,
                options: splitMethods,
                label: (String m) => splitMethodLabel(l10n, m),
                selected: _split,
                onPicked: (String m) => _split = m,
              ),
            ),
            if (dated) ...<Widget>[
              FormSectionHeader(l10n.groupTripSection),
              TextFormField(
                controller: _destination,
                maxLength: GroupInput.destinationMaxLength,
                decoration: InputDecoration(
                  labelText: l10n.groupDestinationLabel,
                  errorText: _errors['destination'],
                ),
              ),
              const SizedBox(height: Insets.sm),
              DateSelectorField(
                label: l10n.groupStartDateLabel,
                value: _start,
                clearable: true,
                errorText: _errors['start'],
                lastDate: DateTime(DateTime.now().year + 5),
                onChanged: (String? v) => setState(() => _start = v),
              ),
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.groupEndDateLabel,
                value: _end,
                clearable: true,
                errorText: _errors['end'],
                lastDate: DateTime(DateTime.now().year + 5),
                onChanged: (String? v) => setState(() => _end = v),
              ),
            ],
            FormSectionHeader(l10n.groupAboutSection),
            TextFormField(
              controller: _description,
              maxLength: GroupInput.descriptionMaxLength,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.groupDescriptionLabel,
                errorText: _errors['description'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _rules,
              maxLength: GroupInput.rulesMaxLength,
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.groupRulesLabel,
                helperText: l10n.groupRulesHelp,
                errorText: _errors['rules'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _timezone,
              maxLength: GroupInput.timezoneMaxLength,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.groupTimezoneLabel,
                helperText: l10n.groupTimezoneHelp,
                errorText: _errors['timezone'],
              ),
            ),
            FormSectionHeader(l10n.groupOptionsSection),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.groupSimplifyLabel),
              subtitle: Text(l10n.groupSimplifyHelp),
              value: _simplify,
              onChanged: (bool v) => setState(() => _simplify = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.groupAllowInvitesLabel),
              subtitle: Text(l10n.groupAllowInvitesHelp),
              value: _allowInvites,
              onChanged: (bool v) => setState(() => _allowInvites = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.groupRequireApprovalLabel),
              subtitle: Text(l10n.groupRequireApprovalHelp),
              value: _requireApproval,
              onChanged: (bool v) => setState(() => _requireApproval = v),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: creating ? l10n.groupCreateButton : l10n.actionSave,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
