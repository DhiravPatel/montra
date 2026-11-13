import { Link } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import type { CalendarItem } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { calendarItemPath } from '@/features/planning/calendarMonth';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

function RenewalRow({ item, today }: { item: CalendarItem; today: string }) {
  const { t, formatLocale } = useI18n();
  const trial = item.kind === 'trial_end';
  const date = formatLocalDate(item.date, formatLocale);
  // Renewals and trial ends belong to a subscription (its page).
  const href = calendarItemPath(item);
  let when: string;
  if (trial) {
    when =
      item.date === today
        ? t('dashboard.renewals.trialEndsToday')
        : t('dashboard.renewals.trialEnds', { date });
  } else {
    when =
      item.date === today
        ? t('dashboard.renewals.renewsToday')
        : t('dashboard.renewals.renews', { date });
  }
  return (
    <li className="flex items-start gap-3 py-3 first:pt-0">
      <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={trial ? 'clock' : 'refresh'} className="size-4" />
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
        <p className="text-sm text-fg-muted">
          <time dateTime={item.date}>{when}</time>
        </p>
      </div>
      {item.amount ? (
        <MoneyText money={item.amount} className="shrink-0 font-medium text-fg" />
      ) : null}
    </li>
  );
}

/**
 * Subscription renewals and trial ends from today through
 * `renewals_through`, soonest first, with the price the API expects.
 */
export function RenewalsWidget({ title, planning }: PlanningWidgetProps) {
  const { t, formatLocale } = useI18n();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={(data) =>
        data
          ? t('dashboard.renewals.scope', {
              date: formatLocalDate(data.renewals_through, formatLocale),
            })
          : t('dashboard.renewals.scopeGeneric')
      }
      loadingLabel={t('dashboard.renewals.loading')}
      errorTitle={t('dashboard.renewals.error')}
      total={(data) => data.renewal_count}
      countText={(data) =>
        t('dashboard.renewals.count', { count: data.renewal_count, shown: data.renewals.length })
      }
      viewAll={{
        to: paths.subscriptions,
        label: (count) => t('dashboard.renewals.viewAll', { count }),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="refresh"
          title={t('dashboard.renewals.empty')}
          description={t('dashboard.renewals.emptyBody')}
          action={
            <ButtonLink to={paths.subscriptionNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('dashboard.renewals.add')}
            </ButtonLink>
          }
        />
      }
    >
      {(data) => (
        <ul className="divide-y divide-line">
          {data.renewals.map((item, index) => (
            <RenewalRow
              key={`${item.entity_id}-${item.kind}-${item.date}-${String(index)}`}
              item={item}
              today={data.today}
            />
          ))}
        </ul>
      )}
    </PlanningWidgetCard>
  );
}
