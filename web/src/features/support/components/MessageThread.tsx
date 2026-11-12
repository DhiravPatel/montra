import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useCallback, useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useCountdown } from '@/shared/hooks/useCountdown';
import { describeError } from '@/shared/i18n/describeError';
import { formatWait } from '@/shared/i18n/formatWait';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { supportApi } from '../api';
import { containsSecretRefusal, dailyCapMessage, isRequestClosed } from '../errors';
import { useSupportMessages } from '../hooks';
import { supportKeys } from '../keys';
import { BODY_MAX } from '../requestForm';
import { containsSecret } from '../secrets';
import type { SupportMessage } from '../types';

/** Who reads the thread: the person who asked, or Montra's support team. */
export type ThreadAudience = 'requester' | 'staff';

interface Values {
  body: string;
}

function authorLabel(message: SupportMessage, audience: ThreadAudience, t: Translate): string {
  if (audience === 'requester') {
    return message.author_role === 'staff'
      ? t('support.thread.fromSupport')
      : t('support.thread.you');
  }
  if (message.author_role === 'requester') return t('support.thread.fromRequester');
  return message.mine ? t('support.thread.youSupport') : t('support.thread.fromSupport');
}

function MessageList({
  messages,
  audience,
}: {
  messages: readonly SupportMessage[];
  audience: ThreadAudience;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  return (
    <ol className="space-y-3" aria-label={t('support.thread.listLabel')}>
      {messages.map((message) => {
        const when = parseTimestamp(message.created_at);
        const fromSupport = message.author_role === 'staff';
        return (
          <li
            key={message.id}
            className={
              fromSupport
                ? 'rounded-lg border border-line bg-surface-muted p-3'
                : 'rounded-lg border border-line bg-surface p-3'
            }
          >
            <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
              <Icon
                name={fromSupport ? 'shield' : 'user'}
                className="size-4 shrink-0 text-fg-muted"
              />
              <span className="font-semibold text-fg">{authorLabel(message, audience, t)}</span>
              {when ? (
                <time dateTime={message.created_at} className="text-fg-muted">
                  {formatDateTime(when, formatLocale, user.timezone)}
                </time>
              ) : null}
            </p>
            {/* Written by a person: shown as plain text, exactly as sent. */}
            <p className="mt-2 break-words whitespace-pre-wrap text-fg">{message.body}</p>
          </li>
        );
      })}
    </ol>
  );
}

interface ReplyFormProps {
  requestId: string;
  audience: ThreadAudience;
  onClosed: () => void;
}

function ReplyForm({ requestId, audience, onClosed }: ReplyFormProps) {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const [deadline, setDeadline] = useState<number | null>(null);
  const remaining = useCountdown(deadline);
  const waitFor = useCallback((seconds: number) => {
    setDeadline(Date.now() + seconds * 1000);
  }, []);
  const waiting = remaining > 0;
  const schema = useMemo(
    () =>
      z.object({
        body: z
          .string()
          .trim()
          .min(1, { error: t('support.thread.bodyRequired') })
          .refine((value) => Array.from(value).length <= BODY_MAX, {
            error: t('validation.maxLength', { max: BODY_MAX }),
          })
          .refine((value) => !containsSecret(value), { error: t('support.form.secret') }),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: { body: '' },
  });
  const mutation = useMutation({
    mutationFn: (body: string) => supportApi.postMessage(requestId, { body }),
    onSuccess: (created) => {
      queryClient.setQueryData<SupportMessage[]>(supportKeys.messages(requestId), (list) =>
        list ? [...list.filter((item) => item.id !== created.id), created] : [created],
      );
      // The request's message count and last activity changed.
      void queryClient.invalidateQueries({ queryKey: supportKeys.request(requestId), exact: true });
      void queryClient.invalidateQueries({ queryKey: supportKeys.mine(), exact: true });
      if (audience === 'staff') {
        void queryClient.invalidateQueries({ queryKey: supportKeys.queueAll() });
      }
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || waiting) return;
    setFormError(null);
    try {
      await mutation.mutateAsync(values.body);
      form.reset({ body: '' });
      toast.show({ tone: 'success', title: t('support.thread.sent') });
    } catch (error) {
      if (containsSecretRefusal(error)) {
        form.setError(
          'body',
          { type: 'server', message: t('support.form.secret') },
          { shouldFocus: true },
        );
        return;
      }
      if (isRequestClosed(error)) {
        setFormError(t('support.thread.closedError'));
        onClosed();
        return;
      }
      const capped = dailyCapMessage(error, t);
      if (capped) {
        if (isApiError(error) && error.retryAfterSeconds) {
          waitFor(error.retryAfterSeconds);
        }
        setFormError(capped);
        return;
      }
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        form.setError(
          'body',
          { type: 'server', message: t('support.form.bodyRefused', { max: BODY_MAX }) },
          { shouldFocus: true },
        );
        return;
      }
      setFormError(describeError(error, t));
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-4">
      <FormAlert message={formError} />
      <TextArea
        label={audience === 'staff' ? t('support.thread.replyLabel') : t('support.thread.addLabel')}
        help={audience === 'staff' ? t('support.thread.staffHelp') : t('support.thread.help')}
        rows={4}
        maxLength={BODY_MAX}
        autoComplete="off"
        error={errors.body?.message}
        {...form.register('body')}
      />
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        {waiting ? (
          // Silent countdown: the error above was already announced.
          <p className="text-sm text-fg-muted" aria-live="off">
            {t('support.contact.retryIn', { wait: formatWait(t, remaining) })}
          </p>
        ) : (
          <span />
        )}
        <Button
          type="submit"
          loading={mutation.isPending}
          aria-disabled={waiting || mutation.isPending || undefined}
          className="sm:ms-auto"
        >
          <Icon name="mail" className="size-4" />
          {audience === 'staff' ? t('support.thread.sendReply') : t('support.thread.send')}
        </Button>
      </div>
    </form>
  );
}

interface MessageThreadProps {
  requestId: string;
  /** Closed requests take no new messages (the API answers 422 request_closed). */
  closed: boolean;
  audience: ThreadAudience;
  /** Called when the API says the request was closed meanwhile (reload it). */
  onClosed?: () => void;
}

/**
 * A request's conversation with Montra support, oldest first, and a form to
 * add to it. Messages are plain text; secrets are refused before sending.
 */
export function MessageThread({ requestId, closed, audience, onClosed }: MessageThreadProps) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const messages = useSupportMessages(requestId);

  const reload = () => {
    void queryClient.invalidateQueries({ queryKey: supportKeys.request(requestId), exact: true });
    onClosed?.();
  };

  let list;
  if (messages.isPending) {
    list = <LoadingState label={t('support.thread.loading')} />;
  } else if (messages.isError) {
    list = hasErrorCode(messages.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        titleAs="h3"
        title={t('support.thread.error')}
        error={messages.error}
        retrying={messages.isFetching}
        onRetry={() => {
          void messages.refetch();
        }}
      />
    );
  } else if (messages.data.length === 0) {
    list = (
      <EmptyState
        titleAs="h3"
        icon="message-square"
        title={t('support.thread.empty.title')}
        description={
          audience === 'staff' ? t('support.thread.empty.staff') : t('support.thread.empty.body')
        }
      />
    );
  } else {
    list = <MessageList messages={messages.data} audience={audience} />;
  }

  return (
    <div className="space-y-5">
      {list}
      {closed ? (
        <p className="flex items-start gap-1.5 text-sm text-fg-muted">
          <Icon name="archive" className="mt-0.5 size-4 shrink-0" />
          {audience === 'staff' ? t('support.thread.closedStaff') : t('support.thread.closed')}
        </p>
      ) : (
        <ReplyForm requestId={requestId} audience={audience} onClosed={reload} />
      )}
    </div>
  );
}
