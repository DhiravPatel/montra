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
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/challenges/application/challenges_providers.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';
import 'package:montra_mobile/features/challenges/domain/challenge_display.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/presentation/community_form_errors.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// Starts a challenge (for the user alone, a group or a community), or
/// edits one the user created: only the title, description, rules, a later
/// end date and the leaderboard can change, and only what changed is sent
/// with the challenge's `version`.
class ChallengeFormScreen extends ConsumerWidget {
  /// A new challenge (optionally for [communityId] or [groupId]), or an
  /// edit of [challengeId].
  const ChallengeFormScreen({
    this.challengeId,
    this.communityId,
    this.groupId,
    super.key,
  });

  /// The challenge to edit.
  final String? challengeId;

  /// Community preset for a new challenge.
  final String? communityId;

  /// Group preset for a new challenge.
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? editing = challengeId;
    if (editing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.challengeCreateTitle)),
        body: _CreateForm(communityId: communityId, groupId: groupId),
      );
    }
    final AsyncValue<ChallengeDto> challenge = ref.watch(
      challengeProvider(editing),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.challengeEditTitle)),
      body: AsyncValueView<ChallengeDto>(
        value: challenge,
        onRetry: () => ref.invalidate(challengeProvider(editing)),
        data: (ChallengeDto c) => _EditForm(original: c),
      ),
    );
  }
}

const Map<String, String> _fields = <String, String>{
  'title': 'title',
  'challenge_type': 'type',
  'metric': 'metric',
  'target_value': 'target',
  'starts_on': 'starts',
  'ends_on': 'ends',
  'group_id': 'scope',
  'community_id': 'scope',
  'visibility': 'scope',
  'leaderboard_enabled': 'leaderboard',
  'description': 'description',
  'rules': 'rules',
};

