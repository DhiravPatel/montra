import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/support/domain/help_guide_content.dart';
import 'package:montra_mobile/features/support/presentation/help_guides_screen.dart';

/// One help guide: summary, sections, a link to the screen it is about
/// and a way to ask for more help.
class HelpGuideScreen extends StatelessWidget {
  /// Creates the screen for the guide at [slug].
  const HelpGuideScreen({required this.slug, super.key});

  /// URL segment of the guide.
  final String slug;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HelpGuide? guide = HelpGuide.fromSlug(slug);
    if (guide == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.helpGuidesTitle)),
        body: MessageStateView(
          icon: Icons.help_outline,
          title: l10n.helpGuidesTitle,
          body: l10n.helpGuidesNotFound,
          action: OutlinedButton(
            onPressed: () => context.go(AppRoutes.helpGuides),
            child: Text(l10n.helpGuidesBack),
          ),
        ),
      );
    }
    final HelpGuideContent content = helpGuideContent(guide);
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(guide.title(l10n))),
      body: ScrollableContent(
        children: <Widget>[
          Text(content.summary(l10n), style: text.bodyLarge),
          for (final HelpGuideSection section in content.sections) ...<Widget>[
            const SizedBox(height: Insets.lg),
            SectionHeading(section.title(l10n)),
            const SizedBox(height: Insets.xs),
            for (final HelpGuideBlock block in section.blocks)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: block.bullet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ExcludeSemantics(
                            child: Text('•  ', style: text.bodyMedium),
                          ),
                          Expanded(
                            child: Text(
                              block.text(l10n),
                              style: text.bodyMedium,
                            ),
                          ),
                        ],
                      )
                    : Text(block.text(l10n), style: text.bodyMedium),
              ),
          ],
          const SizedBox(height: Insets.lg),
          SectionHeading(l10n.helpGuidesRelated),
          const SizedBox(height: Insets.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push(helpGuideDestination(guide)),
              icon: const Icon(Icons.arrow_forward),
              label: Text(content.linkLabel(l10n)),
            ),
          ),
          const SizedBox(height: Insets.md),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.helpGuidesContact),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.newSupportRequest),
          ),
          if (guide == HelpGuide.troubleshooting) const ServiceStatusLink(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.helpGuidesBack),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.helpGuides),
          ),
        ],
      ),
    );
  }
}
