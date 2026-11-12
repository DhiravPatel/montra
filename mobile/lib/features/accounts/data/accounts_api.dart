import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Accounts` tag of the contract.
class AccountsApi {
  /// Creates the API over [client].
  AccountsApi(this._client);

  final ApiClient _client;

  /// `GET /accounts` — ledger balances; archived and closed ones only with
  /// [includeArchived].
  Future<List<AccountDto>> list({bool includeArchived = false}) => _client.send(
    ApiEndpoints.listAccounts,
    query: <String, Object?>{if (includeArchived) 'include_archived': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListAccountDto(json).data,
  );

  /// `GET /accounts/{id}`.
  Future<AccountDto> get(String id) => _client.send(
    ApiEndpoints.getAccount,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeAccountDto(json).data,
  );

  /// `POST /accounts` — idempotent; the opening balance is a ledger event.
  Future<AccountDto> create(AccountInput input, {required String key}) =>
      _client.send(
        ApiEndpoints.createAccount,
        body: input.toJson(),
        headers: <String, String>{Idempotency.header: key},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeAccountDto(json).data,
      );

  /// `PATCH /accounts/{id}` — needs the current `version`.
  Future<AccountDto> update(String id, AccountPatch patch) => _client.send(
    ApiEndpoints.updateAccount,
    pathParameters: <String, String>{'id': id},
    body: patch.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeAccountDto(json).data,
  );

  /// `POST /accounts/{id}/adjustments` — idempotent, reason required.
  Future<AccountDto> adjust(
    String id,
    AdjustmentInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.adjustAccount,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: (Map<String, Object?> json) => decodeEnvelopeAccountDto(json).data,
  );

  /// `POST /accounts/{id}/archive`; with [version], a concurrent change
  /// answers `VERSION_CONFLICT`.
  Future<AccountDto> archive(String id, {int? version}) =>
      _status(ApiEndpoints.archiveAccount, id, version);

  /// `POST /accounts/{id}/restore`.
  Future<AccountDto> restore(String id, {int? version}) =>
      _status(ApiEndpoints.restoreAccount, id, version);

  /// `POST /accounts/{id}/close` — only with a zero balance.
  Future<AccountDto> close(String id, {int? version}) =>
      _status(ApiEndpoints.closeAccount, id, version);

  Future<AccountDto> _status(ApiEndpoint endpoint, String id, int? version) =>
      _client.send(
        endpoint,
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'version': version},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeAccountDto(json).data,
      );

  /// `GET /accounts/{id}/balance` with daily history between [from] and
  /// [to] (`YYYY-MM-DD`).
  Future<BalanceReport> balance(String id, {String? from, String? to}) =>
      _client.send(
        ApiEndpoints.accountBalance,
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'from': from, 'to': to},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeBalanceReport(json).data,
      );

  /// `GET /accounts/{id}/transactions` (newest first).
  Future<CursorPage<TransactionDto>> transactions(
    String id, {
    String? cursor,
    int limit = 10,
  }) => _client.send(
    ApiEndpoints.accountTransactions,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'cursor': cursor, 'limit': limit},
    decode: (Map<String, Object?> json) {
      final EnvelopeListTransactionDto envelope =
          decodeEnvelopeListTransactionDto(json);
      return CursorPage<TransactionDto>(
        envelope.data,
        envelope.meta.nextCursor,
      );
    },
  );

  /// `GET /analytics/accounts` — assets, liabilities and net worth per
  /// currency (server totals; the app never adds balances itself).
  Future<List<BalanceTotals>> totals() => _client.send(
    ApiEndpoints.analyticsAccounts,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeAccountsReport(json).data.totals,
  );
}

/// Accounts endpoints. Overridden in tests.
final Provider<AccountsApi> accountsApiProvider = Provider<AccountsApi>(
  (Ref ref) => AccountsApi(ref.watch(apiClientProvider)),
);
