import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// "12 transactions · Last used 4 Nov 2026" for a merchant.
String merchantUsage(AppLocalizations l10n, MerchantDto m, String locale) =>
    <String>[
      l10n.merchantTransactionCount(m.transactionCount),
      if (m.lastUsedOn case final String last)
        l10n.merchantLastUsed(LocalDates.display(last, locale: locale)),
    ].join(' · ');

/// Which merchants the directory lists (`GET /merchants` `status`).
enum MerchantStatusFilter {
  /// Active merchants (the server default).
  active('active'),

  /// Archived merchants.
  archived('archived'),

  /// Merchants merged into another one.
  merged('merged'),

  /// Every merchant.
  all('all');

  const MerchantStatusFilter(this.wire);

  /// The `status` query value.
  final String wire;
}

String _filterLabel(AppLocalizations l10n, MerchantStatusFilter f) =>
    switch (f) {
      MerchantStatusFilter.active => l10n.merchantsFilterActive,
      MerchantStatusFilter.archived => l10n.merchantsFilterArchived,
      MerchantStatusFilter.merged => l10n.merchantsFilterMerged,
      MerchantStatusFilter.all => l10n.merchantsFilterAll,
    };

/// Merchants the user has paid, searchable by name or alias and filtered
/// by status (active by default), page by page. Each opens its detail with
/// spending history, aliases and merge.
class MerchantsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const MerchantsScreen({super.key});

  @override
  ConsumerState<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends ConsumerState<MerchantsScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  String _search = '';
  MerchantStatusFilter _filter = MerchantStatusFilter.active;

  MerchantDirectoryKey get _key => (query: _search, status: _filter.wire);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _search = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final MerchantDirectoryKey key = _key;
    final AsyncValue<PagedList<MerchantDto>> merchants = ref.watch(
      merchantDirectoryProvider(key),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.merchantsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.md,
              Insets.md,
              Insets.sm,
            ),
            child: TextField(
              controller: _query,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.merchantsSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Semantics(
              label: l10n.merchantsFilterLabel,
              container: true,
              child: Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: <Widget>[
                  for (final MerchantStatusFilter f
                      in MerchantStatusFilter.values)
                    ChoiceChip(
                      label: Text(_filterLabel(l10n, f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: merchants.when(
              skipLoadingOnReload: true,
              loading: () => const LoadingStateView(),
              error: (Object error, StackTrace _) => ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(merchantDirectoryProvider(key)),
              ),
              data: (PagedList<MerchantDto> page) {
                final List<MerchantDto> list = page.items;
                if (list.isEmpty) {
                  return MessageStateView(
                    icon: Icons.storefront_outlined,
                    title: _search.isNotEmpty
                        ? l10n.merchantsNoMatch
                        : (_filter == MerchantStatusFilter.active
                              ? l10n.merchantsEmptyTitle
                              : l10n.merchantsEmptyFiltered),
                    body:
                        _search.isEmpty &&
                            _filter == MerchantStatusFilter.active
                        ? l10n.merchantsEmptyBody
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(merchantDirectoryProvider(key));
                    await ref.read(merchantDirectoryProvider(key).future);
                  },
                  child: ListView.builder(
                    itemCount: list.length + 1,
                    itemBuilder: (BuildContext context, int i) {
                      if (i == list.length) {
                        return LoadMoreFooter(
                          list: page,
                          onLoadMore: () => ref
                              .read(merchantDirectoryProvider(key).notifier)
                              .loadMore(),
                        );
                      }
                      final MerchantDto m = list[i];
                      return ListTile(
                        leading: InitialsAvatar(name: m.name),
                        title: Text(m.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(merchantUsage(l10n, m, locale)),
                            if (m.aliases.isNotEmpty)
                              Text(
                                l10n.merchantAlsoKnownAs(m.aliases.join(', ')),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (m.status == MerchantDtoStatus.archived)
                              Padding(
                                padding: const EdgeInsets.only(top: Insets.xs),
                                child: StatusLabel(
                                  text: l10n.merchantStatusArchived,
                                  icon: Icons.archive_outlined,
                                ),
                              ),
                            if (m.status == MerchantDtoStatus.merged)
                              Padding(
                                padding: const EdgeInsets.only(top: Insets.xs),
                                child: StatusLabel(
                                  text: l10n.merchantStatusMerged,
                                  icon: Icons.merge_type,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push(AppRoutes.merchantDetail(m.id)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks another existing merchant (searching on the server), leaving out
/// [excludeId]. Returns null when dismissed.
Future<MerchantDto?> showMerchantSearchSheet(
  BuildContext context, {
  required String title,
  String? excludeId,
}) => showModalBottomSheet<MerchantDto>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) =>
      _MerchantSearchSheet(title: title, excludeId: excludeId),
);

class _MerchantSearchSheet extends ConsumerStatefulWidget {
  const _MerchantSearchSheet({required this.title, this.excludeId});

  final String title;
  final String? excludeId;

  @override
  ConsumerState<_MerchantSearchSheet> createState() =>
      _MerchantSearchSheetState();
}

class _MerchantSearchSheetState extends ConsumerState<_MerchantSearchSheet> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final MerchantDirectoryKey key = (query: _search, status: 'active');
    final AsyncValue<PagedList<MerchantDto>> merchants = ref.watch(
      merchantDirectoryProvider(key),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onChanged: (String v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) {
                    setState(() => _search = v.trim());
                  }
                });
              },
              decoration: InputDecoration(
                labelText: l10n.merchantsSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: merchants.when(
              skipLoadingOnReload: true,
              loading: () => const LoadingStateView(),
              error: (Object error, StackTrace _) => ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(merchantDirectoryProvider(key)),
              ),
              data: (PagedList<MerchantDto> page) {
                final List<MerchantDto> shown = <MerchantDto>[
                  for (final MerchantDto m in page.items)
                    if (m.id != widget.excludeId) m,
                ];
                if (shown.isEmpty) {
                  return MessageStateView(
                    icon: Icons.search_off,
                    title: l10n.merchantsNoMatch,
                  );
                }
                return ListView.builder(
                  itemCount: shown.length + 1,
                  itemBuilder: (BuildContext context, int i) =>
                      i == shown.length
                      ? LoadMoreFooter(
                          list: page,
                          onLoadMore: () => ref
                              .read(merchantDirectoryProvider(key).notifier)
                              .loadMore(),
                        )
                      : ListTile(
                          leading: InitialsAvatar(name: shown[i].name),
                          title: Text(shown[i].name),
                          subtitle: Text(merchantUsage(l10n, shown[i], locale)),
                          onTap: () => Navigator.of(context).pop(shown[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
