import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/features/support/domain/help_guide_content.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where each guide's "where to do this" link goes in the app.
String helpGuideDestination(HelpGuide guide) => switch (guide) {
  HelpGuide.gettingStarted => AppRoutes.newAccount,
  HelpGuide.noBank => AppRoutes.integrations,
  HelpGuide.balances => AppRoutes.accounts,
  HelpGuide.budgets => AppRoutes.budgets,
  HelpGuide.recurring => AppRoutes.recurring,
  HelpGuide.goals => AppRoutes.goals,
  HelpGuide.groupBalances => AppRoutes.groups,
  HelpGuide.imports => AppRoutes.imports,
  HelpGuide.reconciliation => AppRoutes.accounts,
  HelpGuide.privacy => AppRoutes.privacy,
  HelpGuide.twoStep => AppRoutes.security,
  HelpGuide.fairUse => AppRoutes.limits,
  HelpGuide.troubleshooting => AppRoutes.notificationSettings,
};

/// Whether [content] mentions every word of [query] (case-insensitive) in
/// the current language.
bool helpGuideMatches(
  HelpGuideContent content,
  AppLocalizations l10n,
  String query,
) {
  final List<String> words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return true;
  }
  final String text = content.texts(l10n).join('\n').toLowerCase();
  return words.every(text.contains);
}

/// Opens the service-status page in the browser.
Future<void> openStatusPage(BuildContext context, Uri url) async {
  bool opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    showSnack(context, context.l10n.helpGuidesStatusHelp);
  }
}

/// The status link, or nothing when no status page is configured.
class ServiceStatusLink extends ConsumerWidget {
  /// Creates the link.
  const ServiceStatusLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Uri? url = ref.watch(appConfigProvider).statusPageUrl;
    if (url == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.monitor_heart_outlined),
      title: Text(l10n.helpGuidesStatus),
      subtitle: Text(l10n.helpGuidesStatusHelp),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => openStatusPage(context, url),
    );
  }
}

/// Help guides listed by topic, searchable in the current language.
class HelpGuidesScreen extends StatefulWidget {
  /// Creates the screen, optionally showing only [topic].
  const HelpGuidesScreen({this.topic, super.key});

  /// Topic to show (others hidden until "All guides").
  final HelpGuideTopic? topic;

  @override
  State<HelpGuidesScreen> createState() => _HelpGuidesScreenState();
}

class _HelpGuidesScreenState extends State<HelpGuidesScreen> {
  final TextEditingController _query = TextEditingController();
  late HelpGuideTopic? _topic = widget.topic;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String query = _query.text.trim();
    final List<HelpGuideContent> matches = <HelpGuideContent>[
      for (final HelpGuideContent c in helpGuides)
        if ((query.isNotEmpty || _topic == null || c.topic == _topic) &&
            helpGuideMatches(c, l10n, query))
          c,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpGuidesTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Insets.xl),
        children: <Widget>[
          ContentFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.helpGuidesDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: Insets.md),
                TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.helpGuidesSearch,
                    helperText: l10n.helpGuidesSearchHelp,
                    helperMaxLines: 3,
                    counterText: '',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.sm),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        matches.isEmpty
                            ? l10n.helpGuidesNoResults(query)
                            : l10n.helpGuidesResultCount(matches.length),
                      ),
                    ),
                  ),
                if (query.isEmpty && _topic != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _topic = null),
                      icon: const Icon(Icons.list),
                      label: Text(l10n.helpGuidesBack),
                    ),
                  ),
              ],
            ),
          ),
          for (final HelpGuideTopic topic in HelpGuideTopic.values)
            if (matches.any((HelpGuideContent c) => c.topic == topic))
              ContentFrame(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: Insets.md,
                        bottom: Insets.xs,
                      ),
                      child: SectionHeading(topic.title(l10n)),
                    ),
                    Card(
                      child: Column(
                        children: <Widget>[
                          for (final HelpGuideContent c in matches)
                            if (c.topic == topic)
                              ListTile(
                                title: Text(c.guide.title(l10n)),
                                subtitle: Text(c.summary(l10n)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(c.guide.path),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ContentFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: Text(l10n.helpGuidesContact),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.newSupportRequest),
                ),
                const ServiceStatusLink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
