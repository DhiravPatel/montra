import { describe, expect, it } from 'vitest';
import {
  countLinks,
  excerpt,
  looksSecret,
  paragraphs,
  safeHref,
  tokenizeUserText,
} from './userText';

describe('tokenizeUserText', () => {
  it('keeps plain text as text', () => {
    expect(tokenizeUserText('Paid off <b>my</b> loan <script>alert(1)</script>')).toEqual([
      { kind: 'text', text: 'Paid off <b>my</b> loan <script>alert(1)</script>' },
    ]);
  });

  it('links http and https addresses without trailing punctuation', () => {
    expect(
      tokenizeUserText('See https://rbi.org.in/faq. Also http://example.com/a?b=1, ok'),
    ).toEqual([
      { kind: 'text', text: 'See ' },
      { kind: 'link', text: 'https://rbi.org.in/faq', href: 'https://rbi.org.in/faq' },
      { kind: 'text', text: '. Also ' },
      { kind: 'link', text: 'http://example.com/a?b=1', href: 'http://example.com/a?b=1' },
      { kind: 'text', text: ', ok' },
    ]);
  });

  it('keeps balanced brackets in addresses and drops an unbalanced closing one', () => {
    const tokens = tokenizeUserText(
      '(read https://en.wikipedia.org/wiki/Debt_(finance)) and (https://example.com)',
    );
    expect(tokens.filter((token) => token.kind === 'link').map((token) => token.text)).toEqual([
      'https://en.wikipedia.org/wiki/Debt_(finance)',
      'https://example.com',
    ]);
  });

  it('never links other schemes or addresses with credentials', () => {
    for (const text of [
      'javascript:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'ftp://files.example.com',
      'https://bank.example@evil.example/login',
    ]) {
      expect(tokenizeUserText(text).every((token) => token.kind !== 'link')).toBe(true);
    }
    expect(safeHref('https://user:pass@example.com')).toBeNull();
    expect(safeHref('javascript:alert(1)')).toBeNull();
    expect(safeHref('https://example.com/a b')).toBe('https://example.com/a%20b');
  });

  it('marks @mentions like the API (not e-mails, short names or trailing dots)', () => {
    expect(
      tokenizeUserText('Thanks @Asha_K and @ravi.m! Mail me at someone@example.com, @ab'),
    ).toEqual([
      { kind: 'text', text: 'Thanks ' },
      { kind: 'mention', text: '@Asha_K', username: 'Asha_K' },
      { kind: 'text', text: ' and ' },
      { kind: 'mention', text: '@ravi.m', username: 'ravi.m' },
      { kind: 'text', text: '! Mail me at someone@example.com, @ab' },
    ]);
    expect(tokenizeUserText('ends with dot @priya.')).toEqual([
      { kind: 'text', text: 'ends with dot ' },
      { kind: 'mention', text: '@priya', username: 'priya' },
      { kind: 'text', text: '.' },
    ]);
  });

  it('can leave addresses as text (excerpts)', () => {
    expect(tokenizeUserText('go to https://example.com @asha', { links: false })).toEqual([
      { kind: 'text', text: 'go to https://example.com ' },
      { kind: 'mention', text: '@asha', username: 'asha' },
    ]);
  });
});

describe('text helpers', () => {
  it('splits paragraphs on blank lines', () => {
    expect(paragraphs('One\nline two\n\n\nThree\n \n')).toEqual(['One\nline two', 'Three']);
  });

  it('shortens long text at a word boundary', () => {
    expect(excerpt('short text')).toBe('short text');
    expect(excerpt('one two three four five six', 12)).toBe('one two…');
  });

  it('counts http(s) links', () => {
    expect(countLinks('a https://x.io b http://y.io c HTTPS://z.io')).toBe(3);
    expect(countLinks('no links here')).toBe(0);
  });

  it('spots card numbers, PINs, OTPs and passwords like the API', () => {
    expect(looksSecret('My card is 4111 1111 1111 1111')).toBe(true);
    expect(looksSecret('my UPI PIN is 4321')).toBe(true);
    expect(looksSecret('OTP: 556677')).toBe(true);
    expect(looksSecret('password: hunter22')).toBe(true);
    expect(looksSecret('I saved 15000 this month and paid 3 bills')).toBe(false);
    expect(looksSecret('Order 1234 5678 9012 3456')).toBe(false);
  });
});
