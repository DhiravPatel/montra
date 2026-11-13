import { isJpeg, isPng, stripJpegMetadata, stripPngMetadata } from './imageMetadata';

/**
 * Photo preparation before upload (COST-001). Large photos are scaled down
 * to at most 2048 px on the long edge (never up) and saved as JPEG at
 * quality 0.85; their orientation is applied while decoding and every
 * metadata field (including the GPS location) is left behind. Photos that
 * are already small keep their pixels and only lose their metadata. PDFs and
 * other documents are never touched. Uses the browser's own decoder and
 * canvas (createImageBitmap, OffscreenCanvas): no extra dependency.
 */

export const IMAGE_MAX_EDGE = 2048;
export const JPEG_QUALITY = 0.85;
/** A JPEG within the size limit is re-encoded only above this many bytes (and only if that helps). */
export const REENCODE_ABOVE_BYTES = 1.5 * 1024 * 1024;
/** Photos up to this size are accepted before preparing (they usually shrink well below the limit). */
export const MAX_IMAGE_INPUT_BYTES = 50 * 1024 * 1024;

export type ImageKind = 'jpeg' | 'png' | 'webp' | 'heic';

export interface DecodedImage {
  width: number;
  height: number;
  close?: () => void;
}

/** Decoding and encoding, injectable for tests (jsdom has no image codecs). */
export interface ImageCodec<Image extends DecodedImage = DecodedImage> {
  /** Decodes with the Exif orientation applied. */
  decode(blob: Blob): Promise<Image>;
  /** Draws the image at width × height and encodes it (`type` must be honoured or null returned). */
  encode(
    image: Image,
    width: number,
    height: number,
    type: 'image/jpeg' | 'image/png',
    quality: number,
  ): Promise<Blob | null>;
}

const EXTENSIONS: Readonly<Record<string, ImageKind>> = {
  jpg: 'jpeg',
  jpeg: 'jpeg',
  png: 'png',
  webp: 'webp',
  heic: 'heic',
  heif: 'heic',
};

const TYPES: Readonly<Record<string, ImageKind>> = {
  'image/jpeg': 'jpeg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
  'image/heif': 'heic',
};

/** Which kind of photo a file is (by type, then extension); null for PDFs and everything else. */
export function imageKind(file: Pick<File, 'name' | 'type'>): ImageKind | null {
  const byType = TYPES[file.type.toLowerCase()];
  if (byType) return byType;
  if (file.type && !file.type.startsWith('image/') && file.type !== 'application/octet-stream') {
    return null;
  }
  const dot = file.name.lastIndexOf('.');
  return dot >= 0 ? (EXTENSIONS[file.name.slice(dot + 1).toLowerCase()] ?? null) : null;
}

