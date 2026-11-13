import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/image_metadata.dart';
import 'package:montra_mobile/core/files/image_preparer.dart';
import 'package:montra_mobile/core/files/jpeg_encoder.dart';

/// [width] x [height] premultiplied RGBA: red on the left half, blue on the
/// right half.
Uint8List halves(int width, int height) {
  final Uint8List rgba = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = (y * width + x) * 4;
      final bool left = x < width ~/ 2;
      rgba[i] = left ? 220 : 20;
      rgba[i + 1] = 30;
      rgba[i + 2] = left ? 20 : 220;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

/// An APP1 Exif segment with an orientation and a GPS IFD pointer, the
/// way camera apps write them (little-endian).
List<int> exifWithGps(int orientation) {
  final List<int> tiff = <int>[
    0x49, 0x49, 0x2a, 0x00, 0x08, 0x00, 0x00, 0x00, // II, IFD0 at 8
    0x02, 0x00, // two entries
    0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, orientation, 0, 0, 0,
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x26, 0, 0, 0, // GPS IFD
    0x00, 0x00, 0x00, 0x00, // no next IFD
    // GPS IFD at 38: one entry, GPSLatitudeRef = "N"
    0x01, 0x00, 0x01, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x4e, 0, 0, 0,
    0x00, 0x00, 0x00, 0x00,
  ];
  final List<int> payload = <int>[...'Exif'.codeUnits, 0, 0, ...tiff];
  final int length = payload.length + 2;
  return <int>[0xff, 0xe1, length >> 8, length & 0xff, ...payload];
}

/// [jpeg] with [segment] inserted right after SOI.
Uint8List withSegment(Uint8List jpeg, List<int> segment) => Uint8List.fromList(
  <int>[...jpeg.sublist(0, 2), ...segment, ...jpeg.sublist(2)],
);

bool containsAscii(Uint8List bytes, String text) {
  final List<int> needle = text.codeUnits;
  outer:
  for (int i = 0; i + needle.length <= bytes.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        continue outer;
      }
    }
    return true;
  }
  return false;
}

class FakeDecoder extends ImageDecoder {
  FakeDecoder(this.width, this.height);

  final int width;
  final int height;
  final List<(int, int)> decodes = <(int, int)>[];

  @override
  Future<({int width, int height})?> size(Uint8List bytes) async =>
      (width: width, height: height);

  @override
  Future<RgbaImage?> decode(
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    decodes.add((width, height));
    return RgbaImage(halves(width, height), width, height);
  }
}

Future<Uint8List> syncEncode(RgbaImage image, int quality) async =>
    encodeJpeg(image.pixels, image.width, image.height, quality: quality);

