import 'dart:math' as math;
import 'dart:typed_data';

/// A small baseline JPEG encoder (ITU-T T.81: sequential DCT, Huffman
/// coding, 8-bit, YCbCr 4:2:0) for re-encoding photos before upload.
///
/// Flutter can decode images (`dart:ui`) but only encodes PNG, and the app
/// avoids extra dependencies, so this file does the encoding. It writes a
/// JFIF header and nothing else: no Exif, no location, no thumbnails.
///
/// [rgba] holds `width * height` pixels as R, G, B, A bytes with
/// premultiplied alpha (`ui.ImageByteFormat.rawRgba`); transparent areas are
/// flattened onto white. [quality] is 1–100 (the libjpeg scale).
Uint8List encodeJpeg(
  Uint8List rgba,
  int width,
  int height, {
  int quality = 85,
}) {
  if (width < 1 || height < 1 || width > 65535 || height > 65535) {
    throw ArgumentError('Image size out of range: ${width}x$height');
  }
  if (rgba.length < width * height * 4) {
    throw ArgumentError('Pixel buffer is too small for ${width}x$height');
  }
  return _JpegWriter(quality.clamp(1, 100)).encode(rgba, width, height);
}

/// Natural (row-major) index of each coefficient in zig-zag order.
const List<int> _zigzag = <int>[
  0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, //
  12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
  35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
  58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
];

/// Annex K.1 quantization tables, row-major.
const List<int> _baseLuma = <int>[
  16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, //
  14, 13, 16, 24, 40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62,
  18, 22, 37, 56, 68, 109, 103, 77, 24, 35, 55, 64, 81, 104, 113, 92,
  49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99,
];
const List<int> _baseChroma = <int>[
  17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, //
  24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
];

/// Annex K.3 Huffman tables: code counts per length 1–16, then symbols.
const List<int> _dcLumaBits = <int>[
  0,
  1,
  5,
  1,
  1,
  1,
  1,
  1,
  1,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
];
const List<int> _dcChromaBits = <int>[
  0,
  3,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  0,
  0,
  0,
  0,
  0,
];
const List<int> _dcSymbols = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
const List<int> _acLumaBits = <int>[
  0,
  2,
  1,
  3,
  3,
  2,
  4,
  3,
  5,
  5,
  4,
  4,
  0,
  0,
  1,
  125,
];
const List<int> _acChromaBits = <int>[
  0,
  2,
  1,
  2,
  4,
  4,
  3,
  4,
  7,
  5,
  4,
  4,
  0,
  1,
  2,
  119,
];

/// The irregular start of each AC symbol list; the rest of the 162 symbols
/// (run/size pairs) follow in ascending order.
const List<int> _acLumaHead = <int>[
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, //
  0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
  0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72,
  0x82,
];
const List<int> _acChromaHead = <int>[
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, //
  0x51, 0x07, 0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
  0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0, 0x15, 0x62, 0x72, 0xd1,
  0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1,
];

List<int> _acSymbols(List<int> head) {
  final Set<int> seen = head.toSet();
  final List<int> all = <int>[
    0x00,
    0xf0,
    for (int run = 0; run < 16; run++)
      for (int size = 1; size <= 10; size++) (run << 4) | size,
  ]..sort();
  return <int>[...head, ...all.where((int s) => !seen.contains(s))];
}

/// Canonical Huffman codes (Annex C) indexed by symbol.
class _Huffman {
  _Huffman(this.bits, this.symbols) {
    int code = 0;
    int k = 0;
    for (int length = 1; length <= 16; length++) {
      for (int i = 0; i < bits[length - 1]; i++) {
        codes[symbols[k]] = code;
        lengths[symbols[k]] = length;
        code++;
        k++;
      }
      code <<= 1;
    }
  }

  final List<int> bits;
  final List<int> symbols;
  final Int32List codes = Int32List(256);
  final Int32List lengths = Int32List(256);
}

