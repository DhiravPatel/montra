import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Dialog } from '@/shared/components/Dialog';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useFriends } from '@/shared/finance/sharing';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import { canChangeRole, canInvite, canRemoveMember } from '../../access';
import { groupsApi } from '../../api';
import { groupErrorMessage, shouldReloadGroup } from '../../errors';
import { groupsKeys, refreshGroups } from '../../keys';
import type { AddMemberInput, GroupDetail, GroupMember } from '../../types';
import { actionFor, memberName } from '../../people';
import { MemberRow } from '../MemberRow';

interface RoleChange {
  member: GroupMember;
  role: 'admin' | 'member';
}

/** Members with role changes and removal for owners and admins, plus adding friends. */
export function MembersSection({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  const me = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [removing, setRemoving] = useState<GroupMember | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const active = group.members.filter((member) => member.status === 'active');
  const former = group.members.filter((member) => member.status !== 'active');

  const changeRole = useMutation({
    mutationFn: ({ member, role }: RoleChange) =>
      groupsApi.updateMember(group.id, member.user_id, { role }),
    onSuccess: (updated) => {
      queryClient.setQueryData(groupsKeys.group(updated.id), updated);
      void refreshGroups(queryClient);
    },
  });
  const remove = useMutation({
    mutationFn: (member: GroupMember) => groupsApi.removeMember(group.id, member.user_id),
    // Their recurring bills are paused for the admins: personal calendars change too.
    onSuccess: () => refreshGroups(queryClient, { personal: true }),
  });

  const onChangeRole = (change: RoleChange) => {
    if (changeRole.isPending) return;
    changeRole.mutate(change, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title:
            change.role === 'admin'
              ? t('groups.members.madeAdmin', { name: change.member.display_name })
              : t('groups.members.madeMember', { name: change.member.display_name }),
        });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('groups.members.roleFailed'),
          description: groupErrorMessage(error, t, {
            codes: { NOT_FOUND: 'groups.members.notFound' },
          }),
        });
        if (shouldReloadGroup(error)) reload();
      },
    });
  };

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setRemoveError(null);
    remove.mutate(removing, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: t('groups.members.removed', { name: removing.display_name }),
        });
        setRemoving(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('groups.members.notFound') });
          setRemoving(null);
          reload();
          return;
        }
        setRemoveError(
          groupErrorMessage(error, t, {
            // Removal with an open balance is allowed; this stays for older servers.
            rules: { balance_open: 'groups.members.remove.balanceOpen' },
          }),
        );
        if (shouldReloadGroup(error)) reload();
      },
    });
  };

  const rolePending = (member: GroupMember) =>
    changeRole.isPending && changeRole.variables.member.user_id === member.user_id;

  return (
    <Card
      title={t('groups.members.title')}
      description={t('groups.settings.members.description')}
      actions={
        canInvite(group) ? (
          <Button
            size="sm"
            onClick={() => {
              setAdding(true);
            }}
          >
            <Icon name="user-plus" className="size-4" />
            {t('groups.members.add')}
          </Button>
        ) : undefined
      }
    >
      <ul className="divide-y divide-line">
        {active.map((member) => {
          const roleAllowed = canChangeRole(group, member, me.id);
          const removeAllowed = canRemoveMember(group, member, me.id);
          return (
            <MemberRow
              key={member.user_id}
              member={member}
              isMe={member.user_id === me.id}
              timezone={me.timezone}
            >
              {roleAllowed ? (
                <Button
                  size="sm"
                  variant="secondary"
                  loading={rolePending(member)}
                  aria-label={actionFor(
                    member.role === 'admin'
                      ? t('groups.members.makeMember')
                      : t('groups.members.makeAdmin'),
                    member.display_name,
                  )}
                  onClick={() => {
                    onChangeRole({ member, role: member.role === 'admin' ? 'member' : 'admin' });
                  }}
                >
                  <Icon name={member.role === 'admin' ? 'user' : 'shield'} className="size-4" />
                  {member.role === 'admin'
                    ? t('groups.members.makeMember')
                    : t('groups.members.makeAdmin')}
                </Button>
              ) : null}
              {removeAllowed ? (
                <Button
                  size="sm"
                  variant="secondary"
                  aria-label={actionFor(t('groups.members.remove'), member.display_name)}
                  onClick={() => {
                    setRemoveError(null);
                    setRemoving(member);
                  }}
                >
                  <Icon name="x-circle" className="size-4" />
                  {t('groups.members.remove')}
                </Button>
              ) : null}
            </MemberRow>
          );
        })}
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
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('groups.members.remove.title', { name: removing?.display_name ?? '' })}
        description={
          <>
            <p>{t('groups.members.remove.body')}</p>
            <p>{t('groups.members.remove.balanceNote')}</p>
          </>
        }
        confirmLabel={t('groups.members.remove.confirm')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={removeError}
      />
      <AddFriendDialog group={group} open={adding} onOpenChange={setAdding} reload={reload} />
    </Card>
  );
}

