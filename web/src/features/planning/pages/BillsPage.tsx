import { useId, useState } from 'react';
import { Link, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { billPath, paths } from '@/shared/config/paths';
import type { Bill } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type BillStatusFilter, useBills } from '../api';
import { MarkPaidFlow } from '../components/MarkPaidFlow';
import { PlanningSubNav } from '../components/PlanningSubNav';
import { BillStateBadge } from '../components/StatusBadges';
import { billNeedsAttention } from '../labels';
import { describeSchedule } from '../schedule';
import { HelpGuideLink } from '@/shared/help/HelpGuideLink';

const FILTERS = [
  '',
  'active',
  'paused',
  'archived',
  'all',
] as const satisfies readonly BillStatusFilter[];

const filterLabel = {
  '': 'bills.filter.current',
  active: 'bills.filter.active',
  paused: 'bills.filter.paused',
  archived: 'bills.filter.archived',
  all: 'bills.filter.all',
} as const;

function parseFilter(value: string | null): BillStatusFilter {
  return FILTERS.find((filter) => filter === value) ?? '';
}

/** Bills with their payment state; the ones due now come first. */
export function BillsPage() {
  const { t } = useI18n();
  useDocumentTitle(t('bills.title'));
  const [params, setParams] = useSearchParams();
  const status = parseFilter(params.get('status'));
  const bills = useBills(status);
  const [paying, setPaying] = useState<Bill | null>(null);

  let content;
  if (bills.isPending) {
    content = <LoadingState label={t('bills.loading')} />;
  } else if (bills.isError) {
    content = hasErrorCode(bills.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('bills.error')}
        error={bills.error}
        retrying={bills.isFetching}
        onRetry={() => {
          void bills.refetch();
        }}
      />
    );
  } else if (bills.data.length === 0) {
    content =
      status === '' ? (
        <EmptyState
          titleAs="p"
          icon="receipt"
          title={t('bills.empty.title')}
          description={t('bills.empty.body')}
          action={
            <ButtonLink to={paths.billNew}>
              <Icon name="plus" className="size-4" />
              {t('bills.add')}
            </ButtonLink>
          }
        />
      ) : (
        <EmptyState titleAs="p" icon="receipt" title={t('bills.empty.filtered')} />
      );
  } else {
    const dueNow = bills.data.filter((bill) => billNeedsAttention(bill.state));
    const others = bills.data.filter((bill) => !billNeedsAttention(bill.state));
    content = (
      <div className="space-y-8">
        {dueNow.length > 0 ? (
          <BillGroup title={t('bills.group.dueNow')} bills={dueNow} onPay={setPaying} />
        ) : null}
        {others.length > 0 ? (
          <BillGroup
            title={dueNow.length > 0 ? t('bills.group.others') : t('bills.group.all')}
            bills={others}
            onPay={setPaying}
          />
        ) : null}
      </div>
    );
  }

  return (
    <>
      <PageHeader
        help={<HelpGuideLink guide="recurring" section="bills" />}
        title={t('bills.title')}
        description={t('bills.description')}
        actions={
          <ButtonLink to={paths.billNew}>
            <Icon name="plus" className="size-4" />
            {t('bills.add')}
          </ButtonLink>
        }
      />
      <PlanningSubNav />
      <Card
        title={t('bills.list.title')}
        actions={
          <Select
            label={t('bills.filter.label')}
            hideLabel
            className="min-w-48"
            value={status}
            options={FILTERS.map((value) => ({ value, label: t(filterLabel[value]) }))}
            onChange={(event) => {
              const next = parseFilter(event.target.value);
              setParams(next ? { status: next } : {}, { replace: true });
            }}
          />
        }
      >
        {content}
      </Card>
      {paying?.next_due ? (
        <MarkPaidFlow
          bill={paying}
          occurrence={paying.next_due}
          onClose={() => {
            setPaying(null);
          }}
        />
      ) : null}
    </>
  );
}

function BillGroup({
  title,
  bills,
  onPay,
}: {
  title: string;
  bills: readonly Bill[];
  onPay: (bill: Bill) => void;
}) {
  const headingId = useId();
  return (
    <section aria-labelledby={headingId}>
      <h3 id={headingId} className="mb-2 text-sm font-semibold text-fg-muted">
        {title}
      </h3>
      <ul className="divide-y divide-line">
        {bills.map((bill) => (
          <BillRow key={bill.id} bill={bill} onPay={onPay} />
        ))}
      </ul>
    </section>
  );
}

function BillRow({ bill, onPay }: { bill: Bill; onPay: (bill: Bill) => void }) {
  const { t, formatLocale } = useI18n();
  const amount = bill.next_due?.amount ?? bill.expected_amount;
  const details = [bill.provider_name, describeSchedule(bill.schedule, t, formatLocale)].filter(
    Boolean,
  );
  const canPay = bill.owned && bill.status !== 'archived' && Boolean(bill.next_due);
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="flex min-w-0 flex-1 gap-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
          <Icon name="receipt" />
        </span>
        <div className="min-w-0 space-y-1">
          <Link
            to={billPath(bill.id)}
            className="font-medium text-fg underline-offset-4 hover:underline"
          >
            {bill.name}
          </Link>
          <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
          <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
            <BillStateBadge state={bill.state} />
            {bill.next_due ? (
              <span>
                {t('bills.nextDue', {
                  date: formatLocalDate(bill.next_due.effective_date, formatLocale),
                })}
              </span>
            ) : bill.last_paid ? (
              <span>
                {t('bills.lastPaid', {
                  date: formatLocalDate(bill.last_paid.effective_date, formatLocale),
                })}
              </span>
            ) : null}
          </div>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-3 sm:justify-end">
        {amount ? (
          <MoneyText money={amount} className="font-medium text-fg" />
        ) : (
          <span className="text-sm text-fg-muted">{t('bills.amountVaries')}</span>
        )}
        {canPay ? (
          <Button
            variant="secondary"
            size="sm"
            aria-label={`${t('bills.markPaid.action')}: ${bill.name}`}
            onClick={() => {
              onPay(bill);
            }}
          >
            <Icon name="check" className="size-4" />
            {t('bills.markPaid.action')}
          </Button>
        ) : null}
      </div>
    </li>
  );
}
