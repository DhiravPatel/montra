import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { supportRequestPath } from '@/shared/config/paths';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useMyRequests } from '../hooks';
import { kindLabel } from '../labels';
import { RequestStatusBadge } from './RequestStatusBadge';

/** The signed-in user's requests (newest first, as the API returns them). */
export function MyRequestsList() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const requests = useMyRequests();

  let content;
  if (requests.isPending) {
    content = <LoadingState label={t('support.mine.loading')} />;
  } else if (requests.isError) {
    content = hasErrorCode(requests.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        title={t('support.mine.error')}
        error={requests.error}
        retrying={requests.isFetching}
        onRetry={() => {
          void requests.refetch();
        }}
      />
    );
  } else if (requests.data.length === 0) {
    content = (
      <EmptyState
        icon="inbox"
        title={t('support.mine.empty.title')}
        description={t('support.mine.empty.body')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {requests.data.map((request) => {
          const sent = parseTimestamp(request.created_at);
          return (
            <li key={request.id} className="space-y-1.5 py-4 first:pt-0 last:pb-0">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <TextLink to={supportRequestPath(request.id)} className="min-w-0 break-words">
                  {request.subject}
                </TextLink>
                <RequestStatusBadge status={request.status} />
              </div>
              <p className="text-sm text-fg-muted">
                {[
                  t(kindLabel[request.kind]),
                  t('support.reference', { reference: request.reference }),
                  sent
                    ? t('support.sentOn', { date: formatDate(sent, formatLocale, user.timezone) })
                    : null,
                  request.message_count > 0
                    ? t('support.mine.messages', { count: request.message_count })
                    : null,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <Card title={t('support.mine.title')} description={t('support.mine.description')}>
      {content}
    </Card>
  );
}
