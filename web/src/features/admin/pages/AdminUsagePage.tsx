import { useId } from 'react';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Skeleton } from '@/shared/components/Skeleton';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { formatBytes } from '@/features/privacy/format';
import { useUsage } from '../api';
import { CountTable } from '../components/CountTable';
import { DailyActivity } from '../components/DailyActivity';
import { StatTile } from '../components/StatTile';
import type { Usage } from '../types';

const WINDOWS = ['7', '30', '90', '365'] as const;
type WindowDays = (typeof WINDOWS)[number];
const DEFAULT_WINDOW: WindowDays = '30';

function isWindow(value: unknown): value is WindowDays {
  return typeof value === 'string' && (WINDOWS as readonly string[]).includes(value);
}

/** Map entries, largest count first (ties by name, so the order is stable). */
function byCount(map: Readonly<Record<string, number>>): [string, number][] {
  return Object.entries(map).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
}

function UsageView({ usage }: { usage: Usage }) {
  const { t, formatLocale } = useI18n();
  const nowId = useId();
  const windowId = useId();
  const numbers = new Intl.NumberFormat(formatLocale);
  const count = (value: number) => numbers.format(value);
  const inWindow = t('adminUsage.lastDays', { count: usage.window_days });
  const now = t('adminUsage.rightNow');
  // AI cost arrives in micro-dollars; shown in dollars (a unit change, not a total).
  const aiCost = new Intl.NumberFormat(formatLocale, {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: usage.ai.cost_micro_usd < 1_000_000 ? 4 : 2,
  }).format(usage.ai.cost_micro_usd / 1_000_000);
  const emailsSent = usage.notifications['email:sent'] ?? 0;

  return (
    <div className="space-y-6">
      <section aria-labelledby={nowId} className="space-y-3">
        <h2 id={nowId} className="text-lg font-semibold text-fg">
          {t('adminUsage.now.title')}
        </h2>
        <dl className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <StatTile
            label={t('adminUsage.activeAccounts')}
            value={count(usage.users.active)}
            detail={t('adminUsage.activeAccountsHelp')}
          />
          <StatTile
            label={t('adminUsage.pendingDeletion')}
            value={count(usage.users.pending_deletion)}
            detail={now}
          />
          <StatTile
            label={t('adminUsage.supportOpen')}
            value={count(usage.support_open)}
            detail={t('adminUsage.supportOpenHelp')}
          />
          <StatTile
            label={t('adminUsage.storage')}
            value={formatBytes(usage.storage.bytes, formatLocale)}
            detail={t('adminUsage.files', { count: usage.storage.files })}
          />
        </dl>
      </section>

      <section aria-labelledby={windowId} className="space-y-3">
        <h2 id={windowId} className="text-lg font-semibold text-fg">
          {t('adminUsage.window.title', { count: usage.window_days })}
        </h2>
        <dl className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <StatTile
            label={t('adminUsage.newAccounts')}
            value={count(usage.users.new)}
            detail={inWindow}
          />
          <StatTile
            label={t('adminUsage.transactionsCreated')}
            value={count(usage.transactions_created)}
            detail={inWindow}
          />
          <StatTile
            label={t('adminUsage.emailsSent')}
            value={count(emailsSent)}
            detail={inWindow}
          />
          <StatTile
            label={t('adminUsage.imports')}
            value={count(usage.imports)}
            detail={inWindow}
          />
          <StatTile
            label={t('adminUsage.reports')}
            value={count(usage.reports)}
            detail={inWindow}
          />
          <StatTile
            label={t('adminUsage.aiRequests')}
            value={count(usage.ai.requests)}
            detail={t('adminUsage.aiCost', { cost: aiCost })}
          />
        </dl>
      </section>

      <Card title={t('adminUsage.daily.title')} description={t('adminUsage.daily.description')}>
        <DailyActivity usage={usage} />
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card title={t('adminUsage.storageByArea.title')}>
          <CountTable
            caption={t('adminUsage.storageByArea.title')}
            columns={[t('adminUsage.storageByArea.area'), t('adminUsage.storageByArea.size')]}
            rows={byCount(usage.storage_by_area).map(([area, bytes]) => ({
              key: area,
              cells: [<code key="area">{area}</code>, formatBytes(bytes, formatLocale)],
            }))}
            empty={t('adminUsage.none')}
          />
        </Card>
        <Card title={t('adminUsage.notifications.title')} description={inWindow}>
          <CountTable
            caption={t('adminUsage.notifications.title')}
            columns={[
              t('adminUsage.notifications.channel'),
              t('adminUsage.notifications.status'),
              t('adminUsage.count'),
            ]}
            rows={byCount(usage.notifications).map(([key, value]) => {
              const [channel = key, status = ''] = key.split(':');
              return {
                key,
                cells: [
                  <code key="channel">{channel}</code>,
                  <code key="status">{status}</code>,
                  count(value),
                ],
              };
            })}
            empty={t('adminUsage.none')}
          />
        </Card>
        <Card title={t('adminUsage.jobs.title')} description={inWindow}>
          <CountTable
            caption={t('adminUsage.jobs.title')}
            columns={[t('adminUsage.jobs.status'), t('adminUsage.count')]}
            rows={byCount(usage.jobs).map(([status, value]) => ({
              key: status,
              cells: [<code key="status">{status}</code>, count(value)],
            }))}
            empty={t('adminUsage.none')}
          />
        </Card>
        <Card
          title={t('adminUsage.deadJobs.title')}
          description={t('adminUsage.deadJobs.description', { count: usage.window_days })}
        >
          <CountTable
            caption={t('adminUsage.deadJobs.title')}
            columns={[t('adminUsage.deadJobs.type'), t('adminUsage.count')]}
            rows={byCount(usage.dead_jobs_by_type).map(([type, value]) => ({
              key: type,
              cells: [<code key="type">{type}</code>, count(value)],
            }))}
            empty={t('adminUsage.deadJobs.none')}
          />
        </Card>
      </div>
    </div>
  );
}

