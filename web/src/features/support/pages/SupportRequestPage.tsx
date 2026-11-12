import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { CopyButton } from '@/shared/components/CopyButton';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { MessageThread } from '../components/MessageThread';
import { RequestStatusBadge } from '../components/RequestStatusBadge';
import { useSupportRequest } from '../hooks';
import { kindLabel, statusExplanation } from '../labels';
import type { HelpLocationState } from './HelpPage';

function BackLink() {
  const { t } = useI18n();
  return (
    <p className="mb-2">
      <TextLink to={paths.help}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('support.backToHelp')}
      </TextLink>
    </p>
  );
}

/**
 * One of the user's support requests: its status, what was sent and the
 * conversation with Montra support (staff replies also send a notification).
 * A closed request takes no new messages: a follow-up is a new request that
 * quotes the reference.
 */
export function SupportRequestPage() {
  const { t, formatLocale } = useI18n();
  // The subject stays out of the tab title (it may be personal).
  useDocumentTitle(t('support.request.documentTitle'));
  const { requestId = '' } = useParams();
  const user = useCurrentUser();
  const query = useSupportRequest(requestId);

  if (query.isPending) {
    return (
      <>
        <BackLink />
        <PageHeader title={t('support.request.documentTitle')} />
        <LoadingState label={t('support.request.loading')}>
          <div className="space-y-4">
            <Skeleton className="h-28 w-full" />
            <Skeleton className="h-40 w-full" />
          </div>
        </LoadingState>
      </>
    );
  }
  if (query.isError) {
    let state;
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      state = (
        <EmptyState
          titleAs="h2"
          icon="inbox"
          title={t('support.request.notFound')}
          description={t('support.request.notFoundBody')}
          action={<ButtonLink to={paths.help}>{t('support.backToHelp')}</ButtonLink>}
        />
      );
    } else if (hasErrorCode(query.error, 'FORBIDDEN')) {
      state = <PermissionDenied titleAs="h2" />;
    } else {
      state = (
        <ErrorState
          titleAs="h2"
          title={t('support.request.error')}
          error={query.error}
          retrying={query.isFetching}
          onRetry={() => {
            void query.refetch();
          }}
        />
      );
    }
    return (
      <>
        <BackLink />
        <PageHeader title={t('support.request.documentTitle')} />
        {state}
      </>
    );
  }

  const request = query.data;
  const sent = parseTimestamp(request.created_at);
  const updated = parseTimestamp(request.updated_at);
  const lastMessage = parseTimestamp(request.last_message_at);
  const followUpState: HelpLocationState = { followUp: request.reference };
  const finished = request.status === 'resolved' || request.status === 'closed';

  return (
    <>
      <BackLink />
      <PageHeader
        title={request.subject}
        description={t('support.reference', { reference: request.reference })}
      />
      <div className="space-y-6">
        <Card title={t('support.request.statusTitle')}>
          <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-3">
              <RequestStatusBadge status={request.status} />
              <p className="text-sm text-fg-muted">{t(statusExplanation[request.status])}</p>
            </div>
            <Facts>
              <Fact label={t('support.request.kind')}>{t(kindLabel[request.kind])}</Fact>
              <Fact label={t('support.request.reference')}>
                <span className="flex flex-wrap items-center gap-2">
                  <code className="font-mono">{request.reference}</code>
                  <CopyButton value={request.reference} label={t('support.request.copy')} />
                </span>
              </Fact>
              {sent ? (
                <Fact label={t('support.request.sent')}>
                  <time dateTime={request.created_at}>
                    {formatDateTime(sent, formatLocale, user.timezone)}
                  </time>
                </Fact>
              ) : null}
              {updated ? (
                <Fact label={t('support.request.updated')}>
                  <time dateTime={request.updated_at}>
                    {formatDateTime(updated, formatLocale, user.timezone)}
                  </time>
                </Fact>
              ) : null}
              {lastMessage && request.last_message_at ? (
                <Fact label={t('support.request.lastMessage')}>
                  <time dateTime={request.last_message_at}>
                    {formatDateTime(lastMessage, formatLocale, user.timezone)}
                  </time>
                </Fact>
              ) : null}
            </Facts>
          </div>
        </Card>

        <Card title={t('support.request.messageTitle')}>
          {/* Shown as plain text, exactly as sent. */}
          <p className="break-words whitespace-pre-wrap text-fg">{request.body}</p>
        </Card>

        <Card
          title={t('support.request.repliesTitle')}
          description={t('support.request.repliesDescription')}
        >
          <MessageThread
            requestId={request.id}
            closed={request.status === 'closed'}
            audience="requester"
          />
          {finished ? (
            <div className="mt-5 space-y-3 border-t border-line pt-5 text-sm text-fg-muted">
              <p>{t('support.request.followUpFinished')}</p>
              <ButtonLink to={paths.help} state={followUpState} variant="secondary">
                <Icon name="mail" className="size-4" />
                {t('support.request.followUpAction')}
              </ButtonLink>
            </div>
          ) : null}
        </Card>
      </div>
    </>
  );
}
