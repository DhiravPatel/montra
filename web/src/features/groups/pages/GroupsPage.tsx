import { useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { groupPath, paths } from '@/shared/config/paths';
import { amountSign } from '@/shared/formatting/money';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useGroupsList } from '../api';
import { GroupStateBadges, GroupTypeBadge, RoleBadge } from '../components/GroupBadges';
import { InvitationsToMeCard } from '../components/InvitationsToMeCard';
import { groupTypeIcon, hasTripDetails, tripDates } from '../labels';
import type { Group } from '../types';

/**
 * The caller's balance in the group as the API derives it (positive: owed
 * to you; negative: you owe), shown with words and an icon, never a bare
 * sign.
 */
function MyNet({ group }: { group: Group }) {
  const { t } = useI18n();
  const formatMoney = useFormatMoney();
  const sign = amountSign(group.my_net.amount);
  if (sign === null) return null;
  const amount = formatMoney(group.my_net, { signDisplay: 'never' });
  return (
    <p className="flex items-center gap-1.5 text-sm text-fg">
      <Icon
        name={sign === 1 ? 'arrow-down' : sign === -1 ? 'arrow-up' : 'check-circle'}
        className="size-4 shrink-0 text-fg-muted"
      />
      {sign === 1
        ? t('groups.list.owed', { amount })
        : sign === -1
          ? t('groups.list.owe', { amount })
          : t('groups.list.settled')}
    </p>
  );
}

function GroupRow({ group }: { group: Group }) {
  const { t, formatLocale } = useI18n();
  const dates = hasTripDetails(group.group_type) ? tripDates(group, t, formatLocale) : null;
  const details = [
    t('groups.memberCount', { count: group.member_count }),
    dates,
    hasTripDetails(group.group_type) ? group.destination : null,
  ].filter(Boolean);
  return (
    <li className="flex gap-3 py-4 first:pt-0 last:pb-0">
      <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name={groupTypeIcon[group.group_type]} />
      </span>
      <div className="min-w-0 flex-1 space-y-1.5">
        <Link
          to={groupPath(group.id)}
          className="font-medium break-words text-fg underline-offset-4 hover:underline"
        >
          {group.name}
        </Link>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        <MyNet group={group} />
        <div className="flex flex-wrap gap-2">
          <GroupTypeBadge type={group.group_type} />
          {group.my_role === 'none' ? null : <RoleBadge role={group.my_role} />}
          <GroupStateBadges group={group} />
        </div>
      </div>
    </li>
  );
}

/** Your groups, households, trips and events, plus invitations waiting for you. */
export function GroupsPage() {
  const { t } = useI18n();
  useDocumentTitle(t('groups.title'));
  const [showArchived, setShowArchived] = useState(false);
  const groups = useGroupsList(showArchived);

  const createAction = (
    <ButtonLink to={paths.groupNew}>
      <Icon name="plus" className="size-4" />
      {t('groups.create.action')}
    </ButtonLink>
  );

  let content;
  if (groups.isPending) {
    content = <LoadingState label={t('groups.list.loading')} />;
  } else if (groups.isError) {
    content = hasErrorCode(groups.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('groups.list.error')}
        error={groups.error}
        retrying={groups.isFetching}
        onRetry={() => {
          void groups.refetch();
        }}
      />
    );
  } else if (groups.data.length === 0) {
    content = (
      <EmptyState
        icon="users"
        title={showArchived ? t('groups.list.emptyArchived') : t('groups.list.empty')}
        description={t('groups.list.emptyBody')}
        action={createAction}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {groups.data.map((group) => (
          <GroupRow key={group.id} group={group} />
        ))}
      </ul>
    );
  }

  return (
    <>
      <PageHeader
        title={t('groups.title')}
        description={t('groups.description')}
        actions={createAction}
      />
      <div className="space-y-6">
        <InvitationsToMeCard />
        <Card
          title={t('groups.list.title')}
          actions={
            <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
              <input
                type="checkbox"
                checked={showArchived}
                onChange={(event) => {
                  setShowArchived(event.target.checked);
                }}
                className="size-4 accent-accent"
              />
              {t('groups.list.showArchived')}
            </label>
          }
        >
          {content}
        </Card>
        <Card title={t('groups.joinByLink.title')}>
          <div className="space-y-2 text-sm text-fg-muted">
            <p>{t('groups.joinByLink.body')}</p>
            <p>{t('groups.joinByLink.privacy')}</p>
            <p>
              <TextLink to={paths.groupJoin}>{t('groups.joinByLink.paste')}</TextLink>
            </p>
          </div>
        </Card>
      </div>
    </>
  );
}
