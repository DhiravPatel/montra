import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/subscriptions/application/subscriptions_providers.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_widgets.dart';

/// Subscriptions overview: cost per currency, trials ending soon, upcoming
/// renewals, possible subscriptions to review and the list by status.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String _filter = '';

  Future<void> _refresh() async {
    ref
      ..invalidate(subscriptionSummaryProvider)
      ..invalidate(subscriptionsProvider(_filter));
    try {
      await ref.read(subscriptionsProvider(_filter).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  void _open(String id) => context.push(AppRoutes.subscriptionDetail(id));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<SubscriptionSummary> summary = ref.watch(
      subscriptionSummaryProvider,
    );
    final AsyncValue<List<SubscriptionDto>> list = ref.watch(
      subscriptionsProvider(_filter),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscriptionsTitle),
        actions: <Widget>[
          const HelpGuideButton(HelpGuide.recurring),
          IconButton(
            tooltip: l10n.detectionsTitle,
            icon: const Icon(Icons.manage_search),
            onPressed: () => context.push(AppRoutes.subscriptionDetections),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newSubscription),
        icon: const Icon(Icons.add),
        label: Text(l10n.subscriptionAdd),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            _SummarySection(summary: summary, onOpen: _open),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.lg,
                Insets.md,
                Insets.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.subscriptionListTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: <Widget>[
                  for (final String f in subscriptionListFilters)
                    ChoiceChip(
                      label: Text(subscriptionFilterLabel(l10n, f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            ..._list(context, list),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(
    BuildContext context,
    AsyncValue<List<SubscriptionDto>> list,
  ) {
    final AppLocalizations l10n = context.l10n;
    if (list.hasError && !list.isLoading) {
      final Object error = list.error!;
      return <Widget>[
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: NoticeBanner(
            tone: NoticeTone.error,
            title: l10n.subscriptionListError,
            message: describeError(l10n, error),
            requestId: requestIdOf(error),
            action: TextButton(
              onPressed: () => ref.invalidate(subscriptionsProvider(_filter)),
              child: Text(l10n.actionRetry),
            ),
          ),
        ),
      ];
    }
    final List<SubscriptionDto>? data = list.value;
    if (data == null) {
      return const <Widget>[SizedBox(height: 160, child: LoadingStateView())];
    }
    if (data.isEmpty) {
      return <Widget>[
        if (_filter.isEmpty)
          _InlineMessage(
            icon: Icons.subscriptions_outlined,
            title: l10n.subscriptionEmptyTitle,
            body: l10n.subscriptionEmptyBody,
            action: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newSubscription),
              icon: const Icon(Icons.add),
              label: Text(l10n.subscriptionAdd),
            ),
          )
        else
          _InlineMessage(
            icon: Icons.filter_alt_off_outlined,
            title: l10n.subscriptionEmptyFiltered,
          ),
      ];
    }
    return <Widget>[
      for (final SubscriptionDto s in data)
        SubscriptionTile(subscription: s, onTap: () => _open(s.id)),
      // The server lists at most 500; say so rather than imply that's all.
      if (data.length >= SubscriptionsApi.listCap)
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Text(
            l10n.subscriptionListCapped(SubscriptionsApi.listCap),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }
}

/// An empty-state message laid out inside the scrolling page (no scroll
/// view of its own).
class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? body = this.body;
    final Widget? action = this.action;
    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.md),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            action,
          ],
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary, required this.onOpen});

  final AsyncValue<SubscriptionSummary> summary;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<SubscriptionSummary> s = summary;
    if (s.hasError && !s.isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, 0),
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) =>
              NoticeBanner(
                tone: NoticeTone.error,
                title: l10n.subscriptionSummaryError,
                message: describeError(l10n, s.error!),
                requestId: requestIdOf(s.error!),
                action: TextButton(
                  onPressed: () => ref.invalidate(subscriptionSummaryProvider),
                  child: Text(l10n.actionRetry),
                ),
              ),
        ),
      );
    }
    final SubscriptionSummary? data = s.value;
    if (data == null) {
      return const SizedBox(height: 120, child: LoadingStateView());
    }
    final List<SubscriptionCostTotal> totals = data.totals;
    final List<SubscriptionDto> trials = data.trialsEndingSoon;
    final List<SubscriptionDto> renewals = data.upcomingRenewals;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (totals.isNotEmpty) SubscriptionTotalsCard(totals: totals),
          _DetectionsCard(pending: data.pendingDetections),
          if (trials.isNotEmpty)
            SectionCard(
              title: l10n.subscriptionTrialsTitle,
              children: <Widget>[
                for (final SubscriptionDto t in trials)
                  SubscriptionTile(subscription: t, onTap: () => onOpen(t.id)),
              ],
            ),
          if (renewals.isNotEmpty)
            SectionCard(
              title: l10n.subscriptionRenewalsTitle,
              children: <Widget>[
                for (final SubscriptionDto r in renewals)
                  SubscriptionTile(subscription: r, onTap: () => onOpen(r.id)),
              ],
            ),
        ],
      ),
    );
  }
}

class _DetectionsCard extends StatelessWidget {
  const _DetectionsCard({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.manage_search),
        title: Text(
          pending > 0
              ? l10n.subscriptionDetectionsPending(pending)
              : l10n.detectionsTitle,
        ),
        subtitle: Text(
          pending > 0 ? l10n.subscriptionDetectionsReview : l10n.detectionsHint,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.subscriptionDetections),
      ),
    );
  }
}
