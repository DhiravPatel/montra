import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { applyCodedServerErrors } from '@/features/communities/fieldCodes';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { moderationApi } from '../../api';
import { actErrorMessage } from '../../errors';
import { moderationKeys } from '../../keys';
import {
  DURATION_CHOICES,
  STAFF_ACTIONS,
  STAFF_TARGETS,
  isSevere,
  isStaffTarget,
  needsReason,
  staffActionLabel,
  targetLabel,
} from '../../labels';
import type { ActionKind, ModerationActionInput, StaffTargetType } from '../../types';

const REASON_MAX = 500;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** What an action is about; a report's target when started from the queue. */
export interface ActionTarget {
  type: StaffTargetType;
  id: string;
  reportId?: string;
}

interface ActValues {
  targetType: string;
  targetId: string;
  action: string;
  reason: string;
  /** Hours as text; '' means no end date (bans) or not chosen. */
  duration: string;
}

type FieldName = keyof ActValues;

function actionsFor(targetType: string, reportId: string | undefined): readonly ActionKind[] {
  if (!isStaffTarget(targetType)) return [];
  const actions = STAFF_ACTIONS[targetType];
  return reportId ? [...actions, 'dismiss_report'] : actions;
}

function hasDuration(action: string, targetType: string): boolean {
  return action === 'restrict' || (action === 'ban' && targetType === 'profile');
}

function buildSchema(t: Translate, reportId: string | undefined) {
  return z
    .object({
      targetType: z.string(),
      targetId: z.string(),
      action: z.string(),
      reason: z.string(),
      duration: z.string(),
    })
    .superRefine((values, ctx) => {
      if (!isStaffTarget(values.targetType)) {
        ctx.addIssue({
          code: 'custom',
          path: ['targetType'],
          message: t('moderation.staff.act.targetTypeRequired'),
        });
      }
      if (!UUID.test(values.targetId.trim())) {
        ctx.addIssue({
          code: 'custom',
          path: ['targetId'],
          message: t('moderation.staff.act.targetIdInvalid'),
        });
      }
      const allowed = actionsFor(values.targetType, reportId);
      const action = allowed.find((kind) => kind === values.action);
      if (!action) {
        ctx.addIssue({
          code: 'custom',
          path: ['action'],
          message: t('moderation.staff.act.actionRequired'),
        });
        return;
      }
      const reason = values.reason.trim();
      if (needsReason(action) && !reason) {
        ctx.addIssue({
          code: 'custom',
          path: ['reason'],
          message: t('moderation.staff.act.reasonRequired'),
        });
      } else if (reason.length > REASON_MAX) {
        ctx.addIssue({
          code: 'custom',
          path: ['reason'],
          message: t('validation.maxLength', { max: REASON_MAX }),
        });
      }
      if (action === 'restrict' && !values.duration) {
        ctx.addIssue({
          code: 'custom',
          path: ['duration'],
          message: t('moderation.staff.act.durationRequired'),
        });
      }
    });
}

function toInput(values: ActValues, reportId: string | undefined): ModerationActionInput | null {
  const allowed = actionsFor(values.targetType, reportId);
  const action = allowed.find((kind) => kind === values.action);
  if (!action || !isStaffTarget(values.targetType)) return null;
  const reason = values.reason.trim();
  const hours = Number(values.duration);
  return {
    action,
    target_type: values.targetType,
    target_id: values.targetId.trim(),
    ...(reason ? { reason } : {}),
    ...(reportId ? { report_id: reportId } : {}),
    ...(hasDuration(action, values.targetType) && values.duration && Number.isInteger(hours)
      ? { duration_hours: hours }
      : {}),
  };
}

/**
 * A platform action by Montra staff, in two steps: choose, then confirm a
 * summary. Every action is audited, and the person affected sees the reason.
 */
