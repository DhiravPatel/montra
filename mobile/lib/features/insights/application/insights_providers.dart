import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// A counter bumped after every insight action, feedback or unmute, so
/// lists re-read from the server.
final NotifierProvider<InsightsRevision, int> insightsRevisionProvider =
    NotifierProvider<InsightsRevision, int>(InsightsRevision.new);

/// See [insightsRevisionProvider].
class InsightsRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks insights as changed.
  void bump() => state++;
}

/// What the insights list shows: active ones or everything ([all]), and
/// one kind (`''` = every kind).
typedef InsightFilter = ({bool all, String kind});

/// Insights for an [InsightFilter], page by page ("Load more"). Re-read
/// after insight changes and after finance writes (new records can raise
/// or settle insights).
final AsyncNotifierProviderFamily<
  InsightsController,
  PagedList<InsightDto>,
  InsightFilter
>
insightsProvider = AsyncNotifierProvider.autoDispose
    .family<InsightsController, PagedList<InsightDto>, InsightFilter>(
      InsightsController.new,
    );

/// See [insightsProvider].
class InsightsController extends PagedListController<InsightDto> {
  /// Creates the controller for [filter].
  InsightsController(this.filter);

  /// The filter.
  final InsightFilter filter;

  @override
  Future<PagedList<InsightDto>> build() async {
    ref
      ..watch(financeRevisionProvider)
      ..watch(insightsRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<InsightDto>> fetchPage(String? cursor) => ref
      .read(insightsApiProvider)
      .list(
        all: filter.all,
        kind: filter.kind.isEmpty ? null : filter.kind,
        cursor: cursor,
      );

  @override
  String keyOf(InsightDto item) => item.id;
}

/// How many pages of 200 [insightProvider] reads at most.
const int insightLookupPages = 5;

/// One insight by ID. The contract has no `GET /insights/{id}`, so it is
/// looked up in `GET /insights?all=true` (newest 1000 insights at most);
/// a missing one reads as `null`.
final FutureProviderFamily<InsightDto?, String> insightProvider = FutureProvider
    .autoDispose
    .family<InsightDto?, String>((Ref ref, String id) async {
      ref
        ..watch(currentUserIdProvider)
        ..watch(insightsRevisionProvider);
      final InsightsApi api = ref.read(insightsApiProvider);
      String? cursor;
      for (int page = 0; page < insightLookupPages; page++) {
        final CursorPage<InsightDto> result = await api.list(
          all: true,
          cursor: cursor,
          limit: 200,
        );
        for (final InsightDto insight in result.items) {
          if (insight.id == id) {
            return insight;
          }
        }
        if (!result.hasMore) {
          return null;
        }
        cursor = result.nextCursor;
      }
      return null;
    });

/// The kinds of insight the user muted.
final FutureProvider<List<InsightMuteDto>> insightMutesProvider =
    FutureProvider.autoDispose<List<InsightMuteDto>>((Ref ref) {
      ref
        ..watch(currentUserIdProvider)
        ..watch(insightsRevisionProvider);
      return ref.read(insightsApiProvider).mutes();
    });
