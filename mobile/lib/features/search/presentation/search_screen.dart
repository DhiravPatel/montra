import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters_sheet.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:montra_mobile/features/search/data/search_api.dart';
import 'package:montra_mobile/features/search/domain/search_display.dart';

/// The person's recent searches (`GET /search/recent`).
final FutureProvider<List<RecentDto>> recentSearchesProvider =
    FutureProvider.autoDispose<List<RecentDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(searchApiProvider).recent();
    });

/// Global search (`GET /search`) across transactions, merchants, accounts,
/// categories, budgets, goals, bills, subscriptions, recurring payments,
/// groups, community posts and people (exact usernames only). Results
/// update while typing without being remembered; submitting the search
/// (`save=true`) adds it to the recent searches, which can be cleared.
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [debounce] is the pause after typing before
  /// searching.
  const SearchScreen({
    this.debounce = const Duration(milliseconds: 400),
    super.key,
  });

  /// Pause after the last keystroke.
  final Duration debounce;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _timer;
  String _scope = 'all';
  String _sort = 'relevance';
  int _request = 0;
  bool _loading = false;
  Results? _results;
  Object? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  String get _text => _query.text.trim();

  bool get _valid => _text.length >= SearchApi.minQueryLength;

  void _onChanged(String _) {
    _timer?.cancel();
    if (!_valid) {
      setState(() {
        _request++;
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _timer = Timer(widget.debounce, () => _run(save: false));
  }

  Future<void> _submit() async {
    _timer?.cancel();
    if (!_valid) {
      setState(() => _error = null);
      return;
    }
    FocusScope.of(context).unfocus();
    await _run(save: true);
    ref.invalidate(recentSearchesProvider);
  }

  Future<void> _run({required bool save}) async {
    final int request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Results results = await ref
          .read(searchApiProvider)
          .search(_text, scope: _scope, sort: _sort, save: save);
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _rerun() {
    if (_valid) {
      unawaited(_run(save: false));
    }
  }

  Future<void> _useRecent(RecentDto recent) async {
    _query
      ..text = recent.query
      ..selection = TextSelection.collapsed(offset: recent.query.length);
    setState(() => _scope = recent.scope.isEmpty ? 'all' : recent.scope);
    await _submit();
  }

  Future<void> _clearRecent() async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.searchClearRecentTitle,
      body: l10n.searchClearRecentBody,
      confirmLabel: l10n.searchClearRecent,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(searchApiProvider).clearRecent();
      ref.invalidate(recentSearchesProvider);
      if (mounted) {
        showSnack(context, l10n.searchRecentCleared);
      }
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  /// Saved searches: save this search, or run or delete one.
  Future<void> _openSaved() async {
    final AppLocalizations l10n = context.l10n;
    final AppliedSavedFilter? chosen = await showSavedFiltersSheet(
      context,
      scope: SavedFilterScope.search,
      current: _valid
          ? <String, Object?>{'q': _text, 'scope': _scope, 'sort': _sort}
          : null,
      describe: (Map<String, Object?> json) {
        final SavedSearch? saved = SavedSearch.fromJson(json);
        return saved == null
            ? null
            : '${l10n.savedFiltersSearchFor(saved.query)} · '
                  '${searchScopeLabel(l10n, saved.scope)}';
      },
    );
    if (chosen == null || !mounted) {
      return;
    }
    final SavedSearch saved = SavedSearch.fromJson(chosen.filter)!;
    _query
      ..text = saved.query
      ..selection = TextSelection.collapsed(offset: saved.query.length);
    setState(() {
      _scope = saved.scope;
      _sort = saved.sort;
    });
    showSnack(context, l10n.savedFiltersApplied(chosen.name));
    await _submit();
  }

  Future<void> _pickSort() async {
    final AppLocalizations l10n = context.l10n;
    final String? sort = await showOptionSheet<String>(
      context,
      title: l10n.searchSortTitle,
      selected: _sort,
      options: <SheetOption<String>>[
        for (final String s in <String>['relevance', 'name', 'recent'])
          SheetOption<String>(value: s, label: searchSortLabel(l10n, s)),
      ],
    );
    if (sort != null && sort != _sort && mounted) {
      setState(() => _sort = sort);
      _rerun();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.savedSearchesOpen,
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: _openSaved,
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: TextField(
              controller: _query,
              autofocus: true,
              maxLength: SearchApi.maxQueryLength,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.searchFieldLabel,
                helperText: l10n.searchFieldHelp,
                helperMaxLines: 3,
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: l10n.searchSubmit,
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _submit,
                ),
              ),
              onChanged: _onChanged,
              onSubmitted: (_) => _submit(),
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
                ActionChip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(searchSortLabel(l10n, _sort)),
                  tooltip: l10n.searchSortTitle,
                  onPressed: _pickSort,
                ),
                const SizedBox(width: Insets.sm),
                for (final String scope in <String>[
                  'all',
                  for (final SearchSection s in SearchSection.values) s.wire,
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Insets.sm),
                    child: ChoiceChip(
                      label: Text(searchScopeLabel(l10n, scope)),
                      selected: _scope == scope,
                      onSelected: (_) {
                        setState(() => _scope = scope);
                        _rerun();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Object? error = _error;
    if (!_valid) {
      return _RecentSearches(onUse: _useRecent, onClear: _clearRecent);
    }
    if (error != null) {
      return ErrorStateView(error: error, onRetry: _rerun);
    }
    final Results? results = _results;
    if (results == null) {
      return const LoadingStateView();
    }
    if (isEmptyResult(results)) {
      return MessageStateView(
        icon: Icons.search_off,
        title: l10n.searchNoResults,
        body: l10n.searchNoResultsBody,
      );
    }
    return _ResultsList(results: results);
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onUse, required this.onClear});

  final Future<void> Function(RecentDto recent) onUse;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<RecentDto>> recent = ref.watch(
      recentSearchesProvider,
    );
    return AsyncValueView<List<RecentDto>>(
      value: recent,
      onRetry: () => ref.invalidate(recentSearchesProvider),
      isEmpty: (List<RecentDto> r) => r.isEmpty,
      empty: MessageStateView(
        icon: Icons.manage_search,
        title: l10n.searchStartTitle,
        body: l10n.searchStartBody,
      ),
      data: (List<RecentDto> items) => ListView(
        padding: const EdgeInsets.only(bottom: Insets.xl),
        children: <Widget>[
          ContentFrame(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SectionHeading(l10n.searchRecentTitle),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(l10n.searchClearRecent),
                ),
              ],
            ),
          ),
          for (final RecentDto r in items)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(r.query),
              subtitle: Text(
                '${searchScopeLabel(l10n, r.scope)} · '
                '${formatRelativeTime(l10n, r.createdAt, now: DateTime.now(), locale: locale)}',
              ),
              onTap: () => onUse(r),
            ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final Results results;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final List<Widget> children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, 0),
        child: Text(
          l10n.searchSortedBy(searchSortLabel(l10n, results.sort.json)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ];
    for (final SearchSection s in SearchSection.values) {
      if (hitCount(results, s) == 0) {
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.md,
            Insets.md,
            Insets.xs,
          ),
          child: SectionHeading(searchSectionLabel(l10n, s)),
        ),
      );
      switch (s) {
        case SearchSection.transactions:
          for (final TransactionHit t in results.transactions) {
            final String title =
                t.description ?? t.merchant ?? l10n.searchUntitled;
            children.add(
              ListTile(
                leading: Icon(s.icon),
                title: Text(title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MoneyText(t.amount),
                    Text(
                      <String>[
                        LocalDates.display(t.localDate, locale: locale),
                        if (t.merchant != null && t.merchant != title)
                          t.merchant!,
                        if (t.shared) l10n.searchShared,
                      ].join(' · '),
                    ),
                  ],
                ),
                onTap: () => context.push(AppRoutes.transactionDetail(t.id)),
              ),
            );
          }
        case SearchSection.posts:
          for (final PostHit p in results.posts) {
            children.add(
              ListTile(
                leading: Icon(s.icon),
                title: Text(p.title),
                subtitle: Text(
                  '${p.communityName} · '
                  '${formatShortDate(p.createdAt, locale: locale)}',
                ),
                onTap: () => context.push(AppRoutes.postDetail(p.id)),
              ),
            );
          }
        case SearchSection.users:
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(
                l10n.searchPeopleNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
          for (final UserHit u in results.users) {
            children.add(
              ListTile(
                leading: InitialsAvatar(name: u.displayName),
                title: Text(u.displayName),
                subtitle: u.username == null ? null : Text('@${u.username}'),
                onTap: () => context.push(AppRoutes.friendsTab('find')),
              ),
            );
          }
        case _:
          for (final NamedHit h in namedHits(results, s)) {
            final String? kind = namedHitKind(l10n, s, h.kind);
            children.add(
              ListTile(
                leading: Icon(s.icon),
                title: Text(h.name),
                subtitle: kind == null ? null : Text(kind),
                onTap: () {
                  final String route = namedHitRoute(s, h);
                  // Categories open the Transactions tab filtered.
                  if (s == SearchSection.categories) {
                    context.go(route);
                  } else {
                    context.push(route);
                  }
                },
              ),
            );
          }
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      children: children,
    );
  }
}

/// A saved search (`scope: search`): the `q`, `scope` and `sort` of
/// `GET /search`, as the web saves them too.
@immutable
class SavedSearch {
  /// Creates the search.
  const SavedSearch(this.query, this.scope, this.sort);

  /// Reads a saved filter; null when it has no usable query. An unknown
  /// scope or sort falls back to the defaults.
  static SavedSearch? fromJson(Map<String, Object?> json) {
    final Object? q = json['q'];
    if (q is! String) {
      return null;
    }
    final String query = q.trim().split(RegExp(r'\s+')).join(' ');
    if (query.length < SearchApi.minQueryLength ||
        query.length > SearchApi.maxQueryLength) {
      return null;
    }
    final Set<String> scopes = <String>{
      'all',
      for (final SearchSection s in SearchSection.values) s.wire,
    };
    final Object? scope = json['scope'];
    final Object? sort = json['sort'];
    return SavedSearch(
      query,
      scope is String && scopes.contains(scope) ? scope : 'all',
      sort is String &&
              const <String>{'relevance', 'name', 'recent'}.contains(sort)
          ? sort
          : 'relevance',
    );
  }

  /// The text searched for.
  final String query;

  /// `all` or one section.
  final String scope;

  /// `relevance`, `name` or `recent`.
  final String sort;
}
