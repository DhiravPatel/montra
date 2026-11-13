import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/imports/application/imports_providers.dart';
import 'package:montra_mobile/features/imports/domain/import_display.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';

/// Statement import history (`GET /imports`), optionally for one account,
/// with "Import a statement".
class ImportsScreen extends ConsumerWidget {
  /// Creates the screen; [accountId] limits the list to one account.
  const ImportsScreen({this.accountId, super.key});

  /// Account filter.
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String key = accountId ?? '';
    final AsyncValue<PagedList<ImportBatchDto>> imports = ref.watch(
      importsProvider(key),
    );
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final AccountDto? account = accountId == null ? null : accounts[accountId];
    Future<void> refresh() async {
      ref.invalidate(importsProvider(key));
      try {
        await ref.read(importsProvider(key).future);
      } on Object {
        // Shown by the screen state.
      }
    }

    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.imports)],
        title: Text(l10n.importsTitle),
        bottom: imports.isLoading && imports.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () =>
            context.push(AppRoutes.newImportFor(accountId: accountId)),
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(l10n.importNew),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (account != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Insets.sm,
                children: <Widget>[
                  Text(l10n.importsForAccount(account.name)),
                  TextButton(
                    onPressed: () => context.replace(AppRoutes.imports),
                    child: Text(l10n.importsShowAll),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AsyncValueView<PagedList<ImportBatchDto>>(
              value: imports,
              onRetry: () => ref.invalidate(importsProvider(key)),
              isEmpty: (PagedList<ImportBatchDto> list) => list.items.isEmpty,
              empty: RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    SizedBox(
                      height: 420,
                      child: MessageStateView(
                        icon: Icons.upload_file_outlined,
                        title: l10n.importsEmptyTitle,
                        body: l10n.importsEmptyBody,
                      ),
                    ),
                  ],
                ),
              ),
              data: (PagedList<ImportBatchDto> list) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.items.length + 1,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) =>
                      index == list.items.length
                      ? LoadMoreFooter(
                          list: list,
                          onLoadMore: () => ref
                              .read(importsProvider(key).notifier)
                              .loadMore(),
                        )
                      : ImportTile(batch: list.items[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One import in the history: account, when, status in words and counts.
class ImportTile extends ConsumerWidget {
  /// Creates the tile.
  const ImportTile({required this.batch, super.key});

  /// The import.
  final ImportBatchDto batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final ImportBatchDto b = batch;
    final String accountName =
        accounts[b.accountId]?.name ?? l10n.importUnknownAccount;
    final String? period = b.statementStart != null && b.statementEnd != null
        ? LocalDates.displayRange(
            b.statementStart!,
            b.statementEnd!,
            locale: locale,
          )
        : null;
    return ListTile(
      onTap: () => context.push(AppRoutes.importDetail(b.id)),
      leading: CircleAvatar(
        child: ExcludeSemantics(child: Icon(importStatusIcon(b.status))),
      ),
      title: Text(accountName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              l10n.importStartedOn(formatDateTime(b.createdAt, locale: locale)),
              ?period,
            ].join(' · '),
          ),
          if (b.importedCount > 0 || b.skippedCount > 0 || b.failedCount > 0)
            Text(
              l10n.importCountsSummary(
                b.importedCount,
                b.skippedCount,
                b.failedCount,
              ),
            ),
          const SizedBox(height: Insets.xs),
          StatusLabel(
            text: importStatusLabel(l10n, b.status),
            tone: importStatusTone(b.status),
            icon: importStatusIcon(b.status),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
