import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon, type IconName } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { ExternalLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { supportApi } from '../api';
import { MessageThread } from '../components/MessageThread';
import { RequestStatusBadge } from '../components/RequestStatusBadge';
import { useSupportQueue } from '../hooks';
import { supportKeys } from '../keys';
import {
  REQUEST_KINDS,
  REQUEST_STATUSES,
  STAFF_ACTIONS,
  isRequestKind,
  isRequestStatus,
  kindIcon,
  kindLabel,
  staffActionLabel,
  statusLabel,
} from '../labels';
import type { StaffRequest, StaffStatus } from '../types';

/** The API returns at most this many requests per page of the queue. */
const QUEUE_LIMIT = 200;

const actionIcon: Readonly<Record<StaffStatus, IconName>> = {
  in_progress: 'clock',
  resolved: 'check-circle',
  closed: 'archive',
};

/** Security and privacy reports come first in the queue (the API orders them). */
const PRIORITY_KINDS: ReadonlySet<string> = new Set(['security', 'privacy']);

function statusChangeError(error: unknown, t: Translate): string {
  if (domainRuleCode(error)?.code === 'request_closed') return t('support.queue.alreadyClosed');
  if (hasErrorCode(error, 'NOT_FOUND')) return t('support.queue.gone');
  return describeError(error, t);
}

/** A reply link; each part of the address is encoded so it cannot add mailto fields. */
function mailtoLink(email: string, subject: string): string {
  const address = email.split('@').map(encodeURIComponent).join('@');
  return `mailto:${address}?subject=${encodeURIComponent(subject)}`;
}

interface QueueItemProps {
  request: StaffRequest;
  pendingStatus: StaffStatus | null;
  onChange: (request: StaffRequest, status: StaffStatus) => void;
}

function QueueItem({ request, pendingStatus, onChange }: QueueItemProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const received = parseTimestamp(request.created_at);
  const updated = parseTimestamp(request.updated_at);
  const priority = PRIORITY_KINDS.has(request.kind);
  const actions = STAFF_ACTIONS.filter((status) => status !== request.status);
  const client = [request.client_kind, request.app_version].filter(Boolean).join(' ');
  const [showThread, setShowThread] = useState(false);
  const threadId = useId();
  return (
    <li className="space-y-3 py-5 first:pt-0 last:pb-0">
      <div className="flex flex-wrap items-center gap-2">
        <StatusBadge tone={priority ? 'warning' : 'neutral'} icon={kindIcon[request.kind]}>
          {t(kindLabel[request.kind])}
        </StatusBadge>
        <RequestStatusBadge status={request.status} />
      </div>
      <h3 className="break-words text-base font-semibold text-fg">{request.subject}</h3>
      <dl className="grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
        <div className="flex flex-wrap gap-1">
          <dt className="text-fg-muted">{t('support.queue.reference')}</dt>
          <dd>
            <code className="font-mono text-fg">{request.reference}</code>
          </dd>
        </div>
        {received ? (
          <div className="flex flex-wrap gap-1">
            <dt className="text-fg-muted">{t('support.queue.received')}</dt>
            <dd className="text-fg">
              <time dateTime={request.created_at}>
                {formatDateTime(received, formatLocale, user.timezone)}
              </time>
            </dd>
          </div>
        ) : null}
        {updated && request.updated_at !== request.created_at ? (
          <div className="flex flex-wrap gap-1">
            <dt className="text-fg-muted">{t('support.queue.updated')}</dt>
            <dd className="text-fg">
              <time dateTime={request.updated_at}>
                {formatDateTime(updated, formatLocale, user.timezone)}
              </time>
            </dd>
          </div>
        ) : null}
        <div className="flex flex-wrap gap-1">
          <dt className="text-fg-muted">{t('support.queue.source')}</dt>
          <dd className="text-fg">
            {request.signed_in ? t('support.queue.fromAccount') : t('support.queue.fromContact')}
          </dd>
        </div>
        {request.contact_email ? (
          <div className="flex min-w-0 flex-wrap gap-1">
            <dt className="text-fg-muted">{t('support.queue.replyTo')}</dt>
            <dd className="min-w-0 break-all">
              <ExternalLink
                href={mailtoLink(
                  request.contact_email,
                  t('support.queue.replySubject', { reference: request.reference }),
                )}
              >
                {request.contact_email}
              </ExternalLink>
            </dd>
          </div>
        ) : null}
        {client ? (
          <div className="flex flex-wrap gap-1">
            <dt className="text-fg-muted">{t('support.queue.client')}</dt>
            <dd className="text-fg">{client}</dd>
          </div>
        ) : null}
      </dl>
      <Disclosure summary={t('support.queue.showMessage')}>
        {/* User-written text: rendered as plain text only. */}
        <p className="break-words whitespace-pre-wrap rounded-lg bg-surface-muted p-3 text-sm text-fg">
          {request.body}
        </p>
      </Disclosure>
      {request.signed_in ? (
        <div>
          <Button
            variant="ghost"
            size="sm"
            aria-expanded={showThread}
            aria-controls={threadId}
            onClick={() => {
              setShowThread((value) => !value);
            }}
          >
            <Icon name="message-square" className="size-4" />
            {showThread
              ? t('support.queue.hideThread')
              : t('support.queue.showThread', { count: request.message_count })}
          </Button>
          <div id={threadId} hidden={!showThread} className="mt-3">
            {showThread ? (
              <MessageThread
                requestId={request.id}
                closed={request.status === 'closed'}
                audience="staff"
              />
            ) : null}
          </div>
        </div>
      ) : (
        <p className="text-sm text-fg-muted">{t('support.queue.contactByEmail')}</p>
      )}
      {request.status === 'closed' ? (
        <p className="text-sm text-fg-muted">{t('support.queue.closedNote')}</p>
      ) : (
        <div className="flex flex-wrap gap-2">
          {actions.map((status) => (
            <Button
              key={status}
              variant="secondary"
              size="sm"
              loading={pendingStatus === status}
              aria-label={t('support.queue.actionFor', {
                action: t(staffActionLabel[status]),
                reference: request.reference,
              })}
              onClick={() => {
                onChange(request, status);
              }}
            >
              <Icon name={actionIcon[status]} className="size-4" />
              {t(staffActionLabel[status])}
            </Button>
          ))}
        </div>
      )}
    </li>
  );
}

/** Support staff: the request queue, security and privacy first. Every change is audited. */
export function SupportQueuePage() {
  const { t } = useI18n();
  useDocumentTitle(t('support.queue.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const [params, setParams] = useSearchParams();
  const statusParam = params.get('status');
  const kindParam = params.get('kind');
  const filters = {
    ...(isRequestStatus(statusParam) ? { status: statusParam } : {}),
    ...(isRequestKind(kindParam) ? { kind: kindParam } : {}),
  };
  const queue = useSupportQueue(filters);
  const [closing, setClosing] = useState<StaffRequest | null>(null);
  const [closeError, setCloseError] = useState<string | null>(null);

  const change = useMutation({
    mutationFn: ({ request, status }: { request: StaffRequest; status: StaffStatus }) =>
      supportApi.setStatus(request.id, status),
    onSettled: () => queryClient.invalidateQueries({ queryKey: supportKeys.queueAll() }),
  });

  const announceDone = (updated: StaffRequest) => {
    toast.show({
      tone: 'success',
      title: t('support.queue.changed', {
        reference: updated.reference,
        status: t(statusLabel[updated.status]),
      }),
    });
  };

  const onChange = (request: StaffRequest, status: StaffStatus) => {
    if (change.isPending) return;
    if (status === 'closed') {
      // Closing is final: the API refuses any later change.
      setCloseError(null);
      setClosing(request);
      return;
    }
    change.mutate(
      { request, status },
      {
        onSuccess: announceDone,
        onError: (error) => {
          toast.show({
            tone: 'danger',
            title: t('support.queue.changeFailed'),
            description: statusChangeError(error, t),
          });
        },
      },
    );
  };

  const confirmClose = () => {
    if (!closing || change.isPending) return;
    setCloseError(null);
    change.mutate(
      { request: closing, status: 'closed' },
      {
        onSuccess: (updated) => {
          announceDone(updated);
          setClosing(null);
        },
        onError: (error) => {
          setCloseError(statusChangeError(error, t));
        },
      },
    );
  };

  const setFilter = (key: 'status' | 'kind', value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next, { replace: true });
  };

  const filtered = Boolean(filters.status ?? filters.kind);
  let content;
  if (queue.isPending) {
    content = <LoadingState label={t('support.queue.loading')} />;
  } else if (queue.isError) {
    content = hasErrorCode(queue.error, 'FORBIDDEN') ? (
      <PermissionDenied
        titleAs="h3"
        title={t('support.queue.forbidden.title')}
        description={t('support.queue.forbidden.body')}
      />
    ) : (
      <ErrorState
        title={t('support.queue.error')}
        error={queue.error}
        retrying={queue.isFetching}
        onRetry={() => {
          void queue.refetch();
        }}
      />
    );
  } else if (queue.data.length === 0) {
    content = (
      <EmptyState
        icon="inbox"
        title={filtered ? t('support.queue.emptyFiltered.title') : t('support.queue.empty.title')}
        description={
          filtered ? t('support.queue.emptyFiltered.body') : t('support.queue.empty.body')
        }
      />
    );
  } else {
    const pending = change.isPending ? change.variables : undefined;
    content = (
      <>
        <p className="mb-4 text-sm text-fg-muted" role="status">
          {queue.data.length >= QUEUE_LIMIT
            ? t('support.queue.countCapped', { count: queue.data.length })
            : t('support.queue.count', { count: queue.data.length })}
        </p>
        <ul className="divide-y divide-line">
          {queue.data.map((request) => (
            <QueueItem
              key={request.id}
              request={request}
              pendingStatus={
                pending?.request.id === request.id && pending.status !== 'closed'
                  ? pending.status
                  : null
              }
              onChange={onChange}
            />
          ))}
        </ul>
      </>
    );
  }

  return (
    <>
      <PageHeader title={t('support.queue.title')} description={t('support.queue.description')} />
      <div className="space-y-6">
        <Alert tone="info" title={t('support.queue.audited.title')}>
          <p>{t('support.queue.audited.body')}</p>
        </Alert>
        <Card title={t('support.queue.listTitle')}>
          <div className="mb-5 grid gap-4 sm:grid-cols-2">
            <Select
              label={t('support.queue.filterStatus')}
              value={filters.status ?? ''}
              placeholder={t('support.queue.allStatuses')}
              options={REQUEST_STATUSES.map((value) => ({
                value,
                label: t(statusLabel[value]),
              }))}
              optional
              onChange={(event) => {
                setFilter('status', event.target.value);
              }}
            />
            <Select
              label={t('support.queue.filterKind')}
              value={filters.kind ?? ''}
              placeholder={t('support.queue.allKinds')}
              options={REQUEST_KINDS.map((value) => ({ value, label: t(kindLabel[value]) }))}
              optional
              onChange={(event) => {
                setFilter('kind', event.target.value);
              }}
            />
          </div>
          {content}
        </Card>
      </div>
      <ConfirmDialog
        open={closing !== null}
        onOpenChange={(open) => {
          if (!open) setClosing(null);
        }}
        title={t('support.queue.close.title')}
        description={t('support.queue.close.body', { reference: closing?.reference ?? '' })}
        confirmLabel={t('support.queue.close.confirm')}
        onConfirm={confirmClose}
        pending={change.isPending}
        error={closeError}
      />
    </>
  );
}
