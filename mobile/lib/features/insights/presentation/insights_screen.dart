import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/insights/application/insights_providers.dart';
import 'package:montra_mobile/features/insights/domain/insight_messages.dart';
import 'package:montra_mobile/features/insights/presentation/insight_widgets.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';

/// Insights tab: unusual activity and savings opportunities found by fixed
/// rules over the user's own records (`GET /insights`, page by page;
/// warnings first). Active ones by default, or everything including
/// dismissed, expected, resolved and muted ones; filter by kind. Shortcuts
/// lead to analytics and reports. No AI is used.
class InsightsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _all = false;
  String _kind = '';

  InsightFilter get _filter => (all: _all, kind: _kind);

  Future<void> _refresh() async {
    ref.invalidate(insightsProvider(_filter));
    try {
      await ref.read(insightsProvider(_filter).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  Future<void> _pickKind() async {
    final AppLocalizations l10n = context.l10n;
    final String? kind = await showOptionSheet<String>(
      context,
      title: l10n.insightKindFilter,
      selected: _kind,
      options: <SheetOption<String>>[
        SheetOption<String>(value: '', label: l10n.insightKindAll),
        for (final InsightDtoKind k in InsightDtoKind.values)
          if (k != InsightDtoKind.unrecognized)
            SheetOption<String>(
              value: k.json,
              label: insightKindLabel(l10n, k),
            ),
      ],
    );
    if (kind != null && mounted) {
      setState(() => _kind = kind);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final InsightFilter filter = _filter;
    final AsyncValue<PagedList<InsightDto>> list = ref.watch(
      insightsProvider(filter),
    );
    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.sm,
            Insets.md,
            0,
          ),
          child: Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.insights_outlined, size: 18),
                label: Text(l10n.entryAnalytics),
                onPressed: () => context.push(AppRoutes.analytics),
              ),
              ActionChip(
                avatar: const Icon(Icons.summarize_outlined, size: 18),
                label: Text(l10n.entryReports),
                onPressed: () => context.push(AppRoutes.reports),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.sm,
            Insets.md,
            Insets.xs,
          ),
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.insightViewActive),
                selected: !_all,
                onSelected: (_) => setState(() => _all = false),
              ),
              const SizedBox(width: Insets.sm),
              ChoiceChip(
                label: Text(l10n.insightViewAll),
                selected: _all,
                onSelected: (_) => setState(() => _all = true),
              ),
              const SizedBox(width: Insets.sm),
              ActionChip(
                avatar: const Icon(Icons.filter_list, size: 18),
                label: Text(
                  _kind.isEmpty
                      ? l10n.insightKindAll
                      : insightKindLabel(l10n, InsightDtoKind.fromJson(_kind)),
                ),
                tooltip: l10n.insightKindFilter,
                onPressed: _pickKind,
              ),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navInsights),
        bottom: list.isLoading && list.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.insightMutesTitle,
            icon: const Icon(Icons.notifications_off_outlined),
            onPressed: () => context.push(AppRoutes.insightMutes),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          Expanded(
            child: AsyncValueView<PagedList<InsightDto>>(
              value: list,
              onRetry: () => ref.invalidate(insightsProvider(filter)),
              isEmpty: (PagedList<InsightDto> p) => p.items.isEmpty,
              empty: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    MessageStateView(
                      icon: Icons.lightbulb_outline,
                      title: l10n.insightEmptyTitle,
                      body: l10n.insightEmptyBody,
                    ),
                  ],
                ),
              ),
              data: (PagedList<InsightDto> p) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  itemCount: p.items.length + 2,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.md,
                          Insets.xs,
                          Insets.md,
                          Insets.sm,
                        ),
                        child: Text(
                          l10n.insightRulesNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    if (index == p.items.length + 1) {
                      return LoadMoreFooter(
                        list: p,
                        onLoadMore: () => ref
                            .read(insightsProvider(filter).notifier)
                            .loadMore(),
                      );
                    }
                    final InsightDto insight = p.items[index - 1];
                    return InsightTile(
                      insight: insight,
                      onTap: () =>
                          context.push(AppRoutes.insightDetail(insight.id)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
