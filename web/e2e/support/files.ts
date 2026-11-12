/**
 * Small synthetic files for upload journeys, built in memory and handed to
 * `setInputFiles` as buffers (nothing is written to disk, nothing real).
 */
export interface UploadPayload {
  name: string;
  mimeType: string;
  buffer: Buffer;
}

/** A CSV statement from header + rows (CRLF line endings, as banks export). */
export function csvFile(name: string, rows: readonly (readonly string[])[]): UploadPayload {
  const text = rows
    .map((row) =>
      row
        .map((cell) => (/[",\r\n]/.test(cell) ? `"${cell.replaceAll('"', '""')}"` : cell))
        .join(','),
    )
    .join('\r\n');
  return { name, mimeType: 'text/csv', buffer: Buffer.from(`${text}\r\n`, 'utf8') };
}

/** Any bytes under a chosen name and type (for malformed or mislabelled files). */
export function rawFile(name: string, mimeType: string, content: string | Buffer): UploadPayload {
  return {
    name,
    mimeType,
    buffer: typeof content === 'string' ? Buffer.from(content, 'utf8') : content,
  };
}

/**
 * A valid 8×8 PNG (solid light grey) with a unique tEXt chunk, so every call
 * yields different bytes and the server never treats two receipts as the
 * same file.
 */
export function receiptPng(name: string, label = `${Date.now()}-${Math.random()}`): UploadPayload {
  return { name, mimeType: 'image/png', buffer: tinyPng(label) };
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(bytes: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = (CRC_TABLE[(crc ^ byte) & 0xff] ?? 0) ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Buffer): Buffer {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
}

/** Uncompressed (stored) zlib stream, enough for a tiny image. */
function zlibStored(data: Buffer): Buffer {
  let a = 1;
  let b = 0;
  for (const byte of data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  const header = Buffer.from([0x78, 0x01, 0x01, data.length & 0xff, (data.length >> 8) & 0xff]);
  const nlen = ~data.length & 0xffff;
  const adler = Buffer.alloc(4);
  adler.writeUInt32BE(((b << 16) | a) >>> 0);
  return Buffer.concat([header, Buffer.from([nlen & 0xff, (nlen >> 8) & 0xff]), data, adler]);
}

function tinyPng(label: string): Buffer {
  const size = 8;
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 0; // greyscale
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  // Each scanline: filter byte 0, then 8 grey pixels.
  const raw = Buffer.alloc(size * (size + 1), 0xe0);
  for (let row = 0; row < size; row += 1) raw[row * (size + 1)] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('tEXt', Buffer.from(`Comment\0${label}`, 'latin1')),
    chunk('IDAT', zlibStored(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
