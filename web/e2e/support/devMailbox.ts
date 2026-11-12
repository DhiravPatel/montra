import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Reads links from the Go API's development mailbox (EMAIL_PROVIDER=dev_mailbox
 * writes .eml files). Local development only; never used against hosted APIs.
 */
const MAILBOX =
  process.env.MONTRA_DEV_MAILBOX ??
  fileURLToPath(new URL('../../../backend/.data/mail/', import.meta.url));

function decodeQuotedPrintable(input: string): string {
  const joined = input.replace(/=\r?\n/g, '');
  const bytes: number[] = [];
  for (let index = 0; index < joined.length; index += 1) {
    const char = joined[index] ?? '';
    const hex = joined.slice(index + 1, index + 3);
    if (char === '=' && /^[0-9A-Fa-f]{2}$/.test(hex)) {
      bytes.push(Number.parseInt(hex, 16));
      index += 2;
    } else {
      bytes.push(char.charCodeAt(0));
    }
  }
  return Buffer.from(bytes).toString('utf8');
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Waits for the newest email to `to` containing a `<path>#token=` link and returns the link. */
export async function waitForEmailLink(
  to: string,
  path: '/verify-email' | '/reset-password',
  timeoutMs = 30_000,
): Promise<string> {
  const deadline = Date.now() + timeoutMs;
  const recipient = new RegExp(`^To: <?${escapeRegExp(to)}>?\\s*$`, 'mi');
  const link = new RegExp(`https?://[^\\s"'<>]+${escapeRegExp(path)}#token=[A-Za-z0-9_-]+`);
  while (Date.now() < deadline) {
    const files = readdirSync(MAILBOX)
      .filter((name) => name.endsWith('.eml'))
      .map((name) => join(MAILBOX, name))
      .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
    for (const file of files) {
      const raw = readFileSync(file, 'utf8');
      if (!recipient.test(raw)) continue;
      const match = link.exec(decodeQuotedPrintable(raw));
      if (match) return match[0];
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`No ${path} email for ${to} in ${MAILBOX}`);
}
