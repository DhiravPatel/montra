import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/presentation/community_widgets.dart';
import 'package:montra_mobile/features/moderation/domain/moderation_display.dart';

/// The moderators' tools for one community: the report queue (with the
/// reported excerpt, how many reports the target has, and actions), open
/// appeals to uphold or overturn, and the moderation log with "reverse".
/// Reported content is shown as plain text.
class CommunityModerationScreen extends ConsumerWidget {
  /// Creates the screen for [communityRef].
  const CommunityModerationScreen({required this.communityRef, super.key});

  /// The community's ID or URL name.
  final String communityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CommunityDto> community = ref.watch(
      communityProvider(communityRef),
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.communityModerationTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.moderationTabReports),
              Tab(text: l10n.moderationTabAppeals),
              Tab(text: l10n.moderationTabLog),
            ],
          ),
        ),
        body: AsyncValueView<CommunityDto>(
          value: community,
          onRetry: () => ref.invalidate(communityProvider(communityRef)),
          data: (CommunityDto c) => c.canModerate
              ? TabBarView(
                  children: <Widget>[
                    _ReportsTab(communityId: c.id),
                    _AppealsTab(communityId: c.id),
                    _LogTab(communityId: c.id),
                  ],
                )
              : MessageStateView(
                  icon: Icons.lock_outline,
                  title: l10n.errorPermissionTitle,
                  body: l10n.communitySettingsModeratorsOnly,
                ),
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab({required this.communityId});

  final String communityId;

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  String _status = 'open';

  ReportsQuery get _query => (communityId: widget.communityId, status: _status);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ModerationReportDto>> reports = ref.watch(
      moderationReportsProvider(_query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final String s in const <String>[
                'open',
                'actioned',
                'dismissed',
                'escalated',
              ])
                ChoiceChip(
                  label: Text(reportStatusLabel(l10n, s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<ModerationReportDto>>(
            value: reports,
            onRetry: () => ref.invalidate(moderationReportsProvider(_query)),
            isEmpty: (List<ModerationReportDto> data) => data.isEmpty,
            empty: MessageStateView(
              icon: Icons.verified_outlined,
              title: _status == 'open'
                  ? l10n.moderationReportsEmptyOpen
                  : l10n.moderationReportsEmpty,
            ),
            data: (List<ModerationReportDto> data) => RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(moderationReportsProvider(_query).future),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                children: <Widget>[
                  for (final ModerationReportDto r in data)
                    _ReportCard(communityId: widget.communityId, report: r),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.communityId, required this.report});

  final String communityId;
  final ModerationReportDto report;

  String? get _postId => switch (report.targetType) {
    ModerationReportDtoTargetType.post => report.targetId,
    ModerationReportDtoTargetType.comment => report.postId,
    _ => null,
  };

  ModerationActionInputTargetType? get _contentType =>
      switch (report.targetType) {
        ModerationReportDtoTargetType.post =>
          ModerationActionInputTargetType.post,
        ModerationReportDtoTargetType.comment =>
          ModerationActionInputTargetType.comment,
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final ModerationReportDto r = report;
    final bool open =
        r.status == ModerationReportDtoStatus.open ||
        r.status == ModerationReportDtoStatus.underReview;
    final String? postId = _postId;
    final ModerationActionInputTargetType? content = _contentType;
    final String? author = r.targetUserId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.moderationReportHeadline(
                moderationTargetLabel(l10n, r.targetType.json),
                reportReasonLabel(l10n, r.reason),
              ),
              style: theme.textTheme.titleSmall,
            ),
            Text(formatDateTime(r.createdAt, locale: locale)),
            if (r.preview case final String preview
                when preview.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                l10n.moderationReportPreview(preview),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (r.details case final String details
                when details.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Text(l10n.moderationReportDetails(details)),
            ],
            const SizedBox(height: Insets.xs),
            Text(l10n.moderationOpenReports(r.openReports)),
            const SizedBox(height: Insets.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusLabel(text: reportStatusLabel(l10n, r.status.json)),
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                if (postId != null)
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.postDetail(postId)),
                    child: Text(l10n.moderationOpenPost),
                  ),
                if (open && content != null)
                  FilledButton.tonal(
                    onPressed: () => moderateTarget(
                      context,
                      ref,
                      communityId: communityId,
                      targetType: content,
                      targetId: r.targetId,
                      reportId: r.id,
                      actions: <ModerationActionInputAction>[
                        ...actionsFor(content),
                        ModerationActionInputAction.dismissReport,
                        ModerationActionInputAction.escalate,
                      ],
                    ),
                    child: Text(l10n.moderationActOnContent),
                  )
                else if (open)
                  FilledButton.tonal(
                    onPressed: () => moderateTarget(
                      context,
                      ref,
                      communityId: communityId,
                      targetType: ModerationActionInputTargetType.fromJson(
                        r.targetType.json,
                      ),
                      targetId: r.targetId,
                      reportId: r.id,
                      actions: const <ModerationActionInputAction>[
                        ModerationActionInputAction.dismissReport,
                        ModerationActionInputAction.escalate,
                      ],
                    ),
                    child: Text(l10n.moderationActOnContent),
                  ),
                if (open && author != null)
                  OutlinedButton(
                    onPressed: () => moderateTarget(
                      context,
                      ref,
                      communityId: communityId,
                      targetType: ModerationActionInputTargetType.member,
                      targetId: author,
                      reportId: r.id,
                      actions: actionsFor(
                        ModerationActionInputTargetType.member,
                      ),
                    ),
                    child: Text(l10n.moderationActOnAuthor),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppealsTab extends ConsumerWidget {
  const _AppealsTab({required this.communityId});

  final String communityId;

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    ModerationAppealDto appeal,
    AppealDecisionInputDecision decision,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _NoteDialog(
        title: decision == AppealDecisionInputDecision.upheld
            ? l10n.moderationUpholdTitle
            : l10n.moderationOverturnTitle,
        body: decision == AppealDecisionInputDecision.upheld
            ? l10n.moderationUpholdBody
            : l10n.moderationOverturnBody,
        confirm: decision == AppealDecisionInputDecision.upheld
            ? l10n.moderationUphold
            : l10n.moderationOverturn,
        maxLength: AppealDecisionInput.noteMaxLength,
      ),
    );
    if (note == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(communitiesApiProvider)
          .decideAppeal(
            appeal.id,
            AppealDecisionInput(
              decision: decision,
              note: note.trim().isEmpty ? null : note.trim(),
            ),
          );
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.moderationAppealDecided);
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
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<ModerationAppealDto>> appeals = ref.watch(
      moderationAppealsProvider(communityId),
    );
    return AsyncValueView<List<ModerationAppealDto>>(
      value: appeals,
      onRetry: () => ref.invalidate(moderationAppealsProvider(communityId)),
      isEmpty: (List<ModerationAppealDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.gavel_outlined,
        title: l10n.moderationAppealsEmpty,
      ),
      data: (List<ModerationAppealDto> data) => ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: <Widget>[
          for (final ModerationAppealDto a in data)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.moderationAppealAgainst(
                        moderationActionLabel(l10n, a.action.action),
                        moderationTargetLabel(l10n, a.action.targetType.json),
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(formatDateTime(a.createdAt, locale: locale)),
                    if (a.action.reason case final String reason
                        when reason.isNotEmpty)
                      Text(l10n.moderationDecisionReason(reason)),
                    const SizedBox(height: Insets.sm),
                    Text(l10n.moderationAppealStatement(a.statement)),
                    const SizedBox(height: Insets.xs),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StatusLabel(
                        text: appealStatusLabel(l10n, a.status.json),
                      ),
                    ),
                    if (a.status == ModerationAppealDtoStatus.open) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      Wrap(
                        spacing: Insets.sm,
                        runSpacing: Insets.xs,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => _decide(
                              context,
                              ref,
                              a,
                              AppealDecisionInputDecision.upheld,
                            ),
                            child: Text(l10n.moderationUphold),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _decide(
                              context,
                              ref,
                              a,
                              AppealDecisionInputDecision.overturned,
                            ),
                            child: Text(l10n.moderationOverturn),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogTab extends ConsumerWidget {
  const _LogTab({required this.communityId});

  final String communityId;

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    ModerationActionDto action,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _NoteDialog(
        title: l10n.moderationReverseTitle,
        body: l10n.moderationReverseBody,
        confirm: l10n.moderationReverse,
        maxLength: ModerationReverseInput.noteMaxLength,
      ),
    );
    if (note == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(communitiesApiProvider)
          .reverseAction(
            action.id,
            note: note.trim().isEmpty ? null : note.trim(),
          );
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.moderationReversed);
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
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<ModerationActionDto>> log = ref.watch(
      moderationLogProvider(communityId),
    );
    return AsyncValueView<List<ModerationActionDto>>(
      value: log,
      onRetry: () => ref.invalidate(moderationLogProvider(communityId)),
      isEmpty: (List<ModerationActionDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.history,
        title: l10n.moderationLogEmpty,
      ),
      data: (List<ModerationActionDto> data) => ListView(
        children: <Widget>[
          for (final ModerationActionDto a in data)
            ListTile(
              title: Text(
                l10n.moderationLogLine(
                  moderationActionLabel(l10n, a.action),
                  moderationTargetLabel(l10n, a.targetType.json),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(formatDateTime(a.createdAt, locale: locale)),
                  if (a.reason case final String reason when reason.isNotEmpty)
                    Text(l10n.moderationDecisionReason(reason)),
                  if (a.expiresAt case final DateTime until)
                    Text(
                      l10n.moderationUntil(
                        formatDateTime(until, locale: locale),
                      ),
                    ),
                  if (a.reversedAt case final DateTime at)
                    StatusLabel(
                      text: l10n.moderationReversedAt(
                        formatDateTime(at, locale: locale),
                      ),
                    ),
                ],
              ),
              trailing: a.reversedAt == null && _reversible(a.action)
                  ? TextButton(
                      onPressed: () => _reverse(context, ref, a),
                      child: Text(l10n.moderationReverse),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  static bool _reversible(String action) => const <String>{
    'hide',
    'remove',
    'pin',
    'lock',
    'warn',
    'restrict',
    'ban',
  }.contains(action);
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.maxLength,
  });

  final String title;
  final String body;
  final String confirm;
  final int maxLength;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.body),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _note,
              maxLength: widget.maxLength,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.moderationNoteLabel),
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
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