/** Dimensions that fit within `max` on the long edge, keeping the aspect ratio; never larger. */
export function fitWithin(
  width: number,
  height: number,
  max: number = IMAGE_MAX_EDGE,
): { width: number; height: number } {
  const longEdge = Math.max(width, height);
  if (longEdge <= max) return { width, height };
  const scale = max / longEdge;
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

function renamed(name: string, extension: string): string {
  const base = name.replace(/\.[^./\\]*$/, '') || 'photo';
  return `${base}.${extension}`;
}

async function bytesOf(blob: Blob): Promise<Uint8Array> {
  return new Uint8Array(await blob.arrayBuffer());
}

/** The file without its metadata (same pixels), or the original when there is none to remove. */
async function stripOnly(file: File, kind: ImageKind): Promise<File> {
  const bytes = await bytesOf(file);
  if (kind === 'jpeg' && isJpeg(bytes)) {
    const stripped = stripJpegMetadata(bytes);
    if (stripped?.removed) {
      return new File([stripped.bytes as Uint8Array<ArrayBuffer>], file.name, {
        type: 'image/jpeg',
      });
    }
  }
  if (kind === 'png' && isPng(bytes)) {
    const stripped = stripPngMetadata(bytes);
    if (stripped?.removed) {
      return new File([stripped.bytes as Uint8Array<ArrayBuffer>], file.name, {
        type: 'image/png',
      });
    }
  }
  return file;
}

/** What preparing did to a photo (for tests and diagnostics). */
export type PreparedHow = 'unchanged' | 'stripped' | 'resized' | 'reencoded';

export interface PreparedFile {
  file: File;
  how: PreparedHow;
}

/**
 * Prepares one file for upload. Documents are returned as they are. Photos
 * are decoded (orientation applied) and, when needed, redrawn smaller and
 * saved as JPEG; when the browser cannot decode them (HEIC outside Safari,
 * for example), JPEG and PNG still lose their metadata losslessly and other
 * kinds are sent as picked (the server checks them as usual).
 */
export async function prepareImage<Image extends DecodedImage>(
  file: File,
  codec: ImageCodec<Image> | null,
  { allowJpegOutput }: { allowJpegOutput: boolean },
): Promise<PreparedFile> {
  const kind = imageKind(file);
  if (!kind) return { file, how: 'unchanged' };
  // Undecodable (HEIC outside Safari, a damaged file): fall back to the lossless path.
  const image = codec ? await codec.decode(file).catch(() => null) : null;
  try {
    if (image && image.width > 0 && image.height > 0) {
      const target = fitWithin(image.width, image.height);
      const shrink = target.width < image.width || target.height < image.height;
      const pngExif = kind === 'png' && Boolean(stripPngMetadata(await bytesOf(file))?.hadExif);
      const convert = kind === 'webp' || kind === 'heic';
      const heavyJpeg = kind === 'jpeg' && file.size > REENCODE_ABOVE_BYTES;
      // A PNG with Exif may carry an orientation: redraw it (still PNG) to keep it upright.
      const type = !shrink && kind === 'png' ? 'image/png' : 'image/jpeg';
      if (
        (shrink || convert || heavyJpeg || pngExif) &&
        (type === 'image/png' || allowJpegOutput)
      ) {
        const blob = await codec?.encode(image, target.width, target.height, type, JPEG_QUALITY);
        // Keep the new file when it is a real improvement: smaller, or the only way to
        // shrink the dimensions, convert the format or keep a PNG upright.
        if (blob?.type === type && (blob.size < file.size || shrink || convert || pngExif)) {
          const name = type === 'image/jpeg' ? renamed(file.name, 'jpg') : file.name;
          return {
            file: new File([blob], name, { type }),
            how: shrink ? 'resized' : 'reencoded',
          };
        }
      }
    }
  } finally {
    image?.close?.();
  }
  const stripped = await stripOnly(file, kind);
  return { file: stripped, how: stripped === file ? 'unchanged' : 'stripped' };
}

/** The browser's decoder and canvas, or null where they are missing (old browsers, tests). */
export function browserImageCodec(): ImageCodec<ImageBitmap> | null {
  if (typeof createImageBitmap !== 'function') return null;
  return {
    decode: (blob) => createImageBitmap(blob, { imageOrientation: 'from-image' }),
    encode: async (image, width, height, type, quality) => {
      const draw = (context: OffscreenCanvasRenderingContext2D | CanvasRenderingContext2D) => {
        if (type === 'image/jpeg') {
          // JPEG has no transparency: transparent areas become white, not black.
          context.fillStyle = '#ffffff';
          context.fillRect(0, 0, width, height);
        }
        context.imageSmoothingEnabled = true;
        context.imageSmoothingQuality = 'high';
        context.drawImage(image, 0, 0, width, height);
      };
      if (typeof OffscreenCanvas !== 'undefined') {
        const canvas = new OffscreenCanvas(width, height);
        const context = canvas.getContext('2d');
        if (!context) return null;
        draw(context);
        return canvas.convertToBlob({ type, quality });
      }
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext('2d');
      if (!context) return null;
      draw(context);
      return new Promise<Blob | null>((resolve) => {
        canvas.toBlob(resolve, type, quality);
      });
    },
  };
}
