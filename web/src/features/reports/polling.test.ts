import { describe, expect, it } from 'vitest';
import { makeReport, makeRunningReport, makeStalledReport } from '@/tests/reportsFixtures';
import { displayStatus, isStalled, pollInterval } from './polling';

const NOW = '2026-11-04T10:00:00Z';

describe('report polling', () => {
  it('does not poll when nothing is being prepared', () => {
    expect(pollInterval(undefined)).toBe(false);
    expect(pollInterval({ reports: [makeReport()], serverTime: NOW })).toBe(false);
  });

  it('polls quickly right after a request, then more slowly', () => {
    const report = (requestedAt: string) => makeRunningReport({ requested_at: requestedAt });
    expect(pollInterval({ reports: [report('2026-11-04T09:59:50Z')], serverTime: NOW })).toBe(2000);
    expect(pollInterval({ reports: [report('2026-11-04T09:55:00Z')], serverTime: NOW })).toBe(5000);
    expect(pollInterval({ reports: [report('2026-11-04T09:40:00Z')], serverTime: NOW })).toBe(
      30000,
    );
    // The shortest interval wins when several reports are being prepared.
    expect(
      pollInterval({
        reports: [report('2026-11-04T09:40:00Z'), report('2026-11-04T09:59:59Z')],
        serverTime: NOW,
      }),
    ).toBe(2000);
  });

  it('stops polling for a report that has been waiting too long (by the server’s clock)', () => {
    const stalled = makeStalledReport();
    expect(isStalled(stalled, NOW)).toBe(true);
    expect(pollInterval({ reports: [stalled], serverTime: NOW })).toBe(false);
    expect(isStalled(makeReport(), NOW)).toBe(false);
  });
});

describe('report status', () => {
  it('shows a ready report past its download window as expired (by the server’s clock)', () => {
    expect(displayStatus(makeReport({ expires_at: '2026-11-04T09:59:59Z' }), NOW)).toBe('expired');
    expect(displayStatus(makeReport({ expires_at: '2026-11-04T10:00:01Z' }), NOW)).toBe(
      'completed',
    );
    expect(displayStatus(makeRunningReport(), NOW)).toBe('running');
  });
});
