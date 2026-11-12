import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { reportsApi } from '../api';
import {
  emptyOptions,
  type ReportOptionValues,
  scheduleOptionValues,
  toScheduleInput,
  toSchedulePatch,
} from '../formValues';
import { reportsKeys } from '../keys';
import {
  CADENCES,
  cadenceLabel,
  formatLabel,
  isReportType,
  REPORT_FORMATS,
  REPORT_TYPE_GROUPS,
  reportTypeHelp,
  reportTypeLabel,
} from '../labels';
import type { ReportFormat, ReportSchedule, ScheduleCadence } from '../types';
import { ReportOptionFields } from './ReportOptionFields';

interface Fields {
  type: string;
  format: ReportFormat;
  cadence: ScheduleCadence;
  title: string;
}

const TITLE_MAX = 160;

interface ScheduleDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The schedule to edit; omitted to create one. */
  schedule?: ReportSchedule;
  /** The schedule changed somewhere else: the form restarted from its latest version. */
  conflict?: boolean;
  /** A version conflict was answered: the caller reloads the schedule (the form remounts). */
  onConflict?: () => void;
}

/**
 * Schedules a weekly or monthly report (each run covers the previous full
 * week or month), or edits one: title, format, cadence and filters (the
 * report type stays). Edits send the version read; a concurrent change
 * reloads the schedule and the form starts again from it.
 */
export function ScheduleDialog({
  open,
  onOpenChange,
  schedule,
  conflict = false,
  onConflict,
}: ScheduleDialogProps) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={schedule ? t('reports.schedule.editTitle') : t('reports.schedule.createTitle')}
      description={t('reports.schedule.createDescription')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <>
          {conflict ? (
            <Alert
              tone="warning"
              live="assertive"
              className="mb-5"
              title={t('finance.conflict.title')}
            >
              {t('finance.conflict.body')}
            </Alert>
          ) : null}
          <ScheduleForm
            key={schedule ? `${schedule.id}:${schedule.version}` : 'new'}
            schedule={schedule}
            onPendingChange={setPending}
            onConflict={onConflict}
            onDone={() => {
              onOpenChange(false);
            }}
          />
        </>
      ) : null}
    </Dialog>
  );
}

function ScheduleForm({
  schedule,
  onDone,
  onPendingChange,
  onConflict,
}: {
  schedule: ReportSchedule | undefined;
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
  onConflict: (() => void) | undefined;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [options, setOptions] = useState<ReportOptionValues>(
    schedule ? scheduleOptionValues(schedule) : emptyOptions,
  );
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z.object({
        type: z.string().refine((value) => isReportType(value), {
          error: t('reports.form.typeRequired'),
        }),
        format: z.enum(REPORT_FORMATS),
        cadence: z.enum(CADENCES),
        title: z
          .string()
          .trim()
          .max(TITLE_MAX, { error: t('validation.maxLength', { max: TITLE_MAX }) }),
      }),
    [t],
  );
  const form = useForm<Fields>({
    resolver: zodResolver(schema),
    defaultValues: schedule
      ? {
          type: schedule.report_type,
          format: schedule.format,
          cadence: schedule.cadence,
          title: schedule.title,
        }
      : { type: '', format: 'pdf', cadence: 'monthly', title: '' },
  });
  const [typeValue, format, cadence] = useWatch({
    control: form.control,
    name: ['type', 'format', 'cadence'],
  });
  const type = isReportType(typeValue) ? typeValue : null;
  const save = useMutation({
    mutationFn: (values: Fields & { type: string }) => {
      if (!isReportType(values.type)) throw new Error('report type');
      const input = { ...values, ...options, type: values.type };
      return schedule
        ? reportsApi.updateSchedule(schedule.id, toSchedulePatch(input, schedule))
        : reportsApi.createSchedule(toScheduleInput(input));
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: reportsKeys.schedules() }),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (save.isPending || !isReportType(values.type)) return;
    setFormError(null);
    onPendingChange(true);
    try {
      await save.mutateAsync(values);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: schedule ? t('reports.schedule.updated') : t('reports.schedule.done'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VERSION_CONFLICT') && onConflict) {
        onConflict();
        return;
      }
      setFormError(
        hasErrorCode(error, 'VALIDATION_ERROR')
          ? t('reports.form.invalid')
          : describeError(error, t),
      );
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {schedule ? (
        <p className="text-sm text-fg">
          {t('reports.schedule.editType', {
            type: isReportType(schedule.report_type)
              ? t(reportTypeLabel[schedule.report_type])
              : schedule.report_type,
          })}
        </p>
      ) : (
        <Select
          label={t('reports.form.type')}
          placeholder={t('reports.form.typePlaceholder')}
          groups={REPORT_TYPE_GROUPS.map((group) => ({
            label: t(group.label),
            options: group.types.map((value) => ({ value, label: t(reportTypeLabel[value]) })),
          }))}
          help={type ? t(reportTypeHelp[type]) : undefined}
          error={errors.type?.message}
          {...form.register('type')}
        />
      )}
      <RadioGroup
        legend={t('reports.schedule.cadence')}
        value={cadence}
        options={CADENCES.map((value) => ({ value, label: t(cadenceLabel[value]) }))}
        help={t('reports.schedule.cadenceHelp')}
        onChange={(value) => {
          form.setValue('cadence', value);
        }}
      />
      <RadioGroup
        legend={t('reports.form.format')}
        value={format}
        options={REPORT_FORMATS.map((value) => ({ value, label: t(formatLabel[value]) }))}
        help={
          format === 'pdf' && type === 'transactions'
            ? t('reports.form.pdfLimit')
            : t('reports.form.formatHelp')
        }
        onChange={(value) => {
          form.setValue('format', value);
        }}
      />
      <TextField
        label={t('reports.form.title')}
        optional
        maxLength={TITLE_MAX}
        autoComplete="off"
        help={schedule ? t('reports.schedule.titleEditHelp') : t('reports.form.titleHelp')}
        error={errors.title?.message}
        {...form.register('title')}
      />
      <ReportOptionFields type={type} value={options} onChange={setOptions} />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={save.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={save.isPending}>
          {schedule ? t('common.save') : t('reports.schedule.submit')}
        </Button>
      </div>
    </form>
  );
}
