import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { ProgressMeter, type MeterTone } from '@/shared/components/ProgressMeter';
import { Skeleton } from '@/shared/components/Skeleton';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { formatBasisPoints } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { formatBytes, storageShareBp } from '../format';
import { useLimits } from '../hooks';
import type { Limits, RatePolicy } from '../types';

const policyLabel: Readonly<Record<RatePolicy, MessageKey>> = {
  default: 'privacySettings.limits.policy.default',
  write: 'privacySettings.limits.policy.write',
  upload: 'privacySettings.limits.policy.upload',
  export: 'privacySettings.limits.policy.export',
  social: 'privacySettings.limits.policy.social',
  auth: 'privacySettings.limits.policy.auth',
  ai: 'privacySettings.limits.policy.ai',
};

const policyHelp: Readonly<Record<RatePolicy, MessageKey>> = {
  default: 'privacySettings.limits.policyHelp.default',
  write: 'privacySettings.limits.policyHelp.write',
  upload: 'privacySettings.limits.policyHelp.upload',
  export: 'privacySettings.limits.policyHelp.export',
  social: 'privacySettings.limits.policyHelp.social',
  auth: 'privacySettings.limits.policyHelp.auth',
  ai: 'privacySettings.limits.policyHelp.ai',
};

/** `note_code` sentences (GET /limits); unknown codes fall back to the English `note`. */
const noteKeys: Readonly<Partial<Record<string, MessageKey>>> = {
  fair_use_same_for_everyone: 'privacySettings.limits.free.body',
};

/** Storage share at which the meter changes tone; the text always says so too. */
const NEARLY_FULL_BP = 8_000;

function LimitRow({ label, value, meaning }: { label: string; value: ReactNode; meaning: string }) {
  return (
    <div className="grid gap-1 py-3 first:pt-0 last:pb-0 sm:grid-cols-3 sm:gap-4">
      <dt className="text-sm font-medium text-fg">{label}</dt>
      <dd className="sm:col-span-2">
        <span className="block font-semibold text-fg tabular-nums">{value}</span>
        <span className="block text-sm text-fg-muted">{meaning}</span>
      </dd>
    </div>
  );
}

function StorageCard({ limits }: { limits: Limits }) {
  const { t, formatLocale } = useI18n();
  const used = formatBytes(limits.storage_used_bytes, formatLocale);
  const capped = limits.storage_quota_bytes > 0;
  if (!capped) {
    return (
      <Card title={t('privacySettings.limits.storage.title')}>
        <p className="text-fg">{t('privacySettings.limits.storage.noCap', { used })}</p>
      </Card>
    );
  }
  const quota = formatBytes(limits.storage_quota_bytes, formatLocale);
  const share = storageShareBp(limits.storage_used_bytes, limits.storage_quota_bytes);
  const full = share >= 10_000;
  const nearlyFull = !full && share >= NEARLY_FULL_BP;
  const tone: MeterTone = full ? 'danger' : nearlyFull ? 'warning' : 'accent';
  const summary = t('privacySettings.limits.storage.used', {
    used,
    quota,
    percent: formatBasisPoints(share, formatLocale),
  });
  return (
    <Card
      title={t('privacySettings.limits.storage.title')}
      description={t('privacySettings.limits.storage.description')}
    >
      <div className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="font-semibold text-fg tabular-nums">{summary}</p>
          {full ? (
            <StatusBadge tone="danger">{t('privacySettings.limits.storage.full')}</StatusBadge>
          ) : nearlyFull ? (
            <StatusBadge tone="warning">
              {t('privacySettings.limits.storage.nearlyFull')}
            </StatusBadge>
          ) : null}
        </div>
        <ProgressMeter
          percentBp={share}
          label={t('privacySettings.limits.storage.meter')}
          valueText={summary}
          tone={tone}
        />
        {full || nearlyFull ? (
          <p className="text-sm text-fg-muted">{t('privacySettings.limits.storage.freeUp')}</p>
        ) : null}
      </div>
    </Card>
  );
}

