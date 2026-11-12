import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:montra_mobile/core/files/file_policy.dart';

/// A file the user chose, read into memory. The name is the original file
/// name; it is sent to the server with the upload but never logged.
@immutable
class PickedFile {
  /// Creates the file.
  const PickedFile({required this.name, required this.bytes, this.mimeType});

  /// File name including the extension.
  final String name;

  /// The content.
  final Uint8List bytes;

  /// MIME type reported by the device, if any (the server detects the real
  /// type from the content).
  final String? mimeType;

  /// Size in bytes.
  int get sizeBytes => bytes.length;

  @override
  String toString() => 'PickedFile(${bytes.length} bytes)';
}

/// Where the user takes a file from.
enum FileOrigin {
  /// A new photo from the camera.
  camera,

  /// A photo from the device's photo library.
  photos,

  /// Any document from the device's files.
  files,
}

/// The device camera was not available (no camera app, or access denied).
class CameraUnavailable implements Exception {
  /// Creates the error.
  const CameraUnavailable();
}

/// Lets the user choose a file. Overridden in tests through
/// [fileSourceProvider].
abstract class FileSource {
  /// Asks the user for a file from [origin] that fits [purpose]. Returns
  /// null when the user cancels. Throws [CameraUnavailable] when the camera
  /// cannot be used.
  Future<PickedFile?> pick(FileOrigin origin, UploadPurpose purpose);

  /// Like [pick], but the photo library and the files picker let the user
  /// choose up to [limit] items at once (in the order chosen); the camera
  /// takes one photo. Empty when the user cancels.
  Future<List<PickedFile>> pickMany(
    FileOrigin origin,
    UploadPurpose purpose, {
    required int limit,
  });
}

/// [FileSource] backed by the system pickers: `image_picker` for the camera
/// and photo library (no storage permission needed: Android's photo picker
/// and iOS's PHPicker), `file_picker` for documents (the Storage Access
/// Framework on Android, the document picker on iOS). Only the chosen file
/// is read.
class DeviceFileSource implements FileSource {
  /// Creates the source.
  DeviceFileSource({ImagePicker? imagePicker})
    : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  /// Camera photos are scaled down to this many pixels on the longest side
  /// and re-encoded, which keeps receipts readable and uploads small.
  static const double maxPhotoSide = 3000;

  /// JPEG quality for camera photos.
  static const int photoQuality = 85;

  @override
  Future<PickedFile?> pick(FileOrigin origin, UploadPurpose purpose) async {
    switch (origin) {
      case FileOrigin.camera:
      case FileOrigin.photos:
        final XFile? photo;
        try {
          photo = await _images.pickImage(
            source: origin == FileOrigin.camera
                ? ImageSource.camera
                : ImageSource.gallery,
            maxWidth: maxPhotoSide,
            maxHeight: maxPhotoSide,
            imageQuality: photoQuality,
            requestFullMetadata: false,
          );
        } on PlatformException {
          if (origin == FileOrigin.camera) {
            throw const CameraUnavailable();
          }
          rethrow;
        }
        if (photo == null) {
          return null;
        }
        final Uint8List bytes = await photo.readAsBytes();
        final String name = origin == FileOrigin.camera
            ? _cameraName(photo.name)
            : photo.name;
        return PickedFile(name: name, bytes: bytes, mimeType: photo.mimeType);
      case FileOrigin.files:
        final PlatformFile? file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: purpose.pickerExtensions,
        );
        if (file == null) {
          return null;
        }
        final Uint8List bytes = await file.readAsBytes();
        return PickedFile(
          name: file.name,
          bytes: bytes,
          mimeType: purpose.kindOf(file.name)?.mimeType,
        );
    }
  }

  @override
  Future<List<PickedFile>> pickMany(
    FileOrigin origin,
    UploadPurpose purpose, {
    required int limit,
  }) async {
    if (limit < 1) {
      return const <PickedFile>[];
    }
    switch (origin) {
      case FileOrigin.camera:
        final PickedFile? photo = await pick(origin, purpose);
        return photo == null ? const <PickedFile>[] : <PickedFile>[photo];
      case FileOrigin.photos:
        if (limit == 1) {
          final PickedFile? photo = await pick(origin, purpose);
          return photo == null ? const <PickedFile>[] : <PickedFile>[photo];
        }
        final List<XFile> photos = await _images.pickMultiImage(
          maxWidth: maxPhotoSide,
          maxHeight: maxPhotoSide,
          imageQuality: photoQuality,
          limit: limit,
          requestFullMetadata: false,
        );
        return <PickedFile>[
          for (final XFile photo in photos.take(limit))
            PickedFile(
              name: photo.name,
              bytes: await photo.readAsBytes(),
              mimeType: photo.mimeType,
            ),
        ];
      case FileOrigin.files:
        final List<PlatformFile> files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: purpose.pickerExtensions,
        );
        return <PickedFile>[
          for (final PlatformFile file in files.take(limit))
            PickedFile(
              name: file.name,
              bytes: await file.readAsBytes(),
              mimeType: purpose.kindOf(file.name)?.mimeType,
            ),
        ];
    }
  }

  /// Camera files get a readable name with the capture time instead of a
  /// random one; the extension is kept.
  static String _cameraName(String original) {
    final String ext = FileKind.extensionOf(original);
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final String stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'photo-$stamp.${ext.isEmpty ? 'jpg' : ext}';
  }
}

/// The file source used by upload screens.
final Provider<FileSource> fileSourceProvider = Provider<FileSource>(
  (Ref ref) => DeviceFileSource(),
);
