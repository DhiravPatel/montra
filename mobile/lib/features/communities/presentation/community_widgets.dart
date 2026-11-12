import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Asha Rao · @asha · 5 minutes ago · edited", for posts and comments.
/// Names are shown as plain text exactly as the server sent them.
class AuthorLine extends StatelessWidget {
  /// Creates the line.
  const AuthorLine({
    required this.author,
    required this.createdAt,
    this.edited = false,
    this.now,
    super.key,
  });

  /// Who wrote it.
  final CommunityAuthorDto author;

  /// When it was written.
  final DateTime createdAt;

  /// Whether it was edited.
  final bool edited;

  /// Clock for "… ago" (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final String? handle = author.username == null || author.username!.isEmpty
        ? null
        : '@${author.username}';
    final String when = formatRelativeTime(
      l10n,
      createdAt.toLocal(),
      now: now ?? DateTime.now(),
      locale: locale,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InitialsAvatar(name: author.displayName, size: 28),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            <String>[
              author.displayName,
              ?handle,
              when,
              if (edited) l10n.communityEdited,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// What a reaction bar reacts to.
enum ReactionTarget {
  /// A post.
  post,

  /// A comment.
  comment,
}

/// Reaction chips with counts. Tapping one adds or removes the user's
/// reaction; the counts and the user's reactions shown are always the
/// server's answer (`CommunityReactionsDTO`), never toggled locally.
class ReactionBar extends ConsumerStatefulWidget {
  /// Creates the bar.
  const ReactionBar({
    required this.target,
    required this.id,
    required this.counts,
    required this.mine,
    this.enabled = true,
    super.key,
  });

  /// Post or comment.
  final ReactionTarget target;

  /// Its ID.
  final String id;

  /// Counts as loaded.
  final CommunityReactionCounts counts;

  /// The user's reactions as loaded (wire values).
  final List<String> mine;

  /// Whether the user can react (a member of an active community).
  final bool enabled;

  @override
  ConsumerState<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends ConsumerState<ReactionBar> {
  CommunityReactionsDto? _latest;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.counts != widget.counts ||
        oldWidget.mine.join(',') != widget.mine.join(',')) {
      // Fresh data from the server replaces the last answer.
      _latest = null;
    }
  }

  Future<void> _toggle(CommunityReactionInputKind kind, bool on) async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final CommunitiesApi api = ref.read(communitiesApiProvider);
    setState(() => _busy = true);
    try {
      final CommunityReactionsDto answer = switch ((widget.target, on)) {
        (ReactionTarget.post, true) => await api.unreactPost(widget.id, kind),
        (ReactionTarget.post, false) => await api.reactToPost(widget.id, kind),
        (ReactionTarget.comment, true) => await api.unreactComment(
          widget.id,
          kind,
        ),
        (ReactionTarget.comment, false) => await api.reactToComment(
          widget.id,
          kind,
        ),
      };
      if (mounted) {
        setState(() => _latest = answer);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunityReactionsDto? latest = _latest;
    final CommunityReactionCounts counts = latest == null
        ? widget.counts
        : CommunityReactionCounts(
            like: latest.like,
            helpful: latest.helpful,
            insightful: latest.insightful,
            support: latest.support,
          );
    final Set<String> mine = <String>{...latest?.myReactions ?? widget.mine};
    return Wrap(
      spacing: Insets.xs,
      runSpacing: Insets.xs,
      children: <Widget>[
        for (final CommunityReactionInputKind kind in reactionKinds)
          Semantics(
            label: l10n.reactionSemantics(
              reactionLabel(l10n, kind),
              reactionCount(counts, kind),
            ),
            selected: mine.contains(kind.json),
            button: true,
            excludeSemantics: true,
            child: FilterChip(
              label: Text(
                '${reactionLabel(l10n, kind)} ${reactionCount(counts, kind)}',
              ),
              selected: mine.contains(kind.json),
              showCheckmark: true,
              onSelected: !widget.enabled || _busy
                  ? null
                  : (bool _) => _toggle(kind, mine.contains(kind.json)),
            ),
          ),
      ],
    );
  }
}

/// A poll: the user's choice (one, or several when allowed) and the
/// aggregate results. Voting again replaces the earlier vote; the results
/// shown are the server's answer.
class PollView extends ConsumerStatefulWidget {
  /// Creates the poll.
  const PollView({
    required this.postId,
    required this.poll,
    this.canVote = true,
    super.key,
  });

  /// The post the poll belongs to.
  final String postId;

  /// The poll as loaded.
  final CommunityPollDto poll;

  /// Whether the user may vote (a member; the poll is open).
  final bool canVote;

  @override
  ConsumerState<PollView> createState() => _PollViewState();
}

class _PollViewState extends ConsumerState<PollView> {
  CommunityPollDto? _latest;
  late Set<String> _choice = <String>{...widget.poll.myVotes};
  bool _busy = false;

  CommunityPollDto get _poll => _latest ?? widget.poll;

  @override
  void didUpdateWidget(covariant PollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll != widget.poll) {
      _latest = null;
      _choice = <String>{...widget.poll.myVotes};
    }
  }

  Future<void> _vote() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final CommunityPollDto answer = await ref
          .read(communitiesApiProvider)
          .vote(widget.postId, _choice.toList());
      if (mounted) {
        setState(() {
          _latest = answer;
          _choice = <String>{...answer.myVotes};
        });
        showSnack(context, l10n.pollVoted);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final CommunityPollDto poll = _poll;
    final bool open = widget.canVote && !poll.closed;
    final String locale = Localizations.localeOf(context).toString();
    final Set<String> voted = <String>{...poll.myVotes};
    final bool changed =
        _choice.length != voted.length || !_choice.every(voted.contains);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(poll.question, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              <String>[
                l10n.pollTotalVotes(poll.totalVotes),
                if (poll.allowMultiple) l10n.pollChooseSeveral,
                if (poll.closed)
                  l10n.pollClosed
                else if (poll.closesAt case final DateTime at)
                  l10n.pollClosesAt(formatShortDate(at, locale: locale)),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            RadioGroup<String>(
              groupValue: poll.allowMultiple || _choice.isEmpty
                  ? null
                  : _choice.first,
              onChanged: (String? id) {
                if (id != null && open && !_busy && !poll.allowMultiple) {
                  setState(() => _choice = <String>{id});
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final CommunityPollOptionDto option in poll.options)
                    _PollOptionRow(
                      option: option,
                      total: poll.totalVotes,
                      chosen: _choice.contains(option.id),
                      mine: voted.contains(option.id),
                      multiple: poll.allowMultiple,
                      onChanged: !open || _busy
                          ? null
                          : (bool on) => setState(() {
                              if (poll.allowMultiple) {
                                on
                                    ? _choice.add(option.id)
                                    : _choice.remove(option.id);
                              } else {
                                _choice = <String>{option.id};
                              }
                            }),
                    ),
                ],
              ),
            ),
            if (open) ...<Widget>[
              const SizedBox(height: Insets.sm),
              FilledButton(
                onPressed: _busy || _choice.isEmpty || !changed ? null : _vote,
                child: Text(
                  voted.isEmpty ? l10n.pollVote : l10n.pollChangeVote,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(l10n.pollPrivacyNote, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.option,
    required this.total,
    required this.chosen,
    required this.mine,
    required this.multiple,
    required this.onChanged,
  });

  final CommunityPollOptionDto option;
  final int total;
  final bool chosen;
  final bool mine;
  final bool multiple;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int percent = total <= 0 ? 0 : (option.votes * 100 / total).round();
    final String result = l10n.pollOptionResult(option.votes, percent);
    final Widget control = multiple
        ? Checkbox(
            value: chosen,
            onChanged: onChanged == null
                ? null
                : (bool? v) => onChanged!(v ?? false),
          )
        : Radio<String>(value: option.id, enabled: onChanged != null);
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!chosen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              control,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mine ? l10n.pollYourChoice(option.label) : option.label,
                    ),
                    const SizedBox(height: Insets.xs),
                    ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: total <= 0 ? 0 : option.votes / total,
                        minHeight: 6,
                      ),
                    ),
                    Text(result, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a resource link in the system browser, only when it is `http` or
/// `https`; anything else is refused with a message.
Future<void> openCommunityLink(BuildContext context, String? value) async {
  final AppLocalizations l10n = context.l10n;
  final Uri? uri = safeLink(value);
  if (uri == null) {
    showSnack(context, l10n.communityLinkNotOpened);
    return;
  }
  final bool opened = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    showSnack(context, l10n.communityLinkNotOpened);
  }
}

/// What is being reported.
enum ReportTargetKind {
  /// A post (`POST /posts/{id}/reports`).
  post,

  /// A comment.
  comment,

  /// A community.
  community,
}

/// Asks for a reason (and optional details) and files a report. Posts use
/// `POST /posts/{id}/reports`, everything else `POST /content-reports`.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTargetKind kind,
  required String targetId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final ({PostReportInputReason reason, String details})? answer =
      await showDialog<({PostReportInputReason reason, String details})>(
        context: context,
        builder: (BuildContext dialogContext) => const _ReportDialog(),
      );
  if (answer == null || !context.mounted) {
    return;
  }
  final String? details = answer.details.trim().isEmpty
      ? null
      : answer.details.trim();
  try {
    if (kind == ReportTargetKind.post) {
      await ref
          .read(communitiesApiProvider)
          .reportPost(
            targetId,
            PostReportInput(reason: answer.reason, details: details),
          );
    } else {
      await ref
          .read(moderationApiProvider)
          .report(
            ModerationReportInput(
              reason: ModerationReportInputReason.fromJson(answer.reason.json),
              targetType: switch (kind) {
                ReportTargetKind.comment =>
                  ModerationReportInputTargetType.comment,
                _ => ModerationReportInputTargetType.community,
              },
              targetId: targetId,
              details: details,
            ),
          );
    }
    if (context.mounted) {
      showSnack(context, l10n.contentReportSent);
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      showSnack(
        context,
        error.code == ErrorObjectCode.conflict && error.details.isEmpty
            ? l10n.contentReportAlreadySent
            : describeError(l10n, error),
      );
    }
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  PostReportInputReason? _reason;
  final TextEditingController _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.contentReportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.contentReportIntro),
            const SizedBox(height: Insets.sm),
            RadioGroup<PostReportInputReason>(
              groupValue: _reason,
              onChanged: (PostReportInputReason? v) =>
                  setState(() => _reason = v),
              child: Column(
                children: <Widget>[
                  for (final PostReportInputReason r in reportReasons)
                    RadioListTile<PostReportInputReason>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(reportReasonLabel(l10n, r.json)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: PostReportInput.detailsMaxLength,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.contentReportDetailsLabel,
                helperText: l10n.contentReportDetailsHelp,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () =>
                    Navigator.of(context)
                        .pop((reason: _reason!, details: _details.text)),
          child: Text(l10n.contentReportSend),
        ),
      ],
    );
  }
}

/// Moderation actions offered for a kind of target.
List<ModerationActionInputAction> actionsFor(
  ModerationActionInputTargetType target, {
  bool pinned = false,
  bool locked = false,
  bool hidden = false,
  bool banned = false,
}) => switch (target) {
  ModerationActionInputTargetType.post => <ModerationActionInputAction>[
    if (hidden)
      ModerationActionInputAction.restore
    else
      ModerationActionInputAction.hideValue,
    ModerationActionInputAction.remove,
    if (pinned)
      ModerationActionInputAction.unpin
    else
      ModerationActionInputAction.pin,
    if (locked)
      ModerationActionInputAction.unlock
    else
      ModerationActionInputAction.lock,
  ],
  ModerationActionInputTargetType.comment => <ModerationActionInputAction>[
    if (hidden)
      ModerationActionInputAction.restore
    else
      ModerationActionInputAction.hideValue,
    ModerationActionInputAction.remove,
  ],
  ModerationActionInputTargetType.member => <ModerationActionInputAction>[
    ModerationActionInputAction.warn,
    ModerationActionInputAction.restrict,
    if (banned)
      ModerationActionInputAction.unban
    else
      ModerationActionInputAction.ban,
  ],
  _ => const <ModerationActionInputAction>[],
};

/// Whether [action] needs a reason (shown to the affected person).
bool actionNeedsReason(ModerationActionInputAction action) =>
    action == ModerationActionInputAction.hideValue ||
    action == ModerationActionInputAction.remove ||
    action == ModerationActionInputAction.warn ||
    action == ModerationActionInputAction.restrict ||
    action == ModerationActionInputAction.ban;

/// The verb for a moderation action button.
String moderationVerb(AppLocalizations l10n, ModerationActionInputAction a) =>
    switch (a) {
      ModerationActionInputAction.hideValue => l10n.moderationDoHide,
      ModerationActionInputAction.remove => l10n.moderationDoRemove,
      ModerationActionInputAction.restore => l10n.moderationDoRestore,
      ModerationActionInputAction.pin => l10n.moderationDoPin,
      ModerationActionInputAction.unpin => l10n.moderationDoUnpin,
      ModerationActionInputAction.lock => l10n.moderationDoLock,
      ModerationActionInputAction.unlock => l10n.moderationDoUnlock,
      ModerationActionInputAction.warn => l10n.moderationDoWarn,
      ModerationActionInputAction.restrict => l10n.moderationDoRestrict,
      ModerationActionInputAction.ban => l10n.moderationDoBan,
      ModerationActionInputAction.unban => l10n.moderationDoUnban,
      ModerationActionInputAction.dismissReport => l10n.moderationDoDismiss,
      ModerationActionInputAction.escalate => l10n.moderationDoEscalate,
      ModerationActionInputAction.unrecognized => l10n.statusWordUnknown,
    };

/// Lets a moderator pick one of [actions] for a target, asks for the reason
/// (and how long, for a posting pause), and sends it
/// (`POST /communities/{id}/moderation/actions`). Returns true when done.
Future<bool> moderateTarget(
  BuildContext context,
  WidgetRef ref, {
  required String communityId,
  required ModerationActionInputTargetType targetType,
  required String targetId,
  required List<ModerationActionInputAction> actions,
  String? reportId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final ModerationActionInputAction? action =
      await showDialog<ModerationActionInputAction>(
        context: context,
        builder: (BuildContext dialogContext) => SimpleDialog(
          title: Text(l10n.moderationChooseAction),
          children: <Widget>[
            for (final ModerationActionInputAction a in actions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(a),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(moderationVerb(l10n, a)),
                  ),
                ),
              ),
          ],
        ),
      );
  if (action == null || !context.mounted) {
    return false;
  }
  final ({String reason, int? hours})? details =
      await showDialog<({String reason, int? hours})>(
        context: context,
        builder: (BuildContext dialogContext) => _ActionDetailsDialog(
          action: action,
          title: moderationVerb(l10n, action),
        ),
      );
  if (details == null || !context.mounted) {
    return false;
  }
  try {
    await ref
        .read(communitiesApiProvider)
        .moderate(
          communityId,
          ModerationActionInput(
            action: action,
            targetType: targetType,
            targetId: targetId,
            reportId: reportId,
            reason: details.reason.trim().isEmpty
                ? null
                : details.reason.trim(),
            durationHours: details.hours,
          ),
        );
    ref.read(communityRevisionProvider.notifier).bump();
    if (context.mounted) {
      showSnack(context, l10n.moderationDone);
    }
    return true;
  } on ApiException catch (error) {
    if (context.mounted) {
      showSnack(context, describeError(l10n, error));
    }
    return false;
  }
}

class _ActionDetailsDialog extends StatefulWidget {
  const _ActionDetailsDialog({required this.action, required this.title});

  final ModerationActionInputAction action;
  final String title;

  @override
  State<_ActionDetailsDialog> createState() => _ActionDetailsDialogState();
}

class _ActionDetailsDialogState extends State<_ActionDetailsDialog> {
  final TextEditingController _reason = TextEditingController();
  int _hours = 24;

  static const List<int> _durations = <int>[1, 24, 72, 168, 720];

  static String _spanKey(int hours) => switch (hours) {
    1 => 'h1',
    24 => 'd1',
    72 => 'd3',
    168 => 'w1',
    720 => 'd30',
    _ => '$hours',
  };

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _needsReason => actionNeedsReason(widget.action);

  bool get _timed => widget.action == ModerationActionInputAction.restrict;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool ready = !_needsReason || _reason.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _reason,
              maxLength: ModerationActionInput.reasonMaxLength,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _needsReason
                    ? l10n.moderationReasonLabel
                    : l10n.moderationNoteLabel,
                helperText: _needsReason ? l10n.moderationReasonHelp : null,
                helperMaxLines: 3,
              ),
            ),
            if (_timed) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(l10n.moderationDurationLabel),
              Wrap(
                spacing: Insets.xs,
                children: <Widget>[
                  for (final int h in _durations)
                    ChoiceChip(
                      label: Text(l10n.moderationDuration(_spanKey(h))),
                      selected: _hours == h,
                      onSelected: (_) => setState(() => _hours = h),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context)
                    .pop((reason: _reason.text, hours: _timed ? _hours : null))
              : null,
          child: Text(widget.title),
        ),
      ],
    );
  }
}
