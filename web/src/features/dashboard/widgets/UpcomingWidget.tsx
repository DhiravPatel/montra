import { Link } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { groupRecurringPath, paths } from '@/shared/config/paths';
import type { CalendarItem } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { calendarItemPath } from '@/features/planning/calendarMonth';
import { calendarKindLook, calendarStatusLook } from '@/features/planning/labels';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

/** Where an item lives: its bill, rule, subscription or goal, or the group's shared recurring expenses. */
function itemPath(item: CalendarItem): string | null {
  if (item.entity_type === 'group_recurring_expense') {
    return item.group_id ? groupRecurringPath(item.group_id) : null;
  }
  return calendarItemPath(item);
}

function UpcomingRow({ item, today }: { item: CalendarItem; today: string }) {
  const { t, formatLocale } = useI18n();
  const kind = calendarKindLook[item.kind];
  const overdue = item.status === 'overdue';
  const status = overdue ? null : calendarStatusLook(item.status);
  const href = itemPath(item);
  const date = formatLocalDate(item.date, formatLocale);
  return (
    <li className="flex items-start gap-3 py-3 first:pt-0">
      <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={kind.icon} className="size-4" />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        {href ? (
          <Link
            to={href}
            className="font-medium break-words text-fg underline-offset-4 hover:underline"
          >
            {item.title}
          </Link>
        ) : (
          <p className="font-medium break-words text-fg">{item.title}</p>
        )}
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-fg-muted">
          <time dateTime={item.date}>
            {overdue
              ? t('dashboard.upcoming.wasDue', { date })
              : item.date === today
                ? t('dashboard.upcoming.dueToday')
                : t('dashboard.upcoming.due', { date })}
          </time>
          <span aria-hidden="true">·</span>
          <span>{t(kind.label)}</span>
          {overdue ? (
            // Overdue is said in words with an icon, in a calm tone: nothing is lost yet.
            <StatusBadge tone="warning" icon="clock">
              {t('dashboard.upcoming.overdue')}
            </StatusBadge>
          ) : status && item.status !== 'scheduled' ? (
            <StatusBadge tone={status.tone} icon={status.icon}>
              {t(status.label)}
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

/**
 * Overdue items first (oldest first), then what is due in the next two
 * weeks: bills, recurring items, shared recurring expenses, renewals, trial
 * ends and goal dates, in the order the API chose.
 */
export function UpcomingWidget({ title, planning }: PlanningWidgetProps) {
  const { t, formatLocale } = useI18n();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={(data) =>
        data
          ? t('dashboard.upcoming.scope', {
              date: formatLocalDate(data.upcoming_through, formatLocale),
            })
          : t('dashboard.upcoming.scopeGeneric')
      }
      loadingLabel={t('dashboard.upcoming.loading')}
      errorTitle={t('dashboard.upcoming.error')}
      total={(data) => data.upcoming_count}
      countText={(data) =>
        t('dashboard.upcoming.count', { count: data.upcoming_count, shown: data.upcoming.length })
      }
      viewAll={{
        to: paths.planning,
        label: (count) => t('dashboard.upcoming.viewAll', { count }),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="calendar"
          title={t('dashboard.upcoming.empty')}
          description={t('dashboard.upcoming.emptyBody')}
          action={
            <ButtonLink to={paths.billNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('bills.add')}
            </ButtonLink>
          }
        />
      }
    >
      {(data) => (
        <>
          {data.overdue_count > 0 ? (
            <p className="mb-4 flex items-start gap-2 rounded-lg border border-warning/40 bg-warning-soft p-3 text-sm text-fg">
              <Icon name="clock" className="mt-0.5 size-4 shrink-0 text-warning" />
              <span>{t('dashboard.upcoming.overdueNote', { count: data.overdue_count })}</span>
            </p>
          ) : null}
          <ul className="divide-y divide-line">
            {data.upcoming.map((item, index) => (
              <UpcomingRow
                key={`${item.entity_type}-${item.entity_id}-${item.occurrence_id ?? item.kind}-${item.date}-${String(index)}`}
                item={item}
                today={data.today}
              />
            ))}
          </ul>
        </>
      )}
    </PlanningWidgetCard>
  );
}
