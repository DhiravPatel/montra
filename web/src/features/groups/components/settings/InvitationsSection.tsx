import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useId, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { CopyButton } from '@/shared/components/CopyButton';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupJoinLink } from '@/shared/config/paths';
import { usableShareUrl } from '@/shared/utils/shareUrl';
import { useFriends } from '@/shared/finance/sharing';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { canInvite, isGroupAdmin } from '../../access';
import { groupsApi, useGroupInvitations } from '../../api';
import { groupErrorMessage, isUsernameOrUserIdError, shouldReloadGroup } from '../../errors';
import { groupsKeys } from '../../keys';
import { actionFor, memberName, personName } from '../../people';
import { invitationStatusIcon, invitationStatusLabel, invitationStatusTone } from '../../labels';
import type { GroupDetail, GroupInvitation, GroupInvitationInput } from '../../types';

/**
 * How to invite: a link, a friend (by user ID, so friends who turned
 * username discovery off can be invited too) or someone by their exact
 * username. The last two are `kind: username` invitations for the API.
 */
type InviteKind = 'link' | 'friend' | 'username';

const EXPIRY_DAYS = [1, 3, 7, 14, 30] as const;
const MAX_USES = ['', '1', '5', '10', '25', '50'] as const;
/** Usernames are 3-30 of a-z 0-9 _ . (the API also accepts a leading @). */
const USERNAME = /^@?[a-z0-9_.]{3,30}$/;

/**
 * The one-time link from the create response: the API's `share_url`, or
 * built from the token when there is none. It lives only in this
 * component's memory: never stored, logged or put in a URL.
 */
function NewLink({
  token,
  shareUrl,
  onDone,
}: {
  token: string;
  shareUrl: string | null;
  onDone: () => void;
}) {
  const { t } = useI18n();
  const link = shareUrl ?? groupJoinLink(window.location.origin, token);
  return (
    <Alert tone="success" live="polite" title={t('groups.invite.linkReady')}>
      <p>{t('groups.invite.linkOnce')}</p>
      <TextField
        label={t('groups.invite.linkLabel')}
        readOnly
        value={link}
        onFocus={(event) => {
          event.currentTarget.select();
        }}
      />
      <div className="flex flex-wrap gap-2">
        <CopyButton value={link} label={t('groups.invite.copy')} />
        <Button size="sm" variant="secondary" onClick={onDone}>
          {t('common.done')}
        </Button>
      </div>
    </Alert>
  );
}

/** Friends who are not active members, as choices for a friend invitation. */
function FriendChoice({
  group,
  value,
  error,
  onChange,
}: {
  group: GroupDetail;
  value: string;
  error: string | null;
  onChange: (userId: string) => void;
}) {
  const { t } = useI18n();
  const friends = useFriends();
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
  const options = friends.data
    .filter((friend) => !inGroup.has(friend.user_id))
    .sort((a, b) => a.display_name.localeCompare(b.display_name))
    .map((friend) => ({ value: friend.user_id, label: memberName(friend) }));
  if (options.length === 0) {
    return <p className="text-sm text-fg-muted">{t('groups.members.noFriends')}</p>;
  }
  return (
    <Select
      label={t('groups.invite.friend')}
      help={t('groups.invite.friendHelp')}
      placeholder={t('groups.members.friendPlaceholder')}
      options={options}
      value={value}
      error={error ?? undefined}
      onChange={(event) => {
        onChange(event.target.value);
      }}
    />
  );
}

