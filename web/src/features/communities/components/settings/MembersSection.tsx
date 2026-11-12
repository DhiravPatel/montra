import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDate, formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';
import { isOwner, restrictionEnd } from '../../access';
import { communitiesApi, useCommunityMembers } from '../../api';
import { useCommunityError } from '../../errors';
import { communitiesKeys } from '../../keys';
import type { Community, CommunityMember } from '../../types';
import { RoleBadge } from '../CommunityBadges';
import { PersonName } from '../PersonName';

interface RoleChange {
  member: CommunityMember;
  role: 'moderator' | 'member';
}

function matches(member: CommunityMember, filter: string): boolean {
  if (!filter) return true;
  const needle = filter.toLowerCase().replace(/^@/u, '');
  return (
    member.display_name.toLowerCase().includes(needle) ||
    (member.username ?? '').toLowerCase().includes(needle)
  );
}

/**
 * Active members with their roles. The owner makes members moderators (or
 * back); moderators see the list. Only names and usernames are shown.
 */
export function MembersSection({
  community,
  reload,
}: {
  community: Community;
  reload: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const now = useNow();
  const owner = isOwner(community);
  const members = useCommunityMembers(community.id, 'active');
  const [filter, setFilter] = useState('');
  const [changing, setChanging] = useState<RoleChange | null>(null);
  const [error, setError] = useState<string | null>(null);
  const setRole = useMutation({
    mutationFn: ({ member, role }: RoleChange) =>
      communitiesApi.setRole(community.id, member.user_id, role),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: communitiesKeys.membersOf(community.id) }),
        queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(community.id) }),
      ]),
  });

  const confirm = () => {
    if (!changing || setRole.isPending) return;
    setError(null);
    setRole.mutate(changing, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title:
            changing.role === 'moderator'
              ? t('communities.settings.members.madeModerator', {
                  name: changing.member.display_name,
                })
              : t('communities.settings.members.madeMember', {
                  name: changing.member.display_name,
                }),
        });
        setChanging(null);
      },
      onError: (failure) => {
        setError(
          describe(failure, { codes: { NOT_FOUND: 'communities.settings.members.notMember' } }),
        );
        if (hasErrorCode(failure, 'FORBIDDEN')) reload();
      },
    });
  };

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
    content = (
      <div className="space-y-4">
        <TextField
          type="search"
          label={t('communities.settings.members.filter')}
          aria-required={false}
          autoComplete="off"
          value={filter}
          onChange={(event) => {
            setFilter(event.target.value);
          }}
        />
        <p className="text-sm text-fg-muted" role="status">
          {t('communities.settings.members.count', { count: shown.length })}
        </p>
        {shown.length === 0 ? (
          <EmptyState titleAs="p" icon="users" title={t('communities.settings.members.none')} />
        ) : (
          <ul className="divide-y divide-line">
            {shown.map((member) => {
              const joined = parseTimestamp(member.joined_at);
              const restricted = restrictionEnd(member.restricted_until, now);
              const canChange = owner && member.role !== 'owner' && member.user_id !== user.id;
              const name = member.display_name;
              return (
                <li
                  key={member.user_id}
                  className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
                >
                  <div className="min-w-0 flex-1 space-y-1">
                    <PersonName name={name} username={member.username} />
                    {joined ? (
                      <p className="text-sm text-fg-muted">
                        {t('communities.settings.members.joined', {
                          date: formatDate(joined, formatLocale, user.timezone),
                        })}
                      </p>
                    ) : null}
                    <div className="flex flex-wrap gap-2">
                      <RoleBadge role={member.role} />
                      {restricted ? (
                        <StatusBadge tone="warning" icon="clock">
                          {t('communities.settings.members.restricted', {
                            date: formatDateTime(restricted, formatLocale, user.timezone),
                          })}
                        </StatusBadge>
                      ) : null}
                    </div>
                  </div>
                  {canChange ? (
                    <Button
                      size="sm"
                      variant="secondary"
                      className="shrink-0"
                      aria-label={
                        member.role === 'moderator'
                          ? t('communities.settings.members.removeModeratorNamed', { name })
                          : t('communities.settings.members.makeModeratorNamed', { name })
                      }
                      onClick={() => {
                        setError(null);
                        setChanging({
                          member,
                          role: member.role === 'moderator' ? 'member' : 'moderator',
                        });
                      }}
                    >
                      <Icon name="shield" className="size-4" />
                      {member.role === 'moderator'
                        ? t('communities.settings.members.removeModerator')
                        : t('communities.settings.members.makeModerator')}
                    </Button>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </div>
    );
  }

  return (
    <Card
      title={t('communities.settings.members.title')}
      description={
        owner
          ? t('communities.settings.members.descriptionOwner')
          : t('communities.settings.members.descriptionModerator')
      }
    >
      {content}
      <ConfirmDialog
        open={changing !== null}
        onOpenChange={(open) => {
          if (!open) setChanging(null);
        }}
        tone="primary"
        title={
          changing?.role === 'moderator'
            ? t('communities.settings.members.makeTitle', { name: changing.member.display_name })
            : t('communities.settings.members.removeTitle', {
                name: changing?.member.display_name ?? '',
              })
        }
        description={
          changing?.role === 'moderator'
            ? t('communities.settings.members.makeBody')
            : t('communities.settings.members.removeBody')
        }
        confirmLabel={
          changing?.role === 'moderator'
            ? t('communities.settings.members.makeModerator')
            : t('communities.settings.members.removeModerator')
        }
        pending={setRole.isPending}
        error={error}
        onConfirm={confirm}
      />
    </Card>
  );
}
