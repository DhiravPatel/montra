import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/sha256.dart';

/// Where an upload is.
enum UploadStage {
  /// Checking the file and computing its checksum on the device.
  checking,

  /// Asking the server for an upload (`POST /files/upload-intent`).
  authorizing,

  /// Sending the bytes (`PUT /files/{fileId}/content`).
  sending,

  /// Finishing (`POST /files/{fileId}/complete`).
  finishing,
}

/// A file was refused on the device before anything was sent.
class FileRejected implements Exception {
  /// Creates the error.
  const FileRejected(this.problem, this.purpose);

  /// What is wrong with the file.
  final FileProblem problem;

  /// The purpose whose policy refused it.
  final UploadPurpose purpose;

  @override
  String toString() => 'FileRejected(${problem.name})';
}

/// Uploads files the way the contract describes (spec §10):
///
/// 1. `POST /files/upload-intent` with the purpose, name, type, size and
///    SHA-256 checksum, which returns a single-use `X-Upload-Token`;
/// 2. `PUT /files/{fileId}/content` with the raw bytes, the token and the
///    checksum (`X-Upload-Checksum`) — always to the configured API, never
///    to a URL from the response;
/// 3. `POST /files/{fileId}/complete`, which marks the file ready.
///
/// The result is the ready [FileDto], whose `id` the caller then links
/// (`POST /receipts`, `POST /transactions/{id}/attachments`,
/// `POST /imports`). Files are checked against the purpose's limits first
/// ([FileRejected]); server refusals surface as `ApiException`s.
class FileUploader {
  /// Creates the uploader over [client]; [checksum] is injectable for
  /// tests.
  FileUploader(this._client, {Future<String> Function(Uint8List)? checksum})
    : _checksum = checksum ?? _isolateChecksum;

  final ApiClient _client;
  final Future<String> Function(Uint8List bytes) _checksum;

  /// Uploads [file] for [purpose]. [onStage] reports progress through the
  /// steps and [onProgress] the share of bytes sent (0–1). Cancelling
  /// [cancelToken] stops the transfer; an unfinished upload expires on the
  /// server. Group purposes (`group_attachment`) need the [groupId].
  Future<FileDto> upload(
    PickedFile file,
    UploadPurpose purpose, {
    String? groupId,
    void Function(UploadStage stage)? onStage,
    void Function(double sent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    onStage?.call(UploadStage.checking);
    final FileProblem? problem = purpose.check(file.name, file.sizeBytes);
    if (problem != null) {
      throw FileRejected(problem, purpose);
    }
    final FileKind kind = purpose.kindOf(file.name)!;
    final String checksum = await _checksum(file.bytes);

    onStage?.call(UploadStage.authorizing);
    final UploadIntent intent = await _client.send(
      ApiEndpoints.createUploadIntent,
      body: UploadIntentInput(
        purpose: UploadIntentInputPurpose.fromJson(purpose.wire),
        filename: file.name,
        contentType: kind.mimeType,
        sizeBytes: file.sizeBytes,
        checksumSha256: checksum,
        groupId: groupId,
      ).toJson(),
      cancelToken: cancelToken,
      decode: (Map<String, Object?> json) =>
          decodeEnvelopeUploadIntent(json).data,
    );
    final String fileId = intent.file.id;
    final String? token = _header(intent.headers, 'X-Upload-Token');
    if (token == null) {
      throw StateError('The upload intent has no upload token.');
    }

    onStage?.call(UploadStage.sending);
    await _client.sendBytes(
      ApiEndpoints.uploadFileContent,
      pathParameters: <String, String>{'fileId': fileId},
      bytes: file.bytes,
      headers: <String, String>{
        'X-Upload-Token': token,
        'X-Upload-Checksum': checksum,
      },
      cancelToken: cancelToken,
      onSendProgress: onProgress == null
          ? null
          : (int sent, int total) {
              if (total > 0) {
                onProgress(sent / total);
              }
            },
      decode: (Map<String, Object?> json) => decodeEnvelopeFileDto(json).data,
    );

    onStage?.call(UploadStage.finishing);
    return _client.send(
      ApiEndpoints.completeFileUpload,
      pathParameters: <String, String>{'fileId': fileId},
      cancelToken: cancelToken,
      decode: (Map<String, Object?> json) => decodeEnvelopeFileDto(json).data,
    );
  }

  static String? _header(Map<String, String> headers, String name) {
    for (final MapEntry<String, String> h in headers.entries) {
      if (h.key.toLowerCase() == name.toLowerCase()) {
        return h.value;
      }
    }
    return null;
  }

  /// Hashes off the UI isolate so large files do not freeze the screen.
  static Future<String> _isolateChecksum(Uint8List bytes) =>
      compute(sha256Hex, bytes, debugLabel: 'upload checksum');
}

/// The uploader used by screens. Overridden in tests.
final Provider<FileUploader> fileUploaderProvider = Provider<FileUploader>(
  (Ref ref) => FileUploader(ref.watch(apiClientProvider)),
);
