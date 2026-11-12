import { describe, expect, it } from 'vitest';
import { detectLanguage, resolveFormatLocale, textDirection } from './languages';
import { formatWait } from './formatWait';
import { createTranslator, splitRichText } from './translate';

describe('translator', () => {
  it('interpolates parameters and formats numbers for the locale', () => {
    const t = createTranslator('en', 'en-IN');
    expect(t('auth.signIn.unverified.body', { email: 'a@example.com' })).toContain('a@example.com');
    expect(t('time.seconds', { count: 100000 })).toBe('1,00,000 seconds');
  });

  it('selects plural forms with Intl.PluralRules', () => {
    const t = createTranslator('en', 'en');
    expect(t('time.minutes', { count: 1 })).toBe('1 minute');
    expect(t('time.minutes', { count: 2 })).toBe('2 minutes');
  });

  it('formats Retry-After waits in seconds, minutes or hours', () => {
    const t = createTranslator('en', 'en');
    expect(formatWait(t, 45)).toBe('45 seconds');
    expect(formatWait(t, 61)).toBe('2 minutes');
    expect(formatWait(t, 900)).toBe('15 minutes');
    expect(formatWait(t, 7200)).toBe('2 hours');
    expect(t('auth.retryIn', { wait: formatWait(t, 900) })).toBe(
      'You can try again in 15 minutes.',
    );
    const hi = createTranslator('hi', 'hi-IN');
    expect(hi('auth.retryIn', { wait: formatWait(hi, 900) })).toBe(
      'आप 15 मिनट बाद फिर से प्रयास कर सकते हैं।',
    );
  });

  it('uses the Hindi catalog and falls back to English for missing keys', () => {
    const t = createTranslator('hi', 'hi-IN');
    expect(t('auth.signIn.title')).toBe('साइन इन करें');
    expect(t('settings.sessions.title')).toBe('Signed-in devices');
  });

  it('splits simple rich-text markup', () => {
    expect(
      splitRichText('I agree to the <terms>Terms</terms> and <privacy>Privacy</privacy>.'),
    ).toEqual([
      { tag: null, text: 'I agree to the ' },
      { tag: 'terms', text: 'Terms' },
      { tag: null, text: ' and ' },
      { tag: 'privacy', text: 'Privacy' },
      { tag: null, text: '.' },
    ]);
  });
});

describe('language detection', () => {
  it('picks a supported language and keeps regional formatting', () => {
    expect(detectLanguage(['hi-IN', 'en'])).toBe('hi');
    expect(detectLanguage(['fr-FR'])).toBe('en');
    expect(resolveFormatLocale('en', ['en-IN', 'en'])).toBe('en-IN');
    expect(resolveFormatLocale('hi', ['en-US'])).toBe('hi-IN');
  });

  it('is ready for right-to-left languages', () => {
    expect(textDirection('ar-EG')).toBe('rtl');
    expect(textDirection('hi-IN')).toBe('ltr');
  });
});