/** The fair-use limits, the same for everyone, with the user's own storage use. */
export function LimitsPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('privacySettings.limits.title'));
  const limits = useLimits();
  const number = (value: number) => new Intl.NumberFormat(formatLocale).format(value);
  const noteKey: MessageKey | undefined = limits.data
    ? noteKeys[limits.data.note_code]
    : 'privacySettings.limits.free.body';

  let content;
  if (limits.isPending) {
    content = (
      <LoadingState label={t('privacySettings.limits.loading')}>
        <div className="space-y-4">
          <Skeleton className="h-28 w-full" />
          <Skeleton className="h-64 w-full" />
        </div>
      </LoadingState>
    );
  } else if (limits.isError) {
    content = hasErrorCode(limits.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h2" />
    ) : (
      <ErrorState
        titleAs="h2"
        title={t('privacySettings.limits.error')}
        error={limits.error}
        retrying={limits.isFetching}
        onRetry={() => {
          void limits.refetch();
        }}
      />
    );
  } else {
    const data = limits.data;
    const days = (count: number) => t('privacySettings.limits.days', { count });
    content = (
      <div className="space-y-6">
        <StorageCard limits={data} />

        <Card
          title={t('privacySettings.limits.records.title')}
          description={t('privacySettings.limits.records.description')}
        >
          <dl className="divide-y divide-line">
            <LimitRow
              label={t('privacySettings.limits.maxUpload')}
              value={formatBytes(data.max_upload_bytes, formatLocale)}
              meaning={t('privacySettings.limits.maxUploadHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.importRows')}
              value={t('privacySettings.limits.rows', { count: data.import_max_rows })}
              meaning={t('privacySettings.limits.importRowsHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.openRecurring')}
              value={number(data.max_open_recurring_rules)}
              meaning={t('privacySettings.limits.openRecurringHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.openBills')}
              value={number(data.max_open_bills)}
              meaning={t('privacySettings.limits.openBillsHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.openSubscriptions')}
              value={number(data.max_open_subscriptions)}
              meaning={t('privacySettings.limits.openSubscriptionsHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.openGoals')}
              value={number(data.max_open_goals)}
              meaning={t('privacySettings.limits.openGoalsHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.supportRequests')}
              value={t('privacySettings.limits.perDay', { count: data.support_requests_per_day })}
              meaning={t('privacySettings.limits.supportRequestsHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.downloadWindow')}
              value={days(data.export_download_days)}
              meaning={t('privacySettings.limits.downloadWindowHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.deletionGrace')}
              value={days(data.deletion_grace_days)}
              meaning={t('privacySettings.limits.deletionGraceHelp')}
            />
            <LimitRow
              label={t('privacySettings.limits.ai')}
              value={
                data.ai_requests_per_day > 0
                  ? t('privacySettings.limits.perDay', { count: data.ai_requests_per_day })
                  : t('privacySettings.limits.aiOff')
              }
              meaning={
                data.ai_requests_per_day > 0
                  ? t('privacySettings.limits.aiHelp')
                  : t('privacySettings.limits.aiOffHelp')
              }
            />
          </dl>
        </Card>

        <Card
          title={t('privacySettings.limits.rates.title')}
          description={t('privacySettings.limits.rates.description')}
        >
          {data.rate_limits.length === 0 ? (
            <p className="text-sm text-fg-muted">{t('privacySettings.limits.rates.none')}</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-max border-collapse text-sm">
                <caption className="sr-only">{t('privacySettings.limits.rates.title')}</caption>
                <thead>
                  <tr className="border-b border-line">
                    <th scope="col" className="py-2 pe-4 text-start font-medium text-fg-muted">
                      {t('privacySettings.limits.rates.kind')}
                    </th>
                    <th scope="col" className="py-2 pe-4 text-end font-medium text-fg-muted">
                      {t('privacySettings.limits.rates.perMinute')}
                    </th>
                    <th scope="col" className="py-2 pe-4 text-end font-medium text-fg-muted">
                      {t('privacySettings.limits.rates.burst')}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {data.rate_limits.map((rate) => (
                    <tr key={rate.policy} className="border-b border-line last:border-b-0">
                      <th scope="row" className="py-2 pe-4 text-start font-normal">
                        <span className="block text-fg">{t(policyLabel[rate.policy])}</span>
                        <span className="block text-xs text-fg-muted">
                          {t(policyHelp[rate.policy])}
                        </span>
                      </th>
                      <td className="py-2 pe-4 text-end text-fg tabular-nums">
                        {number(rate.per_minute)}
                      </td>
                      <td className="py-2 pe-4 text-end text-fg tabular-nums">
                        {number(rate.burst)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <p className="mt-4 text-sm text-fg-muted">{t('privacySettings.limits.rates.over')}</p>
        </Card>
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title={t('privacySettings.limits.title')}
        description={t('privacySettings.limits.description')}
      />
      <div className="space-y-6">
        <Alert tone="success" title={t('privacySettings.limits.free.title')}>
          {/* The API's note, localized by note_code; a newer note is shown as sent (English). */}
          {noteKey ? <p>{t(noteKey)}</p> : <p lang="en">{limits.data?.note}</p>}
        </Alert>
        {content}
        <p className="text-sm text-fg-muted">
          <TextLink to={paths.privacySettings}>
            {t('privacySettings.limits.backToPrivacy')}
          </TextLink>
        </p>
      </div>
    </>
  );
}