class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm({this.communityId, this.groupId});

  final String? communityId;
  final String? groupId;

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _target = TextEditingController(text: '7');
  final TextEditingController _description = TextEditingController();
  final TextEditingController _rules = TextEditingController();
  ChallengeInputChallengeType _type = ChallengeInputChallengeType.noSpend;
  ChallengeInputMetric _metric = ChallengeInputMetric.days;
  late String _startsOn = LocalDates.format(LocalDates.today());
  late String _endsOn = LocalDates.format(
    LocalDates.today().add(const Duration(days: 30)),
  );
  late String _scope = widget.communityId != null
      ? 'community'
      : widget.groupId != null
      ? 'group'
      : 'private';
  late String? _groupId = widget.groupId;
  String? _groupName;
  late String? _communityId = widget.communityId;
  String? _communityName;
  bool _leaderboard = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _description.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _pickGroup() async {
    final Picked<GroupDto>? picked = await showGroupPicker(
      context,
      selectedId: _groupId,
      allowNone: false,
    );
    final GroupDto? g = picked?.value;
    if (g != null && mounted) {
      setState(() {
        _groupId = g.id;
        _groupName = g.name;
      });
    }
  }

  Future<void> _pickCommunity() async {
    final AppLocalizations l10n = context.l10n;
    final Picked<CommunityDto>? picked =
        await showSingleSelection<CommunityDto, CommunityDto>(
          context,
          title: l10n.challengePickCommunity,
          source: myCommunitiesProvider,
          onRetry: (WidgetRef ref) => ref.invalidate(myCommunitiesProvider),
          items: (BuildContext context, List<CommunityDto> data) =>
              <SelectionItem<CommunityDto>>[
                for (final CommunityDto c in data)
                  if (c.myStatus == CommunityDtoMyStatus.active)
                    SelectionItem<CommunityDto>(
                      id: c.id,
                      value: c,
                      label: c.name,
                      leading: const Icon(Icons.forum_outlined),
                    ),
              ],
          selectedId: _communityId,
          emptyText: l10n.challengePickCommunityEmpty,
        );
    final CommunityDto? c = picked?.value;
    if (c != null && mounted) {
      setState(() {
        _communityId = c.id;
        _communityName = c.name;
      });
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (_scope == 'group' && _groupId == null ||
        _scope == 'community' && _communityId == null) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'scope': l10n.challengeScopeRequired},
        ),
      );
      return;
    }
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final ChallengeDto created = await ref
          .read(challengesApiProvider)
          .create(
            ChallengeInput(
              title: _title.text.trim(),
              challengeType: _type,
              metric: _metric,
              targetValue: int.parse(_target.text.trim()),
              startsOn: _startsOn,
              endsOn: _endsOn,
              visibility: ChallengeInputVisibility.fromJson(_scope),
              groupId: _scope == 'group' ? _groupId : null,
              communityId: _scope == 'community' ? _communityId : null,
              leaderboardEnabled: _scope == 'private' ? null : _leaderboard,
              description: text(_description),
              rules: text(_rules),
            ),
          );
      ref.read(challengeRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.challengeCreated);
        unawaited(
          router.pushReplacement(AppRoutes.challengeDetail(created.id)),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = formErrorsOf(l10n, error, _fields));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? general = _errors.general;
    final String? presetCommunity = widget.communityId;
    final String? communityName =
        _communityName ??
        (presetCommunity != null && presetCommunity == _communityId
            ? ref.watch(communityProvider(presetCommunity)).value?.name
            : null);
    final DateTime today = LocalDates.today();
    final DateTime start = LocalDates.parse(_startsOn) ?? today;
    return Form(
      key: _form,
      child: ScrollableContent(
        children: <Widget>[
          Text(l10n.challengeCreateIntro),
          const SizedBox(height: Insets.md),
          if (general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: general,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          TextFormField(
            controller: _title,
            maxLength: ChallengeInput.titleMaxLength,
            decoration: InputDecoration(
              labelText: l10n.challengeTitleLabel,
              errorText: _errors['title'],
            ),
            validator: (String? v) =>
                (v ?? '').trim().length < ChallengeInput.titleMinLength
                ? l10n.fieldTooShort('${ChallengeInput.titleMinLength}')
                : null,
          ),
          const SizedBox(height: Insets.sm),
          SectionHeading(l10n.challengeTypeHeading),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final ChallengeInputChallengeType t in challengeTypes)
                ChoiceChip(
                  label: Text(challengeTypeLabel(l10n, t.json)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          SectionHeading(l10n.challengeMetricHeading),
          RadioGroup<ChallengeInputMetric>(
            groupValue: _metric,
            onChanged: (ChallengeInputMetric? m) {
              if (m != null) {
                setState(() => _metric = m);
              }
            },
            child: Column(
              children: <Widget>[
                for (final ChallengeInputMetric m in challengeMetrics)
                  RadioListTile<ChallengeInputMetric>(
                    value: m,
                    contentPadding: EdgeInsets.zero,
                    title: Text(challengeMetricLabel(l10n, m.json)),
                    subtitle: Text(challengeMetricHelp(l10n, m.json)),
                  ),
              ],
            ),
          ),
          TextFormField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.challengeTargetLabel,
              helperText: _metric == ChallengeInputMetric.percent
                  ? l10n.challengeTargetPercentHelp
                  : null,
              errorText: _errors['target'],
            ),
            validator: (String? v) {
              final int? n = int.tryParse((v ?? '').trim());
              if (n == null || n < 1) {
                return l10n.challengeTargetInvalid;
              }
              if (_metric == ChallengeInputMetric.percent && n > 100) {
                return l10n.challengeTargetPercentHelp;
              }
              return null;
            },
          ),
          const SizedBox(height: Insets.md),
          DateSelectorField(
            label: l10n.challengeStartsLabel,
            value: _startsOn,
            errorText: _errors['starts'],
            firstDate: today.subtract(const Duration(days: 30)),
            lastDate: DateTime(today.year + 1, today.month, today.day),
            onChanged: (String? v) {
              if (v != null) {
                setState(() => _startsOn = v);
              }
            },
          ),
          const SizedBox(height: Insets.sm),
          DateSelectorField(
            label: l10n.challengeEndsLabel,
            value: _endsOn,
            helperText: l10n.challengeEndsHelp,
            errorText: _errors['ends'],
            firstDate: start,
            lastDate: DateTime(start.year + 1, start.month, start.day),
            onChanged: (String? v) {
              if (v != null) {
                setState(() => _endsOn = v);
              }
            },
          ),
          const SizedBox(height: Insets.md),
          SectionHeading(l10n.challengeScopeHeading),
          RadioGroup<String>(
            groupValue: _scope,
            onChanged: (String? s) {
              if (s != null) {
                setState(() => _scope = s);
              }
            },
            child: Column(
              children: <Widget>[
                for (final String s in const <String>[
                  'private',
                  'group',
                  'community',
                ])
                  RadioListTile<String>(
                    value: s,
                    contentPadding: EdgeInsets.zero,
                    title: Text(challengeVisibilityLabel(l10n, s)),
                  ),
              ],
            ),
          ),
          if (_scope == 'group')
            SelectorField(
              label: l10n.challengeGroupLabel,
              value: _groupName,
              placeholder: _groupId == null ? null : l10n.challengeGroupChosen,
              errorText: _errors['scope'],
              icon: Icons.groups_outlined,
              onTap: _pickGroup,
            ),
          if (_scope == 'community')
            SelectorField(
              label: l10n.challengeCommunityLabel,
              value: communityName,
              placeholder: _communityId == null
                  ? null
                  : l10n.challengeCommunityChosen,
              errorText: _errors['scope'],
              icon: Icons.forum_outlined,
              onTap: _pickCommunity,
            ),
          if (_scope != 'private') ...<Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _leaderboard,
              onChanged: (bool v) => setState(() => _leaderboard = v),
              title: Text(l10n.challengeLeaderboardLabel),
              subtitle: Text(l10n.challengeLeaderboardHelp),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                l10n.challengePrivateNoLeaderboard,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _description,
            maxLength: ChallengeInput.descriptionMaxLength,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.challengeDescriptionLabel,
              errorText: _errors['description'],
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _rules,
            maxLength: ChallengeInput.rulesMaxLength,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.challengeRulesLabel,
              errorText: _errors['rules'],
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.challengeCreate, onPressed: _submit),
        ],
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.original});

  final ChallengeDto original;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _rules = TextEditingController();
  late String _endsOn;
  late bool _leaderboard;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _EditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.original.version != oldWidget.original.version) {
      _load(widget.original);
    }
  }

  void _load(ChallengeDto c) {
    _title.text = c.title;
    _description.text = c.description ?? '';
    _rules.text = c.rules ?? '';
    _endsOn = c.endsOn;
    _leaderboard = c.leaderboardEnabled;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _rules.dispose();
    super.dispose();
  }

  Map<String, Object?> _json(
    String title,
    String description,
    String rules,
    String endsOn,
    bool leaderboard,
  ) => <String, Object?>{
    'title': title,
    if (description.isNotEmpty) 'description': description,
    if (rules.isNotEmpty) 'rules': rules,
    'ends_on': endsOn,
    'leaderboard_enabled': leaderboard,
  };

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
      _message = null;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final ChallengeDto o = widget.original;
    final Map<String, Object?> patch = partialPatch(
      before: _json(
        o.title,
        o.description ?? '',
        o.rules ?? '',
        o.endsOn,
        o.leaderboardEnabled,
      ),
      after: <String, Object?>{
        ..._json(
          _title.text.trim(),
          _description.text.trim(),
          _rules.text.trim(),
          _endsOn,
          _leaderboard,
        ),
        'version': o.version,
      },
      textFields: const <String>{'description', 'rules'},
    );
    if (!patchHasChanges(patch)) {
      setState(() => _message = l10n.challengeNothingChanged);
      return;
    }
    try {
      await ref.read(challengesApiProvider).update(o.id, patch);
      ref.read(challengeRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.challengeSaved);
        router.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(challengeProvider(o.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(() => _errors = formErrorsOf(l10n, error, _fields));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ChallengeDto o = widget.original;
    final String? general = _errors.general;
    final DateTime start = LocalDates.parse(o.startsOn) ?? LocalDates.today();
    final DateTime end = LocalDates.parse(o.endsOn) ?? start;
    final bool private = o.visibility == ChallengeDtoVisibility.private;
    return Form(
      key: _form,
      child: ScrollableContent(
        children: <Widget>[
          Text(l10n.challengeEditIntro),
          const SizedBox(height: Insets.md),
          if (_conflictReloaded) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.versionConflictReloaded,
            ),
            const SizedBox(height: Insets.md),
          ],
          if (_message case final String m) ...<Widget>[
            NoticeBanner(message: m),
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
            controller: _title,
            maxLength: ChallengeInput.titleMaxLength,
            decoration: InputDecoration(
              labelText: l10n.challengeTitleLabel,
              errorText: _errors['title'],
            ),
            validator: (String? v) =>
                (v ?? '').trim().length < ChallengeInput.titleMinLength
                ? l10n.fieldTooShort('${ChallengeInput.titleMinLength}')
                : null,
          ),
          const SizedBox(height: Insets.sm),
          DateSelectorField(
            label: l10n.challengeEndsLabel,
            value: _endsOn,
            helperText: l10n.challengeEndsLaterHelp,
            errorText: _errors['ends'],
            firstDate: end,
            lastDate: DateTime(start.year + 1, start.month, start.day),
            onChanged: (String? v) {
              if (v != null) {
                setState(() => _endsOn = v);
              }
            },
          ),
          if (!private)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _leaderboard,
              onChanged: (bool v) => setState(() => _leaderboard = v),
              title: Text(l10n.challengeLeaderboardLabel),
              subtitle: Text(l10n.challengeLeaderboardHelp),
            ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _description,
            maxLength: ChallengeInput.descriptionMaxLength,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.challengeDescriptionLabel,
              errorText: _errors['description'],
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _rules,
            maxLength: ChallengeInput.rulesMaxLength,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.challengeRulesLabel,
              errorText: _errors['rules'],
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.actionSave, onPressed: _save),
        ],
      ),
    );
  }
}
