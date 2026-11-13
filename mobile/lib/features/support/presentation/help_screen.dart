import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/support/application/support_providers.dart';
import 'package:montra_mobile/features/support/domain/help_guide_content.dart';
import 'package:montra_mobile/features/support/domain/support_display.dart';
import 'package:montra_mobile/features/support/presentation/help_guides_screen.dart';

/// Help & support: short answers to common questions (each opening the
/// screen it is about), the user's requests and a way to ask for help.
class HelpScreen extends ConsumerWidget {
  /// Creates the screen.
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<RequestDto>> requests = ref.watch(
      supportRequestsProvider,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.helpNewRequest),
        onPressed: () => context.push(AppRoutes.newSupportRequest),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(supportRequestsProvider.future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            ContentFrame(
              child: Text(
                l10n.helpIntro,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const ContentFrame(child: _Guides()),
            const ContentFrame(child: _Topics()),
            ContentFrame(
              child: SectionCard(
                title: l10n.helpYourRequests,
                children: <Widget>[_requestsSection(context, ref, requests)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _requestsSection(
  BuildContext context,
  WidgetRef ref,
  AsyncValue<List<RequestDto>> requests,
) {
  final AppLocalizations l10n = context.l10n;
  final List<RequestDto>? value = requests.value;
  if (value == null && requests.hasError && !requests.isLoading) {
    // The error view scrolls itself, so it needs a bounded height here.
    return SizedBox(
      height: 360,
      child: ErrorStateView(
        error: requests.error!,
        onRetry: () => ref.invalidate(supportRequestsProvider),
      ),
    );
  }
  if (value == null) {
    return const Padding(
      padding: EdgeInsets.all(Insets.lg),
      child: LoadingStateView(),
    );
  }
  if (value.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Text(l10n.helpNoRequests),
    );
  }
  return Column(
    children: <Widget>[for (final RequestDto r in value) _RequestTile(r)],
  );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(this.request);

  final RequestDto request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final (String status, StatusTone tone) = supportStatus(
      l10n,
      request.status,
    );
    return ListTile(
      title: Text(request.subject),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.helpRequestMeta(
              supportKindLabel(l10n, request.kind.json),
              request.reference,
              formatShortDate(
                request.lastMessageAt ?? request.updatedAt,
                locale: locale,
              ),
            ),
          ),
          if (request.messageCount > 0)
            Text(l10n.helpMessageCount(request.messageCount)),
          const SizedBox(height: Insets.xs),
          StatusLabel(text: status, tone: tone),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.supportRequestDetail(request.id)),
    );
  }
}

/// Short answers to the questions people ask most.
class _Topics extends StatelessWidget {
  const _Topics();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<(IconData, String, String, String, String)> topics =
        <(IconData, String, String, String, String)>[
          (
            Icons.balance_outlined,
            l10n.helpTopicMoneyTitle,
            l10n.helpTopicMoneyBody,
            l10n.helpTopicMoneyLink,
            AppRoutes.analytics,
          ),
          (
            Icons.lock_outline,
            l10n.helpTopicPrivacyTitle,
            l10n.helpTopicPrivacyBody,
            l10n.helpTopicPrivacyLink,
            AppRoutes.privacy,
          ),
          (
            Icons.upload_file_outlined,
            l10n.helpTopicImportsTitle,
            l10n.helpTopicImportsBody,
            l10n.helpTopicImportsLink,
            AppRoutes.imports,
          ),
          (
            Icons.groups_outlined,
            l10n.helpTopicGroupsTitle,
            l10n.helpTopicGroupsBody,
            l10n.helpTopicGroupsLink,
            AppRoutes.groups,
          ),
          (
            Icons.speed_outlined,
            l10n.helpTopicLimitsTitle,
            l10n.helpTopicLimitsBody,
            l10n.helpTopicLimitsLink,
            AppRoutes.limits,
          ),
          (
            Icons.gavel_outlined,
            l10n.helpTopicModerationTitle,
            l10n.helpTopicModerationBody,
            l10n.helpTopicModerationLink,
            AppRoutes.myModeration,
          ),
        ];
    return SectionCard(
      title: l10n.helpTopicsTitle,
      children: <Widget>[
        for (final (
              IconData icon,
              String title,
              String body,
              String link,
              String route,
            )
            in topics)
          ExpansionTile(
            leading: Icon(icon),
            title: Text(title),
            childrenPadding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.sm,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(body),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push(route),
                  child: Text(link),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The in-app guides, by topic (HELP-001).
class _Guides extends StatelessWidget {
  const _Guides();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SectionCard(
      title: l10n.helpGuidesTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(l10n.helpGuidesDescription),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: Text(l10n.helpGuidesSearch),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.helpGuides),
        ),
        for (final HelpGuideTopic topic in HelpGuideTopic.values)
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(topic.title(l10n)),
            subtitle: Text(
              helpGuides
                  .where((HelpGuideContent c) => c.topic == topic)
                  .map((HelpGuideContent c) => c.guide.title(l10n))
                  .join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.helpGuidesTopic(topic.name)),
          ),
        const ServiceStatusLink(),
      ],
    );
  }
}
