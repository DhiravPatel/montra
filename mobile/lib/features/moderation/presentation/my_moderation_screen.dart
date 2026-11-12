import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/moderation/application/moderation_providers.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';
import 'package:montra_mobile/features/moderation/domain/moderation_display.dart';

/// What moderation did about the user: the decisions (with the reason,
/// how long they last, and the appeal's state and outcome), appealing a
/// decision within its 30-day window, the user's appeals, and the reports
/// they filed with what happened to them.
class MyModerationScreen extends StatelessWidget {
  /// Creates the screen, opened on [initialTab] (`decisions`, `appeals`
  /// or `reports`).
  const MyModerationScreen({this.initialTab, super.key});

  /// Tab to open first.
  final String? initialTab;

  static const List<String> _tabs = <String>['decisions', 'appeals', 'reports'];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int initial = _tabs.indexOf(initialTab ?? '');
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myModerationTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.myModerationTabDecisions),
              Tab(text: l10n.myModerationTabAppeals),
              Tab(text: l10n.myModerationTabReports),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_DecisionsTab(), _AppealsTab(), _ReportsTab()],
        ),
      ),
    );
  }
}

class _DecisionsTab extends ConsumerWidget {
  const _DecisionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ModerationActionDto>> decisions = ref.watch(
      myModerationProvider,
    );
    return AsyncValueView<List<ModerationActionDto>>(
      value: decisions,
      onRetry: () => ref.invalidate(myModerationProvider),
      isEmpty: (List<ModerationActionDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.verified_user_outlined,
        title: l10n.myModerationDecisionsEmptyTitle,
        body: l10n.myModerationDecisionsEmptyBody,
      ),
      data: (List<ModerationActionDto> data) => RefreshIndicator(
        onRefresh: () => ref.refresh(myModerationProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            Text(l10n.myModerationIntro),
            const SizedBox(height: Insets.sm),
            for (final ModerationActionDto a in data) DecisionCard(action: a),
          ],
        ),
      ),
    );
  }
}

/// One decision about the user, with its appeal.
class DecisionCard extends ConsumerWidget {
  /// Creates the card.
  const DecisionCard({required this.action, this.now, super.key});

  /// The decision.
  final ModerationActionDto action;

  /// Clock (tests).
  final DateTime? now;