function CreateInvitationForm({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [kind, setKind] = useState<InviteKind>('link');
  const [days, setDays] = useState('7');
  const [maxUses, setMaxUses] = useState('');
  const [username, setUsername] = useState('');
  const [friendId, setFriendId] = useState('');
  const [usernameError, setUsernameError] = useState<string | null>(null);
  const [friendError, setFriendError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [created, setCreated] = useState<{ token: string; shareUrl: string | null } | null>(null);
  const create = useMutation({
    // The response may carry the one-time token: keep no copy in the mutation cache.
    ...sensitiveMutation,
    mutationFn: (body: GroupInvitationInput) => groupsApi.createInvitation(group.id, body),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: groupsKeys.group(group.id) }),
  });

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (create.isPending) return;
    setFormError(null);
    const body: GroupInvitationInput = {
      kind: kind === 'link' ? 'link' : 'username',
      expires_in_days: Number(days),
    };
    if (kind === 'username') {
      const name = username.trim().toLowerCase();
      if (!USERNAME.test(name)) {
        setUsernameError(t('groups.invite.usernameInvalid'));
        return;
      }
      body.username = name.replace(/^@/, '');
    } else if (kind === 'friend') {
      if (!friendId) {
        setFriendError(t('groups.members.friendRequired'));
        return;
      }
      body.user_id = friendId;
    } else if (maxUses) {
      body.max_uses = Number(maxUses);
    }
    setUsernameError(null);
    setFriendError(null);
    create.mutate(body, {
      onSuccess: (invitation) => {
        if (invitation.kind === 'link' && invitation.token) {
          setCreated({ token: invitation.token, shareUrl: usableShareUrl(invitation.share_url) });
          toast.show({ tone: 'success', title: t('groups.invite.linkCreated') });
        } else {
          setUsername('');
          setFriendId('');
          toast.show({ tone: 'success', title: t('groups.invite.usernameSent') });
        }
      },
      onError: (error) => {
        if (kind === 'username' && hasErrorCode(error, 'NOT_FOUND')) {
          setUsernameError(t('groups.invite.usernameNotFound'));
          return;
        }
        if (kind === 'friend' && hasErrorCode(error, 'NOT_FOUND')) {
          setFriendError(t('groups.invite.friendNotFound'));
          return;
        }
        if (isUsernameOrUserIdError(error)) {
          if (kind === 'friend') setFriendError(t('groups.invite.usernameOrUserId'));
          else if (kind === 'username') setUsernameError(t('groups.invite.usernameOrUserId'));
          else setFormError(t('groups.invite.usernameOrUserId'));
          return;
        }
        setFormError(
          groupErrorMessage(error, t, { codes: { CONFLICT: 'groups.invite.alreadyMember' } }),
        );
        if (shouldReloadGroup(error)) reload();
      },
    });
  };

  if (created) {
    return (
      <NewLink
        token={created.token}
        shareUrl={created.shareUrl}
        onDone={() => {
          setCreated(null);
        }}
      />
    );
  }

  return (
    <form noValidate onSubmit={submit} className="space-y-5">
      <FormAlert message={formError} />
      <RadioGroup<InviteKind>
        legend={t('groups.invite.kind')}
        value={kind}
        onChange={(value) => {
          setKind(value);
          setFormError(null);
        }}
        options={[
          { value: 'link', label: t('groups.invite.kind.link') },
          { value: 'friend', label: t('groups.invite.kind.friend') },
          { value: 'username', label: t('groups.invite.kind.username') },
        ]}
      />
      {kind === 'friend' ? (
        <FriendChoice
          group={group}
          value={friendId}
          error={friendError}
          onChange={(userId) => {
            setFriendId(userId);
            setFriendError(null);
          }}
        />
      ) : null}
      {kind === 'username' ? (
        <TextField
          label={t('groups.invite.username')}
          help={t('groups.invite.usernameHelp')}
          autoComplete="off"
          autoCapitalize="none"
          spellCheck={false}
          maxLength={31}
          value={username}
          error={usernameError ?? undefined}
          onChange={(event) => {
            setUsername(event.target.value);
          }}
        />
      ) : null}
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('groups.invite.expiry')}
          value={days}
          options={EXPIRY_DAYS.map((count) => ({
            value: String(count),
            label: t('groups.invite.days', { count }),
          }))}
          onChange={(event) => {
            setDays(event.target.value);
          }}
        />
        {kind === 'link' ? (
          <Select
            label={t('groups.invite.maxUses')}
            value={maxUses}
            options={MAX_USES.map((uses) => ({
              value: uses,
              label: uses
                ? t('groups.invite.uses', { count: Number(uses) })
                : t('groups.invite.unlimited'),
            }))}
            onChange={(event) => {
              setMaxUses(event.target.value);
            }}
          />
        ) : null}
      </div>
      <p className="text-sm text-fg-muted">
        {kind === 'link' ? t('groups.invite.linkHelp') : t('groups.invite.usernameNote')}
      </p>
      <Button type="submit" loading={create.isPending}>
        <Icon name={kind === 'link' ? 'link' : 'user-plus'} className="size-4" />
        {kind === 'link' ? t('groups.invite.createLink') : t('groups.invite.send')}
      </Button>
    </form>
  );
}

