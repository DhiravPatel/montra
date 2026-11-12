import { useParams } from 'react-router';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { TextLink } from '@/shared/components/TextLink';
import {
  groupBalancesPath,
  groupExpenseNewPath,
  groupRecurringPath,
  groupReportsPath,
  groupSettingsPath,
} from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { ActivityCard } from '../components/ActivityCard';
import { BalanceSummaryCard } from '../components/BalanceSummaryCard';
import { GroupAboutCard } from '../components/GroupAboutCard';
import { GroupStateBadges, GroupTypeBadge, RoleBadge } from '../components/GroupBadges';
import { GroupMembersCard } from '../components/GroupMembersCard';
import { BackToGroups, GroupPage } from '../components/GroupPage';
import { GroupSubNav } from '../components/GroupSubNav';
import { hasTripDetails, tripDates } from '../labels';
import type { GroupDetail } from '../types';

function QuickActions({ group }: { group: GroupDetail }) {
  const { t } = useI18n();
  const active = group.status === 'active';
  return (
    <nav aria-label={t('groups.detail.quickActions')} className="mb-6">
      <ul className="flex flex-wrap gap-2">
        {active ? (
          <li>
            <ButtonLink to={groupExpenseNewPath(group.id)}>
              <Icon name="plus" className="size-4" />
              {t('groups.detail.addExpense')}
            </ButtonLink>
          </li>
        ) : null}
        <li>
          <ButtonLink to={groupBalancesPath(group.id)} variant="secondary">
            <Icon name="handshake" className="size-4" />
            {t('groups.detail.settleUp')}
          </ButtonLink>
        </li>
        <li>
          <ButtonLink to={groupRecurringPath(group.id)} variant="secondary">
            <Icon name="repeat" className="size-4" />
            {t('groups.detail.recurring')}
          </ButtonLink>
        </li>
        <li>
          <ButtonLink to={groupReportsPath(group.id)} variant="secondary">
            <Icon name="bar-chart" className="size-4" />
            {t('groups.detail.reports')}
          </ButtonLink>
        </li>
      </ul>
    </nav>
  );
}

function Overview({ group }: { group: GroupDetail }) {
  const { t, formatLocale } = useI18n();
  const trip = hasTripDetails(group.group_type);
  const details = [
    t('groups.memberCount', { count: group.member_count }),
    trip ? tripDates(group, t, formatLocale) : null,
    trip ? group.destination : null,
  ].filter(Boolean);
  return (
    <>
      <BackToGroups />
      <PageHeader
        title={group.name}
        description={
          <div className="space-y-2">
            <p>{details.join(' · ')}</p>
            <div className="flex flex-wrap gap-2">
              <GroupTypeBadge type={group.group_type} />
              {group.my_role === 'none' ? null : <RoleBadge role={group.my_role} />}
              <GroupStateBadges group={group} />
            </div>
          </div>
        }
      />
      <GroupSubNav groupId={group.id} />
      {group.status === 'archived' ? (
        <Alert tone="warning" className="mb-6" title={t('groups.archived.title')}>
          <p>{t('groups.archived.body')}</p>
          {group.my_role === 'owner' ? (
            <TextLink to={groupSettingsPath(group.id)}>{t('groups.archived.restoreLink')}</TextLink>
          ) : null}
        </Alert>
      ) : null}
      <QuickActions group={group} />
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <ActivityCard group={group} />
        </div>
        <div className="space-y-6">
          <BalanceSummaryCard groupId={group.id} />
          <GroupMembersCard group={group} />
          <GroupAboutCard group={group} />
        </div>
      </div>
    </>
  );
}

/** A group's overview: your position, members, details and recent activity. */
export function GroupDetailPage() {
  const { t } = useI18n();
  const { groupId = '' } = useParams();
  // The title never carries the group's name (personal data).
  useDocumentTitle(t('groups.detail.documentTitle'));
  return (
    <GroupPage groupId={groupId} title={t('groups.detail.documentTitle')}>
      {({ group }) => <Overview group={group} />}
    </GroupPage>
  );
}
