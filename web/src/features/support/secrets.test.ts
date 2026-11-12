import { describe, expect, it } from 'vitest';
import { containsSecret, passesLuhn } from './secrets';

describe('containsSecret (mirrors the API check)', () => {
  it('finds card numbers that pass the Luhn check, with or without separators', () => {
    expect(containsSecret('My card 4111 1111 1111 1111 was charged')).toBe(true);
    expect(containsSecret('card 4111-1111-1111-1111')).toBe(true);
    expect(containsSecret('4111111111111111')).toBe(true);
  });

  it('ignores long numbers that are not card numbers', () => {
    expect(containsSecret('Order 4111 1111 1111 1112 failed')).toBe(false);
    expect(containsSecret('Reference 1234567890')).toBe(false);
    expect(containsSecret('It happened on 2026-11-05 at 10:30')).toBe(false);
  });

  it('finds PINs, OTPs, CVVs and passwords next to a value', () => {
    expect(containsSecret('my OTP is 482913')).toBe(true);
    expect(containsSecret('UPI PIN: 1234')).toBe(true);
    expect(containsSecret('cvv=123')).toBe(true);
    expect(containsSecret('one-time code 99881')).toBe(true);
    expect(containsSecret('password: hunter22')).toBe(true);
    expect(containsSecret('Net banking password = abcd1234')).toBe(true);
  });

  it('allows talking about these things without the values', () => {
    expect(containsSecret('I never received the OTP email')).toBe(false);
    expect(containsSecret('How do I change my password?')).toBe(false);
    expect(containsSecret('The PIN screen froze')).toBe(false);
  });
});

describe('passesLuhn', () => {
  it('checks length and checksum', () => {
    expect(passesLuhn('4111111111111111')).toBe(true);
    expect(passesLuhn('4111111111111112')).toBe(false);
    expect(passesLuhn('411111111111')).toBe(false);
    expect(passesLuhn('4111 1111 1111 1111')).toBe(false);
  });
});
