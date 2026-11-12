import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/insights/application/insights_providers.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/insights/domain/insight_messages.dart';

/// Muted kinds of insight (`GET /insights/mutes`) with "Unmute"
/// (`DELETE /insights/mutes`), which also brings back the insights the
/// mute was hiding and says how many.
class InsightMutesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const InsightMutesScreen({super.key});

  @override
  ConsumerState<InsightMutesScreen> createState() => _InsightMutesScreenState();
}

class _InsightMutesScreenState extends ConsumerState<InsightMutesScreen> {
  final Set<String> _busy = <String>{};

  Future<void> _unmute(InsightMuteDto mute) async {
    final AppLocalizations l10n = context.l10n;
    final String key = '${mute.subtype}|${mute.scope}';
    if (_busy.contains(key)) {
      return;
    }
    setState(() => _busy.add(key));
    try {
      final UnmuteResult result = await ref
          .read(insightsApiProvider)
          .unmute(mute.subtype, scope: mute.scope);
      ref.read(insightsRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.insightUnmuted(result.reopened));
      }
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<InsightMuteDto>> mutes = ref.watch(
      insightMutesProvider,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightMutesTitle)),
      body: AsyncValueView<List<InsightMuteDto>>(
        value: mutes,
        onRetry: () => ref.invalidate(insightMutesProvider),
        isEmpty: (List<InsightMuteDto> m) => m.isEmpty,
        empty: MessageStateView(
          icon: Icons.notifications_active_outlined,
          title: l10n.insightMutesEmptyTitle,
          body: l10n.insightMutesEmptyBody,
        ),
        data: (List<InsightMuteDto> items) => ListView(
          padding: const EdgeInsets.only(bottom: Insets.xl),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(l10n.insightMutesHelp),
            ),
            for (final InsightMuteDto m in items)
              ListTile(
                title: Text(insightSubtypeLabel(l10n, m.subtype)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${m.scope == '*' ? l10n.insightMuteEverywhere : l10n.insightMuteOneRecord} · '
                      '${l10n.insightMutedOn(formatShortDate(m.createdAt, locale: locale))}',
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _busy.contains('${m.subtype}|${m.scope}')
                            ? null
                            : () => _unmute(m),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: Text(l10n.insightUnmute),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
