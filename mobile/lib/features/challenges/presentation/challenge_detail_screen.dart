import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/challenges/application/challenges_providers.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';
import 'package:montra_mobile/features/challenges/domain/challenge_display.dart';

/// Whether the user takes part in [c].
bool isParticipant(ChallengeDto c) =>
    c.me != null && c.me!.status != ChallengeParticipationDtoStatus.left;

/// One challenge: what it is, joining (progress stays private unless the
/// user shares it), daily check-ins (sending a day again corrects it),
/// progress with milestones, what the user shares, and the leaderboard —
/// which is mutual: only people who appear on it can see it. The creator
/// can edit or cancel the challenge.
class ChallengeDetailScreen extends ConsumerWidget {
  /// Creates the screen for [challengeId].
  const ChallengeDetailScreen({required this.challengeId, super.key});

  /// The challenge.
  final String challengeId;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    ChallengeDto c,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.challengeCancelTitle,
      body: l10n.challengeCancelBody,
      confirmLabel: l10n.challengeCancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(challengesApiProvider).cancel(c.id);
      ref.read(challengeRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.challengeCancelledDone);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ChallengeDto> challenge = ref.watch(
      challengeProvider(challengeId),
    );
    final ChallengeDto? loaded = challenge.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.title ?? l10n.challengesTitle),
        actions: <Widget>[
          if (loaded != null &&
              loaded.mine &&
              loaded.status == ChallengeDtoStatus.active)
            PopupMenuButton<String>(
              tooltip: l10n.actionMore,
              onSelected: (String choice) async {
                if (choice == 'edit') {
                  await context.push(AppRoutes.editChallenge(loaded.id));
                } else {
                  await _cancel(context, ref, loaded);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (!loaded.ended)
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(l10n.actionEdit),
                  ),
                PopupMenuItem<String>(
                  value: 'cancel',
                  child: Text(l10n.challengeCancel),
                ),
              ],
            ),
        ],
      ),
      body: AsyncValueView<ChallengeDto>(
        value: challenge,
        onRetry: () => ref.invalidate(challengeProvider(challengeId)),
        data: (ChallengeDto c) => RefreshIndicator(
          onRefresh: () => ref.refresh(challengeProvider(challengeId).future),
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            children: <Widget>[
              _Overview(challenge: c),
              const SizedBox(height: Insets.md),
              if (isParticipant(c))
                _Participation(challenge: c)
              else if (challengeIsOpen(c))
                _JoinCard(challenge: c)
              else
                NoticeBanner(message: l10n.challengeNotOpenNote),
              const SizedBox(height: Insets.md),
              _Leaderboard(challenge: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.challenge});

  final ChallengeDto challenge;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final ChallengeDto c = challenge;
    final ChallengeScopeRef? community = c.community;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(c.title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: Insets.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusLabel(
            text: challengeStatusLabel(l10n, c),
            tone: challengeIsOpen(c) ? StatusTone.positive : StatusTone.neutral,
          ),
        ),
        const SizedBox(height: Insets.sm),
        SectionCard(
          children: <Widget>[
            DetailRow(
              label: l10n.challengeTypeHeading,
              value: challengeTypeLabel(l10n, c.challengeType),
            ),
            DetailRow(
              label: l10n.challengeGoalLabel,
              value: challengeTargetText(l10n, c.metric.json, c.targetValue),
            ),
            DetailRow(
              label: l10n.challengeMetricHeading,
              value: challengeMetricLabel(l10n, c.metric.json),
            ),
            DetailRow(
              label: l10n.challengeDatesLabel,
              value: LocalDates.displayRange(
                c.startsOn,
                c.endsOn,
                locale: locale,
              ),
            ),
            DetailRow(
              label: l10n.challengeScopeHeading,
              value:
                  c.group?.name ??
                  community?.name ??
                  challengeVisibilityLabel(l10n, c.visibility.json),
              onTap: community == null
                  ? null
                  : () => context.push(AppRoutes.communityPage(community.id)),
            ),
            DetailRow(
              label: l10n.challengeParticipantsLabel,
              value: '${c.participantCount}',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Text(challengeMetricHelp(l10n, c.metric.json)),
        ),
        if (c.description case final String d when d.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(d),
        ],
        if (c.rules case final String r when r.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.challengeRulesLabel),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[Text(r)],
          ),
      ],
    );
  }
}

class _JoinCard extends ConsumerStatefulWidget {
  const _JoinCard({required this.challenge});

  final ChallengeDto challenge;

