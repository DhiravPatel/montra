import { describe, expect, it } from 'vitest';
import { ApiError } from '@/shared/api/errors';
import { createTranslator } from '@/shared/i18n/translate';
import { integrationErrorMessage } from './errors';

const t = createTranslator('en', 'en-IN');

function conflict(code?: string) {
  return new ApiError({
    status: 409,
    code: 'CONFLICT',
    message: 'A sync is already running.',
    details: code ? [{ message: 'A sync is already running.', code }] : [],
  });
}

describe('integration error messages', () => {
  it('localizes 409 sync_running whatever started it', () => {
    expect(integrationErrorMessage(conflict('sync_running'), t, 'sync')).toBe(
      'A sync is already running. Wait for it to finish.',
    );
    expect(integrationErrorMessage(conflict('sync_running'), t, 'disconnect')).toBe(
      'A sync is already running. Wait for it to finish.',
    );
  });

  it('still reads an uncoded 409 on sync as a running sync', () => {
    expect(integrationErrorMessage(conflict(), t, 'sync')).toBe(
      'A sync is already running. Wait for it to finish.',
    );
  });
});