/**
 * Invites a friend by their user ID (POST /groups/{id}/members); they join
 * when they accept. Friends are found even when they turned username
 * discovery off, so every friend who is not a member can be chosen.
 */
function AddFriendDialog({
  group,
  open,
  onOpenChange,
  reload,
}: {
  group: GroupDetail;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  reload: () => void;
}) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('groups.members.addTitle')}
      description={t('groups.members.addDescription')}
      busy={pending}
    >
      {open ? (
        <AddFriendForm
          group={group}
          onPendingChange={setPending}
          reload={reload}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function AddFriendForm({
  group,
  onPendingChange,
  onDone,
  reload,
}: {
  group: GroupDetail;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
  reload: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const friends = useFriends();
  const [userId, setUserId] = useState('');
  const [personError, setPersonError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const add = useMutation({
    mutationFn: (body: AddMemberInput) => groupsApi.addMember(group.id, body),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: groupsKeys.group(group.id) }),
  });

  if (friends.isPending) return <LoadingState label={t('groups.members.friendsLoading')} />;
  if (friends.isError) {
    return (
      <ErrorState
        titleAs="p"
        title={t('groups.members.friendsError')}
        error={friends.error}
        retrying={friends.isFetching}
        onRetry={() => {
          void friends.refetch();
        }}
      />
    );
  }

  const inGroup = new Set(
    group.members.filter((member) => member.status === 'active').map((member) => member.user_id),
  );
  const candidates = friends.data
    .filter((friend) => !inGroup.has(friend.user_id))
    .sort((a, b) => a.display_name.localeCompare(b.display_name));

  if (candidates.length === 0) {
    return (
      <div className="space-y-5">
        <p className="text-sm text-fg-muted">{t('groups.members.noFriends')}</p>
        <div className="flex justify-end">
          <Button variant="secondary" onClick={onDone}>
            {t('common.close')}
          </Button>
        </div>
      </div>
    );
  }

  const submit = () => {
    if (add.isPending) return;
    setFormError(null);
    const friend = candidates.find((candidate) => candidate.user_id === userId);
    if (!friend) {
      setPersonError(t('groups.members.friendRequired'));
      return;
    }
    setPersonError(null);
    onPendingChange(true);
    add.mutate(
      { user_id: friend.user_id },
      {
        onSuccess: () => {
          onPendingChange(false);
          toast.show({
            tone: 'success',
            title: t('groups.members.invited', { name: memberName(friend) }),
          });
          onDone();
        },
        onError: (error) => {
          onPendingChange(false);
          if (hasErrorCode(error, 'NOT_FOUND')) {
            setPersonError(t('groups.invite.friendNotFound'));
            return;
          }
          setFormError(
            groupErrorMessage(error, t, { codes: { CONFLICT: 'groups.invite.alreadyMember' } }),
          );
          if (shouldReloadGroup(error)) reload();
        },
      },
    );
  };

  return (
    <form
      noValidate
      className="space-y-5"
      onSubmit={(event) => {
        event.preventDefault();
        submit();
      }}
    >
      <FormAlert message={formError} />
      <Select
        label={t('groups.members.friend')}
        placeholder={t('groups.members.friendPlaceholder')}
        help={t('groups.members.friendHelp')}
        options={candidates.map((friend) => ({ value: friend.user_id, label: memberName(friend) }))}
        value={userId}
        error={personError ?? undefined}
        onChange={(event) => {
          setUserId(event.target.value);
        }}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={add.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={add.isPending}>
          {t('groups.members.addSubmit')}
        </Button>
      </div>
    </form>
  );
}
