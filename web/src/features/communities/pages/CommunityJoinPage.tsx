import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { readFragmentToken } from '@/features/auth/fragmentToken';
import { useFragmentToken } from '@/features/auth/hooks/useFragmentToken';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityPath, paths } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { communitiesApi } from '../api';
import { PersonName } from '../components/PersonName';
import { useCommunityError } from '../errors';
import { refreshCommunity, storeCommunity } from '../keys';
import type { CommunityInvitationPreview, InvitationStatus } from '../types';

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
      setError(t('communities.join.paste.invalid'));
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
        label={t('communities.join.paste.label')}
        help={t('communities.join.paste.help')}
        autoComplete="off"
        spellCheck={false}
        value={value}
        error={error ?? undefined}
        onChange={(event) => {
          setValue(event.target.value);
        }}
      />
      <Button type="submit" variant="secondary">
        {t('communities.join.paste.submit')}
      </Button>
    </form>
  );
}

/** Why a link cannot be used, by the status the preview reports (`active` never lands here). */
const unusable: Readonly<
  Record<Exclude<InvitationStatus, 'active'>, { title: MessageKey; body: MessageKey }>
> = {
  used: { title: 'communities.join.used.title', body: 'communities.join.used.body' },
  declined: { title: 'communities.join.invalid.title', body: 'communities.join.invalid.body' },
  revoked: { title: 'communities.join.revoked.title', body: 'communities.join.revoked.body' },
  expired: { title: 'communities.join.expired.title', body: 'communities.join.expired.body' },
};

function UnusableLink({
  title,
  body,
  onToken,
}: {
  title: string;
  body: string;
  onToken: (token: string) => void;
}) {
  const { t } = useI18n();
  return (
    <Card>
      <EmptyState
        titleAs="h2"
        icon="clock"
        title={title}
        description={body}
        action={<ButtonLink to={paths.communities}>{t('communities.backToList')}</ButtonLink>}
      />
      <PasteLinkForm onToken={onToken} />
    </Card>
  );
}

function AlreadyMember({ preview }: { preview: CommunityInvitationPreview | null }) {
  const { t } = useI18n();
  return (
    <Card>
      <EmptyState
        titleAs="h2"
        icon="users"
        title={t('communities.join.member.title')}
        description={
          preview
            ? t('communities.join.member.bodyNamed', { name: preview.community_name })
            : t('communities.join.member.body')
        }
        action={
          preview ? (
            <ButtonLink to={communityPath(preview.community_id)}>
              {t('communities.join.member.open')}
            </ButtonLink>
          ) : (
            <ButtonLink to={paths.communities}>{t('communities.join.member.action')}</ButtonLink>
          )
        }
      />
    </Card>
  );
}

/**
 * Joins a community from an invitation link (`/communities/join#token=…`).
 * The token is read from the fragment once and the fragment is removed
 * from the address bar and history right away; it is sent only in request
 * bodies: first to preview what the link is for (the community, who
 * created the link, how many members, whether it still works), then when
 * the person chooses to join.
 */
