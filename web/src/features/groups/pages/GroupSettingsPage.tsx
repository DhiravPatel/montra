import { useParams } from 'react-router';
import { Alert } from '@/shared/components/Alert';
import { PageHeader } from '@/shared/components/PageHeader';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { BackToGroups, GroupPage } from '../components/GroupPage';
import { GroupSubNav } from '../components/GroupSubNav';
import { GroupDetailsSection } from '../components/settings/GroupDetailsSection';
import { InvitationsSection } from '../components/settings/InvitationsSection';
import { JoinRequestsSection } from '../components/settings/JoinRequestsSection';
import { LeaveSection } from '../components/settings/LeaveSection';
import { MembersSection } from '../components/settings/MembersSection';
import { NotificationsSection } from '../components/settings/NotificationsSection';
import { OwnerSection } from '../components/settings/OwnerSection';
import { roleLabel } from '../labels';

/**
 * Group settings. Every member sees this page; controls follow the user's
 * role (owner, admin, member) and the group's status, and the API remains
 * the authority (its permission answers are shown and the group reloaded).
 */
export function GroupSettingsPage() {
  const t = useT();
  const { groupId = '' } = useParams();
  useDocumentTitle(t('groups.settings.title'));
  return (
    <GroupPage groupId={groupId} title={t('groups.settings.title')}>
      {({ group, reload }) => (
        <>
          <BackToGroups />
          <PageHeader title={t('groups.settings.title')} description={group.name} />
          <GroupSubNav groupId={group.id} />
          {group.my_role === 'none' ? null : (
            <p className="mb-6 text-sm text-fg-muted">
              {t('groups.settings.yourRole', { role: t(roleLabel[group.my_role]) })}
            </p>
          )}
          {group.status === 'archived' ? (
            <Alert tone="warning" className="mb-6" title={t('groups.archived.title')}>
              {group.my_role === 'owner'
                ? t('groups.archived.ownerBody')
                : t('groups.archived.body')}
            </Alert>
          ) : null}
          <div className="space-y-6">
            <GroupDetailsSection group={group} reload={reload} />
            <NotificationsSection group={group} reload={reload} />
            <MembersSection group={group} reload={reload} />
            <InvitationsSection group={group} reload={reload} />
            <JoinRequestsSection group={group} reload={reload} />
            <OwnerSection group={group} reload={reload} />
            <LeaveSection group={group} reload={reload} />
          </div>
        </>
      )}
    </GroupPage>
  );
}
