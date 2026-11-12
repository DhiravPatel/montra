import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Search` tag: one search across the user's records,
/// readable community posts and people (exact usernames only), plus the
/// recent searches.
class SearchApi {
  /// Creates the API over [client].
  SearchApi(this._client);

  final ApiClient _client;

  /// Shortest query the server accepts.
  static const int minQueryLength = 2;

  /// Longest query the server accepts.
  static const int maxQueryLength = 100;

  /// `GET /search`. [scope] is `all` or one section (`transactions`,
  /// `merchants`, …); [sort] is `relevance`, `name` or `recent`. [save]
  /// remembers the query in the recent searches: send it only when the
  /// person submits the search, never while typing.
  Future<Results> search(
    String query, {
    String scope = 'all',
    String sort = 'relevance',
    int? limit,
    bool save = false,
  }) => _client.send(
    ApiEndpoints.search,
    query: <String, Object?>{
      'q': query,
      'scope': scope,
      'sort': sort,
      'limit': limit,
      'save': save,
    },
    decode: (Map<String, Object?> json) => decodeEnvelopeResults(json).data,
  );

  /// `GET /search/recent`: the last searches the person submitted.
  Future<List<RecentDto>> recent() => _client.send(
    ApiEndpoints.recentSearches,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListRecentDto(json).data,
  );

  /// `DELETE /search/recent`: forgets every recent search; returns how
  /// many were removed.
  Future<int> clearRecent() => _client.send(
    ApiEndpoints.clearRecentSearches,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeDeletedDto(json).data.deleted,
  );
}

/// Search endpoints. Overridden in tests.
final Provider<SearchApi> searchApiProvider = Provider<SearchApi>(
  (Ref ref) => SearchApi(ref.watch(apiClientProvider)),
);