export function CommunityJoinPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('communities.join.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const linkToken = useFragmentToken();
  const [pastedToken, setPastedToken] = useState<string | null>(null);
  const token = pastedToken ?? linkToken;
  const preview = useMutation({ ...sensitiveMutation, mutationFn: communitiesApi.previewLink });
  const accept = useMutation({ ...sensitiveMutation, mutationFn: communitiesApi.acceptLink });
  const { mutate: loadPreview } = preview;

  useEffect(() => {
    if (token) loadPreview(token);
  }, [token, loadPreview]);

  const join = () => {
    if (!token || accept.isPending) return;
    accept.mutate(token, {
      onSuccess: (community) => {
        storeCommunity(queryClient, community);
        void refreshCommunity(queryClient, community.id);
        toast.show({
          tone: 'success',
          title: t('communities.membership.joined', { name: community.name }),
        });
        void navigate(communityPath(community.id), { replace: true });
      },
    });
  };

  const takePastedToken = (next: string) => {
    accept.reset();
    setPastedToken(next);
  };

  let body;
  if (!token) {
    body = (
      <Card>
        <EmptyState
          titleAs="h2"
          icon="link"
          title={t('communities.join.missing.title')}
          description={t('communities.join.missing.body')}
        />
        <PasteLinkForm onToken={takePastedToken} />
      </Card>
    );
  } else if (
    (accept.isError && hasErrorCode(accept.error, 'GONE')) ||
    (preview.isError && hasErrorCode(preview.error, 'GONE'))
  ) {
    body = (
      <UnusableLink
        title={t('communities.join.invalid.title')}
        body={t('communities.join.invalid.body')}
        onToken={takePastedToken}
      />
    );
  } else if (accept.isError && hasErrorCode(accept.error, 'CONFLICT')) {
    // 409 already_member: the link worked for this person before.
    body = <AlreadyMember preview={preview.data ?? null} />;
  } else if (
    (accept.isError && hasErrorCode(accept.error, 'FORBIDDEN')) ||
    (preview.isError && hasErrorCode(preview.error, 'FORBIDDEN'))
  ) {
    body = (
      <Card>
        <EmptyState
          titleAs="h2"
          icon="ban"
          title={t('communities.join.banned.title')}
          description={
            <>
              <p>{t('communities.join.banned.body')}</p>
              <p className="mt-2">
                <TextLink to={paths.myModeration}>{t('communities.notice.appealLink')}</TextLink>
              </p>
            </>
          }
        />
      </Card>
    );
  } else if (preview.isError) {
    body = (
      <Card>
        <ErrorState
          titleAs="h2"
          title={t('communities.join.previewError')}
          error={preview.error}
          retrying={preview.isPending}
          onRetry={() => {
            loadPreview(token);
          }}
        />
      </Card>
    );
  } else if (!preview.isSuccess) {
    body = (
      <Card>
        <LoadingState label={t('communities.join.loading')} />
      </Card>
    );
  } else if (preview.data.already_member) {
    body = <AlreadyMember preview={preview.data} />;
  } else if (preview.data.status !== 'active') {
    const why = unusable[preview.data.status];
    body = <UnusableLink title={t(why.title)} body={t(why.body)} onToken={takePastedToken} />;
  } else {
    const invitation = preview.data;
    const failure = accept.isError ? describe(accept.error) : null;
    const expires = parseTimestamp(invitation.expires_at);
    body = (
      <Card>
        <div className="space-y-6">
          <div className="flex gap-4">
            <span className="inline-flex size-12 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
              <Icon name="users" className="size-6" />
            </span>
            <div className="min-w-0 space-y-1">
              <h2 className="text-lg font-semibold break-words text-fg">
                {t('communities.join.invitedTo', { name: invitation.community_name })}
              </h2>
              <p className="text-sm text-fg-muted">{t('communities.join.invitedBody')}</p>
            </div>
          </div>
          <Facts>
            <Fact label={t('communities.join.members')}>
              {t('communities.memberCount', { count: invitation.member_count })}
            </Fact>
            {invitation.invited_by ? (
              <Fact label={t('communities.join.invitedBy')}>
                <PersonName
                  name={invitation.invited_by.display_name}
                  username={invitation.invited_by.username}
                />
              </Fact>
            ) : null}
            {expires ? (
              <Fact label={t('communities.join.expiresLabel')}>
                <time dateTime={invitation.expires_at}>
                  {formatDateTime(expires, formatLocale, user.timezone)}
                </time>
              </Fact>
            ) : null}
          </Facts>
          <Alert tone="info">{t('communities.join.privacy')}</Alert>
          <FormAlert message={failure} />
          <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <ButtonLink to={paths.communities} variant="ghost">
              {t('communities.join.notNow')}
            </ButtonLink>
            <Button loading={accept.isPending} onClick={join}>
              <Icon name="user-plus" className="size-4" />
              {t('communities.join.submit')}
            </Button>
          </div>
        </div>
      </Card>
    );
  }

  return (
    <>
      <PageHeader
        title={t('communities.join.title')}
        description={t('communities.join.description')}
      />
      {body}
    </>
  );
}
