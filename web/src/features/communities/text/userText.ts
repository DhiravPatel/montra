/**
 * Community text is plain text written by people (spec §20B.17). It is
 * never rendered as HTML: the renderer only turns http(s) addresses into
 * links and marks @mentions, and everything else stays text that React
 * escapes.
 */

export type UserTextToken =
  | { kind: 'text'; text: string }
  | { kind: 'link'; text: string; href: string }
  | { kind: 'mention'; text: string; username: string };

/** http(s) addresses up to the next space or quote-like character. */
const URL_PATTERN = /\bhttps?:\/\/[^\s<>"'`]+/giu;
/** Punctuation that ends a sentence rather than an address. */
const TRAILING_PUNCTUATION = new Set(['.', ',', ';', ':', '!', '?', "'", '"', '’', '”', '…']);
const CLOSERS: Readonly<Record<string, string>> = { ')': '(', ']': '[', '}': '{' };
/**
 * @username mentions, as the API finds them (usernames are 3-30 of
 * letters, digits, _ and .); an @ inside a word or an e-mail is not one.
 */
const MENTION_PATTERN = /(^|[^A-Za-z0-9_.@])@([A-Za-z0-9_.]{3,30})/gu;

function count(text: string, char: string): number {
  let total = 0;
  for (const c of text) if (c === char) total += 1;
  return total;
}

/** Drops sentence punctuation and unbalanced closing brackets from the end of an address. */
function trimAddress(candidate: string): string {
  let address = candidate;
  for (;;) {
    const last = address.at(-1);
    if (last === undefined) return address;
    const opener = CLOSERS[last];
    if (TRAILING_PUNCTUATION.has(last)) {
      address = address.slice(0, -1);
    } else if (opener !== undefined && count(address, opener) < count(address, last)) {
      address = address.slice(0, -1);
    } else {
      return address;
    }
  }
}

/**
 * The address to link to, or null when it must stay text: only absolute
 * http(s) URLs with a host and without embedded credentials
 * (`https://bank.example@evil.example` tricks readers).
 */
export function safeHref(text: string): string | null {
  let url: URL;
  try {
    url = new URL(text);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
  if (!url.hostname || url.username || url.password) return null;
  return url.href;
}

function pushText(tokens: UserTextToken[], text: string) {
  if (!text) return;
  const last = tokens.at(-1);
  if (last?.kind === 'text') {
    tokens[tokens.length - 1] = { kind: 'text', text: last.text + text };
  } else {
    tokens.push({ kind: 'text', text });
  }
}

function addMentions(tokens: UserTextToken[], text: string) {
  let index = 0;
  for (const match of text.matchAll(MENTION_PATTERN)) {
    const before = match[1] ?? '';
    const raw = match[2] ?? '';
    const username = raw.replace(/\.+$/u, '');
    if (username.length < 3) continue;
    const start = match.index + before.length;
    pushText(tokens, text.slice(index, start));
    tokens.push({ kind: 'mention', text: `@${username}`, username });
    index = start + 1 + username.length;
  }
  pushText(tokens, text.slice(index));
}

/**
 * Splits text into plain text, safe links and mentions. With
 * `links: false` (feed excerpts, report previews) addresses stay text.
 */
export function tokenizeUserText(
  text: string,
  { links = true }: { links?: boolean } = {},
): UserTextToken[] {
  const tokens: UserTextToken[] = [];
  let index = 0;
  if (links) {
    for (const match of text.matchAll(URL_PATTERN)) {
      const address = trimAddress(match[0]);
      const href = safeHref(address);
      if (!href) continue;
      addMentions(tokens, text.slice(index, match.index));
      tokens.push({ kind: 'link', text: address, href });
      index = match.index + address.length;
    }
  }
  addMentions(tokens, text.slice(index));
  return tokens;
}

/** Paragraphs separated by blank lines (single line breaks stay inside a paragraph). */
export function paragraphs(text: string): string[] {
  return text
    .split(/\n\s*\n/u)
    .map((part) => part.trim())
    .filter(Boolean);
}

/** The start of a text, cut at a word boundary, with an ellipsis when shortened. */
export function excerpt(text: string, maxChars = 280): string {
  const chars = Array.from(text.trim());
  if (chars.length <= maxChars) return chars.join('');
  const cut = chars.slice(0, maxChars).join('');
  const space = cut.search(/\s\S*$/u);
  return `${(space > maxChars / 2 ? cut.slice(0, space) : cut).trimEnd()}…`;
}

/** http(s) addresses in a text (the API allows at most 3 per post or comment). */
export function countLinks(text: string): number {
  return text.match(/\bhttps?:\/\//giu)?.length ?? 0;
}

const DIGIT_RUN = /(?:\d[ -]?){13,19}/gu;
const SECRET_WORDS =
  /\b(?:cvv2?|cvc|upi\s*pin|atm\s*pin|mpin|pin|otp|one[- ]time\s+(?:password|code))\b\s*(?:is|:|=|-)?\s*\d{3,8}\b|\b(?:net\s*banking\s+)?password\s*[:=]\s*\S{4,}/iu;

function luhn(digits: string): boolean {
  if (digits.length < 13 || digits.length > 19 || !/^\d+$/u.test(digits)) return false;
  let sum = 0;
  let double = false;
  for (let i = digits.length - 1; i >= 0; i -= 1) {
    let n = Number(digits[i]);
    if (double) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    double = !double;
  }
  return sum % 10 === 0;
}

/**
 * Whether text looks like it contains a card number, CVV, PIN, OTP or
 * password (the same checks the API applies), so people are warned before
 * sending it. The API refuses such text anyway.
 */
export function looksSecret(text: string): boolean {
  if (SECRET_WORDS.test(text)) return true;
  for (const run of text.match(DIGIT_RUN) ?? []) {
    if (luhn(run.trim().replace(/[ -]/gu, ''))) return true;
  }
  return false;
}
