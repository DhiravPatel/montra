import { describe, expect, it } from 'vitest';
import { makeAccess, REPORT_FILE } from '@/tests/reportsFixtures';
import { parseSignedFileUrl, safeFileName } from './download';

describe('report download links', () => {
  it('reads the file ID and signature from the API’s signed link', () => {
    expect(parseSignedFileUrl(makeAccess().url, 'http://localhost:5173')).toEqual({
      fileId: REPORT_FILE,
      query: {
        exp: '1793869250',
        sig: 'vynsUVtiJfOLY_xT0qcoLpJW6ZH8sEsQyxtsZR8KMtw',
        sub: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      },
    });
    // A relative link resolves against the page.
    expect(
      parseSignedFileUrl(`/api/v1/files/${REPORT_FILE}/content?exp=1`, 'http://localhost:5173')
        ?.fileId,
    ).toBe(REPORT_FILE);
  });

  it('rejects links of any other shape', () => {
    expect(parseSignedFileUrl('https://storage.example/object?sig=1', 'http://x')).toBeNull();
    expect(parseSignedFileUrl('/api/v1/files/not-an-id/content', 'http://x')).toBeNull();
    expect(parseSignedFileUrl('http://[bad', 'http://x')).toBeNull();
  });

  it('keeps the server’s file name but never a folder or reserved character', () => {
    expect(safeFileName('monthly-summary-20261104.csv', 'csv')).toBe(
      'monthly-summary-20261104.csv',
    );
    expect(safeFileName('../a/b:c.pdf', 'pdf')).toBe('..-a-b-c.pdf');
    expect(safeFileName('  ', 'xlsx')).toBe('montra-report.xlsx');
    expect(safeFileName('..', 'json')).toBe('montra-report.json');
  });
});
