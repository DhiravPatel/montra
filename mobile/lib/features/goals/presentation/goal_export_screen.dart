import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart';

/// The goal's contribution history as CSV (`text/csv`): a preview of the
/// exact text, and ways to share it, save it where the user chooses (the
/// system "save as" dialog) or copy it. Nothing is written anywhere the
/// user didn't pick.
class GoalExportScreen extends ConsumerWidget {
  /// Creates the screen for [goalId].
  const GoalExportScreen({required this.goalId, super.key});

  /// The goal.
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<GoalExport> export = ref.watch(goalExportProvider(goalId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.goalExportTitle)),
      body: AsyncValueView<GoalExport>(
        value: export,
        onRetry: () => ref.invalidate(goalExportProvider(goalId)),
        data: (GoalExport e) => _ExportBody(export: e),
      ),
    );
  }
}

class _ExportBody extends ConsumerWidget {
  const _ExportBody({required this.export});

  final GoalExport export;

  Future<void> _copy(BuildContext context) async {
    final String message = context.l10n.goalExportCopied;
    await Clipboard.setData(ClipboardData(text: export.csv));
    if (context.mounted) {
      showSnack(context, message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? fileName = export.fileName;
    final int rows = export.rowCount;
    return ScrollableContent(
      children: <Widget>[
        Text(l10n.goalExportIntroShare, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Insets.md),
        SectionCard(
          children: <Widget>[
            if (fileName != null)
              DetailRow(label: l10n.goalExportFileLabel, value: fileName),
            DetailRow(
              label: l10n.goalExportRowsLabel,
              value: l10n.goalExportRows(rows),
            ),
          ],
        ),
        if (rows == 0) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(l10n.goalExportEmpty, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: <Widget>[
            Builder(
              builder: (BuildContext context) => FilledButton.icon(
                onPressed: () =>
                    shareDownloadedFile(context, ref, export.toFile()),
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.fileShare),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  saveDownloadedFile(context, ref, export.toFile()),
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.fileSave),
            ),
            OutlinedButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy),
              label: Text(l10n.goalExportCopy),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        Semantics(
          header: true,
          child: Text(
            l10n.goalExportPreviewTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(Insets.md),
            child: SelectableText(
              export.csv,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const <String>['Courier', 'monospace'],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
