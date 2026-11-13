import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';

/// Where a saved filter applies (`scope` in the API). The filter itself is
/// the query of the matching list endpoint, exactly as the server takes it
/// (`GET /transactions` parameters, or `q`/`scope`/`sort` of `GET /search`),
/// so the web and the app can apply each other's saved filters.
enum SavedFilterScope {
  /// The transactions list.
  transactions('transactions'),

  /// Global search.
  search('search');

  const SavedFilterScope(this.wire);

  /// The API value.
  final String wire;
}

/// Saved filter names: 1–80 characters after trimming (the server checks
/// the trimmed length and refuses names that are only spaces).
abstract final class SavedFilterName {
  /// Longest name.
  static const int maxLength = 80;

  /// The name as it is sent.
  static String normalize(String raw) => raw.trim();

  /// A message for an unusable name, or null.
  static String? validate(AppLocalizations l10n, String? raw) {
    final String name = normalize(raw ?? '');
    if (name.isEmpty) {
      return l10n.savedFiltersNameRequired;
    }
    if (name.runes.length > maxLength) {
      return l10n.savedFiltersNameTooLong;
    }
    return null;
  }
}

/// The filter of a saved filter as a JSON object, or null when it is not
/// one (the server stores any JSON value, so other clients could have
/// saved something this app cannot read).
Map<String, Object?>? savedFilterObject(SavedFilterDto saved) {
  final Object? filter = saved.filter;
  if (filter is! Map) {
    return null;
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> e in filter.entries)
      if (e.key is String) e.key! as String: e.value,
  };
}

/// Typed calls for saved filters. The contract has list, create and delete
/// only (no update or single read); creating needs no idempotency key, and
/// there is no fair-use cap on how many are kept.
class SavedFiltersApi {
  /// Creates the API over [client].
  SavedFiltersApi(this._client);

  final ApiClient _client;

  /// `GET /saved-filters?scope=`, ordered by name.
  Future<List<SavedFilterDto>> list(SavedFilterScope scope) => _client.send(
    ApiEndpoints.listSavedFilters,
    query: <String, Object?>{'scope': scope.wire},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListSavedFilterDto(json).data,
  );

  /// `POST /saved-filters`. A name already used in the scope (ignoring
  /// case) answers 409 `CONFLICT`.
  Future<SavedFilterDto> create(
    SavedFilterScope scope,
    String name,
    Map<String, Object?> filter,
  ) => _client.send(
    ApiEndpoints.createSavedFilter,
    body: SavedFiltersCreateRequest(
      scope: SavedFiltersCreateRequestScope.fromJson(scope.wire),
      name: SavedFilterName.normalize(name),
      filter: filter,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeSavedFilterDto(json).data,
  );

  /// `DELETE /saved-filters/{id}`.
  Future<void> delete(String id) => _client.send(
    ApiEndpoints.deleteSavedFilter,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );
}

/// Saved-filter endpoints. Overridden in tests.
final Provider<SavedFiltersApi> savedFiltersApiProvider =
    Provider<SavedFiltersApi>(
      (Ref ref) => SavedFiltersApi(ref.watch(apiClientProvider)),
    );

/// The person's saved filters for a scope.
final FutureProviderFamily<List<SavedFilterDto>, SavedFilterScope>
savedFiltersProvider = FutureProvider.autoDispose
    .family<List<SavedFilterDto>, SavedFilterScope>((
      Ref ref,
      SavedFilterScope scope,
    ) {
      ref.watch(currentUserIdProvider);
      return ref.read(savedFiltersApiProvider).list(scope);
    });
