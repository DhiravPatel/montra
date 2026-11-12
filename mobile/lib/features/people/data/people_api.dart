import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Read-only calls behind the person and group pickers used when sharing a
/// budget or goal (group and friend management come in a later round).
class PeopleApi {
  /// Creates the API over [client].
  PeopleApi(this._client);

  final ApiClient _client;

  /// `GET /connections`: people the user is connected with.
  Future<List<PublicProfile>> friends() => _client.send(
    ApiEndpoints.listFriends,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListPublicProfile(json).data,
  );

  /// `GET /groups` (active ones unless [includeArchived]).
  Future<List<GroupDto>> groups({bool includeArchived = false}) => _client.send(
    ApiEndpoints.listGroups,
    query: <String, Object?>{if (includeArchived) 'include_archived': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListGroupDto(json).data,
  );

  /// `GET /groups/{id}` with its members.
  Future<GroupDetail> group(String id) => _client.send(
    ApiEndpoints.getGroup,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeGroupDetail(json).data,
  );
}

/// The [PeopleApi] over the shared client.
final Provider<PeopleApi> peopleApiProvider = Provider<PeopleApi>(
  (Ref ref) => PeopleApi(ref.watch(apiClientProvider)),
);
