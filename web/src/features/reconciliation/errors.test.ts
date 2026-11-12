import { describe, expect, it } from 'vitest';
import { ApiError } from '@/shared/api/errors';
import { createTranslator } from '@/shared/i18n/translate';
import { reconciliationErrorMessage } from './errors';

const t = createTranslator('en', 'en-IN');
const hi = createTranslator('hi', 'hi-IN');

function coded(status: 409 | 422, code: 'CONFLICT' | 'VALIDATION_ERROR', detail: string) {
  return new ApiError({
    status,
    code,
    message: 'English fallback.',
    details: [
      {
        field: code === 'VALIDATION_ERROR' ? 'body.transaction_ids' : undefined,
        message: 'English fallback.',
        code: detail,
      },
    ],
  });
}

describe('reconciliation error messages', () => {
  it('localizes an item listed twice (duplicate_item)', () => {
    const error = coded(422, 'VALIDATION_ERROR', 'duplicate_item');
    expect(reconciliationErrorMessage(error, t, 'en-IN')).toBe(
      'Each transaction and statement row can be chosen only once in a match.',
    );
    expect(reconciliationErrorMessage(error, hi, 'hi-IN')).not.toBe(
      reconciliationErrorMessage(error, t, 'en-IN'),
    );
  });

  it('localizes a transaction that is already matched (409 transaction_already_matched)', () => {
    expect(
      reconciliationErrorMessage(coded(409, 'CONFLICT', 'transaction_already_matched'), t, 'en-IN'),
    ).toBe('A transaction you chose is already matched or reconciled. We’ve refreshed the list.');
  });

  it('keeps the general conflict text for other conflicts', () => {
    expect(reconciliationErrorMessage(coded(409, 'CONFLICT', 'something_new'), t, 'en-IN')).toBe(
      'This was already matched or changed. We’ve refreshed the list.',
    );
  });
});