/** Operator dashboard (platform admins): aggregate counts and a daily series, never personal data. */
export function AdminUsagePage() {
  const { t } = useI18n();
  useDocumentTitle(t('adminUsage.title'));
  const [params, setParams] = useSearchParams();
  const daysParam = params.get('days');
  const days: WindowDays = isWindow(daysParam) ? daysParam : DEFAULT_WINDOW;
  const usage = useUsage(Number(days));

  let content;
  if (usage.isPending) {
    content = (
      <LoadingState label={t('adminUsage.loading')}>
        <div className="space-y-4">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-64 w-full" />
        </div>
      </LoadingState>
    );
  } else if (usage.isError && !usage.data) {
    content = hasErrorCode(usage.error, 'FORBIDDEN') ? (
      <PermissionDenied
        titleAs="h2"
        title={t('adminUsage.forbidden.title')}
        description={t('adminUsage.forbidden.body')}
      />
    ) : (
      <ErrorState
        titleAs="h2"
        title={t('adminUsage.error')}
        error={usage.error}
        retrying={usage.isFetching}
        onRetry={() => {
          void usage.refetch();
        }}
      />
    );
  } else {
    // While another window loads, the previous one stays in place, dimmed.
    const refreshing = usage.isPlaceholderData && usage.isFetching;
    content = (
      <div
        aria-busy={refreshing || undefined}
        className={refreshing ? 'opacity-60 transition-opacity motion-reduce:transition-none' : ''}
      >
        {usage.isError ? (
          // A background refresh failed: the figures shown are the last ones loaded.
          <Alert tone="warning" live="polite" className="mb-6" title={t('adminUsage.staleTitle')}>
            <p>{t('adminUsage.staleBody')}</p>
            <Button
              variant="secondary"
              size="sm"
              loading={usage.isFetching}
              onClick={() => {
                void usage.refetch();
              }}
            >
              {t('common.retry')}
            </Button>
          </Alert>
        ) : null}
        <UsageView usage={usage.data} />
      </div>
    );
  }

  return (
    <>
      <PageHeader title={t('adminUsage.title')} description={t('adminUsage.description')} />
      <div className="space-y-6">
        <Alert tone="info" title={t('adminUsage.privacy.title')}>
          <p>{t('adminUsage.privacy.body')}</p>
        </Alert>
        <RadioGroup
          legend={t('adminUsage.windowLegend')}
          value={days}
          onChange={(next) => {
            setParams(
              (current) => {
                const updated = new URLSearchParams(current);
                updated.set('days', next);
                return updated;
              },
              { replace: true },
            );
          }}
          options={WINDOWS.map((value) => ({
            value,
            label: t('adminUsage.lastDays', { count: Number(value) }),
          }))}
        />
        {content}
      </div>
    </>
  );
}
