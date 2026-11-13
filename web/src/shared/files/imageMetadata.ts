/**
 * Lossless metadata removal for photos (COST-001, privacy): drops Exif
 * (including GPS location), XMP, IPTC and comments from JPEG files, and
 * text, time and Exif chunks from PNG files, without re-encoding the
 * picture. A JPEG keeps its orientation in a minimal Exif block, so it
 * still displays the right way up. Anything unexpected returns null and
 * the caller keeps the original bytes.
 */

const EXIF_HEADER = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
const ORIENTATION_TAG = 0x0112;

function startsWith(bytes: Uint8Array, offset: number, prefix: readonly number[]): boolean {
  return prefix.every((value, index) => bytes[offset + index] === value);
}

export function isJpeg(bytes: Uint8Array): boolean {
  return bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
}

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

export function isPng(bytes: Uint8Array): boolean {
  return bytes.length > 8 && startsWith(bytes, 0, PNG_SIGNATURE);
}

/** The Exif orientation (1–8) in an APP1 Exif payload, or null. */
function exifOrientation(bytes: Uint8Array, start: number, end: number): number | null {
  const tiff = start + EXIF_HEADER.length;
  if (tiff + 8 > end) return null;
  const little = bytes[tiff] === 0x49 && bytes[tiff + 1] === 0x49;
  const big = bytes[tiff] === 0x4d && bytes[tiff + 1] === 0x4d;
  if (!little && !big) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const u16 = (at: number) => view.getUint16(at, little);
  const u32 = (at: number) => view.getUint32(at, little);
  const ifd = tiff + u32(tiff + 4);
  if (ifd + 2 > end) return null;
  const count = u16(ifd);
  for (let index = 0; index < count; index += 1) {
    const entry = ifd + 2 + index * 12;
    if (entry + 12 > end) return null;
    if (u16(entry) === ORIENTATION_TAG) {
      const value = u16(entry + 8);
      return value >= 1 && value <= 8 ? value : null;
    }
  }
  return null;
}

/** APP1 Exif segment holding only the orientation (big-endian TIFF, one IFD entry). */
function orientationSegment(orientation: number): number[] {
  const payload = [
    ...EXIF_HEADER,
    0x4d,
    0x4d,
    0x00,
    0x2a,
    0x00,
    0x00,
    0x00,
    0x08, // TIFF header, IFD0 at 8
    0x00,
    0x01, // one entry
    0x01,
    0x12,
    0x00,
    0x03,
    0x00,
    0x00,
    0x00,
    0x01, // orientation, SHORT, count 1
    0x00,
    orientation,
    0x00,
    0x00, // value
    0x00,
    0x00,
    0x00,
    0x00, // no next IFD
  ];
  const length = payload.length + 2;
  return [0xff, 0xe1, length >> 8, length & 0xff, ...payload];
}

/** Segments kept: JFIF (APP0), ICC colour profile (APP2) and Adobe colour transform (APP14). */
const KEPT_APP_MARKERS = new Set([0xe0, 0xe2, 0xee]);

export interface StrippedJpeg {
  bytes: Uint8Array;
  /** Orientation found in the original Exif (1 when there was none). */
  orientation: number;
  /** Whether any metadata segment was removed. */
  removed: boolean;
}

/** Removes JPEG metadata segments, keeping the image data and the orientation. */
export function stripJpegMetadata(bytes: Uint8Array): StrippedJpeg | null {
  if (!isJpeg(bytes)) return null;
  const out: number[] = [0xff, 0xd8];
  let orientation = 1;
  let removed = false;
  let offset = 2;
  let insertAt = 2; // the orientation block goes after SOI, or after a leading JFIF segment
  while (offset < bytes.length) {
    if (bytes[offset] !== 0xff) return null;
    let marker = bytes[offset + 1] ?? 0;
    while (marker === 0xff) {
      offset += 1; // fill bytes
      marker = bytes[offset + 1] ?? 0;
    }
    if (marker === 0xd9) return null; // EOI before any scan: malformed
    if ((marker >= 0xd0 && marker <= 0xd7) || marker === 0x01) {
      out.push(0xff, marker);
      offset += 2;
      continue;
    }
    if (offset + 4 > bytes.length) return null;
    const length = ((bytes[offset + 2] ?? 0) << 8) | (bytes[offset + 3] ?? 0);
    const end = offset + 2 + length;
    if (length < 2 || end > bytes.length) return null;
    if (marker === 0xda) {
      // Start of scan: everything from here (entropy-coded data, later
      // markers, EOI) is the picture and is kept as it is.
      const extra = orientation !== 1 ? orientationSegment(orientation) : [];
      const head = [...out.slice(0, insertAt), ...extra, ...out.slice(insertAt)];
      const result = new Uint8Array(head.length + bytes.length - offset);
      result.set(head, 0);
      result.set(bytes.subarray(offset), head.length);
      return { bytes: result, orientation, removed };
    }
    const isApp = marker >= 0xe0 && marker <= 0xef;
    if (marker === 0xfe || (isApp && !KEPT_APP_MARKERS.has(marker))) {
      if (marker === 0xe1 && startsWith(bytes, offset + 4, EXIF_HEADER)) {
        orientation = exifOrientation(bytes, offset + 4, end) ?? orientation;
      }
      removed = true;
    } else {
      const first = out.length === 2;
      for (let index = offset; index < end; index += 1) out.push(bytes[index] ?? 0);
      if (marker === 0xe0 && first) insertAt = out.length;
    }
    offset = end;
  }
  return null;
}

/** The orientation (1–8) recorded in a JPEG's Exif, 1 when absent. */
export function jpegOrientation(bytes: Uint8Array): number {
  return stripJpegMetadata(bytes)?.orientation ?? 1;
}

/** PNG chunks that carry text, time or Exif (which may include a location). */
const PNG_METADATA = new Set(['tEXt', 'zTXt', 'iTXt', 'tIME', 'eXIf']);

export interface StrippedPng {
  bytes: Uint8Array;
  /** The PNG had an eXIf chunk (which can carry an orientation). */
  hadExif: boolean;
  removed: boolean;
}

/** Removes PNG text, time and Exif chunks; the image chunks are kept byte for byte. */
export function stripPngMetadata(bytes: Uint8Array): StrippedPng | null {
  if (!isPng(bytes)) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const keep: Uint8Array[] = [bytes.subarray(0, 8)];
  let hadExif = false;
  let removed = false;
  let offset = 8;
  while (offset + 12 <= bytes.length) {
    const length = view.getUint32(offset);
    const end = offset + 12 + length;
    if (end > bytes.length) return null;
    const type = String.fromCharCode(...bytes.subarray(offset + 4, offset + 8));
    if (PNG_METADATA.has(type)) {
      if (type === 'eXIf') hadExif = true;
      removed = true;
    } else {
      keep.push(bytes.subarray(offset, end));
    }
    offset = end;
    if (type === 'IEND') break;
  }
  const size = keep.reduce((sum, chunk) => sum + chunk.length, 0);
  const result = new Uint8Array(size);
  let at = 0;
  for (const chunk of keep) {
    result.set(chunk, at);
    at += chunk.length;
  }
  return { bytes: result, hadExif, removed };
}
