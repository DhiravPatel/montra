import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { CopyButton } from '@/shared/components/CopyButton';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityJoinLink } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { communitiesApi, useCommunityInvitations } from '../../api';
import { conflictCode, useCommunityError } from '../../errors';
import { communitiesKeys } from '../../keys';
import {
  invitationKindLabel,
  invitationStatusIcon,
  invitationStatusLabel,
  invitationStatusTone,
} from '../../labels';
import type { Community, CommunityInvitation, CommunityInvitationInput } from '../../types';
import { PersonName } from '../PersonName';

type InviteKind = 'link' | 'username';

const EXPIRY_DAYS = [1, 3, 7, 14, 30] as const;
/** Usernames are 3-30 of a-z 0-9 _ . (the API also accepts a leading @). */
const USERNAME = /^@?[a-z0-9_.]{3,30}$/u;

/**
 * The one-time link, built from the token in the create response. It lives
 * only in this component's memory: never stored, logged or put in a URL of
 * this app (only in the link people copy).
 */
function NewLink({
  token,
  expiresAt,
  onDone,
}: {
  token: string;
  expiresAt: string;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const link = communityJoinLink(window.location.origin, token);
  const expires = parseTimestamp(expiresAt);
  return (
    <Alert tone="success" live="polite" title={t('communities.settings.invite.linkReady')}>
      <p>{t('communities.settings.invite.linkOnce')}</p>
      {expires ? (
        <p>
          {t('communities.settings.invite.linkExpires', {
            date: formatDateTime(expires, formatLocale, user.timezone),
          })}
        </p>
      ) : null}
      <TextField
        label={t('communities.settings.invite.linkLabel')}
        readOnly
        value={link}
        onFocus={(event) => {
          event.currentTarget.select();
        }}
      />
      <div className="flex flex-wrap gap-2">
        <CopyButton value={link} label={t('communities.settings.invite.copy')} />
        <Button size="sm" variant="secondary" onClick={onDone}>
          {t('common.done')}
        </Button>
      </div>
    </Alert>
  );
}

/** Invites a person by username, or creates a link that works once. */
function InviteForm({ community }: { community: Community }) {
  const { t } = useI18n();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const [kind, setKind] = useState<InviteKind>('link');
  const [days, setDays] = useState('7');
  const [username, setUsername] = useState('');
  const [usernameError, setUsernameError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [created, setCreated] = useState<{ token: string; expiresAt: string } | null>(null);
  const create = useMutation({
    // The response may carry the one-time token: keep no copy in the mutation cache.
    ...sensitiveMutation,
    mutationFn: (body: CommunityInvitationInput) =>
      communitiesApi.createInvitation(community.id, body),
    onSettled: () =>
      queryClient.invalidateQueries({ queryKey: communitiesKeys.invitationsOf(community.id) }),
  });

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (create.isPending) return;
    setFormError(null);
    const body: CommunityInvitationInput = { expires_in_days: Number(days) };
    let name = '';
    if (kind === 'username') {
      name = username.trim().toLowerCase();
      if (!USERNAME.test(name)) {
        setUsernameError(t('communities.settings.invite.usernameInvalid'));
        return;
      }
      name = name.replace(/^@/u, '');
      body.username = name;
    }
    setUsernameError(null);
    create.mutate(body, {
      onSuccess: (invitation) => {
        if (invitation.token) {
          setCreated({ token: invitation.token, expiresAt: invitation.expires_at });
          toast.show({ tone: 'success', title: t('communities.settings.invite.linkCreated') });
        } else {
          setUsername('');
          toast.show({
            tone: 'success',
            title: t('communities.settings.invite.sent', { username: name }),
          });
        }
      },
      onError: (error) => {
        if (kind === 'username' && hasErrorCode(error, 'NOT_FOUND')) {
          setUsernameError(t('communities.settings.invite.usernameNotFound'));
          return;
        }
        if (kind === 'username' && conflictCode(error) === 'already_member') {
          setUsernameError(t('communities.settings.invite.alreadyMember'));
          return;
        }
        setFormError(describe(error));
      },
    });
  };

  if (created) {
    return (
      <NewLink
        token={created.token}
        expiresAt={created.expiresAt}
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
        legend={t('communities.settings.invite.kind')}
        value={kind}
        onChange={(value) => {
          setKind(value);
          setFormError(null);
          setUsernameError(null);
        }}
        options={[
          { value: 'link', label: t('communities.settings.invite.kind.link') },
          { value: 'username', label: t('communities.settings.invite.kind.username') },
        ]}
      />
      {kind === 'username' ? (
        <TextField
          label={t('communities.settings.invite.username')}
          help={t('communities.settings.invite.usernameHelp')}
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
      <Select
        className="sm:max-w-xs"
        label={t('communities.settings.invite.expiry')}
        value={days}
        options={EXPIRY_DAYS.map((count) => ({
          value: String(count),
          label: t('communities.settings.invite.days', { count }),
        }))}
        onChange={(event) => {
          setDays(event.target.value);
        }}
      />
      <p className="text-sm text-fg-muted">
        {kind === 'link'
          ? t('communities.settings.invite.linkHelp')
          : t('communities.settings.invite.usernameNote')}
      </p>
      <Button type="submit" loading={create.isPending}>
        <Icon name={kind === 'link' ? 'link' : 'user-plus'} className="size-4" />
        {kind === 'link'
          ? t('communities.settings.invite.createLink')
          : t('communities.settings.invite.send')}
      </Button>
    </form>
  );
}

/** What an invitation was for: the person invited, or a link. */
function InvitationWho({ invitation }: { invitation: CommunityInvitation }) {
  const { t } = useI18n();
  if (invitation.kind === 'username') {
    return invitation.invitee ? (
      <PersonName name={invitation.invitee.display_name} username={invitation.invitee.username} />
    ) : (
      <span className="font-medium text-fg">{t('communities.settings.invite.list.someone')}</span>
    );
  }
  return (
    <span className="font-medium text-fg">{t('communities.settings.invite.list.linkItem')}</span>
  );
}

/**
 * The invitations moderators sent (active ones, or every status), with
 * who sent them and Revoke for the ones that still work. Tokens are never
 * shown again.
 */
function InvitationList({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const [includeInactive, setIncludeInactive] = useState(false);
  const invitations = useCommunityInvitations(community.id, includeInactive);
  const [revoking, setRevoking] = useState<CommunityInvitation | null>(null);
  const [error, setError] = useState<string | null>(null);
  const revoke = useMutation({
    mutationFn: (invitation: CommunityInvitation) =>
      communitiesApi.revokeInvitation(community.id, invitation.id),
    onSettled: () =>
      queryClient.invalidateQueries({ queryKey: communitiesKeys.invitationsOf(community.id) }),
  });

  const date = (value: string | undefined) => {
    const parsed = parseTimestamp(value);
    return parsed ? formatDateTime(parsed, formatLocale, user.timezone) : null;
  };

  const confirmRevoke = () => {
    if (!revoking || revoke.isPending) return;
    setError(null);
    revoke.mutate(revoking, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('communities.settings.invite.list.revoked') });
        setRevoking(null);
      },
      onError: (failure) => {
        if (conflictCode(failure) === 'invitation_inactive' || hasErrorCode(failure, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('communities.settings.invite.list.inactive') });
          setRevoking(null);
          return;
        }
        setError(describe(failure));
      },
    });
  };

  let content;
  if (invitations.isPending) {
    content = <LoadingState label={t('communities.settings.invite.list.loading')} />;
  } else if (invitations.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.settings.invite.list.error')}
        error={invitations.error}
        retrying={invitations.isFetching}
        onRetry={() => {
          void invitations.refetch();
        }}
      />
    );
  } else if (invitations.data.length === 0) {
    content = (
      <EmptyState
        titleAs="p"
        icon="mail"
        title={
          includeInactive
            ? t('communities.settings.invite.list.emptyAll')
            : t('communities.settings.invite.list.empty')
        }
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line" aria-busy={invitations.isFetching || undefined}>
        {invitations.data.map((invitation) => {
          const created = date(invitation.created_at);
          const expires = date(invitation.expires_at);
          const inviter = invitation.invited_by;
          return (
            <li
              key={invitation.id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start"
            >
              <div className="min-w-0 flex-1 space-y-1">
                <InvitationWho invitation={invitation} />
                <div className="flex flex-wrap gap-2">
                  <StatusBadge tone="neutral" icon={invitation.kind === 'link' ? 'link' : 'user'}>
                    {t(invitationKindLabel[invitation.kind])}
                  </StatusBadge>
                  <StatusBadge
                    tone={invitationStatusTone[invitation.status]}
                    icon={invitationStatusIcon[invitation.status]}
                  >
                    {t(invitationStatusLabel[invitation.status])}
                  </StatusBadge>
                </div>
                <p className="text-sm text-fg-muted">
                  {[
                    inviter
                      ? t('communities.settings.invite.list.by', {
                          name:
                            inviter.user_id === user.id
                              ? t('communities.mod.you')
                              : inviter.username
                                ? `${inviter.display_name} (@${inviter.username})`
                                : inviter.display_name,
                        })
                      : null,
                    created
                      ? t('communities.settings.invite.list.created', { date: created })
                      : null,
                    expires && invitation.status === 'active'
                      ? t('communities.settings.invite.list.expires', { date: expires })
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </p>
              </div>
              {invitation.status === 'active' && community.status === 'active' ? (
                <Button
                  size="sm"
                  variant="secondary"
                  className="shrink-0"
                  aria-label={
                    invitation.kind === 'username' && invitation.invitee
                      ? t('communities.settings.invite.list.revokeNamed', {
                          name: invitation.invitee.display_name,
                        })
                      : t('communities.settings.invite.list.revokeLink')
                  }
                  onClick={() => {
                    setError(null);
                    setRevoking(invitation);
                  }}
                >
                  <Icon name="ban" className="size-4" />
                  {t('communities.settings.invite.list.revoke')}
                </Button>
              ) : null}
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <div className="space-y-4 border-t border-line pt-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h3 className="text-base font-semibold text-fg">
            {t('communities.settings.invite.list.title')}
          </h3>
          <p className="text-sm text-fg-muted">
            {t('communities.settings.invite.list.description')}
          </p>
        </div>
        <Checkbox
          label={t('communities.settings.invite.list.includeInactive')}
          checked={includeInactive}
          onChange={(event) => {
            setIncludeInactive(event.target.checked);
          }}
        />
      </div>
      {content}
      <ConfirmDialog
        open={revoking !== null}
        onOpenChange={(open) => {
          if (!open) setRevoking(null);
        }}
        title={
          revoking?.kind === 'username' && revoking.invitee
            ? t('communities.settings.invite.list.revokeTitleNamed', {
                name: revoking.invitee.display_name,
              })
            : t('communities.settings.invite.list.revokeTitle')
        }
        description={t('communities.settings.invite.list.revokeBody')}
        confirmLabel={t('communities.settings.invite.list.revokeConfirm')}
        pending={revoke.isPending}
        error={error}
        onConfirm={confirmRevoke}
      />
    </div>
  );
}

/**
 * Inviting people (by username, or with a link that works once) and the
 * invitations already sent, which moderators can revoke while they are
 * still active.
 */
export function InvitationsSection({ community }: { community: Community }) {
  const { t } = useI18n();
  return (
    <Card
      title={t('communities.settings.invite.title')}
      description={t('communities.settings.invite.description')}
    >
      <div className="space-y-6">
        {community.status === 'active' ? (
          <InviteForm community={community} />
        ) : (
          <p className="text-sm text-fg-muted">{t('communities.settings.invite.paused')}</p>
        )}
        <InvitationList community={community} />
      </div>
    </Card>
  );
}