  Future<void> _appeal(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final String? statement = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const _AppealDialog(),
    );
    if (statement == null || statement.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref.read(moderationApiProvider).appeal(action.id, statement.trim());
      ref
        ..invalidate(myModerationProvider)
        ..invalidate(myAppealsProvider);
      if (context.mounted) {
        showSnack(context, l10n.appealSent);
      }
    } on ApiException catch (error) {
      ref.invalidate(myModerationProvider);
      if (context.mounted) {
        showSnack(
          context,
          error.code == ErrorObjectCode.conflict && error.details.isEmpty
              ? l10n.appealAlreadySent
              : describeError(l10n, error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final ModerationActionDto a = action;
    final DateTime clock = now ?? DateTime.now();
    final ModerationAppealState? appeal = a.appeal;
    final DateTime? until = a.appealUntil;
    final bool canAppeal =
        a.appealable &&
        appeal == null &&
        a.reversedAt == null &&
        (until == null || until.isAfter(clock));
    final DateTime? expires = a.expiresAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.moderationLogLine(
                  moderationActionLabel(l10n, a.action),
                  moderationTargetLabel(l10n, a.targetType.json),
                ),
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(formatDateTime(a.createdAt, locale: locale)),
            if (a.communityId == null) Text(l10n.myModerationByStaff),
            if (a.reason case final String reason when reason.isNotEmpty)
              Text(l10n.moderationDecisionReason(reason)),
            if (expires != null)
              Text(
                expires.isAfter(clock)
                    ? l10n.moderationUntil(
                        formatDateTime(expires, locale: locale),
                      )
                    : l10n.myModerationEnded(
                        formatDateTime(expires, locale: locale),
                      ),
              ),
            if (a.reversedAt case final DateTime at) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusLabel(
                  text: l10n.moderationReversedAt(
                    formatDateTime(at, locale: locale),
                  ),
                  tone: StatusTone.positive,
                ),
              ),
            ],
            if (appeal != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              NoticeBanner(
                tone: appeal.status == ModerationAppealStateStatus.overturned
                    ? NoticeTone.success
                    : NoticeTone.info,
                title: appealStatusLabel(l10n, appeal.status.json),
                message: <String>[
                  appealStatusHelp(l10n, appeal.status.json),
                  if (appeal.decisionNote case final String note
                      when note.isNotEmpty)
                    l10n.appealDecisionNote(note),
                  if (appeal.decidedAt case final DateTime at)
                    l10n.appealDecidedOn(formatDateTime(at, locale: locale)),
                ].join('\n'),
              ),
            ] else if (canAppeal) ...<Widget>[
              const SizedBox(height: Insets.sm),
              if (until != null)
                Text(l10n.appealWindow(formatDateTime(until, locale: locale))),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => _appeal(context, ref),
                  icon: const Icon(Icons.gavel_outlined),
                  label: Text(l10n.appealAction),
                ),
              ),
            ] else if (a.reversedAt == null) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Text(
                until != null && !until.isAfter(clock)
                    ? l10n.moderationErrorAppealWindowPassed
                    : l10n.moderationErrorNotAppealable,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppealDialog extends StatefulWidget {
  const _AppealDialog();

  @override
  State<_AppealDialog> createState() => _AppealDialogState();
}

class _AppealDialogState extends State<_AppealDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.appealTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.appealIntro),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              maxLength: ModerationAppealInput.statementMaxLength,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.appealStatementLabel),
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
          onPressed: _text.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_text.text),
          child: Text(l10n.appealSend),
        ),
      ],
    );
  }
}

class _AppealsTab extends ConsumerWidget {
  const _AppealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<ModerationAppealDto>> appeals = ref.watch(
      myAppealsProvider,
    );
    return AsyncValueView<List<ModerationAppealDto>>(
      value: appeals,
      onRetry: () => ref.invalidate(myAppealsProvider),
      isEmpty: (List<ModerationAppealDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.gavel_outlined,
        title: l10n.myModerationAppealsEmpty,
      ),
      data: (List<ModerationAppealDto> data) => RefreshIndicator(
        onRefresh: () => ref.refresh(myAppealsProvider.future),
        child: ListView(
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
                      Text(
                        l10n.appealSentOn(
                          formatDateTime(a.createdAt, locale: locale),
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(l10n.moderationAppealStatement(a.statement)),
                      const SizedBox(height: Insets.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: StatusLabel(
                          text: appealStatusLabel(l10n, a.status.json),
                          tone: a.status == ModerationAppealDtoStatus.overturned
                              ? StatusTone.positive
                              : StatusTone.neutral,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(appealStatusHelp(l10n, a.status.json)),
                      if (a.decisionNote case final String note
                          when note.isNotEmpty)
                        Text(l10n.appealDecisionNote(note)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<ModerationReportDto>> reports = ref.watch(
      myReportsProvider,
    );
    return AsyncValueView<List<ModerationReportDto>>(
      value: reports,
      onRetry: () => ref.invalidate(myReportsProvider),
      isEmpty: (List<ModerationReportDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.flag_outlined,
        title: l10n.myModerationReportsEmpty,
      ),
      data: (List<ModerationReportDto> data) => RefreshIndicator(
        onRefresh: () => ref.refresh(myReportsProvider.future),
        child: ListView(
          children: <Widget>[
            for (final ModerationReportDto r in data)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(
                  l10n.moderationReportHeadline(
                    moderationTargetLabel(l10n, r.targetType.json),
                    reportReasonLabel(l10n, r.reason),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(formatDateTime(r.createdAt, locale: locale)),
                    const SizedBox(height: Insets.xs),
                    StatusLabel(text: reportStatusLabel(l10n, r.status.json)),
                    Text(reportStatusHelp(l10n, r.status.json)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
