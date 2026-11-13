import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/image_metadata.dart';
import 'package:montra_mobile/core/files/jpeg_encoder.dart';

/// What to do with a picked image before it is uploaded.
enum ImagePlan {
  /// Upload it as it is (not an image, or a format left alone).
  keep,

  /// Remove metadata (location, camera details) without touching pixels.
  stripMetadata,

  /// Decode, scale down if needed and re-encode as JPEG (no metadata).
  reencode,
}

/// The plan for one image and, for [ImagePlan.reencode], the output size.
@immutable
class ImageDecision {
  /// Creates the decision.
  const ImageDecision(this.plan, {this.width = 0, this.height = 0});

  /// What to do.
  final ImagePlan plan;

  /// Output width in pixels (re-encoding only).
  final int width;

  /// Output height in pixels (re-encoding only).
  final int height;

  @override
  bool operator ==(Object other) =>
      other is ImageDecision &&
      other.plan == plan &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(plan, width, height);

  @override
  String toString() => 'ImageDecision(${plan.name}, ${width}x$height)';
}

/// Decides how to prepare an image (COST-001): photos larger than
/// [maxSide] pixels on their long edge are scaled down (never up) and
/// re-encoded as JPEG at a good quality; HEIC and WebP are converted to
/// JPEG; a JPEG that is already small enough in pixels but heavy in bytes
/// (above [reencodeAboveBytes]) is re-encoded too. Everything else that is
/// a JPEG or PNG only loses its metadata. PDFs and other files are never
/// touched. [width] and [height] are as displayed (orientation applied).
ImageDecision decideImage({
  required ImageFormat? format,
  required int width,
  required int height,
  required int sizeBytes,
  int maxSide = ImagePreparer.defaultMaxSide,
  int reencodeAboveBytes = ImagePreparer.defaultReencodeAboveBytes,
}) {
  if (format == null || format == ImageFormat.gif) {
    return const ImageDecision(ImagePlan.keep);
  }
  final int longEdge = math.max(width, height);
  if (longEdge <= 0) {
    // Size unknown (could not be decoded): metadata can still be removed.
    return format == ImageFormat.jpeg || format == ImageFormat.png
        ? const ImageDecision(ImagePlan.stripMetadata)
        : const ImageDecision(ImagePlan.keep);
  }
  if (longEdge > maxSide) {
    final double scale = maxSide / longEdge;
    return ImageDecision(
      ImagePlan.reencode,
      width: math.max(1, math.min(maxSide, (width * scale).round())),
      height: math.max(1, math.min(maxSide, (height * scale).round())),
    );
  }
  if (format == ImageFormat.heic ||
      format == ImageFormat.webp ||
      (format == ImageFormat.jpeg && sizeBytes > reencodeAboveBytes)) {
    return ImageDecision(ImagePlan.reencode, width: width, height: height);
  }
  return const ImageDecision(ImagePlan.stripMetadata);
}

/// Decoded pixels: premultiplied RGBA, row-major.
@immutable
class RgbaImage {
  /// Creates the image.
  const RgbaImage(this.pixels, this.width, this.height);

  /// `width * height * 4` bytes.
  final Uint8List pixels;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;
}

/// Decodes images. The default uses the Flutter engine (`dart:ui`), which
/// applies the Exif orientation, so pixels come out the right way up.
abstract class ImageDecoder {
  /// Creates the decoder.
  const ImageDecoder();

  /// The displayed size of [bytes], or null when they cannot be decoded.
  Future<({int width, int height})?> size(Uint8List bytes);

  /// [bytes] decoded and scaled to [width] x [height] (displayed size), or
  /// null when they cannot be decoded.
  Future<RgbaImage?> decode(
    Uint8List bytes, {
    required int width,
    required int height,
  });
}

/// [ImageDecoder] backed by `dart:ui`.
class UiImageDecoder extends ImageDecoder {
  /// Creates the decoder.
  const UiImageDecoder();