function InvitationRow({
  invitation,
  onRevoke,
}: {
  invitation: GroupInvitation;
  onRevoke: (invitation: GroupInvitation) => void;
}) {
  const { t, formatLocale } = useI18n();
  const me = useCurrentUser();
  const expires = parseTimestamp(invitation.expires_at);
  const created = parseTimestamp(invitation.created_at);
  const link = invitation.kind === 'link';
  const uses =
    invitation.max_uses !== undefined
      ? t('groups.invite.usedOf', { count: invitation.use_count, max: invitation.max_uses })
      : t('groups.invite.used', { count: invitation.use_count });
  const invitedBy = invitation.invited_by
    ? invitation.invited_by.user_id === me.id
      ? t('groups.invite.invitedByYou')
      : t('groups.invite.invitedBy', { name: personName(invitation.invited_by) })
    : null;
  const details = [
    link ? uses : null,
    invitedBy,
    created
      ? t('groups.invite.created', { date: formatDateTime(created, formatLocale, me.timezone) })
      : null,
    expires && invitation.status === 'active'
      ? t('groups.invite.expires', { date: formatDateTime(expires, formatLocale, me.timezone) })
      : null,
  ].filter(Boolean);
  const title = link
    ? t('groups.invite.linkTitle')
    : invitation.invitee
      ? t('groups.invite.invitee', { name: personName(invitation.invitee) })
      : t('groups.invite.usernameTitle');
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="flex min-w-0 flex-1 gap-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
          <Icon name={link ? 'link' : 'user'} />
        </span>
        <div className="min-w-0 space-y-1">
          <p className="font-medium break-words text-fg">{title}</p>
          <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
          <StatusBadge
            tone={invitationStatusTone[invitation.status]}
            icon={invitationStatusIcon[invitation.status]}
          >
            {t(invitationStatusLabel[invitation.status])}
          </StatusBadge>
        </div>
      </div>
      {invitation.status === 'active' ? (
        <Button
          size="sm"
          variant="secondary"
          className="shrink-0"
          aria-label={actionFor(
            t('groups.invite.revoke'),
            created
              ? `${title}, ${t('groups.invite.created', {
                  date: formatDateTime(created, formatLocale, me.timezone),
                })}`
              : title,
          )}
          onClick={() => {
            onRevoke(invitation);
          }}
        >
          <Icon name="ban" className="size-4" />
          {t('groups.invite.revoke')}
        </Button>
      ) : null}
    </li>
  );
}

/**
 * Invitation links and username invitations. Admins see and manage every
 * invitation; members (when the group allows them to invite) see theirs.
 */
export function InvitationsSection({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const headingId = useId();
  const [showPast, setShowPast] = useState(false);
  const [revoking, setRevoking] = useState<GroupInvitation | null>(null);
  const [revokeError, setRevokeError] = useState<string | null>(null);
  const allowed = canInvite(group);
  const admin = isGroupAdmin(group.my_role);
  const invitations = useGroupInvitations(group.id, showPast);
  const revoke = useMutation({
    mutationFn: (invitation: GroupInvitation) =>
      groupsApi.revokeInvitation(group.id, invitation.id),
    onSettled: () => queryClient.invalidateQueries({ queryKey: groupsKeys.group(group.id) }),
  });

  const confirmRevoke = () => {
    if (!revoking || revoke.isPending) return;
    setRevokeError(null);
    revoke.mutate(revoking, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('groups.invite.revoked') });
        setRevoking(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('groups.invite.alreadyInactive') });
          setRevoking(null);
          return;
        }
        setRevokeError(groupErrorMessage(error, t));
        if (shouldReloadGroup(error)) reload();
      },
    });
  };

  let list;
  if (invitations.isPending) {
    list = <LoadingState label={t('groups.invite.loading')} />;
  } else if (invitations.isError) {
    list = (
      <ErrorState
        titleAs="p"
        title={t('groups.invite.error')}
        error={invitations.error}
        retrying={invitations.isFetching}
        onRetry={() => {
          void invitations.refetch();
        }}
      />
    );
  } else if (invitations.data.length === 0) {
    list = (
      <EmptyState
        titleAs="p"
        icon="mail"
        title={showPast ? t('groups.invite.emptyAll') : t('groups.invite.empty')}
      />
    );
  } else {
    list = (
      <ul className="divide-y divide-line">
        {invitations.data.map((invitation) => (
          <InvitationRow
            key={invitation.id}
            invitation={invitation}
            onRevoke={(target) => {
              setRevokeError(null);
              setRevoking(target);
            }}
          />
        ))}
      </ul>
    );
  }

  return (
    <Card
      title={t('groups.invite.title')}
      description={
        admin ? t('groups.invite.descriptionAdmin') : t('groups.invite.descriptionMember')
      }
    >
      <div className="space-y-6">
        {allowed ? (
          <CreateInvitationForm group={group} reload={reload} />
        ) : (
          <p className="text-sm text-fg-muted">
            {group.status === 'archived'
              ? t('groups.invite.archived')
              : t('groups.invite.notAllowed')}
          </p>
        )}
        <section aria-labelledby={headingId} className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h3 id={headingId} className="text-base font-semibold text-fg">
              {t('groups.invite.listTitle')}
            </h3>
            <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
              <input
                type="checkbox"
                checked={showPast}
                onChange={(event) => {
                  setShowPast(event.target.checked);
                }}
                className="size-4 accent-accent"
              />
              {t('groups.invite.showPast')}
            </label>
          </div>
          {list}
        </section>
      </div>
      <ConfirmDialog
        open={revoking !== null}
        onOpenChange={(open) => {
          if (!open) setRevoking(null);
        }}
        title={t('groups.invite.revokeTitle')}
        description={
          revoking?.kind === 'link'
            ? t('groups.invite.revokeLinkBody')
            : t('groups.invite.revokeUsernameBody')
        }
        confirmLabel={t('groups.invite.revokeConfirm')}
        onConfirm={confirmRevoke}
        pending={revoke.isPending}
        error={revokeError}
      />
    </Card>
  );
}
