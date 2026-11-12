import { createHmac } from 'node:crypto';

/** RFC 6238 TOTP (SHA-1, 6 digits, 30 s), matching the API's authenticator setup. */
function base32Decode(input: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const char of input.replace(/[\s=]/g, '').toUpperCase()) {
    const value = alphabet.indexOf(char);
    if (value >= 0) bits += value.toString(2).padStart(5, '0');
  }
  const bytes: number[] = [];
  for (let index = 0; index + 8 <= bits.length; index += 8)
    bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
  return Buffer.from(bytes);
}

export function totp(secret: string, time = Date.now()): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(time / 30_000)));
  const digest = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const offset = (digest[digest.length - 1] ?? 0) & 0x0f;
  return ((digest.readUInt32BE(offset) & 0x7fffffff) % 1_000_000).toString().padStart(6, '0');
}

/** Codes are single use, so wait until the authenticator would show a new one. */
export async function waitForNextTotpStep(): Promise<void> {
  const wait = 30_000 - (Date.now() % 30_000) + 750;
  await new Promise((resolve) => setTimeout(resolve, wait));
}
