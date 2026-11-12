import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';
import 'package:montra_mobile/features/labels/presentation/merchants_screen.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:url_launcher/url_launcher.dart';

enum _MerchantAction { merge, archive, unarchive }

/// One merchant: details, 12 months of spending per currency (chart with
/// a text summary and a list), aliases, and merge/archive actions.
class MerchantDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [merchantId].
  const MerchantDetailScreen({required this.merchantId, super.key});

  /// Merchant to show.
  final String merchantId;

  @override
  ConsumerState<MerchantDetailScreen> createState() =>
      _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends ConsumerState<MerchantDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<String> Function(LabelsApi api) action) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final LabelsApi api = ref.read(labelsApiProvider);
    setState(() => _busy = true);
    try {
      final String done = await action(api);
      finance.bump();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.versionConflict) {
        // Changed elsewhere: show the latest version.
        ref.invalidate(merchantDetailProvider(widget.merchantId));
      }
      if (mounted) {
        showSnack(
          context,
          error.code == ErrorObjectCode.versionConflict
              ? l10n.versionConflictReloaded
              : describeError(l10n, error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addAlias(MerchantDetail m) async {
    final AppLocalizations l10n = context.l10n;
    final String? alias = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _AliasDialog(merchantName: m.name),
    );
    if (alias == null || !mounted) {
      return;
    }
    await _run((LabelsApi api) async {
      await api.addMerchantAlias(m.id, alias);
      return l10n.merchantAliasAdded(alias);
    });
  }

  Future<void> _removeAlias(MerchantDetail m, String alias) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.merchantAliasRemoveTitle(alias),
      body: l10n.merchantAliasRemoveBody(m.name),
      confirmLabel: l10n.merchantAliasRemove,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run((LabelsApi api) async {
      await api.removeMerchantAlias(m.id, alias);
      return l10n.merchantAliasRemoved(alias);
    });
  }

  Future<void> _actions(MerchantDetail m) async {
    final AppLocalizations l10n = context.l10n;
    final bool archived = m.status == MerchantDetailStatus.archived;
    final _MerchantAction? action = await showOptionSheet<_MerchantAction>(
      context,
      title: m.name,
      options: <SheetOption<_MerchantAction>>[
        SheetOption<_MerchantAction>(
          value: _MerchantAction.merge,
          label: l10n.merchantMergeAction,
          subtitle: l10n.merchantMergeHelp,
          icon: Icons.merge_type,
        ),
        if (archived)
          SheetOption<_MerchantAction>(
            value: _MerchantAction.unarchive,
            label: l10n.merchantUnarchive,
            icon: Icons.unarchive_outlined,
          )
        else
          SheetOption<_MerchantAction>(
            value: _MerchantAction.archive,
            label: l10n.merchantArchive,
            subtitle: l10n.merchantArchiveHelp,
            icon: Icons.archive_outlined,
          ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _MerchantAction.merge:
        await _merge(m);
      case _MerchantAction.archive:
        await _run((LabelsApi api) async {
          await api.updateMerchant(
            m.id,
            MerchantPatch(archived: true, version: m.version),
          );
          return l10n.merchantArchived(m.name);
        });
      case _MerchantAction.unarchive:
        await _run((LabelsApi api) async {
          await api.updateMerchant(
            m.id,
            MerchantPatch(archived: false, version: m.version),
          );
          return l10n.merchantUnarchived(m.name);
        });
    }
  }

  /// Merges another merchant into this one after a preview of what moves
  /// (`POST /merchants/merge/preview`) and a confirmation.
  Future<void> _merge(MerchantDetail target) async {
    final AppLocalizations l10n = context.l10n;
    final MerchantDto? source = await showMerchantSearchSheet(
      context,
      title: l10n.merchantMergePickTitle(target.name),
      excludeId: target.id,
    );
    if (source == null || !mounted) {
      return;
    }
    final LabelsApi labels = ref.read(labelsApiProvider);
    setState(() => _busy = true);
    final MerchantMergeResult preview;
    try {
      preview = await labels.previewMerchantMerge(
        targetId: target.id,
        sourceIds: <String>[source.id],
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, describeError(l10n, error));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    final List<String> moves = merchantMergeAffectedLines(
      l10n,
      preview.affected,
    );
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.merchantMergeTitle(source.name, target.name),
      body: moves.isEmpty
          ? l10n.merchantMergePreviewNothing(source.name, target.name)
          : l10n.merchantMergePreviewBody(
              target.name,
              moves.join('\n'),
              source.name,
            ),
      confirmLabel: l10n.merchantMergeConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run((LabelsApi api) async {
      await api.mergeMerchants(
        targetId: target.id,
        sourceIds: <String>[source.id],
      );
      return l10n.merchantMerged(source.name, target.name);
    });
  }

  Future<void> _openWebsite(String website) async {
    final AppLocalizations l10n = context.l10n;
    final Uri? uri = Uri.tryParse(website.trim());
    bool opened = false;
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on PlatformException {
        opened = false;
      }
    }
    if (!opened && mounted) {
      showSnack(context, l10n.merchantWebsiteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<MerchantDetail> merchant = ref.watch(
      merchantDetailProvider(widget.merchantId),
    );
    final MerchantDetail? m = merchant.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(m?.name ?? l10n.merchantDetailTitle),
        actions: <Widget>[
          if (m != null && m.status != MerchantDetailStatus.merged) ...<Widget>[
            IconButton(
              tooltip: l10n.merchantEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.editMerchant(m.id)),
            ),
            IconButton(
              tooltip: l10n.merchantMoreActions,
              icon: const Icon(Icons.more_vert),
              onPressed: _busy ? null : () => _actions(m),
            ),
          ],
        ],
      ),
      body: merchant.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingStateView(),
        error: (Object error, StackTrace _) => ErrorStateView(
          error: error,
          onRetry: () =>
              ref.invalidate(merchantDetailProvider(widget.merchantId)),
        ),
        data: (MerchantDetail m) => _Body(
          merchant: m,
          busy: _busy,
          onAddAlias: () => _addAlias(m),
          onRemoveAlias: (String alias) => _removeAlias(m, alias),
          onOpenWebsite: _openWebsite,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.merchant,
    required this.busy,
    required this.onAddAlias,
    required this.onRemoveAlias,
    required this.onOpenWebsite,
  });

  final MerchantDetail merchant;
  final bool busy;
  final VoidCallback onAddAlias;
  final ValueChanged<String> onRemoveAlias;
  final ValueChanged<String> onOpenWebsite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final MerchantDetail m = merchant;
    final CategoryDto? category = m.defaultCategoryId == null
        ? null
        : ref.watch(categoryIndexProvider)[m.defaultCategoryId];
    final Map<String, List<MerchantSpend>> byCurrency =
        <String, List<MerchantSpend>>{};
    for (final MerchantSpend s in m.spending) {
      (byCurrency[s.total.currency] ??= <MerchantSpend>[]).add(s);
    }
    final List<String> currencies = byCurrency.keys.toList()..sort();
    return ScrollableContent(
      children: <Widget>[
        if (m.status == MerchantDetailStatus.archived) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.info,
            message: l10n.merchantArchivedNote,
          ),
          const SizedBox(height: Insets.md),
        ],
        if (m.status == MerchantDetailStatus.merged) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.info,
            message: l10n.merchantMergedNote,
            action: switch (m.mergedIntoId) {
              final String into => TextButton(
                onPressed: () =>
                    context.pushReplacement(AppRoutes.merchantDetail(into)),
                child: Text(l10n.merchantOpenMergedInto),
              ),
              null => null,
            },
          ),
          const SizedBox(height: Insets.md),
        ],
        SectionCard(
          title: l10n.merchantDetailsSection,
          children: <Widget>[
            DetailRow(
              label: l10n.merchantDefaultCategory,
              value: category == null
                  ? l10n.merchantNoDefaultCategory
                  : categoryName(l10n, category),
            ),
            DetailRow(
              label: l10n.merchantTransactionsLabel,
              value: '${m.transactionCount}',
            ),
            if (m.lastUsedOn case final String last)
              DetailRow(
                label: l10n.merchantLastUsedLabel,
                value: LocalDates.display(last, locale: locale),
              ),
            if (m.website case final String website when website.isNotEmpty)
              DetailRow(
                label: l10n.merchantWebsiteLabel,
                value: website,
                onTap: () => onOpenWebsite(website),
              ),
            if (m.notes case final String notes when notes.isNotEmpty)
              DetailRow(label: l10n.merchantNotesLabel, value: notes),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.merchantSpendingSection,
          children: <Widget>[
            if (currencies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.merchantNoSpending),
              )
            else
              for (final String currency in currencies)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                  child: _SpendingChart(
                    merchantName: m.name,
                    currency: currency,
                    months: byCurrency[currency]!
                      ..sort(
                        (MerchantSpend a, MerchantSpend b) =>
                            a.month.compareTo(b.month),
                      ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.merchantAliasesSection,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(l10n.merchantAliasesHelp),
            ),
            if (m.aliases.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.merchantNoAliases),
              )
            else
              for (final String alias in m.aliases)
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(alias),
                  trailing: m.status == MerchantDetailStatus.merged
                      ? null
                      : IconButton(
                          tooltip: l10n.merchantAliasRemoveTooltip(alias),
                          icon: const Icon(Icons.close),
                          onPressed: busy ? null : () => onRemoveAlias(alias),
                        ),
                ),
            if (m.status != MerchantDetailStatus.merged)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                child: TextButton.icon(
                  onPressed: busy ? null : onAddAlias,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.merchantAddAlias),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        OutlinedButton.icon(
          onPressed: () =>
              context.push(TransactionFilter(merchantId: m.id).toLocation()),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l10n.merchantSeeTransactions),
        ),
      ],
    );
  }
}

