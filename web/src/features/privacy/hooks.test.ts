import { describe, expect, it } from 'vitest';
import { makeExportJob } from '@/tests/privacyFixtures';
import { EXPORT_POLL_LIMIT, exportPollInterval, isExportActive } from './hooks';

describe('export polling', () => {
  it('polls quickly at first, then slower, while the export is queued or running', () => {
    const running = makeExportJob({ status: 'running' });
    expect(exportPollInterval(makeExportJob(), 0)).toBe(2_000);
    expect(exportPollInterval(running, 29)).toBe(2_000);
    expect(exportPollInterval(running, 30)).toBe(10_000);
  });

  it('stops once the export is finished, or after the polling limit', () => {
    expect(exportPollInterval(makeExportJob({ status: 'completed' }), 3)).toBe(false);
    expect(exportPollInterval(makeExportJob({ status: 'failed' }), 3)).toBe(false);
    expect(exportPollInterval(undefined, 0)).toBe(false);
    expect(exportPollInterval(makeExportJob({ status: 'running' }), EXPORT_POLL_LIMIT)).toBe(false);
  });

  it('treats only queued and running exports as active', () => {
    expect(isExportActive(makeExportJob({ status: 'queued' }))).toBe(true);
    expect(isExportActive(makeExportJob({ status: 'running' }))).toBe(true);
    expect(isExportActive(makeExportJob({ status: 'expired' }))).toBe(false);
  });
});