  @override
  Future<({int width, int height})?> size(Uint8List bytes) async {
    // The size callback runs before any pixels are decoded, so reading the
    // size of a large photo stays cheap.
    try {
      ({int width, int height})? result;
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        bytes,
      );
      final ui.Codec codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (int w, int h) {
          result = (width: w, height: h);
          return ui.TargetImageSize(width: w, height: h);
        },
      );
      codec.dispose();
      return result;
    } on Object {
      return null;
    }
  }

  @override
  Future<RgbaImage?> decode(
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    final ui.Image? image = await _decode(bytes, width: width, height: height);
    if (image == null) {
      return null;
    }
    try {
      final ByteData? data = await image.toByteData();
      if (data == null) {
        return null;
      }
      return RgbaImage(data.buffer.asUint8List(), image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  /// Decodes through `instantiateImageCodecWithSize`, whose size callback
  /// receives the displayed (oriented) size, so the target never swaps
  /// width and height for rotated photos.
  static Future<ui.Image?> _decode(
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    try {
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        bytes,
      );
      final ui.Codec codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (int _, int _) =>
            ui.TargetImageSize(width: width, height: height),
      );
      try {
        final ui.FrameInfo frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } on Object {
      return null;
    }
  }
}

/// Encodes off the UI isolate.
typedef JpegEncoder = Future<Uint8List> Function(RgbaImage image, int quality);

Future<Uint8List> _isolateEncode(RgbaImage image, int quality) => compute(
  _encodeJob,
  (image.pixels, image.width, image.height, quality),
  debugLabel: 'jpeg encode',
);

Uint8List _encodeJob((Uint8List, int, int, int) job) =>
    encodeJpeg(job.$1, job.$2, job.$3, quality: job.$4);

/// Makes photos smaller and private before they are uploaded (COST-001):
/// see [decideImage] for when an image is scaled or re-encoded. Location
/// and other Exif details never leave the device: re-encoded images carry
/// no metadata, and kept JPEG/PNG files have theirs removed (a JPEG keeps
/// only its orientation). The returned file's bytes are the ones the
/// uploader checksums and sends.
class ImagePreparer {
  /// Creates the preparer.
  const ImagePreparer({
    this.maxSide = defaultMaxSide,
    this.quality = defaultQuality,
    this.reencodeAboveBytes = defaultReencodeAboveBytes,
    this.decoder = const UiImageDecoder(),
    this._encoder,
  });

  /// Longest side of an uploaded photo, in pixels.
  static const int defaultMaxSide = 2048;

  /// JPEG quality for re-encoded photos.
  static const int defaultQuality = 85;

  /// A JPEG within [defaultMaxSide] is re-encoded only above this size.
  static const int defaultReencodeAboveBytes = 1536 * 1024;

  /// Longest side, in pixels.
  final int maxSide;

  /// JPEG quality (1–100).
  final int quality;

  /// Re-encode threshold for JPEGs that are not too large in pixels.
  final int reencodeAboveBytes;

  /// Image decoder.
  final ImageDecoder decoder;

  final JpegEncoder? _encoder;

  /// The file to upload for [file]: unchanged unless it is an image that
  /// [purpose] accepts as JPEG. Never throws for a bad image: anything that
  /// cannot be processed is uploaded as picked (the server checks it).
  Future<PickedFile> prepare(PickedFile file, UploadPurpose purpose) async {
    final ImageFormat? format = ImageFormat.sniff(file.bytes);
    if (format == null ||
        format == ImageFormat.gif ||
        !purpose.kinds.contains(FileKind.jpeg)) {
      return file;
    }
    final ({int width, int height})? size = await decoder.size(file.bytes);
    final ImageDecision decision = decideImage(
      format: format,
      width: size?.width ?? 0,
      height: size?.height ?? 0,
      sizeBytes: file.sizeBytes,
      maxSide: maxSide,
      reencodeAboveBytes: reencodeAboveBytes,
    );
    switch (decision.plan) {
      case ImagePlan.keep:
        return file;
      case ImagePlan.stripMetadata:
        return _stripped(file, format) ?? file;
      case ImagePlan.reencode:
        final Uint8List? jpeg = await _reencode(file.bytes, decision);
        if (jpeg == null) {
          return _stripped(file, format) ?? file;
        }
        final PickedFile reencoded = _asJpeg(file, jpeg);
        // Re-encoding only for weight: keep whichever is smaller.
        final bool resized =
            math.max(decision.width, decision.height) <
            math.max(size?.width ?? 0, size?.height ?? 0);
        if (!resized && format == ImageFormat.jpeg) {
          final PickedFile stripped = _stripped(file, format) ?? file;
          return stripped.sizeBytes <= reencoded.sizeBytes
              ? stripped
              : reencoded;
        }
        return reencoded;
    }
  }

  Future<Uint8List?> _reencode(Uint8List bytes, ImageDecision d) async {
    final RgbaImage? image = await decoder.decode(
      bytes,
      width: d.width,
      height: d.height,
    );
    if (image == null) {
      return null;
    }
    try {
      return await (_encoder ?? _isolateEncode)(image, quality);
    } on Object {
      return null;
    }
  }

  static PickedFile? _stripped(PickedFile file, ImageFormat format) {
    switch (format) {
      case ImageFormat.jpeg:
        final Uint8List? bytes = ImageMetadata.stripJpeg(file.bytes);
        return bytes == null ? null : _asJpeg(file, bytes);
      case ImageFormat.png:
        final Uint8List? bytes = ImageMetadata.stripPng(file.bytes);
        return bytes == null
            ? null
            : PickedFile(
                name: _withExtension(file.name, 'png', const <String>{'png'}),
                bytes: bytes,
                mimeType: FileKind.png.mimeType,
              );
      case ImageFormat.webp:
      case ImageFormat.heic:
      case ImageFormat.gif:
        return null;
    }
  }

  static PickedFile _asJpeg(PickedFile file, Uint8List bytes) => PickedFile(
    name: _withExtension(file.name, 'jpg', const <String>{'jpg', 'jpeg'}),
    bytes: bytes,
    mimeType: FileKind.jpeg.mimeType,
  );

  /// [name] with extension [ext] unless it already has one of [accepted]
  /// (the server checks that the extension matches the content).
  static String _withExtension(String name, String ext, Set<String> accepted) {
    if (accepted.contains(FileKind.extensionOf(name))) {
      return name;
    }
    final int dot = name.lastIndexOf('.');
    final String stem = dot > 0 ? name.substring(0, dot) : name;
    return '${stem.isEmpty ? 'photo' : stem}.$ext';
  }
}

/// The preparer used by the uploader. Overridden in tests.
final Provider<ImagePreparer> imagePreparerProvider = Provider<ImagePreparer>(
  (Ref ref) => const ImagePreparer(),
);