class _JpegWriter {
  _JpegWriter(int quality) {
    final int scale = quality < 50 ? 5000 ~/ quality : 200 - quality * 2;
    for (int i = 0; i < 64; i++) {
      _qLuma[i] = ((_baseLuma[i] * scale + 50) ~/ 100).clamp(1, 255);
      _qChroma[i] = ((_baseChroma[i] * scale + 50) ~/ 100).clamp(1, 255);
    }
    for (int u = 0; u < 8; u++) {
      final double c = u == 0 ? math.sqrt1_2 : 1.0;
      for (int x = 0; x < 8; x++) {
        _cos[u * 8 + x] = c / 2 * math.cos((2 * x + 1) * u * math.pi / 16);
      }
    }
  }

  final Int32List _qLuma = Int32List(64);
  final Int32List _qChroma = Int32List(64);
  final Float64List _cos = Float64List(64);
  final Float64List _tmp = Float64List(64);
  final Float64List _coef = Float64List(64);
  final Int32List _quantized = Int32List(64);

  final _Huffman _dcLuma = _Huffman(_dcLumaBits, _dcSymbols);
  final _Huffman _dcChroma = _Huffman(_dcChromaBits, _dcSymbols);
  final _Huffman _acLuma = _Huffman(_acLumaBits, _acSymbols(_acLumaHead));
  final _Huffman _acChroma = _Huffman(_acChromaBits, _acSymbols(_acChromaHead));

  final BytesBuilder _out = BytesBuilder();
  int _bitBuffer = 0;
  int _bitCount = 0;
  final List<int> _pending = <int>[];

  Uint8List encode(Uint8List rgba, int width, int height) {
    _writeHeaders(width, height);
    final Float64List y = Float64List(256);
    final Float64List cb = Float64List(64);
    final Float64List cr = Float64List(64);
    final Float64List block = Float64List(64);
    int dcY = 0;
    int dcCb = 0;
    int dcCr = 0;
    for (int my = 0; my < height; my += 16) {
      for (int mx = 0; mx < width; mx += 16) {
        cb.fillRange(0, 64, 0);
        cr.fillRange(0, 64, 0);
        for (int py = 0; py < 16; py++) {
          final int sy = math.min(my + py, height - 1);
          for (int px = 0; px < 16; px++) {
            final int sx = math.min(mx + px, width - 1);
            final int i = (sy * width + sx) * 4;
            // Premultiplied alpha flattened onto white.
            final int white = 255 - rgba[i + 3];
            final double r = (rgba[i] + white).clamp(0, 255).toDouble();
            final double g = (rgba[i + 1] + white).clamp(0, 255).toDouble();
            final double b = (rgba[i + 2] + white).clamp(0, 255).toDouble();
            y[py * 16 + px] = 0.299 * r + 0.587 * g + 0.114 * b - 128;
            final int c = (py >> 1) * 8 + (px >> 1);
            cb[c] += (-0.168736 * r - 0.331264 * g + 0.5 * b) / 4;
            cr[c] += (0.5 * r - 0.418688 * g - 0.081312 * b) / 4;
          }
        }
        for (int by = 0; by < 2; by++) {
          for (int bx = 0; bx < 2; bx++) {
            for (int r = 0; r < 8; r++) {
              for (int c = 0; c < 8; c++) {
                block[r * 8 + c] = y[(by * 8 + r) * 16 + bx * 8 + c];
              }
            }
            dcY = _encodeBlock(block, _qLuma, dcY, _dcLuma, _acLuma);
          }
        }
        dcCb = _encodeBlock(cb, _qChroma, dcCb, _dcChroma, _acChroma);
        dcCr = _encodeBlock(cr, _qChroma, dcCr, _dcChroma, _acChroma);
      }
    }
    _flushBits();
    _out.add(<int>[0xff, 0xd9]);
    return _out.takeBytes();
  }

