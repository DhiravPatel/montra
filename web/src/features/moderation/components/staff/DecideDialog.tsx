import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useEffect, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useT } from '@/shared/i18n/I18nContext';
import { moderationApi } from '../../api';
import { decideErrorMessage } from '../../errors';
import { moderationKeys } from '../../keys';
import type { AppealDecision, ModerationAppeal } from '../../types';

const NOTE_MAX = 1000;

/**
 * Upholds or overturns an appeal, in two steps (choose, then confirm).
 * Decisions are final; overturning reverses the original action. The API
 * may require someone other than the moderator who acted.
 */
export function DecideDialog({
  appeal,
  open,
  onOpenChange,
}: {
  appeal: ModerationAppeal | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('moderation.staff.decide.title')}
      description={t('moderation.staff.decide.description')}
      busy={pending}
    >
      {open && appeal ? (
        <DecideFlow
          appeal={appeal}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function DecideFlow({
  appeal,
  onPendingChange,
  onDone,
}: {
  appeal: ModerationAppeal;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [decision, setDecision] = useState<AppealDecision | ''>('');
  const [note, setNote] = useState('');
  const [step, setStep] = useState<'form' | 'review'>('form');
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const reviewHeading = useRef<HTMLHeadingElement>(null);
  const decide = useMutation({
    mutationFn: (body: { decision: AppealDecision; note: string }) =>
      moderationApi.decide(appeal.id, {
        decision: body.decision,
        ...(body.note ? { note: body.note } : {}),
      }),
  });

  useEffect(() => {
    if (step === 'review') reviewHeading.current?.focus();
  }, [step]);

  const toReview = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!decision) {
      setFieldError(t('moderation.staff.decide.choose'));
      return;
    }
    if (note.trim().length > NOTE_MAX) {
      setFieldError(t('validation.maxLength', { max: NOTE_MAX }));
      return;
    }
    setFieldError(null);
    setSubmitError(null);
    setStep('review');
  };

  const confirm = async () => {
    if (!decision || decide.isPending) return;
    setSubmitError(null);
    onPendingChange(true);
    try {
      await decide.mutateAsync({ decision, note: note.trim() });
      onPendingChange(false);
      void queryClient.invalidateQueries({ queryKey: moderationKeys.staff() });
      toast.show({
        tone: 'success',
        title:
          decision === 'overturned'
            ? t('moderation.staff.decide.doneOverturned')
            : t('moderation.staff.decide.doneUpheld'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'CONFLICT') || hasErrorCode(error, 'NOT_FOUND')) {
        // Decided or withdrawn elsewhere: refresh the queue.
        void queryClient.invalidateQueries({ queryKey: moderationKeys.staffAppeals() });
      }
      setSubmitError(decideErrorMessage(error, t));
    }
  };

  if (step === 'review' && decision) {
    return (
      <div className="space-y-5">
        <h3
          ref={reviewHeading}
          tabIndex={-1}
          className="text-base font-semibold text-fg outline-none"
        >
          {t('moderation.staff.decide.reviewTitle')}
        </h3>
        {submitError ? (
          <Alert tone="danger" live="assertive">
            {submitError}
          </Alert>
        ) : null}
        <Facts>
          <Fact label={t('moderation.staff.decide.decision')}>
            {decision === 'overturned'
              ? t('moderation.staff.decide.overturn')
              : t('moderation.staff.decide.uphold')}
          </Fact>
          <Fact label={t('moderation.staff.decide.note')}>
            {note.trim() ? (
              <span className="whitespace-pre-line">{note.trim()}</span>
            ) : (
              t('moderation.staff.decide.noNote')
            )}
          </Fact>
        </Facts>
        <Alert tone="info" title={t('moderation.staff.audit.title')}>
          {decision === 'overturned'
            ? t('moderation.staff.decide.finalOverturn')
            : t('moderation.staff.decide.finalUphold')}
        </Alert>
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={decide.isPending}
            onClick={() => {
              setStep('form');
            }}
          >
            {t('common.back')}
          </Button>
          <Button
            loading={decide.isPending}
            onClick={() => {
              void confirm();
            }}
          >
            {t('moderation.staff.decide.confirm')}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={toReview} noValidate className="space-y-5">
      <blockquote className="border-s-4 border-line ps-3 text-sm whitespace-pre-line text-fg">
        {appeal.statement}
      </blockquote>
      <RadioGroup<AppealDecision | ''>
        legend={t('moderation.staff.decide.decision')}
        variant="cards"
        value={decision}
        onChange={setDecision}
        error={fieldError && !decision ? fieldError : undefined}
        options={[
          {
            value: 'upheld',
            label: t('moderation.staff.decide.uphold'),
            description: t('moderation.staff.decide.upholdHelp'),
          },
          {
            value: 'overturned',
            label: t('moderation.staff.decide.overturn'),
            description: t('moderation.staff.decide.overturnHelp'),
          },
        ]}
      />
      <TextArea
        label={t('moderation.staff.decide.note')}
        optional
        help={t('moderation.staff.decide.noteHelp')}
        maxLength={NOTE_MAX}
        value={note}
        error={fieldError && decision ? fieldError : undefined}
        onChange={(event) => {
          setNote(event.target.value);
        }}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit">{t('moderation.staff.decide.review')}</Button>
      </div>
    </form>
  );
}