void main() {
  group('decideImage', () {
    test('never touches PDFs or other non-images', () {
      expect(
        decideImage(
          format: null,
          width: 5000,
          height: 5000,
          sizeBytes: 9e6.toInt(),
        ),
        const ImageDecision(ImagePlan.keep),
      );
    });

    test('scales the long edge down to 2048 and keeps the aspect ratio', () {
      expect(
        decideImage(
          format: ImageFormat.jpeg,
          width: 4032,
          height: 3024,
          sizeBytes: 3000000,
        ),
        const ImageDecision(ImagePlan.reencode, width: 2048, height: 1536),
      );
      expect(
        decideImage(
          format: ImageFormat.png,
          width: 1000,
          height: 6000,
          sizeBytes: 100,
        ),
        const ImageDecision(ImagePlan.reencode, width: 341, height: 2048),
      );
    });

    test('never upscales: small images only lose their metadata', () {
      expect(
        decideImage(
          format: ImageFormat.jpeg,
          width: 640,
          height: 480,
          sizeBytes: 90000,
        ),
        const ImageDecision(ImagePlan.stripMetadata),
      );
      expect(
        decideImage(
          format: ImageFormat.jpeg,
          width: 2048,
          height: 2048,
          sizeBytes: 900000,
        ),
        const ImageDecision(ImagePlan.stripMetadata),
      );
    });

    test('re-encodes heavy JPEGs, HEIC and WebP at their own size', () {
      expect(
        decideImage(
          format: ImageFormat.jpeg,
          width: 1800,
          height: 1200,
          sizeBytes: 4 * 1024 * 1024,
        ),
        const ImageDecision(ImagePlan.reencode, width: 1800, height: 1200),
      );
      expect(
        decideImage(
          format: ImageFormat.heic,
          width: 1200,
          height: 900,
          sizeBytes: 500000,
        ),
        const ImageDecision(ImagePlan.reencode, width: 1200, height: 900),
      );
    });
  });

  group('ImageFormat.sniff', () {
    test('detects formats from content, not names', () {
      expect(
        ImageFormat.sniff(encodeJpeg(halves(8, 8), 8, 8)),
        ImageFormat.jpeg,
      );
      expect(
        ImageFormat.sniff(Uint8List.fromList('%PDF-1.7\n'.codeUnits)),
        isNull,
      );
      expect(
        ImageFormat.sniff(
          Uint8List.fromList(<int>[0, 0, 0, 24, ...'ftypheic'.codeUnits]),
        ),
        ImageFormat.heic,
      );
    });
  });

  group('ImageMetadata', () {
    test('strips location but keeps the orientation', () {
      final Uint8List original = withSegment(
        encodeJpeg(halves(16, 8), 16, 8),
        exifWithGps(6),
      );
      expect(ImageMetadata.jpegOrientation(original), 6);
      final Uint8List stripped = ImageMetadata.stripJpeg(original)!;
      expect(ImageMetadata.jpegOrientation(stripped), 6);
      // The GPS pointer tag (0x8825, little-endian 25 88) is gone.
      expect(
        containsAscii(stripped, String.fromCharCodes(<int>[0x25, 0x88])),
        isFalse,
      );
      expect(
        containsAscii(original, String.fromCharCodes(<int>[0x25, 0x88])),
        isTrue,
      );
      expect(stripped.length, lessThan(original.length));
    });

    test('rejects files that are not JPEGs', () {
      expect(
        ImageMetadata.stripJpeg(Uint8List.fromList(<int>[1, 2, 3])),
        isNull,
      );
      expect(
        ImageMetadata.stripPng(Uint8List.fromList(<int>[1, 2, 3])),
        isNull,
      );
    });
  });

  group('encodeJpeg and the dart:ui decoder', () {
    testWidgets('round-trips pixels and honours the Exif orientation', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        const UiImageDecoder decoder = UiImageDecoder();
        final Uint8List jpeg = encodeJpeg(halves(40, 20), 40, 20);
        expect(await decoder.size(jpeg), (width: 40, height: 20));
        final RgbaImage plain = (await decoder.decode(
          jpeg,
          width: 40,
          height: 20,
        ))!;
        // Left half red, right half blue.
        expect(plain.pixels[(10 * 40 + 5) * 4], greaterThan(180));
        expect(plain.pixels[(10 * 40 + 35) * 4 + 2], greaterThan(180));

        final Uint8List rotated = withSegment(jpeg, exifWithGps(6));
        expect(await decoder.size(rotated), (width: 20, height: 40));
        final RgbaImage upright = (await decoder.decode(
          rotated,
          width: 20,
          height: 40,
        ))!;
        expect(upright.width, 20);
        expect(upright.height, 40);
        // Rotated 90° clockwise: the red (left) half is now on top.
        expect(upright.pixels[(5 * 20 + 10) * 4], greaterThan(180));
        expect(upright.pixels[(35 * 20 + 10) * 4 + 2], greaterThan(180));
      });
    });
  });

  group('ImagePreparer', () {
    test('scales large photos down and renames them .jpg', () async {
      final FakeDecoder decoder = FakeDecoder(4000, 3000);
      final ImagePreparer preparer = ImagePreparer(
        decoder: decoder,
        encoder: syncEncode,
      );
      final PickedFile photo = PickedFile(
        name: 'IMG_0001.HEIC',
        bytes: Uint8List.fromList(<int>[
          0,
          0,
          0,
          24,
          ...'ftypheic'.codeUnits,
          0,
          0,
        ]),
      );
      final PickedFile out = await preparer.prepare(
        photo,
        UploadPurpose.receipt,
      );
      expect(decoder.decodes, <(int, int)>[(2048, 1536)]);
      expect(out.name, 'IMG_0001.jpg');
      expect(out.mimeType, 'image/jpeg');
      expect(ImageFormat.sniff(out.bytes), ImageFormat.jpeg);
    });

    test('leaves PDFs and purposes without photos alone', () async {
      final FakeDecoder decoder = FakeDecoder(9000, 9000);
      final ImagePreparer preparer = ImagePreparer(decoder: decoder);
      final PickedFile pdf = PickedFile(
        name: 'bill.pdf',
        bytes: Uint8List.fromList('%PDF-1.7 ...'.codeUnits),
      );
      expect(
        identical(await preparer.prepare(pdf, UploadPurpose.receipt), pdf),
        isTrue,
      );
      final PickedFile csv = PickedFile(
        name: 'statement.csv',
        bytes: Uint8List.fromList('date,amount\n'.codeUnits),
      );
      expect(
        identical(
          await preparer.prepare(csv, UploadPurpose.statementImport),
          csv,
        ),
        isTrue,
      );
      expect(decoder.decodes, isEmpty);
    });

    test('small JPEGs keep their pixels and lose their location', () async {
      final Uint8List original = withSegment(
        encodeJpeg(halves(64, 48), 64, 48),
        exifWithGps(3),
      );
      final ImagePreparer preparer = ImagePreparer(
        decoder: FakeDecoder(64, 48),
        encoder: syncEncode,
      );
      final PickedFile out = await preparer.prepare(
        PickedFile(name: 'avatar.jpeg', bytes: original),
        UploadPurpose.avatar,
      );
      expect(out.name, 'avatar.jpeg');
      expect(ImageMetadata.jpegOrientation(out.bytes), 3);
      expect(
        containsAscii(out.bytes, String.fromCharCodes(<int>[0x25, 0x88])),
        isFalse,
      );
      // Same scan data: only the header changed.
      expect(
        out.bytes.sublist(out.bytes.length - 100),
        original.sublist(original.length - 100),
      );
    });
  });
}
