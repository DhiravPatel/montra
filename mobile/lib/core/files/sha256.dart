import 'dart:typed_data';

/// SHA-256 (FIPS 180-4) of [data] as 64 lower-case hex digits.
///
/// Used for the optional `checksum_sha256` of an upload intent and the
/// `X-Upload-Checksum` header, so the server can reject a corrupted upload.
/// The `crypto` package is not a direct dependency of the app, so the digest
/// is computed here (verified against the NIST test vectors in
/// `test/core/files/sha256_test.dart`). Large files should be hashed off the
/// UI isolate (see `FileUploader`).
String sha256Hex(Uint8List data) {
  final Uint32List h = Uint32List.fromList(_initial);
  final Uint32List w = Uint32List(64);
  final int fullBlocks = data.length ~/ 64;
  final ByteData view = ByteData.sublistView(data);
  for (int block = 0; block < fullBlocks; block++) {
    _compress(h, w, view, block * 64);
  }
  // The tail: the remaining bytes, 0x80, zero padding and the bit length.
  final int rest = data.length - fullBlocks * 64;
  final int tailLength = rest + 9 <= 64 ? 64 : 128;
  final Uint8List tail = Uint8List(tailLength)
    ..setRange(0, rest, data, fullBlocks * 64);
  tail[rest] = 0x80;
  final ByteData tailView = ByteData.sublistView(tail);
  final int bits = data.length * 8;
  tailView
    ..setUint32(tailLength - 8, (bits ~/ 0x100000000) & _mask)
    ..setUint32(tailLength - 4, bits & _mask);
  for (int offset = 0; offset < tailLength; offset += 64) {
    _compress(h, w, tailView, offset);
  }
  final StringBuffer out = StringBuffer();
  for (final int word in h) {
    out.write(word.toRadixString(16).padLeft(8, '0'));
  }
  return out.toString();
}

const int _mask = 0xFFFFFFFF;

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

void _compress(Uint32List h, Uint32List w, ByteData data, int offset) {
  for (int t = 0; t < 16; t++) {
    w[t] = data.getUint32(offset + t * 4);
  }
  for (int t = 16; t < 64; t++) {
    final int x = w[t - 15];
    final int y = w[t - 2];
    final int s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
    final int s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
    w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _mask;
  }
  int a = h[0];
  int b = h[1];
  int c = h[2];
  int d = h[3];
  int e = h[4];
  int f = h[5];
  int g = h[6];
  int hh = h[7];
  for (int t = 0; t < 64; t++) {
    final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
    final int ch = (e & f) ^ ((~e) & _mask & g);
    final int t1 = (hh + s1 + ch + _k[t] + w[t]) & _mask;
    final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
    final int maj = (a & b) ^ (a & c) ^ (b & c);
    final int t2 = (s0 + maj) & _mask;
    hh = g;
    g = f;
    f = e;
    e = (d + t1) & _mask;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mask;
  }
  h[0] = (h[0] + a) & _mask;
  h[1] = (h[1] + b) & _mask;
  h[2] = (h[2] + c) & _mask;
  h[3] = (h[3] + d) & _mask;
  h[4] = (h[4] + e) & _mask;
  h[5] = (h[5] + f) & _mask;
  h[6] = (h[6] + g) & _mask;
  h[7] = (h[7] + hh) & _mask;
}

const List<int> _initial = <int>[
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19,
];

const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];