export function ActionDialog({
  open,
  onOpenChange,
  target,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  target: ActionTarget | null;
}) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={
        target?.reportId ? t('moderation.staff.act.titleReport') : t('moderation.staff.act.title')
      }
      description={t('moderation.staff.act.description')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <ActionFlow
          target={target}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function ActionFlow({
  target,
  onPendingChange,
  onDone,
}: {
  target: ActionTarget | null;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const reportId = target?.reportId;
  const [step, setStep] = useState<'form' | 'review'>('form');
  const [reviewed, setReviewed] = useState<ModerationActionInput | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const reviewHeading = useRef<HTMLHeadingElement>(null);
  const focusAfterBack = useRef<FieldName | null>(null);
  const schema = useMemo(() => buildSchema(t, reportId), [t, reportId]);
  const form = useForm<ActValues, unknown, ActValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      targetType: target?.type ?? '',
      targetId: target?.id ?? '',
      action: '',
      reason: '',
      duration: '',
    },
  });
  const [targetType, action] = useWatch({ control: form.control, name: ['targetType', 'action'] });
  const act = useMutation({ mutationFn: (body: ModerationActionInput) => moderationApi.act(body) });

  useEffect(() => {
    if (step === 'review') {
      reviewHeading.current?.focus();
    } else if (focusAfterBack.current) {
      form.setFocus(focusAfterBack.current);
      focusAfterBack.current = null;
    }
  }, [step, form]);

  const toReview = form.handleSubmit((values) => {
    const input = toInput(values, reportId);
    if (!input) return;
    setFormError(null);
    setSubmitError(null);
    setReviewed(input);
    setStep('review');
  });

  const back = (field: FieldName = 'action') => {
    focusAfterBack.current = field;
    setStep('form');
  };

  const confirm = async () => {
    if (!reviewed || act.isPending) return;
    setSubmitError(null);
    onPendingChange(true);
    try {
      await act.mutateAsync(reviewed);
      onPendingChange(false);
      void Promise.all([
        queryClient.invalidateQueries({ queryKey: moderationKeys.staffReportLists() }),
        queryClient.invalidateQueries({ queryKey: moderationKeys.staffActionLists() }),
      ]);
      toast.show({ tone: 'success', title: t('moderation.staff.act.done') });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        // A report's target is shown read-only, so its problems go in the summary.
        const fields: Readonly<Partial<Record<string, FieldName>>> = target
          ? { action: 'action', reason: 'reason', duration_hours: 'duration' }
          : {
              target_type: 'targetType',
              target_id: 'targetId',
              action: 'action',
              reason: 'reason',
              duration_hours: 'duration',
            };
        const rest = applyCodedServerErrors(error, form.setError, fields, t);
        setFormError(rest.length > 0 ? rest.join(' ') : null);
        const first = error.details
          .map((detail) => fields[detail.field?.replace(/^body\./, '') ?? ''])
          .find(Boolean);
        back(first ?? 'action');
        return;
      }
      setSubmitError(actErrorMessage(error, t));
    }
  };

  const { errors } = form.formState;
  const allowed = actionsFor(targetType, reportId);
  const durationShown = hasDuration(action, targetType);

  if (step === 'review' && reviewed) {
    const duration = DURATION_CHOICES.find((choice) => choice.hours === reviewed.duration_hours);
    const severe = isSevere(reviewed.action);
    return (
      <div className="space-y-5">
        <h3
          ref={reviewHeading}
          tabIndex={-1}
          className="text-base font-semibold text-fg outline-none"
        >
          {t('moderation.staff.act.reviewTitle')}
        </h3>
        {submitError ? (
          <Alert tone="danger" live="assertive">
            {submitError}
          </Alert>
        ) : null}
        <Facts>
          <Fact label={t('moderation.staff.act.action')}>
            {t(staffActionLabel(reviewed.action, reviewed.target_type))}
          </Fact>
          <Fact label={t('moderation.staff.act.target')}>
            <span className="block">{t(targetLabel(reviewed.target_type))}</span>
            <code className="font-mono text-sm break-all">{reviewed.target_id}</code>
          </Fact>
          {reviewed.report_id ? (
            <Fact label={t('moderation.staff.act.report')}>
              <code className="font-mono text-sm break-all">{reviewed.report_id}</code>
            </Fact>
          ) : null}
          <Fact label={t('moderation.staff.act.reason')}>
            {reviewed.reason ? (
              <span className="whitespace-pre-line">{reviewed.reason}</span>
            ) : (
              t('moderation.staff.act.noReason')
            )}
          </Fact>
          {hasDuration(reviewed.action, reviewed.target_type) ? (
            <Fact label={t('moderation.staff.act.duration')}>
              {duration ? t(duration.key) : t('moderation.staff.duration.none')}
            </Fact>
          ) : null}
        </Facts>
        <Alert tone="info" title={t('moderation.staff.audit.title')}>
          {t('moderation.staff.act.auditNote')}
        </Alert>
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={act.isPending}
            onClick={() => {
              back();
            }}
          >
            {t('common.back')}
          </Button>
          <Button
            variant={severe ? 'danger' : 'primary'}
            loading={act.isPending}
            onClick={() => {
              void confirm();
            }}
          >
            {t('moderation.staff.act.confirm')}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={toReview} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {target ? (
        <Facts>
          <Fact label={t('moderation.staff.act.target')}>
            <span className="block">{t(targetLabel(target.type))}</span>
            <code className="font-mono text-sm break-all">{target.id}</code>
          </Fact>
        </Facts>
      ) : (
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('moderation.staff.act.targetType')}
            placeholder={t('moderation.staff.act.targetTypePlaceholder')}
            options={STAFF_TARGETS.map((value) => ({ value, label: t(targetLabel(value)) }))}
            error={errors.targetType?.message}
            {...form.register('targetType', {
              onChange: () => {
                form.setValue('action', '');
                form.setValue('duration', '');
              },
            })}
          />
          <TextField
            label={t('moderation.staff.act.targetId')}
            help={t('moderation.staff.act.targetIdHelp')}
            autoComplete="off"
            spellCheck={false}
            error={errors.targetId?.message}
            {...form.register('targetId')}
          />
        </div>
      )}
      <Select
        label={t('moderation.staff.act.action')}
        placeholder={t('moderation.staff.act.actionPlaceholder')}
        options={allowed.map((value) => ({
          value,
          label: t(staffActionLabel(value, targetType)),
        }))}
        disabled={allowed.length === 0}
        error={errors.action?.message}
        {...form.register('action', {
          onChange: () => {
            form.setValue('duration', '');
          },
        })}
      />
      <TextArea
        label={t('moderation.staff.act.reason')}
        optional={!needsReason(action)}
        help={t('moderation.staff.act.reasonHelp')}
        maxLength={REASON_MAX}
        error={errors.reason?.message}
        {...form.register('reason')}
      />
      {durationShown ? (
        <Select
          label={t('moderation.staff.act.duration')}
          optional={action !== 'restrict'}
          placeholder={
            action === 'restrict'
              ? t('moderation.staff.act.durationPlaceholder')
              : t('moderation.staff.duration.none')
          }
          options={DURATION_CHOICES.map((choice) => ({
            value: String(choice.hours),
            label: t(choice.key),
          }))}
          error={errors.duration?.message}
          {...form.register('duration')}
        />
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit">{t('moderation.staff.act.review')}</Button>
      </div>
    </form>
  );
}
