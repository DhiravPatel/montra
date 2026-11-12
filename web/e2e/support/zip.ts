import { inflateRawSync } from 'node:zlib';

/**
 * Reads a ZIP archive's entries (stored or deflated) from its central
 * directory, enough to check what a data export contains. Test helper only.
 */
export function readZip(archive: Buffer): Map<string, Buffer> {
  const entries = new Map<string, Buffer>();
  const endOfDirectory = archive.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (endOfDirectory < 0) throw new Error('Not a ZIP archive');
  const count = archive.readUInt16LE(endOfDirectory + 10);
  let offset = archive.readUInt32LE(endOfDirectory + 16);
  for (let index = 0; index < count; index += 1) {
    if (archive.readUInt32LE(offset) !== 0x02014b50) throw new Error('Bad ZIP directory');
    const method = archive.readUInt16LE(offset + 10);
    const compressedSize = archive.readUInt32LE(offset + 20);
    const nameLength = archive.readUInt16LE(offset + 28);
    const extraLength = archive.readUInt16LE(offset + 30);
    const commentLength = archive.readUInt16LE(offset + 32);
    const localHeader = archive.readUInt32LE(offset + 42);
    const name = archive.toString('utf8', offset + 46, offset + 46 + nameLength);
    const localNameLength = archive.readUInt16LE(localHeader + 26);
    const localExtraLength = archive.readUInt16LE(localHeader + 28);
    const start = localHeader + 30 + localNameLength + localExtraLength;
    const data = archive.subarray(start, start + compressedSize);
    entries.set(name, method === 8 ? inflateRawSync(data) : Buffer.from(data));
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}
