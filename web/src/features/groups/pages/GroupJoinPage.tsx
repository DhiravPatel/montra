import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { readFragmentToken } from '@/features/auth/fragmentToken';
import { useFragmentToken } from '@/features/auth/hooks/useFragmentToken';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupPath, paths } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { groupsApi } from '../api';
import { groupConflictCode, groupErrorMessage } from '../errors';
import { groupsKeys, refreshGroups } from '../keys';
import { groupTypeName, isGroupType, groupTypeIcon } from '../labels';
import { personName } from '../people';
import type { InvitationPreview } from '../types';

/** Why a link cannot be used any more (preview `status` other than active). */
const unusable: Readonly<
  Record<Exclude<InvitationPreview['status'], 'active'>, { title: MessageKey; body: MessageKey }>
> = {
  expired: { title: 'groups.join.expired.title', body: 'groups.join.expired.body' },
  accepted: { title: 'groups.join.used.title', body: 'groups.join.used.body' },
  revoked: { title: 'groups.join.revoked.title', body: 'groups.join.revoked.body' },
  declined: { title: 'groups.join.revoked.title', body: 'groups.join.revoked.body' },
};

/**
 * Lets someone who arrived without a usable link (or lost it on the way,
 * e.g. through signing in) paste the invitation link. The token is read
 * from the link's fragment and kept in memory only.
 */
function PasteLinkForm({ onToken }: { onToken: (token: string) => void }) {
  const { t } = useI18n();
  const [value, setValue] = useState('');
  const [error, setError] = useState<string | null>(null);
  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    const text = value.trim();
    const hash = text.indexOf('#');
    const token = hash >= 0 ? readFragmentToken(text.slice(hash)) : null;
    if (!token) {
      setError(t('groups.join.paste.invalid'));
      return;
    }
    setError(null);
    setValue('');
    onToken(token);
  };
  return (
    <form noValidate onSubmit={submit} className="space-y-4">
      <TextField
        type="url"
        label={t('groups.join.paste.label')}
        help={t('groups.join.paste.help')}
        autoComplete="off"
        spellCheck={false}
        value={value}
        error={error ?? undefined}
        onChange={(event) => {
          setValue(event.target.value);
        }}
      />
      <Button type="submit" variant="secondary">
        {t('groups.join.paste.submit')}
      </Button>
    </form>
  );
}

/**
 * Joins a group from an invitation link (`/groups/join#token=…`). The
 * token is read from the fragment once, the fragment is removed from the
 * address bar and history, and the token is sent only in request bodies:
 * first to preview the group (who invited you, how many members, whether
 * the admins approve new members), then to join when the user confirms.
 * Groups that require approval answer with a pending join request instead.
 */
