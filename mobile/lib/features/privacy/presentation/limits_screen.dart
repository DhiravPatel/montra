import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/privacy/domain/privacy_display.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';

/// Fair-use limits (`GET /limits`): the same for everyone and never a paid
/// tier. Shows file storage use as a meter, the caps on open records, the
/// import, upload and support limits, request rates and how long downloads
/// and the deletion grace period last.
class LimitsScreen extends ConsumerWidget {
  /// Creates the screen.
  const LimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.limitsTitle)),
      body: AsyncValueView<Limits>(
        value: ref.watch(limitsProvider),
        onRetry: () => ref.invalidate(limitsProvider),
        data: (Limits limits) => RefreshIndicator(
          onRefresh: () => ref.refresh(limitsProvider.future),
          child: _LimitsBody(limits: limits),
        ),
      ),
    );
  }
}

class _LimitsBody extends StatelessWidget {
  const _LimitsBody({required this.limits});

  final Limits limits;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    String n(int value) => NumberFormat.decimalPattern(locale).format(value);
    final int quota = limits.storageQuotaBytes;
    final double share = quota <= 0
        ? 0
        : (limits.storageUsedBytes / quota).clamp(0, 1).toDouble();
    final String used = l10n.limitsStorageUsed(
      formatFileSize(l10n, limits.storageUsedBytes),
      formatFileSize(l10n, quota),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      children: <Widget>[
        ContentFrame(
          child: Text(
            limits.noteCode == LimitsNoteCode.fairUseSameForEveryone
                ? l10n.limitsFairUseNote
                : limits.note,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        ContentFrame(
          child: SectionCard(
            title: l10n.limitsStorageTitle,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(used),
                    const SizedBox(height: Insets.sm),
                    Semantics(
                      value: l10n.limitsStoragePercent((share * 100).round()),
                      child: ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: share,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      l10n.limitsUploadSize(
                        formatFileSize(l10n, limits.maxUploadBytes),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ContentFrame(
          child: SectionCard(
            title: l10n.limitsOpenRecordsTitle,
            children: <Widget>[
              DetailRow(
                label: l10n.limitsOpenBillsLabel,
                value: n(limits.maxOpenBills),
              ),
              DetailRow(
                label: l10n.limitsOpenRecurringLabel,
                value: n(limits.maxOpenRecurringRules),
              ),
              DetailRow(
                label: l10n.limitsOpenSubscriptionsLabel,
                value: n(limits.maxOpenSubscriptions),
              ),
              DetailRow(
                label: l10n.limitsOpenGoalsLabel,
                value: n(limits.maxOpenGoals),
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.limitsOpenRecordsHelp),
              ),
            ],
          ),
        ),
        ContentFrame(
          child: SectionCard(
            title: l10n.limitsOtherTitle,
            children: <Widget>[
              DetailRow(
                label: l10n.limitsImportRowsLabel,
                value: n(limits.importMaxRows),
              ),
              DetailRow(
                label: l10n.limitsSupportPerDayLabel,
                value: n(limits.supportRequestsPerDay),
              ),
              DetailRow(
                label: l10n.limitsExportDaysLabel,
                value: l10n.limitsDays(limits.exportDownloadDays),
              ),
              DetailRow(
                label: l10n.limitsDeletionGraceLabel,
                value: l10n.limitsDays(limits.deletionGraceDays),
              ),
            ],
          ),
        ),
        if (limits.rateLimits.isNotEmpty)
          ContentFrame(
            child: SectionCard(
              title: l10n.limitsRatesTitle,
              children: <Widget>[
                for (final RateLimit r in limits.rateLimits)
                  if (r.policy != RateLimitPolicy.ai)
                    DetailRow(
                      label: rateLimitPolicyLabel(l10n, r.policy),
                      value: l10n.limitsPerMinute(n(r.perMinute)),
                    ),
                Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Text(l10n.limitsRatesHelp),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
