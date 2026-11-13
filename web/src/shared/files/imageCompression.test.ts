import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import {
  type DecodedImage,
  fitWithin,
  type ImageCodec,
  imageKind,
  prepareImage,
  REENCODE_ABOVE_BYTES,
} from './imageCompression';
import { jpegOrientation, stripJpegMetadata, stripPngMetadata } from './imageMetadata';
import { fileProblem } from './uploadChecks';
import { prepareForUpload, sha256Hex, uploadFile } from './upload';

// --- Byte fixtures -----------------------------------------------------------

function segment(marker: number, payload: number[]): number[] {
  const length = payload.length + 2;
  return [0xff, marker, length >> 8, length & 0xff, ...payload];
}

const ascii = (text: string) => Array.from(text, (char) => char.charCodeAt(0));

/** Exif with orientation and a GPS IFD pointer (little-endian TIFF). */
function exifWithGps(orientation: number): number[] {
  return segment(0xe1, [
    ...ascii('Exif'),
    0,
    0,
    0x49,
    0x49,
    0x2a,
    0x00,
    0x08,
    0x00,
    0x00,
    0x00, // II, 42, IFD0 at 8
    0x02,
    0x00, // two entries
    0x12,
    0x01,
    0x03,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    orientation,
    0x00,
    0x00,
    0x00,
    0x25,
    0x88,
    0x04,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x26,
    0x00,
    0x00,
    0x00, // GPS IFD at 38
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00, // GPS IFD: one entry (latitude ref "N")
    0x01,
    0x00,
    0x02,
    0x00,
    0x02,
    0x00,
    0x00,
    0x00,
    0x4e,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
}

const JFIF = segment(0xe0, [...ascii('JFIF'), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]);
const ICC = segment(0xe2, [...ascii('ICC_PROFILE'), 0, 1, 1, 9, 9]);
const XMP = segment(0xe1, [...ascii('http://ns.adobe.com/xap/1.0/'), 0, ...ascii('<x:xmpmeta/>')]);
const COMMENT = segment(0xfe, ascii('taken at home'));
const QUANT = segment(0xdb, [0, ...new Array<number>(64).fill(1)]);
const SCAN = [...segment(0xda, [1, 1, 0, 0, 63, 0]), 0x12, 0x34, 0xff, 0x00, 0x56, 0xff, 0xd9];

function jpeg(...segments: number[][]): Uint8Array<ArrayBuffer> {
  return new Uint8Array([0xff, 0xd8, ...segments.flat(), ...SCAN]);
}

function contains(bytes: Uint8Array, needle: number[]): boolean {
  outer: for (let index = 0; index + needle.length <= bytes.length; index += 1) {
    for (let offset = 0; offset < needle.length; offset += 1) {
      if (bytes[index + offset] !== needle[offset]) continue outer;
    }
    return true;
  }
  return false;
}

function pngChunk(type: string, data: number[]): number[] {
  const length = data.length;
  return [
    length >>> 24,
    (length >> 16) & 255,
    (length >> 8) & 255,
    length & 255,
    ...ascii(type),
    ...data,
    0,
    0,
    0,
    0,
  ];
}

const PNG = new Uint8Array([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  ...pngChunk('IHDR', [0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0]),
  ...pngChunk('tEXt', ascii('Comment\0secret')),
  ...pngChunk('eXIf', [0x4d, 0x4d, 0, 42]),
  ...pngChunk('IDAT', [1, 2, 3]),
  ...pngChunk('IEND', []),
]);

// --- Fake codec ----------------------------------------------------------------

interface FakeImage extends DecodedImage {
  closed: boolean;
}

function fakeCodec(width: number, height: number, outputBytes = 1000) {
  const calls: { width: number; height: number; type: string; quality: number }[] = [];
  const images: FakeImage[] = [];
  const codec: ImageCodec<FakeImage> = {
    decode: () => {
      const image: FakeImage = {
        width,
        height,
        closed: false,
        close() {
          image.closed = true;
        },
      };
      images.push(image);
      return Promise.resolve(image);
    },
    encode: (_image, w, h, type, quality) => {
      calls.push({ width: w, height: h, type, quality });
      return Promise.resolve(new Blob([new Uint8Array(outputBytes).fill(7)], { type }));
    },
  };
  return { codec, calls, images };
}

const failingCodec: ImageCodec = {
  decode: () => Promise.reject(new Error('cannot decode')),
  encode: () => Promise.resolve(null),
};

// --- Tests -----------------------------------------------------------------------

describe('JPEG metadata', () => {
  it('drops Exif (with GPS), XMP and comments, keeps JFIF, the colour profile and the picture', () => {
    const original = jpeg(JFIF, exifWithGps(6), XMP, COMMENT, ICC, QUANT);
    const stripped = stripJpegMetadata(original)!;
    expect(stripped.removed).toBe(true);
    expect(stripped.orientation).toBe(6);
    const out = stripped.bytes;
    expect(contains(out, [0x25, 0x88])).toBe(false); // GPS pointer tag
    expect(contains(out, ascii('xmpmeta'))).toBe(false);
    expect(contains(out, ascii('taken at home'))).toBe(false);
    expect(contains(out, ascii('JFIF'))).toBe(true);
    expect(contains(out, ascii('ICC_PROFILE'))).toBe(true);
    expect(contains(out, SCAN)).toBe(true);
    // Orientation survives in a minimal Exif block placed after JFIF.
    expect(jpegOrientation(out)).toBe(6);
    expect(out.indexOf(0xe1)).toBeGreaterThan(out.indexOf(0xe0));
    expect(Array.from(out.slice(-2))).toEqual([0xff, 0xd9]);
  });

  it('adds no Exif block when the photo is already upright', () => {
    const stripped = stripJpegMetadata(jpeg(exifWithGps(1), QUANT))!;
    expect(contains(stripped.bytes, ascii('Exif'))).toBe(false);
    expect(stripped.bytes).toEqual(jpeg(QUANT));
  });

  it('returns null for something that is not a JPEG or is cut short', () => {
    expect(stripJpegMetadata(new Uint8Array([1, 2, 3]))).toBeNull();
    expect(stripJpegMetadata(jpeg(QUANT).slice(0, 10))).toBeNull();
  });
});

describe('PNG metadata', () => {
  it('drops text and Exif chunks and keeps the image chunks', () => {
    const stripped = stripPngMetadata(PNG)!;
    expect(stripped.removed).toBe(true);
    expect(stripped.hadExif).toBe(true);
    expect(contains(stripped.bytes, ascii('secret'))).toBe(false);
    expect(contains(stripped.bytes, ascii('eXIf'))).toBe(false);
    expect(contains(stripped.bytes, ascii('IDAT'))).toBe(true);
    expect(contains(stripped.bytes, ascii('IEND'))).toBe(true);
  });
});

describe('photo preparation', () => {
  it('fits the long edge within 2048 px and never upscales', () => {
    expect(fitWithin(4032, 3024)).toEqual({ width: 2048, height: 1536 });
    expect(fitWithin(3000, 6000)).toEqual({ width: 1024, height: 2048 });
    expect(fitWithin(800, 600)).toEqual({ width: 800, height: 600 });
    expect(fitWithin(2048, 10)).toEqual({ width: 2048, height: 10 });
  });

  it('knows photos from documents', () => {
    expect(imageKind({ name: 'a.JPG', type: '' })).toBe('jpeg');
    expect(imageKind({ name: 'scan', type: 'image/heic' })).toBe('heic');
    expect(imageKind({ name: 'bill.pdf', type: 'application/pdf' })).toBeNull();
    expect(imageKind({ name: 'photo.jpg', type: 'application/pdf' })).toBeNull();
    expect(imageKind({ name: 'rows.csv', type: 'text/csv' })).toBeNull();
  });

  it('never touches a PDF', async () => {
    const pdf = new File(['%PDF-1.7 big'], 'bill.pdf', { type: 'application/pdf' });
    const { codec, calls } = fakeCodec(5000, 5000);
    expect(await prepareForUpload(pdf, 'receipt', codec)).toBe(pdf);
    expect(calls).toEqual([]);
  });

  it('scales a large photo to 2048 px as a JPEG at quality 0.85 and releases the decoded image', async () => {
    const photo = new File([jpeg(exifWithGps(6), QUANT)], 'IMG_1.HEIC', { type: 'image/heic' });
    const { codec, calls, images } = fakeCodec(4032, 3024);
    const result = await prepareImage(photo, codec, { allowJpegOutput: true });
    expect(result.how).toBe('resized');
    expect(calls).toEqual([{ width: 2048, height: 1536, type: 'image/jpeg', quality: 0.85 }]);
    expect(result.file.name).toBe('IMG_1.jpg');
    expect(result.file.type).toBe('image/jpeg');
    expect(images.every((image) => image.closed)).toBe(true);
  });

  it('keeps a small JPEG’s pixels and only removes its metadata', async () => {
    const photo = new File([jpeg(JFIF, exifWithGps(3), QUANT)], 'lunch.jpg', {
      type: 'image/jpeg',
    });
    const { codec, calls } = fakeCodec(1200, 900);
    const result = await prepareImage(photo, codec, { allowJpegOutput: true });
    expect(calls).toEqual([]);
    expect(result.how).toBe('stripped');
    const bytes = new Uint8Array(await result.file.arrayBuffer());
    expect(contains(bytes, [0x25, 0x88])).toBe(false);
    expect(jpegOrientation(bytes)).toBe(3);
  });

  it('re-encodes a heavy small JPEG only when that makes it smaller', async () => {
    const heavy = new Uint8Array(REENCODE_ABOVE_BYTES + 10);
    heavy.set(jpeg(QUANT));
    const photo = new File([heavy], 'scan.jpg', { type: 'image/jpeg' });
    const smaller = await prepareImage(photo, fakeCodec(1500, 1500, 500_000).codec, {
      allowJpegOutput: true,
    });
    expect(smaller.how).toBe('reencoded');
    expect(smaller.file.size).toBe(500_000);
    const larger = await prepareImage(photo, fakeCodec(1500, 1500, heavy.length + 1).codec, {
      allowJpegOutput: true,
    });
    expect(larger.file.size).toBe(heavy.length);
  });

  it('still strips metadata when the browser cannot decode the photo', async () => {
    const photo = new File([jpeg(exifWithGps(1), QUANT)], 'x.jpg', { type: 'image/jpeg' });
    const result = await prepareImage(photo, failingCodec, { allowJpegOutput: true });
    expect(result.how).toBe('stripped');
    const unreadable = new File(['not a picture'], 'x.webp', { type: 'image/webp' });
    expect((await prepareImage(unreadable, null, { allowJpegOutput: true })).file).toBe(unreadable);
  });

  it('accepts photos larger than the upload limit before preparing them, but not documents', () => {
    const bigPhoto = new File([new Uint8Array(20 * 1024 * 1024)], 'big.jpg', {
      type: 'image/jpeg',
    });
    const bigPdf = new File([new Uint8Array(20 * 1024 * 1024)], 'big.pdf', {
      type: 'application/pdf',
    });
    expect(fileProblem(bigPhoto, 'receipt')).toBeNull();
    expect(fileProblem(bigPdf, 'receipt')).toBe('tooLarge');
  });
});

describe('uploadFile with a photo', () => {
  it('sends the size and checksum of the prepared bytes, and exactly those bytes', async () => {
    const FILE_ID = '5b1f8a52-7d2e-4c2a-9f4a-1d1e2f3a4b5c';
    const original = new File([jpeg(exifWithGps(6), QUANT), new Uint8Array(4000)], 'big.jpg', {
      type: 'image/jpeg',
    });
    const { codec } = fakeCodec(4000, 3000, 1234);
    const prepared = await prepareForUpload(original, 'receipt', fakeCodec(4000, 3000, 1234).codec);
    const expectedChecksum = await sha256Hex(prepared);
    let intent: Record<string, unknown> = {};
    let put = { checksum: '', size: 0, body: '' };
    const record = {
      id: FILE_ID,
      purpose: 'receipt',
      status: 'ready',
      original_filename: 'big.jpg',
      created_at: '2026-11-13T08:00:00Z',
    };
    server.use(
      http.post(`${API}/files/upload-intent`, async ({ request }) => {
        intent = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(
          envelope({
            file: { ...record, status: 'pending_upload' },
            upload_url: `http://localhost:8080/api/v1/files/${FILE_ID}/content`,
            method: 'PUT',
            headers: { 'X-Upload-Token': 'tok' },
            expires_at: '2026-11-13T08:15:00Z',
            max_bytes: 15728640,
          }),
          { status: 201 },
        );
      }),
      http.put(`${API}/files/${FILE_ID}/content`, async ({ request }) => {
        const body = new Uint8Array(await request.arrayBuffer());
        put = {
          checksum: request.headers.get('X-Upload-Checksum') ?? '',
          size: body.byteLength,
          body: await sha256Hex(new Blob([body])),
        };
        return HttpResponse.json(envelope({ ...record, status: 'uploaded' }));
      }),
      http.post(`${API}/files/${FILE_ID}/complete`, () => HttpResponse.json(envelope(record))),
    );
    await uploadFile(original, { purpose: 'receipt', codec });
    expect(intent).toMatchObject({
      purpose: 'receipt',
      filename: 'big.jpg',
      content_type: 'image/jpeg',
      size_bytes: 1234,
      checksum_sha256: expectedChecksum,
    });
    expect(put).toEqual({ checksum: expectedChecksum, size: 1234, body: expectedChecksum });
    expect(original.size).not.toBe(1234);
  });
});
