import { describe, expect, it } from 'vitest';
import { clearUrlFragment, readFragmentToken } from './fragmentToken';

describe('fragment tokens', () => {
  it('reads well-formed tokens only', () => {
    expect(readFragmentToken('#token=abcdefghijklmnopqrstuv_-123')).toBe(
      'abcdefghijklmnopqrstuv_-123',
    );
    expect(readFragmentToken('#token=short')).toBeNull();
    expect(readFragmentToken('#token=has spaces in it here')).toBeNull();
    expect(readFragmentToken('')).toBeNull();
  });

  it('removes the fragment without adding a history entry', () => {
    window.history.replaceState(
      { keep: true },
      '',
      '/reset-password?x=1#token=abcdefghijklmnopqrstuv',
    );
    const length = window.history.length;
    clearUrlFragment();
    expect(window.location.hash).toBe('');
    expect(window.location.pathname + window.location.search).toBe('/reset-password?x=1');
    expect(window.history.length).toBe(length);
    expect(window.history.state).toEqual({ keep: true });
  });
});
