import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';

/// Mocks for the shared file services (`core/files`).
class MockFileUploader extends Mock implements FileUploader {}

class MockFileDownloader extends Mock implements FileDownloader {}

/// Registers fallback values for `any()` on the file services.
void registerFileFallbacks() {
  registerFallbackValue(
    PickedFile(name: 'fallback.jpg', bytes: Uint8List.fromList(<int>[1])),
  );
  registerFallbackValue(UploadPurpose.receipt);
  registerFallbackValue(FileOrigin.files);
  registerFallbackValue(
    DownloadedFile(
      name: 'fallback.pdf',
      bytes: Uint8List(1),
      mimeType: 'application/pdf',
    ),
  );
}

/// A picked file with [text] as its content.
PickedFile pickedFile({
  String name = 'receipt.jpg',
  String text = 'jpeg-bytes',
  String? mimeType = 'image/jpeg',
}) => PickedFile(
  name: name,
  bytes: Uint8List.fromList(utf8.encode(text)),
  mimeType: mimeType,
);

/// Answers picks from a queue; records what was asked.
class FakeFileSource implements FileSource {
  /// Creates the source answering with [results] in order (null =
  /// cancelled). An [Exception] in the queue is thrown instead.
  FakeFileSource([List<Object?> results = const <Object?>[]])
    : _results = List<Object?>.of(results);

  final List<Object?> _results;

  /// Every request: where from and for what.
  final List<(FileOrigin, UploadPurpose)> requests =
      <(FileOrigin, UploadPurpose)>[];

  /// Adds an answer.
  void enqueue(Object? result) => _results.add(result);

  @override
  Future<PickedFile?> pick(FileOrigin origin, UploadPurpose purpose) async {
    requests.add((origin, purpose));
    if (_results.isEmpty) {
      return null;
    }
    final Object? next = _results.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    return next as PickedFile?;
  }

  /// Every [pickMany] request: where from, for what and the limit.
  final List<(FileOrigin, UploadPurpose, int)> manyRequests =
      <(FileOrigin, UploadPurpose, int)>[];

  /// Answers with the next queued item: a list of files as they are, a
  /// single file as a list of one, null (cancelled) as an empty list.
  @override
  Future<List<PickedFile>> pickMany(
    FileOrigin origin,
    UploadPurpose purpose, {
    required int limit,
  }) async {
    manyRequests.add((origin, purpose, limit));
    if (_results.isEmpty) {
      return const <PickedFile>[];
    }
    final Object? next = _results.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    if (next is List<PickedFile>) {
      return next.take(limit).toList();
    }
    return next == null
        ? const <PickedFile>[]
        : <PickedFile>[next as PickedFile];
  }
}

/// Records shared and saved files.
class FakeFileExporter implements FileExporter {
  /// Files passed to [share].
  final List<DownloadedFile> shared = <DownloadedFile>[];

  /// Files passed to [save].
  final List<DownloadedFile> saved = <DownloadedFile>[];

  /// What [save] answers (false = the user cancelled).
  bool saveResult = true;

  @override
  Future<bool> share(DownloadedFile file, {Rect? origin}) async {
    shared.add(file);
    return true;
  }

  @override
  Future<bool> save(DownloadedFile file) async {
    saved.add(file);
    return saveResult;
  }
}

/// A `FileDTO` JSON object.
Map<String, Object?> fileDtoJson({
  String id = 'file-1',
  String purpose = 'receipt',
  String status = 'ready',
  String? name = 'receipt.jpg',
  String? contentType = 'image/jpeg',
  int? size = 2048,
}) => <String, Object?>{
  'id': id,
  'purpose': purpose,
  'status': status,
  'original_filename': ?name,
  'content_type': ?contentType,
  'size_bytes': ?size,
  'created_at': '2026-11-05T10:00:00Z',
};

/// A ready [FileDto].
FileDto fileDto({
  String id = 'file-1',
  String purpose = 'receipt',
  String? name = 'receipt.jpg',
  String? contentType = 'image/jpeg',
}) => FileDto.fromJson(
  fileDtoJson(id: id, purpose: purpose, name: name, contentType: contentType),
);

/// An [Access] (short-lived signed link).
Access access({
  String fileId = 'file-1',
  String filename = 'receipt.jpg',
  String contentType = 'image/jpeg',
}) => Access.fromJson(<String, Object?>{
  'url': 'http://localhost:8080/api/v1/files/$fileId/content?exp=1&sub=u&sig=s',
  'expires_at': '2026-11-05T10:05:00Z',
  'content_type': contentType,
  'filename': filename,
});

/// A downloaded file.
DownloadedFile downloadedFile({
  String name = 'report.csv',
  String mimeType = 'text/csv',
  String text = 'a,b\n1,2\n',
}) => DownloadedFile(
  name: name,
  bytes: Uint8List.fromList(utf8.encode(text)),
  mimeType: mimeType,
);
