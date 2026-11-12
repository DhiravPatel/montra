import { describe, expect, it } from 'vitest';
import { usableShareUrl } from './shareUrl';

describe('usableShareUrl', () => {
  it('keeps an absolute http(s) link exactly as sent', () => {
    expect(usableShareUrl('https://app.montra.example/groups/join#token=abc')).toBe(
      'https://app.montra.example/groups/join#token=abc',
    );
    expect(usableShareUrl('http://localhost:5173/communities/join#token=x')).toBe(
      'http://localhost:5173/communities/join#token=x',
    );
  });

  it('refuses missing, relative and non-web links', () => {
    expect(usableShareUrl(undefined)).toBeNull();
    expect(usableShareUrl('')).toBeNull();
    expect(usableShareUrl('/groups/join#token=abc')).toBeNull();
    expect(usableShareUrl('javascript:alert(1)')).toBeNull();
    expect(usableShareUrl('data:text/html,hi')).toBeNull();
  });
});
