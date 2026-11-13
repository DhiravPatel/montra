import 'dart:typed_data';

/// Image formats recognized from their first bytes (the server sniffs the
/// same way; the file name is not trusted).
enum ImageFormat {
  /// JPEG (`FF D8 FF`).
  jpeg,

  /// PNG.
  png,

  /// WebP (RIFF container).
  webp,

  /// HEIC / HEIF (ISO BMFF `ftyp` box with a HEIF brand).
  heic,

  /// GIF.
  gif;

  /// Detects the format of [bytes], or null when they are not an image
  /// this app handles (PDFs, spreadsheets, text, …).
  static ImageFormat? sniff(Uint8List bytes) {
    bool at(int offset, List<int> expected) {
      if (bytes.length < offset + expected.length) {
        return false;
      }
      for (int i = 0; i < expected.length; i++) {
        if (bytes[offset + i] != expected[i]) {
          return false;
        }
      }
      return true;
    }

    if (at(0, const <int>[0xff, 0xd8, 0xff])) {
      return jpeg;
    }
    if (at(0, const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return png;
    }
    if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
      return webp;
    }
    if (at(0, 'GIF8'.codeUnits)) {
      return gif;
    }
    if (at(4, 'ftyp'.codeUnits) && bytes.length >= 12) {
      final String brand = String.fromCharCodes(bytes.sublist(8, 12));
      const Set<String> heif = <String>{
        'heic',
        'heix',
        'hevc',
        'hevx',
        'heim',
        'heis',
        'mif1',
        'msf1',
      };
      if (heif.contains(brand)) {
        return heic;
      }
    }
    return null;
  }
}

/// Reads and removes metadata from JPEG and PNG files without decoding the
/// pixels, so nothing is lost to a second compression.
abstract final class ImageMetadata {
  /// The Exif orientation (1–8) of a JPEG, or 1 when it has none.
  static int jpegOrientation(Uint8List bytes) {
    try {
      for (final _Segment s in _jpegSegments(bytes)) {
        if (s.marker == 0xe1) {
          final int? orientation = _exifOrientation(bytes, s.start, s.end);
          if (orientation != null) {
            return orientation;
          }
        }
        if (s.marker == 0xda) {
          break;
        }
      }
    } on FormatException {
      return 1;
    }
    return 1;
  }

  /// A copy of a JPEG without Exif (camera details, location), XMP, IPTC
  /// and comments. The colour profile (APP2) and Adobe colour transform
  /// (APP14) are kept, and so is the orientation, rewritten as a minimal
  /// Exif block, so the photo still shows the right way up. Returns null
  /// when the file is not a well-formed JPEG.
  static Uint8List? stripJpeg(Uint8List bytes) {
    final List<_Segment> segments;
    try {
      segments = _jpegSegments(bytes).toList();
    } on FormatException {
      return null;
    }
    if (segments.isEmpty || segments.last.marker != 0xda) {
      return null;
    }
    int orientation = 1;
    final BytesBuilder out = BytesBuilder()..add(const <int>[0xff, 0xd8]);
    final List<_Segment> kept = <_Segment>[];
    for (final _Segment s in segments) {
      if (s.marker == 0xe1) {
        orientation = _exifOrientation(bytes, s.start, s.end) ?? orientation;
        continue;
      }
      final bool app = s.marker >= 0xe0 && s.marker <= 0xef;
      final bool keepApp =
          s.marker == 0xe0 || s.marker == 0xe2 || s.marker == 0xee;
      if ((app && !keepApp) || s.marker == 0xfe) {
        continue;
      }
      kept.add(s);
    }
    bool wroteExif = false;
    for (final _Segment s in kept) {
      if (!wroteExif && s.marker != 0xe0) {
        if (orientation != 1) {
          out.add(_minimalExif(orientation));
        }
        wroteExif = true;
      }
      // Marker, then the segment (length field included) or, for SOS, the
      // rest of the file.
      out
        ..add(<int>[0xff, s.marker])
        ..add(Uint8List.sublistView(bytes, s.start, s.end));
    }
    return out.takeBytes();
  }

