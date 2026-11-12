import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { TextLink } from '@/shared/components/TextLink';
import { groupRecurringPath } from '@/shared/config/paths';
import { currencyName } from '@/shared/currency/currencies';
import { useI18n } from '@/shared/i18n/I18nContext';
import { groupTypeLabel, hasTripDetails, isHome, splitMethodLabel, tripDates } from '../labels';
import type { GroupDetail } from '../types';

/** The group's settings as members see them (read-only). */
export function GroupFacts({ group }: { group: GroupDetail }) {
  const { t, formatLocale } = useI18n();
  const trip = hasTripDetails(group.group_type);
  const dates = trip ? tripDates(group, t, formatLocale) : null;
  return (
    <Facts>
      <Fact label={t('groups.about.type')}>{t(groupTypeLabel[group.group_type])}</Fact>
      {trip ? (
        <Fact label={t('groups.about.dates')}>{dates ?? t('groups.about.noDates')}</Fact>
      ) : null}
      {trip && group.destination ? (
        <Fact label={t('groups.about.destination')}>{group.destination}</Fact>
      ) : null}
      {group.description ? (
        <Fact label={t('groups.about.description')}>
          <span className="whitespace-pre-line">{group.description}</span>
        </Fact>
      ) : null}
      <Fact label={t('groups.about.currency')}>
        {`${currencyName(group.base_currency, formatLocale)} (${group.base_currency})`}
      </Fact>
      <Fact label={t('groups.about.timezone')}>{group.timezone.replaceAll('_', ' ')}</Fact>
      <Fact label={t('groups.about.split')}>{t(splitMethodLabel[group.default_split_method])}</Fact>
      <Fact label={t('groups.about.simplify')}>
        {group.simplify_debts ? t('groups.about.simplifyOn') : t('groups.about.simplifyOff')}
      </Fact>
      <Fact label={t('groups.about.invites')}>
        {group.allow_member_invites ? t('groups.about.invitesOn') : t('groups.about.invitesOff')}
      </Fact>
      <Fact label={t('groups.about.joinApproval')}>
        {group.require_join_approval
          ? t('groups.about.joinApprovalOn')
          : t('groups.about.joinApprovalOff')}
      </Fact>
      {group.rules ? (
        <Fact label={t('groups.about.rules')}>
          <span className="whitespace-pre-line">{group.rules}</span>
        </Fact>
      ) : null}
    </Facts>
  );
}

/** About the group, with trip reminders and household bills where they apply. */
export function GroupAboutCard({ group }: { group: GroupDetail }) {
  const { t } = useI18n();
  const trip = hasTripDetails(group.group_type);
  return (
    <Card title={t('groups.about.title')}>
      <div className="space-y-4">
        <GroupFacts group={group} />
        {trip && (group.start_date || group.end_date) ? (
          <p className="text-sm text-fg-muted">{t('groups.about.tripReminders')}</p>
        ) : null}
        {isHome(group.group_type) ? (
          <p className="text-sm text-fg-muted">
            {t('groups.about.homeBills')}{' '}
            <TextLink to={groupRecurringPath(group.id)}>{t('groups.about.homeBillsLink')}</TextLink>
          </p>
        ) : null}
      </div>
    </Card>
  );
}
