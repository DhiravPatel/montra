import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { Disclosure } from '@/shared/components/Disclosure';
import { TextLink } from '@/shared/components/TextLink';
import { groupSettingsPath } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { canInvite, isGroupAdmin } from '../access';
import type { GroupDetail } from '../types';
import { MemberRow } from './MemberRow';

/**
 * Who is in the group: names, usernames and roles only. Former members
 * stay listed (their past expenses still count in the balances).
 */
export function GroupMembersCard({ group }: { group: GroupDetail }) {
  const t = useT();
  const me = useCurrentUser();
  const active = group.members.filter((member) => member.status === 'active');
  const former = group.members.filter((member) => member.status !== 'active');
  const manage = isGroupAdmin(group.my_role) || canInvite(group);
  return (
    <Card
      title={t('groups.members.title')}
      description={t('groups.memberCount', { count: active.length })}
      actions={
        manage ? (
          <TextLink to={groupSettingsPath(group.id)}>{t('groups.members.manage')}</TextLink>
        ) : undefined
      }
    >
      <ul className="divide-y divide-line">
        {active.map((member) => (
          <MemberRow
            key={member.user_id}
            member={member}
            isMe={member.user_id === me.id}
            timezone={me.timezone}
          />
        ))}
      </ul>
      {former.length > 0 ? (
        <Disclosure className="mt-4" summary={t('groups.members.former', { count: former.length })}>
          <p className="mb-3 text-sm text-fg-muted">{t('groups.members.formerHelp')}</p>
          <ul className="divide-y divide-line">
            {former.map((member) => (
              <MemberRow key={member.user_id} member={member} isMe={false} timezone={me.timezone} />
            ))}
          </ul>
        </Disclosure>
      ) : null}
    </Card>
  );
}
