import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/insights/application/insights_providers.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/insights/domain/insight_messages.dart';
import 'package:montra_mobile/features/insights/presentation/insight_widgets.dart';

/// One insight: the localized message, why it was raised (`rule_code`),
/// the amounts it is based on, the record it is about, and what can be done
/// with it (dismiss, snooze, expected, resolved, mute this kind, reopen),
/// plus "Was this helpful?" (`my_feedback`). Actions never change the
/// user's records.
class InsightDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const InsightDetailScreen({required this.insightId, super.key});

  /// The insight.
  final String insightId;

  @override
  ConsumerState<InsightDetailScreen> createState() =>
      _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  /// The server's answer to the last action or feedback.
  InsightDto? _latest;
  final TextEditingController _note = TextEditingController();
  bool _noteLoaded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _changed(InsightDto updated) {
    setState(() => _latest = updated);
    ref.read(insightsRevisionProvider.notifier).bump();
  }

  Future<void> _act(
    InsightDto insight,
    ActionInputAction action, {
    int? snoozeDays,
  }) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final InsightDto updated = await ref
          .read(insightsApiProvider)
          .act(insight.id, action, snoozeDays: snoozeDays);
      if (!mounted) {
        return;
      }
      _changed(updated);
      showSnack(context, switch (action) {
        ActionInputAction.dismiss => l10n.insightDismissed,
        ActionInputAction.snooze => l10n.insightSnoozed(snoozeDays ?? 0),
        ActionInputAction.expected => l10n.insightMarkedExpected,
        ActionInputAction.resolved => l10n.insightMarkedResolved,
        ActionInputAction.mute => l10n.insightMuted,
        ActionInputAction.reopen => l10n.insightReopened,
        ActionInputAction.unrecognized => l10n.insightSaved,
      });
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _snooze(InsightDto insight) async {
    final AppLocalizations l10n = context.l10n;
    final int? days = await showOptionSheet<int>(
      context,
      title: l10n.insightSnoozeTitle,
      options: <SheetOption<int>>[
        for (final int d in <int>[1, 7, 30])
          SheetOption<int>(value: d, label: l10n.insightSnoozeDays(d)),
      ],
    );
    if (days != null && mounted) {
      await _act(insight, ActionInputAction.snooze, snoozeDays: days);
    }
  }

  Future<void> _mute(InsightDto insight) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.insightMuteTitle,
      body: l10n.insightMuteBody(insightSubtypeLabel(l10n, insight.subtype)),
      confirmLabel: l10n.insightMute,
    );
    if (confirmed && mounted) {
      await _act(insight, ActionInputAction.mute);
    }
  }

  Future<void> _feedback(
    InsightDto insight,
    FeedbackInputFeedback feedback,
  ) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final InsightDto updated = await ref
          .read(insightsApiProvider)
          .feedback(insight.id, feedback, note: _note.text.trim());
      if (!mounted) {
        return;
      }
      _changed(updated);
      showSnack(context, l10n.insightFeedbackSaved);
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<InsightDto?> loaded = ref.watch(
      insightProvider(widget.insightId),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightDetailTitle)),
      body: AsyncValueView<InsightDto?>(
        value: _latest == null ? loaded : AsyncData<InsightDto?>(_latest),
        onRetry: () => ref.invalidate(insightProvider(widget.insightId)),
        isEmpty: (InsightDto? i) => i == null,
        empty: MessageStateView(
          icon: Icons.search_off,
          title: l10n.insightNotFoundTitle,
          body: l10n.insightNotFoundBody,
        ),
        data: (InsightDto? insight) => _body(context, insight!),
      ),
    );
  }

  Widget _body(BuildContext context, InsightDto insight) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final InsightText text = insightText(l10n, insight, locale: locale);
    final InsightParams params = InsightParams(insight.messageParams);
    final Object? rawAmounts = insight.evidence['amounts'];
    final Map<String, Money> amounts = InsightParams(
      rawAmounts is Map<String, Object?> ? rawAmounts : null,
    ).amounts;
    final ({String route, String label, bool tab})? link = insightRecordLink(
      l10n,
      params,
    );
    final String? rule = insightRuleText(l10n, insight.ruleCode);
    final FeedbackDto? mine = insight.myFeedback;
    if (!_noteLoaded) {
      _note.text = mine?.note ?? '';
      _noteLoaded = true;
    }
    final bool active = insight.status == InsightDtoStatus.active;
    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: <Widget>[
                  InsightSeverityLabel(insight.severity),
                  StatusLabel(
                    text: insightStatusLabel(l10n, insight.status),
                    tone: active ? StatusTone.neutral : StatusTone.positive,
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Semantics(
                header: true,
                child: Text(text.title, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: Insets.sm),
              Text(text.body),
              if (insight.snoozedUntil case final DateTime until
                  when insight.status == InsightDtoStatus.snoozed) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Text(
                  l10n.insightSnoozedUntil(
                    formatDateTime(until, locale: locale),
                  ),
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          title: l10n.insightWhyTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs,
              ),
              child: Text(rule ?? l10n.insightRuleUnknown),
            ),
            if (insight.periodStart case final String from)
              DetailRow(
                label: l10n.insightPeriod,
                value: LocalDates.displayRange(
                  from,
                  insight.periodEnd ?? from,
                  locale: locale,
                ),
              ),
            DetailRow(
              label: l10n.insightKindLabel,
              value: insightKindLabel(l10n, insight.kind),
            ),
            for (final MapEntry<String, Money> e in amounts.entries)
              DetailRow(
                label: insightAmountLabel(l10n, e.key),
                child: MoneyText(e.value),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs,
              ),
              child: Text(
                l10n.insightRulesNote,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (link != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: OutlinedButton.icon(
              onPressed: () =>
                  link.tab ? context.go(link.route) : context.push(link.route),
              icon: const Icon(Icons.open_in_new),
              label: Text(link.label),
            ),
          ),
        SectionCard(
          title: l10n.insightActionsTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(l10n.insightActionsHelp),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (active) ...<Widget>[
                    SubmitButton(
                      kind: SubmitButtonKind.outlined,
                      icon: Icons.check_circle_outline,
                      label: l10n.insightActionExpected,
                      onPressed: () =>
                          _act(insight, ActionInputAction.expected),
                    ),
                    const SizedBox(height: Insets.sm),
                    SubmitButton(
                      kind: SubmitButtonKind.outlined,
                      icon: Icons.task_alt,
                      label: l10n.insightActionResolved,
                      onPressed: () =>
                          _act(insight, ActionInputAction.resolved),
                    ),
                    const SizedBox(height: Insets.sm),
                    OutlinedButton.icon(
                      onPressed: () => _snooze(insight),
                      icon: const Icon(Icons.snooze),
                      label: Text(l10n.insightActionSnooze),
                    ),
                    const SizedBox(height: Insets.sm),
                    SubmitButton(
                      kind: SubmitButtonKind.outlined,
                      icon: Icons.close,
                      label: l10n.insightActionDismiss,
                      onPressed: () => _act(insight, ActionInputAction.dismiss),
                    ),
                    const SizedBox(height: Insets.sm),
                    OutlinedButton.icon(
                      onPressed: () => _mute(insight),
                      icon: const Icon(Icons.notifications_off_outlined),
                      label: Text(l10n.insightActionMute),
                    ),
                  ] else
                    SubmitButton(
                      kind: SubmitButtonKind.outlined,
                      icon: Icons.restart_alt,
                      label: l10n.insightActionReopen,
                      onPressed: () => _act(insight, ActionInputAction.reopen),
                    ),
                ],
              ),
            ),
          ],
        ),
        SectionCard(
          title: l10n.insightFeedbackTitle,
          children: <Widget>[
            if (mine != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Text(
                  l10n.insightFeedbackYours(
                    insightFeedbackLabel(l10n, mine.feedback),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: l10n.insightFeedbackNote,
                  helperText: l10n.insightFeedbackNoteHelp,
                  helperMaxLines: 3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: <Widget>[
                  for (final FeedbackInputFeedback f in <FeedbackInputFeedback>[
                    FeedbackInputFeedback.helpful,
                    FeedbackInputFeedback.notHelpful,
                    FeedbackInputFeedback.incorrect,
                  ])
                    ChoiceChip(
                      label: Text(
                        insightFeedbackLabel(
                          l10n,
                          FeedbackDtoFeedback.fromJson(f.json),
                        ),
                      ),
                      selected: mine?.feedback.json == f.json,
                      onSelected: (_) => _feedback(insight, f),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
