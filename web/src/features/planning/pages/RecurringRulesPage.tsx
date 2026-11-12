import { Link, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { paths, recurringPath } from '@/shared/config/paths';
import { useAccounts } from '@/shared/finance/reference';
import type { RecurringRule } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type RuleKindFilter, type RuleStatusFilter, useRecurringRules } from '../api';
import { PlanningSubNav } from '../components/PlanningSubNav';
import { RuleStatusBadge } from '../components/StatusBadges';
import { isEditableKind, recurringKindIcon, recurringKindLabel } from '../labels';
import { describeSchedule } from '../schedule';

const KINDS = ['', 'expense', 'income', 'transfer'] as const satisfies readonly RuleKindFilter[];
const STATUSES = ['', 'active', 'paused', 'ended'] as const satisfies readonly RuleStatusFilter[];

const kindFilterLabel = {
  '': 'recurring.filter.allKinds',
  expense: 'recurring.kind.expense',
  income: 'recurring.kind.income',
  transfer: 'recurring.kind.transfer',
} as const;

const statusFilterLabel = {
  '': 'recurring.filter.anyStatus',
  active: 'recurring.status.active',
  paused: 'recurring.status.paused',
  ended: 'recurring.status.ended',
} as const;

function parseKind(value: string | null): RuleKindFilter {
  return KINDS.find((option) => option === value) ?? '';
}

function parseStatus(value: string | null): RuleStatusFilter {
  return STATUSES.find((option) => option === value) ?? '';
}

/** Recurring income, expenses and transfers (bills have their own page). */
export function RecurringRulesPage() {
  const { t } = useI18n();
  useDocumentTitle(t('recurring.title'));
  const [params, setParams] = useSearchParams();
  const kind = parseKind(params.get('kind'));
  const status = parseStatus(params.get('status'));
  const rules = useRecurringRules(kind, status);
  const accounts = useAccounts(true);
  const accountNames = new Map((accounts.data ?? []).map((account) => [account.id, account.name]));
  const filtered = kind !== '' || status !== '';

  const setFilter = (name: 'kind' | 'status', value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(name, value);
    else next.delete(name);
    setParams(next, { replace: true });
  };

  let content;
  if (rules.isPending) {
    content = <LoadingState label={t('recurring.loading')} />;
  } else if (rules.isError) {
    content = hasErrorCode(rules.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('recurring.error')}
        error={rules.error}
        retrying={rules.isFetching}
        onRetry={() => {
          void rules.refetch();
        }}
      />
    );
  } else {
    // Bills and shared schedules are managed on their own pages.
    const visible = rules.data.filter((rule) => isEditableKind(rule.kind));
    content =
      visible.length === 0 ? (
        filtered ? (
          <EmptyState titleAs="p" icon="repeat" title={t('recurring.empty.filtered')} />
        ) : (
          <EmptyState
            titleAs="p"
            icon="repeat"
            title={t('recurring.empty.title')}
            description={t('recurring.empty.body')}
            action={
              <ButtonLink to={paths.recurringNew}>
                <Icon name="plus" className="size-4" />
                {t('recurring.add')}
              </ButtonLink>
            }
          />
        )
      ) : (
        <ul className="divide-y divide-line">
          {visible.map((rule) => (
            <RuleRow
              key={rule.id}
              rule={rule}
              accountName={accountNames.get(rule.account_id ?? '')}
            />
          ))}
        </ul>
      );
  }

  return (
    <>
      <PageHeader
        title={t('recurring.title')}
        description={t('recurring.description')}
        actions={
          <ButtonLink to={paths.recurringNew}>
            <Icon name="plus" className="size-4" />
            {t('recurring.add')}
          </ButtonLink>
        }
      />
      <PlanningSubNav />
      <Card
        title={t('recurring.list.title')}
        actions={
          <div className="flex flex-wrap gap-2">
            <Select
              label={t('recurring.filter.kind')}
              hideLabel
              className="min-w-40"
              value={kind}
              options={KINDS.map((value) => ({ value, label: t(kindFilterLabel[value]) }))}
              onChange={(event) => {
                setFilter('kind', event.target.value);
              }}
            />
            <Select
              label={t('recurring.filter.status')}
              hideLabel
              className="min-w-40"
              value={status}
              options={STATUSES.map((value) => ({ value, label: t(statusFilterLabel[value]) }))}
              onChange={(event) => {
                setFilter('status', event.target.value);
              }}
            />
          </div>
        }
      >
        {content}
      </Card>
    </>
  );
}

function RuleRow({ rule, accountName }: { rule: RecurringRule; accountName?: string }) {
  const { t, formatLocale } = useI18n();
  const details = [
    t(recurringKindLabel[rule.kind]),
    describeSchedule(rule, t, formatLocale),
    accountName,
    // The payee (or payer) comes with the rule.
    rule.merchant?.name,
  ].filter(Boolean);
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="flex min-w-0 flex-1 gap-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
          <Icon name={recurringKindIcon[rule.kind]} />
        </span>
        <div className="min-w-0 space-y-1">
          <Link
            to={recurringPath(rule.id)}
            className="font-medium text-fg underline-offset-4 hover:underline"
          >
            {rule.name}
          </Link>
          <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
          <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
            {rule.status === 'active' ? null : <RuleStatusBadge status={rule.status} />}
            {rule.auto_post ? (
              <StatusBadge tone="info" icon="repeat">
                {t('recurring.autoPostBadge')}
              </StatusBadge>
            ) : null}
            <span>
              {rule.next_occurrence
                ? t('recurring.next', { date: formatLocalDate(rule.next_occurrence, formatLocale) })
                : t('recurring.noNext')}
            </span>
          </div>
        </div>
      </div>
      <div className="shrink-0 sm:text-end">
        {rule.amount && !rule.amount_is_variable ? (
          <MoneyText money={rule.amount} className="font-medium text-fg" />
        ) : (
          <span className="text-sm text-fg-muted">{t('recurring.amountVaries')}</span>
        )}
      </div>
    </li>
  );
}