  /// A copy of a PNG without text, time and Exif chunks (`tEXt`, `zTXt`,
  /// `iTXt`, `tIME`, `eXIf`). Returns null when the file is not a
  /// well-formed PNG.
  static Uint8List? stripPng(Uint8List bytes) {
    const Set<String> drop = <String>{'tEXt', 'zTXt', 'iTXt', 'tIME', 'eXIf'};
    if (bytes.length < 8) {
      return null;
    }
    final BytesBuilder out = BytesBuilder()
      ..add(Uint8List.sublistView(bytes, 0, 8));
    int offset = 8;
    bool ended = false;
    while (offset + 12 <= bytes.length) {
      final int length = _u32(bytes, offset, bigEndian: true);
      final int end = offset + 12 + length;
      if (length < 0 || end > bytes.length) {
        return null;
      }
      final String type = String.fromCharCodes(
        bytes.sublist(offset + 4, offset + 8),
      );
      if (!drop.contains(type)) {
        out.add(Uint8List.sublistView(bytes, offset, end));
      }
      offset = end;
      if (type == 'IEND') {
        ended = true;
        break;
      }
    }
    return ended ? out.takeBytes() : null;
  }

  static List<int> _minimalExif(int orientation) => <int>[
    0xff, 0xe1, 0x00, 0x22, // APP1, length 34
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    0x4d,
    0x4d,
    0x00,
    0x2a,
    0x00,
    0x00,
    0x00,
    0x08, // big-endian TIFF, IFD0 at 8
    0x00, 0x01, // one entry
    0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
    0x00, orientation, 0x00, 0x00, // value
    0x00, 0x00, 0x00, 0x00, // no next IFD
  ];

  /// Segments after SOI. Each covers the length field and payload; the
  /// last one is SOS and extends to the end of the file.
  static Iterable<_Segment> _jpegSegments(Uint8List b) sync* {
    if (b.length < 4 || b[0] != 0xff || b[1] != 0xd8) {
      throw const FormatException('Not a JPEG');
    }
    int i = 2;
    while (i < b.length) {
      if (b[i] != 0xff) {
        throw const FormatException('Expected a marker');
      }
      while (i < b.length && b[i] == 0xff) {
        i++; // fill bytes
      }
      if (i >= b.length) {
        throw const FormatException('Truncated JPEG');
      }
      final int marker = b[i];
      i++;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
        yield _Segment(marker, i, i);
        continue;
      }
      if (marker == 0xd9) {
        throw const FormatException('Image ends before the scan');
      }
      if (i + 2 > b.length) {
        throw const FormatException('Truncated segment');
      }
      final int length = (b[i] << 8) | b[i + 1];
      if (length < 2 || i + length > b.length) {
        throw const FormatException('Bad segment length');
      }
      if (marker == 0xda) {
        yield _Segment(marker, i, b.length);
        return;
      }
      yield _Segment(marker, i, i + length);
      i += length;
    }
    throw const FormatException('No image data');
  }

  /// Orientation from an APP1 segment ([start] is the length field), or
  /// null when it is not Exif or has no valid orientation.
  static int? _exifOrientation(Uint8List b, int start, int end) {
    final int tiff = start + 2 + 6;
    if (end - start < 2 + 6 + 8 ||
        String.fromCharCodes(b.sublist(start + 2, start + 6)) != 'Exif') {
      return null;
    }
    final bool big;
    if (b[tiff] == 0x4d && b[tiff + 1] == 0x4d) {
      big = true;
    } else if (b[tiff] == 0x49 && b[tiff + 1] == 0x49) {
      big = false;
    } else {
      return null;
    }
    final int ifd = tiff + _u32(b, tiff + 4, bigEndian: big);
    if (ifd + 2 > end) {
      return null;
    }
    final int count = _u16(b, ifd, bigEndian: big);
    for (int n = 0; n < count; n++) {
      final int entry = ifd + 2 + n * 12;
      if (entry + 12 > end) {
        return null;
      }
      if (_u16(b, entry, bigEndian: big) == 0x0112 &&
          _u16(b, entry + 2, bigEndian: big) == 3) {
        final int value = _u16(b, entry + 8, bigEndian: big);
        return value >= 1 && value <= 8 ? value : null;
      }
    }
    return null;
  }

  static int _u16(Uint8List b, int i, {required bool bigEndian}) =>
      bigEndian ? (b[i] << 8) | b[i + 1] : b[i] | (b[i + 1] << 8);

  static int _u32(Uint8List b, int i, {required bool bigEndian}) => bigEndian
      ? (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]
      : b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);
}

class _Segment {
  const _Segment(this.marker, this.start, this.end);

  final int marker;
  final int start;
  final int end;
}
