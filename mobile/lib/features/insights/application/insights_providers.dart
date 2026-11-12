import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/api_exception.dart';
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

/// One insight by ID (`GET /insights/{id}`, any status); an insight that
/// does not exist (or is not the user's) reads as `null`.
final FutureProviderFamily<InsightDto?, String> insightProvider = FutureProvider
    .autoDispose
    .family<InsightDto?, String>((Ref ref, String id) async {
      ref
        ..watch(currentUserIdProvider)
        ..watch(insightsRevisionProvider);
      try {
        return await ref.read(insightsApiProvider).get(id);
      } on ApiException catch (error) {
        // Unknown, someone else's, or not an ID at all (a mistyped link
        // answers 422 on `path.id`).
        if (error.code == ErrorObjectCode.notFound ||
            error.details.any((Detail d) => d.field == 'path.id')) {
          return null;
        }
        rethrow;
      }
    });

/// The kinds of insight the user muted.
final FutureProvider<List<InsightMuteDto>> insightMutesProvider =
    FutureProvider.autoDispose<List<InsightMuteDto>>((Ref ref) {
      ref
        ..watch(currentUserIdProvider)
        ..watch(insightsRevisionProvider);
      return ref.read(insightsApiProvider).mutes();
    });