  @override
  ConsumerState<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends ConsumerState<_JoinCard> {
  bool _share = false;
  bool _leaderboard = false;

  Future<void> _join() async {
    final AppLocalizations l10n = context.l10n;
    try {
      await ref
          .read(challengesApiProvider)
          .join(
            widget.challenge.id,
            ChallengeJoinInput(
              shareProgress: _share,
              showOnLeaderboard: _share && _leaderboard,
            ),
          );
      ref.read(challengeRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.challengeJoinedDone);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SectionCard(
      title: l10n.challengeJoinTitle,
      padding: const EdgeInsets.all(Insets.sm),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Text(l10n.challengePrivacyNote),
        ),
        SwitchListTile(
          value: _share,
          onChanged: (bool v) => setState(() {
            _share = v;
            if (!v) {
              _leaderboard = false;
            }
          }),
          title: Text(l10n.challengeShareProgress),
          subtitle: Text(l10n.challengeShareProgressHelp),
        ),
        if (widget.challenge.leaderboardEnabled)
          SwitchListTile(
            value: _leaderboard,
            onChanged: _share
                ? (bool v) => setState(() => _leaderboard = v)
                : null,
            title: Text(l10n.challengeShowOnLeaderboard),
            subtitle: Text(l10n.challengeShowOnLeaderboardHelp),
          ),
        Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: SubmitButton(label: l10n.challengeJoin, onPressed: _join),
        ),
      ],
    );
  }
}

class _Participation extends ConsumerStatefulWidget {
  const _Participation({required this.challenge});

  final ChallengeDto challenge;

  @override
  ConsumerState<_Participation> createState() => _ParticipationState();
}

class _ParticipationState extends ConsumerState<_Participation> {
  late String _date = _defaultDate();
  bool _done = true;
  final TextEditingController _value = TextEditingController(text: '1');
  final TextEditingController _note = TextEditingController();
  String? _valueError;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  String _defaultDate() {
    final ChallengeDto c = widget.challenge;
    final String today = LocalDates.format(LocalDates.today());
    if (today.compareTo(c.endsOn) > 0) {
      return c.endsOn;
    }
    if (today.compareTo(c.startsOn) < 0) {
      return c.startsOn;
    }
    return today;
  }

  bool get _binary =>
      widget.challenge.metric == ChallengeDtoMetric.days ||
      widget.challenge.metric == ChallengeDtoMetric.streak;