  void _writeHeaders(int width, int height) {
    _out.add(<int>[0xff, 0xd8]);
    // APP0 JFIF 1.01, no density, no thumbnail.
    _out.add(<int>[0xff, 0xe0, 0, 16, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0]);
    _out.add(<int>[0, 1, 0, 1, 0, 0]);
    // DQT: both tables, written in zig-zag order.
    _out.add(<int>[0xff, 0xdb, 0, 132, 0]);
    _out.add(<int>[for (final int i in _zigzag) _qLuma[i]]);
    _out.add(<int>[1]);
    _out.add(<int>[for (final int i in _zigzag) _qChroma[i]]);
    // SOF0: 8-bit, 3 components, Y 2x2, Cb and Cr 1x1.
    _out.add(<int>[0xff, 0xc0, 0, 17, 8]);
    _out.add(<int>[height >> 8, height & 0xff, width >> 8, width & 0xff, 3]);
    _out.add(<int>[1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
    // DHT.
    final List<(int, _Huffman)> tables = <(int, _Huffman)>[
      (0x00, _dcLuma),
      (0x10, _acLuma),
      (0x01, _dcChroma),
      (0x11, _acChroma),
    ];
    int length = 2;
    for (final (int _, _Huffman h) in tables) {
      length += 17 + h.symbols.length;
    }
    _out.add(<int>[0xff, 0xc4, length >> 8, length & 0xff]);
    for (final (int id, _Huffman h) in tables) {
      _out
        ..addByte(id)
        ..add(h.bits)
        ..add(h.symbols);
    }
    // SOS.
    _out.add(<int>[0xff, 0xda, 0, 12, 3, 1, 0x00, 2, 0x11, 3, 0x11, 0, 63, 0]);
  }

  /// Forward DCT, quantization and Huffman coding of one 8x8 block (level
  /// shifted). Returns the block's DC value for the next prediction.
  int _encodeBlock(
    Float64List block,
    Int32List quant,
    int previousDc,
    _Huffman dc,
    _Huffman ac,
  ) {
    // tmp = C · block; coef = tmp · Cᵀ.
    for (int u = 0; u < 8; u++) {
      for (int x = 0; x < 8; x++) {
        double sum = 0;
        for (int k = 0; k < 8; k++) {
          sum += _cos[u * 8 + k] * block[k * 8 + x];
        }
        _tmp[u * 8 + x] = sum;
      }
    }
    for (int u = 0; u < 8; u++) {
      for (int v = 0; v < 8; v++) {
        double sum = 0;
        for (int k = 0; k < 8; k++) {
          sum += _tmp[u * 8 + k] * _cos[v * 8 + k];
        }
        _coef[u * 8 + v] = sum;
      }
    }
    for (int i = 0; i < 64; i++) {
      final int natural = _zigzag[i];
      _quantized[i] = (_coef[natural] / quant[natural]).round();
    }
    final int dcValue = _quantized[0];
    _writeValue(dcValue - previousDc, dc);
    int zeros = 0;
    for (int i = 1; i < 64; i++) {
      final int value = _quantized[i];
      if (value == 0) {
        zeros++;
        continue;
      }
      while (zeros > 15) {
        _writeCode(ac, 0xf0);
        zeros -= 16;
      }
      final int size = _category(value);
      _writeCode(ac, (zeros << 4) | size);
      _writeBits(_magnitude(value, size), size);
      zeros = 0;
    }
    if (zeros > 0) {
      _writeCode(ac, 0x00);
    }
    return dcValue;
  }

  void _writeValue(int value, _Huffman table) {
    final int size = _category(value);
    _writeCode(table, size);
    if (size > 0) {
      _writeBits(_magnitude(value, size), size);
    }
  }

  static int _category(int value) {
    int v = value.abs();
    int size = 0;
    while (v > 0) {
      size++;
      v >>= 1;
    }
    return size;
  }

  static int _magnitude(int value, int size) =>
      value >= 0 ? value : value + (1 << size) - 1;

  void _writeCode(_Huffman table, int symbol) =>
      _writeBits(table.codes[symbol], table.lengths[symbol]);

  void _writeBits(int bits, int count) {
    _bitBuffer = (_bitBuffer << count) | (bits & ((1 << count) - 1));
    _bitCount += count;
    while (_bitCount >= 8) {
      final int byte = (_bitBuffer >> (_bitCount - 8)) & 0xff;
      _pending.add(byte);
      if (byte == 0xff) {
        _pending.add(0); // byte stuffing
      }
      _bitCount -= 8;
      _bitBuffer &= (1 << _bitCount) - 1;
    }
    if (_pending.length >= 4096) {
      _out.add(_pending);
      _pending.clear();
    }
  }

  void _flushBits() {
    if (_bitCount > 0) {
      _writeBits((1 << (8 - _bitCount)) - 1, 8 - _bitCount);
    }
    _out.add(_pending);
    _pending.clear();
  }
}
