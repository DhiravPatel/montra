import { useState } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextField } from '@/shared/components/TextField';
import { formatDateTime } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';
import { canActOnMember, restrictionEnd } from '../../access';
import { useCommunityMembers } from '../../api';
import type { Community, CommunityMember } from '../../types';
import { RoleBadge } from '../CommunityBadges';
import { PersonName } from '../PersonName';
import { type ActionTarget, ActionDialog } from './ActionDialog';

type View = 'active' | 'banned';

function matches(member: CommunityMember, filter: string): boolean {
  if (!filter) return true;
  const needle = filter.toLowerCase().replace(/^@/u, '');
  return (
    member.display_name.toLowerCase().includes(needle) ||
    (member.username ?? '').toLowerCase().includes(needle)
  );
}

/**
 * Members a moderator can warn, restrict or ban, and banned members who can
 * be let back in. Only the owner (and Montra staff) act on moderators.
 */
export function MembersModerationSection({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const now = useNow();
  const [view, setView] = useState<View>('active');
  const [filter, setFilter] = useState('');
  const members = useCommunityMembers(community.id, view);
  const [acting, setActing] = useState<ActionTarget | null>(null);

  let content;
  if (members.isPending) {
    content = <LoadingState label={t('communities.settings.members.loading')} />;
  } else if (members.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.settings.members.error')}
        error={members.error}
        retrying={members.isFetching}
        onRetry={() => {
          void members.refetch();
        }}
      />
    );
  } else {
    const shown = members.data.filter((member) => matches(member, filter.trim()));
    content =
      shown.length === 0 ? (
        <EmptyState
          titleAs="p"
          icon="users"
          title={
            view === 'banned'
              ? t('communities.mod.members.noneBanned')
              : t('communities.settings.members.none')
          }
        />
      ) : (
        <ul className="divide-y divide-line">
          {shown.map((member) => {
            const restricted = restrictionEnd(member.restricted_until, now);
            const name = member.display_name;
            const allowed = canActOnMember(community, user, member);
            return (
              <li
                key={member.user_id}
                className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
              >
                <div className="min-w-0 flex-1 space-y-1">
                  <PersonName name={name} username={member.username} />
                  <div className="flex flex-wrap gap-2">
                    {view === 'banned' ? (
                      <StatusBadge tone="danger" icon="ban">
                        {t('communities.mod.members.banned')}
                      </StatusBadge>
                    ) : (
                      <RoleBadge role={member.role} />
                    )}
                    {restricted ? (
                      <StatusBadge tone="warning" icon="clock">
                        {t('communities.settings.members.restricted', {
                          date: formatDateTime(restricted, formatLocale, user.timezone),
                        })}
                      </StatusBadge>
                    ) : null}
                  </div>
                </div>
                {allowed ? (
                  <Button
                    size="sm"
                    variant="secondary"
                    className="shrink-0"
                    aria-label={t('communities.mod.moderateMember', { name })}
                    onClick={() => {
                      setActing({
                        type: 'member',
                        id: member.user_id,
                        summary: member.username ? `${name} (@${member.username})` : name,
                        state: { banned: view === 'banned' },
                      });
                    }}
                  >
                    <Icon name="shield" className="size-4" />
                    {view === 'banned'
                      ? t('communities.action.unban')
                      : t('communities.mod.moderate')}
                  </Button>
                ) : null}
              </li>
            );
          })}
        </ul>
      );
  }

  return (
    <Card
      title={t('communities.mod.members.title')}
      description={t('communities.mod.members.description')}
    >
      <div className="space-y-5">
        <div className="flex flex-wrap items-end gap-4">
          <RadioGroup<View>
            legend={t('communities.mod.members.show')}
            value={view}
            onChange={setView}
            options={[
              { value: 'active', label: t('communities.mod.members.active') },
              { value: 'banned', label: t('communities.mod.members.bannedList') },
            ]}
          />
          <TextField
            type="search"
            className="min-w-56 flex-1"
            label={t('communities.settings.members.filter')}
            aria-required={false}
            autoComplete="off"
            value={filter}
            onChange={(event) => {
              setFilter(event.target.value);
            }}
          />
        </div>
        {content}
      </div>
      <ActionDialog
        communityId={community.id}
        target={acting}
        open={acting !== null}
        onOpenChange={(open) => {
          if (!open) setActing(null);
        }}
      />
    </Card>
  );
}
