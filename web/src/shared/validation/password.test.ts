import { describe, expect, it } from 'vitest';
import { evaluatePassword, firstUnmetPasswordRule } from './password';

describe('password policy (mirrors the API)', () => {
  it('requires at least 10 characters, counted as code points', () => {
    expect(firstUnmetPasswordRule('abc-123-x')).toBe('length');
    expect(firstUnmetPasswordRule('abc-123-xy')).toBeNull();
    expect(firstUnmetPasswordRule('🔒🔒🔒🔒🔒ab-cd')).toBeNull();
  });

  it('rejects common passwords case-insensitively', () => {
    expect(firstUnmetPasswordRule('Password123')).toBe('notCommon');
  });

  it('rejects passwords containing the email local part (4+ characters)', () => {
    expect(firstUnmetPasswordRule('ashwini-2026!', 'Ashwini@example.com')).toBe('notEmail');
    expect(firstUnmetPasswordRule('abc-secret-99', 'abc@example.com')).toBeNull();
  });

  it('requires some variety of characters', () => {
    expect(firstUnmetPasswordRule('aaaaabbbbb')).toBe('variety');
  });

  it('caps length at 128 characters', () => {
    expect(firstUnmetPasswordRule(`${'ab1-'.repeat(32)}x`)).toBe('tooLong');
  });

  it('reports every rule for live hints', () => {
    expect(evaluatePassword('').every((rule) => !rule.met)).toBe(true);
    expect(evaluatePassword('quiet-harbor-71', 'asha@example.com').every((rule) => rule.met)).toBe(
      true,
    );
  });
});
