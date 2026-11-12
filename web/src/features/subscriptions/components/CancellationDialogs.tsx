import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { ExternalLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { errorDetailCode, isStaleRecordError } from '@/shared/finance/domainErrors';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { SubscriptionActionInput, SubscriptionDetail } from '@/shared/finance/types';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { useI18n, useT } from '@/shared/i18n/I18nContext';
import { subscriptionsApi } from '../api';
import { subscriptionErrorMessage } from '../errors';

interface DialogProps {
  subscription: SubscriptionDetail;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/**
 * A lifecycle step sent with the version on screen. When the subscription
 * changed meanwhile (stale version, or a status the step no longer fits)
 * the latest version is loaded.
 */
function useLifecycle(
  subscription: SubscriptionDetail,
  action: 'cancellation-started' | 'cancelled',
) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: SubscriptionActionInput) =>
      subscriptionsApi.act(subscription.id, action, subscription.version, body),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.subscription(updated.id), updated);
      void invalidateFinance(queryClient);
    },
    onError: (error) => {
      if (isStaleRecordError(error)) {
        void queryClient.invalidateQueries({ queryKey: financeKeys.subscription(subscription.id) });
      }
    },
  });
}

/** Date and note fields shared by both steps. */
function WhenAndNote({
  dateLabel,
  date,
  onDate,
  dateError,
  note,
  onNote,
}: {
  dateLabel: string;
  date: string;
  onDate: (value: string) => void;
  dateError?: string;
  note: string;
  onNote: (value: string) => void;
}) {
  const t = useT();
  return (
    <>
      <TextField
        type="date"
        label={dateLabel}
        value={date}
        error={dateError}
        onChange={(event) => {
          onDate(event.target.value);
        }}
      />
      <TextArea
        label={t('subscriptions.cancel.note')}
        help={t('subscriptions.cancel.noteHelp')}
        optional
        maxLength={500}
        value={note}
        onChange={(event) => {
          onNote(event.target.value);
        }}
      />
    </>
  );
}

/**
 * Step 1: the user has started cancelling with the provider. Montra only
 * keeps track; it never contacts the provider.
 */
export function StartCancellationDialog({ subscription, open, onOpenChange }: DialogProps) {
  const t = useT();
  const mutation = useLifecycle(subscription, 'cancellation-started');
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('subscriptions.cancel.startTitle')}
      description={t('subscriptions.cancel.startBody', { name: subscription.name })}
      busy={mutation.isPending}
    >
      {open ? (
        <CancellationForm
          subscription={subscription}
          kind="start"
          pending={mutation.isPending}
          onCancel={() => {
            onOpenChange(false);
          }}
          onSubmit={(body) => mutation.mutateAsync(body)}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

/**
 * Step 2: record the cancellation only after the provider confirmed it. The
 * API refuses without `confirm: true`, so the user must tick the statement.
 */
export function MarkCancelledDialog({ subscription, open, onOpenChange }: DialogProps) {
  const t = useT();
  const mutation = useLifecycle(subscription, 'cancelled');
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('subscriptions.cancel.doneTitle')}
      description={t('subscriptions.cancel.doneBody', { name: subscription.name })}
      busy={mutation.isPending}
    >
      {open ? (
        <CancellationForm
          subscription={subscription}
          kind="done"
          pending={mutation.isPending}
          onCancel={() => {
            onOpenChange(false);
          }}
          onSubmit={(body) => mutation.mutateAsync(body)}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function CancellationForm({
  subscription,
  kind,
  pending,
  onCancel,
  onSubmit,
  onDone,
}: {
  subscription: SubscriptionDetail;
  kind: 'start' | 'done';
  pending: boolean;
  onCancel: () => void;
  onSubmit: (body: SubscriptionActionInput) => Promise<unknown>;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const user = useCurrentUser();
  const [date, setDate] = useState(() => todayInTimeZone(user.timezone));
  const [note, setNote] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const [dateError, setDateError] = useState<string | undefined>(undefined);
  const [confirmError, setConfirmError] = useState<string | undefined>(undefined);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    if (pending) return;
    setError(null);
    const badDate = !isLocalDate(date);
    setDateError(
      badDate ? (date ? t('validation.dateInvalid') : t('validation.dateRequired')) : undefined,
    );
    const missingConfirm = kind === 'done' && !confirmed;
    setConfirmError(missingConfirm ? t('subscriptions.cancel.confirmRequired') : undefined);
    if (badDate || missingConfirm) return;
    // Marking it cancelled records the date the cancellation took effect (cancelled_on).
    const body: SubscriptionActionInput = {
      ...(kind === 'done' ? { cancelled_on: date, confirm: true } : { effective_on: date }),
      ...(note.trim() ? { note: note.trim() } : {}),
    };
    try {
      await onSubmit(body);
      toast.show({
        tone: 'success',
        title:
          kind === 'start' ? t('subscriptions.cancel.startDone') : t('subscriptions.cancel.done'),
      });
      onDone();
    } catch (failure) {
      if (errorDetailCode(failure) === 'cancellation_confirmation_required') {
        setConfirmed(false);
        setConfirmError(t('subscriptions.cancel.confirmRequired'));
        return;
      }
      if (hasErrorCode(failure, 'VALIDATION_ERROR')) {
        const dateIssue = failure.details.some(
          (detail) => detail.field === 'body.cancelled_on' || detail.field === 'body.effective_on',
        );
        if (dateIssue) {
          setDateError(t('validation.dateInvalid'));
          return;
        }
      }
      setError(subscriptionErrorMessage(failure, t, formatLocale));
    }
  };

  return (
    <form
      noValidate
      className="space-y-5"
      onSubmit={(event) => {
        event.preventDefault();
        void submit();
      }}
    >
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      {kind === 'start' && subscription.cancellation_url ? (
        <p className="text-sm">
          <ExternalLink href={subscription.cancellation_url} newTab>
            {t('subscriptions.cancellation.openPage')}
          </ExternalLink>
        </p>
      ) : null}
      <WhenAndNote
        dateLabel={
          kind === 'start'
            ? t('subscriptions.cancel.startedOn')
            : t('subscriptions.cancel.cancelledOn')
        }
        date={date}
        onDate={setDate}
        dateError={dateError}
        note={note}
        onNote={setNote}
      />
      {kind === 'done' ? (
        <Checkbox
          label={t('subscriptions.cancel.confirmLabel', { name: subscription.name })}
          description={t('subscriptions.cancel.confirmHelp')}
          checked={confirmed}
          error={confirmError}
          onChange={(event) => {
            setConfirmed(event.target.checked);
          }}
        />
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={pending} onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={pending}>
          {kind === 'start'
            ? t('subscriptions.cancel.startSubmit')
            : t('subscriptions.cancel.doneSubmit')}
        </Button>
      </div>
    </form>
  );
}