export function GroupJoinPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('groups.join.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const linkToken = useFragmentToken();
  const [pastedToken, setPastedToken] = useState<string | null>(null);
  const token = pastedToken ?? linkToken;
  const previewed = useRef<string | null>(null);
  const preview = useMutation({ ...sensitiveMutation, mutationFn: groupsApi.previewLink });
  const accept = useMutation({ ...sensitiveMutation, mutationFn: groupsApi.acceptLink });
  const { mutate: previewLink } = preview;
  const { reset: resetAccept } = accept;

  useEffect(() => {
    // Preview each token once, even when development mode runs effects twice.
    if (!token || previewed.current === token) return;
    previewed.current = token;
    resetAccept();
    previewLink(token);
  }, [token, previewLink, resetAccept]);

  const join = () => {
    if (!token || accept.isPending) return;
    accept.mutate(token, {
      onSuccess: (result) => {
        if (result.outcome === 'pending') {
          // The admins decide; the request shows up for them in the group's settings.
          toast.show({ tone: 'success', title: t('groups.join.requested.title') });
          return;
        }
        const { group } = result;
        queryClient.setQueryData(groupsKeys.group(group.id), group);
        void refreshGroups(queryClient);
        toast.show({ tone: 'success', title: t('groups.join.joined', { name: group.name }) });
        void navigate(groupPath(group.id), { replace: true });
      },
    });
  };

  let body;
  if (!token) {
    body = (
      <Card>
        <EmptyState
          titleAs="h2"
          icon="link"
          title={t('groups.join.missing.title')}
          description={t('groups.join.missing.body')}
        />
        <PasteLinkForm onToken={setPastedToken} />
      </Card>
    );
  } else if (preview.isError) {
    if (hasErrorCode(preview.error, 'GONE')) {
      body = (
        <Card>
          <EmptyState
            titleAs="h2"
            icon="link"
            title={t('groups.join.invalid.title')}
            description={t('groups.join.invalid.body')}
            action={<ButtonLink to={paths.groups}>{t('groups.backToList')}</ButtonLink>}
          />
          <PasteLinkForm onToken={setPastedToken} />
        </Card>
      );
    } else if (hasErrorCode(preview.error, 'FORBIDDEN')) {
      body = <PermissionDenied titleAs="h2" />;
    } else {
      body = (
        <ErrorState
          titleAs="h2"
          title={t('groups.join.previewFailed')}
          error={preview.error}
          onRetry={() => {
            previewLink(token);
          }}
        />
      );
    }
  } else if (!preview.isSuccess) {
    body = <LoadingState label={t('groups.join.checking')} />;
  } else if (preview.data.status !== 'active') {
    const copy = unusable[preview.data.status];
    body = (
      <Card>
        <EmptyState
          titleAs="h2"
          icon="clock"
          title={t(copy.title)}
          description={t(copy.body, { name: preview.data.group_name })}
          action={<ButtonLink to={paths.groups}>{t('groups.backToList')}</ButtonLink>}
        />
      </Card>
    );
  } else {
    const invitation = preview.data;
    const expires = parseTimestamp(invitation.expires_at);
    const conflict = accept.isError ? groupConflictCode(accept.error) : null;
    const gone = accept.isError && hasErrorCode(accept.error, 'GONE');
    // The API says so (409 already_member), or the preview did.
    const member = invitation.already_member || conflict === 'already_member';
    const requested = accept.isSuccess && accept.data.outcome === 'pending';
    const alreadyRequested = conflict === 'join_request_pending';
    const failure =
      accept.isError && !gone && !member && !alreadyRequested
        ? groupErrorMessage(accept.error, t, {
            // A 409 without a code (older server): either of the two.
            codes: { CONFLICT: 'groups.joinRequest.conflict' },
          })
        : null;
    const facts = [
      groupTypeName(invitation.group_type, t),
      t('groups.memberCount', { count: invitation.member_count }),
      expires
        ? t('groups.join.expires', {
            date: formatDateTime(expires, formatLocale, user.timezone),
          })
        : null,
    ].filter(Boolean);
    const finished = gone || member || requested || alreadyRequested;
    body = (
      <Card>
        <div className="space-y-6">
          <div className="flex gap-4">
            <span className="inline-flex size-12 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
              <Icon
                name={
                  isGroupType(invitation.group_type)
                    ? groupTypeIcon[invitation.group_type]
                    : 'users'
                }
                className="size-6"
              />
            </span>
            <div className="min-w-0 space-y-1">
              <h2 className="text-lg font-semibold break-words text-fg">
                {t('groups.join.invitedTo', { name: invitation.group_name })}
              </h2>
              <p className="text-sm text-fg-muted">{facts.join(' · ')}</p>
              {invitation.invited_by ? (
                <p className="text-sm break-words text-fg-muted">
                  {t('groups.join.invitedBy', { name: personName(invitation.invited_by) })}
                </p>
              ) : null}
            </div>
          </div>
          <Alert tone="info">{t('groups.join.privacy')}</Alert>
          {invitation.requires_approval && !finished ? (
            <Alert tone="info" title={t('groups.join.approval.title')}>
              {t('groups.join.approval.body')}
            </Alert>
          ) : null}
          <FormAlert message={failure} />
          {gone ? (
            <Alert tone="warning" live="assertive" title={t('groups.join.used.title')}>
              {t('groups.join.goneAfterPreview')}
            </Alert>
          ) : null}
          {member ? (
            <Alert tone="info" live="polite" title={t('groups.join.alreadyMember.title')}>
              <p>{t('groups.join.alreadyMember.body')}</p>
              <ButtonLink to={groupPath(invitation.group_id)} variant="secondary" size="sm">
                {t('groups.join.alreadyMember.open')}
              </ButtonLink>
            </Alert>
          ) : null}
          {requested ? (
            <Alert tone="success" live="polite" title={t('groups.join.requested.title')}>
              <p>{t('groups.join.requested.body', { name: invitation.group_name })}</p>
              <ButtonLink to={paths.groups} variant="secondary" size="sm">
                {t('groups.join.alreadyMember.action')}
              </ButtonLink>
            </Alert>
          ) : null}
          {alreadyRequested ? (
            <Alert tone="info" live="polite" title={t('groups.join.pending.title')}>
              <p>{t('groups.join.pending.body', { name: invitation.group_name })}</p>
              <ButtonLink to={paths.groups} variant="secondary" size="sm">
                {t('groups.join.alreadyMember.action')}
              </ButtonLink>
            </Alert>
          ) : null}
          {finished ? null : (
            <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <ButtonLink to={paths.groups} variant="ghost">
                {t('groups.join.notNow')}
              </ButtonLink>
              <Button loading={accept.isPending} onClick={join}>
                <Icon
                  name={invitation.requires_approval ? 'mail' : 'user-plus'}
                  className="size-4"
                />
                {invitation.requires_approval ? t('groups.join.request') : t('groups.join.submit')}
              </Button>
            </div>
          )}
        </div>
      </Card>
    );
  }

  return (
    <>
      <PageHeader title={t('groups.join.title')} description={t('groups.join.description')} />
      {body}
    </>
  );
}
