import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Support` tag: the user's support requests with
/// their message threads, and the contact form for people who are signed
/// out. Staff tools (`/support/queue`) are web-only.
class SupportApi {
  /// Creates the API over [client].
  SupportApi(this._client);

  final ApiClient _client;

  /// `GET /support/requests`: the user's requests, newest first.
  Future<List<RequestDto>> list() => _client.send(
    ApiEndpoints.listSupportRequests,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListRequestDto(json).data,
  );

  /// `POST /support/requests`: a new request (10 a day: `daily_cap`; text
  /// with card numbers, PINs, OTPs or passwords: `contains_secret`).
  Future<RequestDto> create(RequestInput input) => _client.send(
    ApiEndpoints.createSupportRequest,
    body: input.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRequestDto(json).data,
  );

  /// `GET /support/requests/{id}`.
  Future<RequestDto> get(String id) => _client.send(
    ApiEndpoints.getSupportRequest,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeRequestDto(json).data,
  );

  /// `GET /support/requests/{id}/messages`: the thread, oldest first.
  Future<List<MessageDto>> messages(String id) => _client.send(
    ApiEndpoints.supportRequestMessages,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListMessageDto(json).data,
  );

  /// `POST /support/requests/{id}/messages` (a closed request answers 422
  /// `request_closed`).
  Future<MessageDto> reply(String id, String body) => _client.send(
    ApiEndpoints.createSupportRequestMessage,
    pathParameters: <String, String>{'id': id},
    body: MessageInput(body: body).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeMessageDto(json).data,
  );

  /// `POST /support/contact` (no sign-in; `202` with a reference).
  Future<ContactResult> contact(ContactInput input) => _client.send(
    ApiEndpoints.contactSupport,
    body: input.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeContactResult(json).data,
  );
}

/// The [SupportApi] over the shared client. Overridden in tests.
final Provider<SupportApi> supportApiProvider = Provider<SupportApi>(
  (Ref ref) => SupportApi(ref.watch(apiClientProvider)),
);