class _SpendingChart extends ConsumerWidget {
  const _SpendingChart({
    required this.merchantName,
    required this.currency,
    required this.months,
  });

  final String merchantName;
  final String currency;
  final List<MerchantSpend> months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    String month(MerchantSpend s) =>
        LocalDates.displayMonth('${s.month}-01', locale: locale);
    int largest = 0;
    MerchantSpend? top;
    for (final MerchantSpend s in months) {
      if (s.total.amountMinor > largest) {
        largest = s.total.amountMinor;
        top = s;
      }
    }
    final MerchantSpend? highest = top;
    final String summary = highest == null
        ? l10n.merchantSpendingSummaryNone(currency)
        : l10n.merchantSpendingSummary(
            currency,
            months.length,
            month(highest),
            formatMoney(context, ref, highest.total),
          );
    return AccessibleChart(
      summary: summary,
      chart: HorizontalBars(
        entries: <BarEntry>[
          for (final MerchantSpend s in months)
            BarEntry(
              label: month(s),
              valueText: formatMoney(context, ref, s.total),
              fraction: largest == 0 || s.total.amountMinor <= 0
                  ? 0
                  : s.total.amountMinor / largest,
              detail: l10n.merchantTransactionCount(s.count),
            ),
        ],
      ),
      table: Column(
        children: <Widget>[
          for (final MerchantSpend s in months.reversed)
            DetailRow(
              label: month(s),
              value:
                  '${formatMoney(context, ref, s.total)} · '
                  '${l10n.merchantTransactionCount(s.count)}',
            ),
        ],
      ),
    );
  }
}

class _AliasDialog extends StatefulWidget {
  const _AliasDialog({required this.merchantName});

  final String merchantName;

  @override
  State<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends State<_AliasDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _alias = TextEditingController();

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  void _done() {
    if (_form.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_alias.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.merchantAddAlias),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.merchantAliasDialogBody(widget.merchantName)),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _alias,
              autofocus: true,
              maxLength: 200,
              decoration: InputDecoration(labelText: l10n.merchantAliasLabel),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.merchantAliasRequired : null,
              onFieldSubmitted: (_) => _done(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _done, child: Text(l10n.merchantAddAlias)),
      ],
    );
  }
}
