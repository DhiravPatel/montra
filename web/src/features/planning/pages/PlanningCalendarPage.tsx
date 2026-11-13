import { Link, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { paths } from '@/shared/config/paths';
import type { CalendarItem } from '@/shared/finance/types';
import { formatLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useCalendar, useRecurringReport } from '../api';
import {
  calendarItemPath,
  dayHeading,
  groupByDate,
  monthLabel,
  monthRange,
  parseMonth,
  shiftMonth,
} from '../calendarMonth';
import { CommitmentList } from '../components/CommitmentList';
import { PlanningSubNav } from '../components/PlanningSubNav';
import { calendarKindLook, calendarStatusLook } from '../labels';

/** Upcoming: bills, recurring items, renewals, trial ends and goal dates by day. */
export function PlanningCalendarPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('calendar.title'));
  const user = useCurrentUser();
  const today = todayInTimeZone(user.timezone);
  const currentMonth = today.slice(0, 7);
  const [params, setParams] = useSearchParams();
  const month = parseMonth(params.get('month')) ?? currentMonth;
  const { from, to } = monthRange(month);
  const calendar = useCalendar(from, to);
  const label = monthLabel(month, formatLocale);

  const goTo = (next: string) => {
    setParams(next === currentMonth ? {} : { month: next }, { replace: true });
  };

  let content;
  if (calendar.isPending) {
    content = <LoadingState label={t('calendar.loading')} />;
  } else if (calendar.isError) {
    content = hasErrorCode(calendar.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('calendar.error')}
        error={calendar.error}
        retrying={calendar.isFetching}
        onRetry={() => {
          void calendar.refetch();
        }}
      />
    );
  } else if (calendar.data.length === 0) {
    content = (
      <EmptyState
        titleAs="p"
        icon="calendar"
        title={t('calendar.empty.title', { month: label })}
        description={t('calendar.empty.body')}
        action={
          <>
            <ButtonLink to={paths.billNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('bills.add')}
            </ButtonLink>
            <ButtonLink to={paths.recurringNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('recurring.add')}
            </ButtonLink>
          </>
        }
      />
    );
  } else {
    const days = groupByDate(calendar.data);
    const projected = calendar.data.some((item) => item.status === 'projected');
    content = (
      <>
        <ol className="space-y-6">
          {days.map((day) => (
            <li key={day.date}>
              <h3 className="flex flex-wrap items-center gap-2 text-sm font-semibold text-fg">
                <time dateTime={day.date}>{dayHeading(day.date, formatLocale)}</time>
                {day.date === today ? (
                  <StatusBadge tone="info" icon="calendar">
                    {t('calendar.today')}
                  </StatusBadge>
                ) : null}
              </h3>
              <ul className="mt-2 divide-y divide-line rounded-lg border border-line">
                {day.items.map((item, index) => (
                  <CalendarRow
                    key={`${item.entity_type}-${item.entity_id}-${item.occurrence_id ?? item.kind}-${String(index)}`}
                    item={item}
                  />
                ))}
              </ul>
            </li>
          ))}
        </ol>
        {projected ? (
          <p className="mt-6 text-sm text-fg-muted">{t('calendar.projectedNote')}</p>
        ) : null}
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t('calendar.title')}
        description={t('calendar.description')}
        actions={
          <>
            <ButtonLink to={paths.billNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('bills.add')}
            </ButtonLink>
            <ButtonLink to={paths.recurringNew}>
              <Icon name="plus" className="size-4" />
              {t('recurring.add')}
            </ButtonLink>
          </>
        }
      />
      <PlanningSubNav />
      <div className="grid items-start gap-6 lg:grid-cols-3">
        <section
          aria-labelledby="calendar-month-heading"
          className="rounded-xl border border-line bg-surface p-5 shadow-card sm:p-6 lg:col-span-2"
        >
          <div className="mb-5 flex flex-wrap items-center gap-2">
            <IconButton
              icon="chevron-left"
              label={t('calendar.previous')}
              onClick={() => {
                goTo(shiftMonth(month, -1));
              }}
            />
            <h2
              id="calendar-month-heading"
              className="min-w-40 text-center text-lg font-semibold text-fg"
            >
              {label}
            </h2>
            <IconButton
              icon="chevron-right"
              label={t('calendar.next')}
              onClick={() => {
                goTo(shiftMonth(month, 1));
              }}
            />
            {month === currentMonth ? null : (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  goTo(currentMonth);
                }}
              >
                {t('calendar.thisMonth')}
              </Button>
            )}
            <p role="status" className="sr-only">
              {calendar.isSuccess ? t('calendar.showing', { month: label }) : ''}
            </p>
          </div>
          {content}
        </section>
        <CommitmentsCard />
      </div>
    </>
  );
}

function CalendarRow({ item }: { item: CalendarItem }) {
  const { t, formatLocale } = useI18n();
  const kind = calendarKindLook[item.kind];
  const status = calendarStatusLook(item.status);
  const href = calendarItemPath(item);
  // A moved occurrence is listed on its new date and names the date it was planned for.
  const movedFrom = item.postponed_to && item.scheduled_on ? item.scheduled_on : null;
  return (
    <li className="flex items-center gap-3 px-4 py-3">
      <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={kind.icon} className="size-4" />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        {href ? (
          <Link to={href} className="font-medium text-fg underline-offset-4 hover:underline">
            {item.title}
          </Link>
        ) : (
          <p className="font-medium text-fg">{item.title}</p>
        )}
        <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
          <span>{t(kind.label)}</span>
          {status ? (
            <StatusBadge tone={status.tone} icon={status.icon}>
              {t(status.label)}
            </StatusBadge>
          ) : (
            <span>{item.status}</span>
          )}
          {movedFrom ? (
            <StatusBadge tone="info" icon="clock">
              {t('calendar.movedFrom', { date: formatLocalDate(movedFrom, formatLocale) })}
            </StatusBadge>
          ) : null}
        </div>
      </div>
      {item.amount ? (
        <MoneyText money={item.amount} className="shrink-0 font-medium text-fg" />
      ) : null}
    </li>
  );
}

/** Fixed recurring amounts as a monthly equivalent per currency (from the API). */
function CommitmentsCard() {
  const { t } = useI18n();
  const report = useRecurringReport();
  let body;
  if (report.isPending) {
    body = <LoadingState label={t('calendar.commitments.loading')} />;
  } else if (report.isError) {
    body = (
      <ErrorState
        titleAs="p"
        title={t('calendar.commitments.error')}
        error={report.error}
        retrying={report.isFetching}
        onRetry={() => {
          void report.refetch();
        }}
      />
    );
  } else {
    body = (
      <CommitmentList commitments={report.data.commitments} noteCode={report.data.note_code} />
    );
  }
  return (
    <Card
      title={t('calendar.commitments.title')}
      description={t('calendar.commitments.description')}
    >
      {body}
    </Card>
  );
}