  Future<void> _checkIn() async {
    final AppLocalizations l10n = context.l10n;
    int value;
    if (_binary) {
      value = _done ? 1 : 0;
    } else {
      final int? n = int.tryParse(_value.text.trim());
      final bool percent =
          widget.challenge.metric == ChallengeDtoMetric.percent;
      if (n == null || n < 0 || (percent && n > 100)) {
        setState(
          () => _valueError = percent
              ? l10n.challengeTargetPercentHelp
              : l10n.challengeTargetInvalid,
        );
        return;
      }
      value = n;
    }
    setState(() => _valueError = null);
    try {
      await ref
          .read(challengesApiProvider)
          .recordProgress(
            widget.challenge.id,
            ChallengeProgressInput(
              date: _date,
              value: value,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            ),
          );
      ref.read(challengeRevisionProvider.notifier).bump();
      if (mounted) {
        _note.clear();
        showSnack(context, l10n.challengeCheckInSaved);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _sharing({required bool share, required bool show}) async {
    final AppLocalizations l10n = context.l10n;
    try {
      await ref
          .read(challengesApiProvider)
          .updateParticipation(
            widget.challenge.id,
            ChallengeJoinInput(shareProgress: share, showOnLeaderboard: show),
          );
      ref.read(challengeRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.challengeSharingSaved);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _leave() async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.challengeLeaveTitle,
      body: l10n.challengeLeaveBody,
      confirmLabel: l10n.challengeLeave,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(challengesApiProvider).leave(widget.challenge.id);
      ref.read(challengeRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.challengeLeftDone);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final ChallengeDto c = widget.challenge;
    final ChallengeParticipationDto me = c.me!;
    final int percent = me.percentComplete.clamp(0, 100);
    final bool open = challengeIsOpen(c);
    final DateTime start = LocalDates.parse(c.startsOn) ?? LocalDates.today();
    final DateTime end = LocalDates.parse(c.endsOn) ?? start;
    final DateTime today = LocalDates.today();
    final DateTime last = end.isBefore(today) ? end : today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: l10n.challengeYourProgressTitle,
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            Text(
              l10n.challengeProgressLine(
                me.progressValue,
                challengeTargetText(l10n, c.metric.json, c.targetValue),
              ),
            ),
            const SizedBox(height: Insets.xs),
            Semantics(
              label: l10n.challengeYourProgress(percent),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  LinearProgressIndicator(value: percent / 100, minHeight: 8),
                  const SizedBox(height: Insets.xs),
                  Text(l10n.challengeYourProgress(percent)),
                ],
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              l10n.challengeStreaks(me.currentStreak, me.bestStreak),
              style: theme.textTheme.bodySmall,
            ),
            if (me.completedAt case final DateTime done)
              Text(
                l10n.challengeCompletedOn(formatDateTime(done, locale: locale)),
              ),
            const SizedBox(height: Insets.sm),
            for (final int m in challengeMilestones)
              Row(
                children: <Widget>[
                  Icon(
                    percent >= m ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    semanticLabel: percent >= m
                        ? l10n.challengeMilestoneReached
                        : l10n.challengeMilestoneAhead,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(child: Text(challengeMilestoneLabel(l10n, m))),
                ],
              ),
          ],
        ),
        if (open) ...<Widget>[
          const SizedBox(height: Insets.md),
          SectionCard(
            title: l10n.challengeCheckInTitle,
            padding: const EdgeInsets.all(Insets.md),
            children: <Widget>[
              Text(l10n.challengeCheckInHelp),
              const SizedBox(height: Insets.sm),
              DateSelectorField(
                label: l10n.challengeCheckInDate,
                value: _date,
                firstDate: start,
                lastDate: last.isBefore(start) ? start : last,
                onChanged: (String? v) {
                  if (v != null) {
                    setState(() => _date = v);
                  }
                },
              ),
              const SizedBox(height: Insets.sm),
              if (_binary)
                Wrap(
                  spacing: Insets.xs,
                  children: <Widget>[
                    ChoiceChip(
                      label: Text(l10n.challengeCheckInDone),
                      selected: _done,
                      onSelected: (_) => setState(() => _done = true),
                    ),
                    ChoiceChip(
                      label: Text(l10n.challengeCheckInMissed),
                      selected: !_done,
                      onSelected: (_) => setState(() => _done = false),
                    ),
                  ],
                )
              else
                TextField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: c.metric == ChallengeDtoMetric.percent
                        ? l10n.challengeCheckInPercent
                        : l10n.challengeCheckInCount,
                    errorText: _valueError,
                  ),
                ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: _note,
                maxLength: ChallengeProgressInput.noteMaxLength,
                decoration: InputDecoration(
                  labelText: l10n.challengeCheckInNote,
                  helperText: l10n.challengeCheckInNoteHelp,
                ),
              ),
              const SizedBox(height: Insets.sm),
              SubmitButton(label: l10n.challengeCheckIn, onPressed: _checkIn),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.challengeSharingTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(l10n.challengePrivacyNote),
            ),
            SwitchListTile(
              value: me.shareProgress,
              onChanged: (bool v) =>
                  _sharing(share: v, show: v && me.showOnLeaderboard),
              title: Text(l10n.challengeShareProgress),
              subtitle: Text(l10n.challengeShareProgressHelp),
            ),
            if (c.leaderboardEnabled)
              SwitchListTile(
                value: me.showOnLeaderboard,
                onChanged: me.shareProgress
                    ? (bool v) => _sharing(share: true, show: v)
                    : null,
                title: Text(l10n.challengeShowOnLeaderboard),
                subtitle: Text(l10n.challengeShowOnLeaderboardHelp),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SubmitButton(
          kind: SubmitButtonKind.outlined,
          icon: Icons.logout,
          label: l10n.challengeLeave,
          onPressed: _leave,
        ),
      ],
    );
  }
}

class _Leaderboard extends ConsumerWidget {
  const _Leaderboard({required this.challenge});

  final ChallengeDto challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ChallengeDto c = challenge;
    final ChallengeParticipationDto? me = c.me;
    final bool appears =
        isParticipant(c) && me!.shareProgress && me.showOnLeaderboard;
    final List<Widget> body;
    if (!c.leaderboardEnabled) {
      body = <Widget>[
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Text(l10n.challengeErrorNoLeaderboard),
        ),
      ];
    } else if (!appears) {
      body = <Widget>[
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Text(l10n.challengeErrorLeaderboardOptIn),
        ),
      ];
    } else {
      final AsyncValue<List<ChallengeLeaderboardEntry>> entries = ref.watch(
        challengeLeaderboardProvider(c.id),
      );
      body = <Widget>[
        AsyncValueView<List<ChallengeLeaderboardEntry>>(
          value: entries,
          onRetry: () => ref.invalidate(challengeLeaderboardProvider(c.id)),
          isEmpty: (List<ChallengeLeaderboardEntry> data) => data.isEmpty,
          empty: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(l10n.challengeLeaderboardEmpty),
          ),
          data: (List<ChallengeLeaderboardEntry> data) => Column(
            children: <Widget>[
              for (final ChallengeLeaderboardEntry e in data)
                ListTile(
                  leading: CircleAvatar(child: Text('${e.rank}')),
                  title: Text(
                    e.isMe
                        ? l10n.challengeLeaderboardYou(e.displayName)
                        : e.displayName,
                  ),
                  subtitle: Text(
                    <String>[
                      l10n.challengeYourProgress(e.percentComplete),
                      l10n.challengeStreakNow(e.currentStreak),
                      if (e.completed) l10n.challengeStatusCompleted,
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.sm,
          ),
          child: Text(l10n.challengeLeaderboardNote),
        ),
      ];
    }
    return SectionCard(title: l10n.challengeLeaderboardTitle, children: body);
  }
}
