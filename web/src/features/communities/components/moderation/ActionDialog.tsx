import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { communitiesApi } from '../../api';
import { fieldProblems, splitFieldProblems, useCommunityError } from '../../errors';
import { communitiesKeys } from '../../keys';
import {
  DANGEROUS_ACTIONS,
  REASON_REQUIRED,
  actionChoiceHelp,
  actionChoiceLabel,
  actionDoneName,
} from '../../labels';
import { type ActionTarget, actionsFor } from '../../moderationActions';
import type { ModerationActionInput, ModerationActionKind } from '../../types';

export type { ActionTarget };

const REASON_MAX = 500;
/** Restriction and ban lengths in hours. */
const DURATIONS = [1, 24, 72, 168, 720] as const;

function durationLabel(hours: number, t: Translate): string {
  return hours < 24
    ? t('communities.mod.duration.hours', { count: hours })
    : t('communities.mod.duration.days', { count: hours / 24 });
}

/**
 * Takes a moderation action in two steps: choose the action, the reason
 * (shown to the person affected) and how long it lasts, then confirm a
 * summary that says the action is recorded in the moderation log.
 */
export function ActionDialog({
  communityId,
  target,
  open,
  onOpenChange,
}: {
  communityId: string;
  target: ActionTarget | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const [busy, setBusy] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('communities.mod.action.title')}
      description={target?.summary}
      busy={busy}
      size="lg"
    >
      {open && target ? (
        <ActionForm
          key={`${target.type}:${target.id}:${target.reportId ?? ''}`}
          communityId={communityId}
          target={target}
          onBusyChange={setBusy}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

type Step = 'choose' | 'confirm';

function ActionForm({
  communityId,
  target,
  onBusyChange,
  onDone,
}: {
  communityId: string;
  target: ActionTarget;
  onBusyChange: (busy: boolean) => void;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const choices = actionsFor(target);
  const [step, setStep] = useState<Step>('choose');
  const [action, setAction] = useState<ModerationActionKind | ''>('');
  const [reason, setReason] = useState('');
  const [hours, setHours] = useState('');
  const [errors, setErrors] = useState<{ action?: string; reason?: string; hours?: string }>({});
  const [formError, setFormError] = useState<string | null>(null);
  const act = useMutation({
    mutationFn: (body: ModerationActionInput) => communitiesApi.act(communityId, body),
  });

  const needsReason = action !== '' && REASON_REQUIRED.has(action);
  const hasDuration = action === 'restrict' || action === 'ban';
  const affectsPerson = action !== '' && REASON_REQUIRED.has(action);

  const review = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFormError(null);
    const next: typeof errors = {};
    if (action === '') next.action = t('communities.mod.action.chooseRequired');
    const text = reason.trim();
    if (needsReason && !text) next.reason = t('communities.mod.action.reasonRequired');
    else if (Array.from(text).length > REASON_MAX) {
      next.reason = t('validation.maxLength', { max: REASON_MAX });
    }
    if (action === 'restrict' && !hours) next.hours = t('communities.mod.action.durationRequired');
    setErrors(next);
    if (Object.keys(next).length === 0) setStep('confirm');
  };

  const confirm = () => {
    if (act.isPending || action === '') return;
    setFormError(null);
    const text = reason.trim();
    const body: ModerationActionInput = {
      action,
      target_type: target.type,
      target_id: target.id,
      ...(text ? { reason: text } : {}),
      ...(target.reportId ? { report_id: target.reportId } : {}),
      ...(hasDuration && hours ? { duration_hours: Number(hours) } : {}),
    };
    onBusyChange(true);
    act.mutate(body, {
      onSuccess: (done) => {
        onBusyChange(false);
        toast.show({
          tone: 'success',
          title: t('communities.mod.action.done'),
          description: actionDoneName(done.action, t),
        });
        void Promise.all([
          queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(communityId) }),
          queryClient.invalidateQueries({ queryKey: communitiesKeys.feedOf(communityId) }),
          queryClient.invalidateQueries({ queryKey: communitiesKeys.membersOf(communityId) }),
          target.postId
            ? queryClient.invalidateQueries({ queryKey: communitiesKeys.post(target.postId) })
            : null,
        ]);
        onDone();
      },
      onError: (error) => {
        onBusyChange(false);
        const problems = fieldProblems(error, t);
        if (problems.length > 0) {
          const { byField, rest } = splitFieldProblems(problems, {
            reason: 'reason',
            duration_hours: 'hours',
            action: 'action',
          } as const);
          setErrors(byField);
          setFormError(rest.length > 0 ? rest.join(' ') : null);
          setStep('choose');
          return;
        }
        if (hasErrorCode(error, 'NOT_FOUND')) {
          void queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(communityId) });
        }
        setFormError(
          describe(error, {
            codes: {
              FORBIDDEN:
                target.type === 'member'
                  ? 'communities.mod.action.forbiddenMember'
                  : 'communities.mod.action.forbidden',
              CONFLICT: 'communities.mod.action.conflict',
              NOT_FOUND: target.reportId
                ? 'communities.mod.action.reportGone'
                : 'communities.mod.action.targetGone',
            },
          }),
        );
      },
    });
  };

  if (step === 'confirm' && action !== '') {
    const text = reason.trim();
    return (
      <div className="space-y-5">
        <FormAlert message={formError} />
        <Facts>
          <Fact label={t('communities.mod.action.summaryAction')}>
            {t(actionChoiceLabel[action])}
          </Fact>
          <Fact label={t('communities.mod.action.summaryTarget')}>
            <span className="break-words">{target.summary}</span>
          </Fact>
          {text ? (
            <Fact label={t('communities.mod.action.summaryReason')}>
              <span className="break-words whitespace-pre-line">{text}</span>
            </Fact>
          ) : null}
          {hasDuration ? (
            <Fact label={t('communities.mod.action.summaryDuration')}>
              {hours ? durationLabel(Number(hours), t) : t('communities.mod.duration.untilLifted')}
            </Fact>
          ) : null}
        </Facts>
        <Alert tone="info" title={t('communities.mod.audited.title')}>
          {affectsPerson
            ? t('communities.mod.action.auditedPerson')
            : t('communities.mod.action.audited')}
        </Alert>
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={act.isPending}
            onClick={() => {
              setStep('choose');
            }}
          >
            {t('common.back')}
          </Button>
          <Button
            variant={DANGEROUS_ACTIONS.has(action) ? 'danger' : 'primary'}
            loading={act.isPending}
            onClick={confirm}
          >
            {t('communities.mod.action.confirm', { action: t(actionChoiceLabel[action]) })}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <form noValidate onSubmit={review} className="space-y-5">
      <FormAlert message={formError} />
      <RadioGroup<ModerationActionKind | ''>
        legend={t('communities.mod.action.choose')}
        variant="cards"
        value={action}
        onChange={(value) => {
          setAction(value);
          setErrors({});
        }}
        options={choices.map((value) => ({
          value,
          label: t(actionChoiceLabel[value]),
          description: t(actionChoiceHelp[value]),
        }))}
        error={errors.action}
      />
      <TextArea
        label={t('communities.mod.action.reason')}
        help={
          needsReason
            ? t('communities.mod.action.reasonHelp')
            : t('communities.mod.action.noteHelp')
        }
        optional={!needsReason}
        rows={3}
        maxLength={REASON_MAX}
        value={reason}
        error={errors.reason}
        onChange={(event) => {
          setReason(event.target.value);
        }}
      />
      {hasDuration ? (
        <Select
          label={t('communities.mod.action.duration')}
          optional={action === 'ban'}
          value={hours}
          error={errors.hours}
          placeholder={
            action === 'ban'
              ? t('communities.mod.duration.untilLifted')
              : t('communities.mod.duration.choose')
          }
          options={DURATIONS.map((value) => ({
            value: String(value),
            label: durationLabel(value, t),
          }))}
          onChange={(event) => {
            setHours(event.target.value);
          }}
        />
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit">{t('communities.mod.action.review')}</Button>
      </div>
    </form>
  );
}
