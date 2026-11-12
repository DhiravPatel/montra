import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:share_plus/share_plus.dart';

/// A file downloaded into memory, ready to show, share or save.
@immutable
class DownloadedFile {
  /// Creates the file.
  const DownloadedFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  /// File name to offer when sharing or saving.
  final String name;

  /// The content.
  final Uint8List bytes;

  /// MIME type as served.
  final String mimeType;

  /// Whether the file is an image the app can show itself.
  bool get isImage => mimeType.startsWith('image/');

  /// Whether the file is a PDF.
  bool get isPdf => mimeType == FileKind.pdf.mimeType;

  @override
  String toString() => 'DownloadedFile(${bytes.length} bytes)';
}

/// Downloads private files through short-lived signed links:
/// `GET /files/{fileId}/access` (or a report's `GET /reports/{id}/download`)
/// returns an [Access], whose URL is fetched right away. Links are never
/// stored, shown or logged.
class FileDownloader {
  /// Creates the downloader over [client].
  FileDownloader(this._client);

  final ApiClient _client;

  /// `GET /files/{fileId}/access`: a signed link valid for a few minutes.
  Future<Access> access(String fileId) => _client.send(
    ApiEndpoints.fileAccess,
    pathParameters: <String, String>{'fileId': fileId},
    decode: (Map<String, Object?> json) => decodeEnvelopeAccess(json).data,
  );

  /// Fetches the file behind [access].
  Future<DownloadedFile> fetch(
    Access access, {
    void Function(double received)? onProgress,
  }) async {
    final DownloadedBytes body = await _client.downloadSigned(
      access.url,
      onReceiveProgress: onProgress == null
          ? null
          : (int received, int total) {
              if (total > 0) {
                onProgress(received / total);
              }
            },
    );
    final String served = (body.contentType ?? access.contentType)
        .split(';')
        .first
        .trim();
    return DownloadedFile(
      name: access.filename.isEmpty ? 'file' : access.filename,
      bytes: body.bytes,
      mimeType: served.isEmpty ? access.contentType : served,
    );
  }

  /// Downloads file [fileId] (access, then fetch).
  Future<DownloadedFile> download(String fileId) async =>
      fetch(await access(fileId));
}

/// The downloader used by screens. Overridden in tests.
final Provider<FileDownloader> fileDownloaderProvider =
    Provider<FileDownloader>(
      (Ref ref) => FileDownloader(ref.watch(apiClientProvider)),
    );

/// Hands a downloaded file to the user. Overridden in tests through
/// [fileExporterProvider].
abstract class FileExporter {
  /// Opens the system share sheet (other apps, "Save to Files", Drive…).
  /// [origin] anchors the sheet on tablets. Returns false when the user
  /// dismissed it.
  Future<bool> share(DownloadedFile file, {Rect? origin});

  /// Asks where to save the file (the system "save as" dialog) and writes
  /// it there. Returns false when the user cancelled.
  Future<bool> save(DownloadedFile file);
}

/// [FileExporter] backed by `share_plus` (share sheet) and `file_picker`
/// (Android's Storage Access Framework / the iOS document picker for
/// saving). Neither needs a storage permission.
class DeviceFileExporter implements FileExporter {
  /// Creates the exporter.
  const DeviceFileExporter();

  @override
  Future<bool> share(DownloadedFile file, {Rect? origin}) async {
    final ShareResult result = await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(file.bytes, name: file.name, mimeType: file.mimeType),
        ],
        fileNameOverrides: <String>[file.name],
        sharePositionOrigin: origin,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> save(DownloadedFile file) async {
    final Uri? saved = await FilePicker.saveFile(
      fileName: file.name,
      bytes: file.bytes,
      mimeType: file.mimeType,
    );
    return saved != null;
  }
}

/// The exporter used by screens. Overridden in tests.
final Provider<FileExporter> fileExporterProvider = Provider<FileExporter>(
  (Ref ref) => const DeviceFileExporter(),
);
