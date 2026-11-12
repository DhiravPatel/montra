import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { DateRangeFields } from '@/shared/finance/components/DateRangeFields';
import type { DateRangePreset } from '@/shared/finance/types';
import { isLocalDate } from '@/shared/formatting/dates';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { reportsApi } from '../api';
import { defaultRange, emptyOptions, type ReportOptionValues, toReportInput } from '../formValues';
import { reportsKeys } from '../keys';
import {
  formatLabel,
  isReportType,
  PERIOD_TYPES,
  REPORT_FORMATS,
  REPORT_TYPE_GROUPS,
  reportTypeHelp,
  reportTypeLabel,
} from '../labels';
import type { ReportFormat, ReportInput } from '../types';
import { ReportOptionFields } from './ReportOptionFields';

interface Fields {
  type: string;
  format: ReportFormat;
  range: DateRangePreset | 'custom';
  from: string;
  to: string;
  title: string;
}

const TITLE_MAX = 160;

/** Asks the API for a report; it is prepared in the background and appears in the list. */
export function ReportDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('reports.create.title')}
      description={t('reports.create.description')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <ReportForm
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function ReportForm({
  onDone,
  onPendingChange,
}: {
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [options, setOptions] = useState<ReportOptionValues>(emptyOptions);
  const [periodTouched, setPeriodTouched] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z
        .object({
          type: z.string().refine((value) => isReportType(value), {
            error: t('reports.form.typeRequired'),
          }),
          format: z.enum(REPORT_FORMATS),
          range: z.custom<Fields['range']>((value) => typeof value === 'string'),
          from: z.string(),
          to: z.string(),
          title: z
            .string()
            .trim()
            .max(TITLE_MAX, { error: t('validation.maxLength', { max: TITLE_MAX }) }),
        })
        .superRefine((values, ctx) => {
          if (!isReportType(values.type) || !PERIOD_TYPES.has(values.type)) return;
          if (values.range !== 'custom') return;
          if (!isLocalDate(values.from) || !isLocalDate(values.to)) {
            ctx.addIssue({ code: 'custom', path: ['from'], message: t('validation.dateRequired') });
          } else if (values.from > values.to) {
            ctx.addIssue({ code: 'custom', path: ['from'], message: t('validation.dateOrder') });
          }
        }),
    [t],
  );
  const form = useForm<Fields>({
    resolver: zodResolver(schema),
    defaultValues: { type: '', format: 'csv', range: 'this_month', from: '', to: '', title: '' },
  });
  const [typeValue, format, range, from, to] = useWatch({
    control: form.control,
    name: ['type', 'format', 'range', 'from', 'to'],
  });
  const type = isReportType(typeValue) ? typeValue : null;
  const create = useMutation({
    mutationFn: (body: ReportInput) => reportsApi.create(body),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: reportsKeys.list() }),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (create.isPending || !isReportType(values.type)) return;
    setFormError(null);
    onPendingChange(true);
    try {
      await create.mutateAsync(toReportInput({ ...values, ...options, type: values.type }));
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: t('reports.create.done'),
        description: t('reports.create.doneBody'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (
        hasErrorCode(error, 'VALIDATION_ERROR') &&
        isApiError(error) &&
        error.details.length > 0
      ) {
        let unmatched = false;
        for (const detail of error.details) {
          if (
            detail.field?.startsWith('body.filters.from') ||
            detail.field?.startsWith('body.filters.to')
          ) {
            form.setError('from', { type: 'server', message: t('reports.form.periodInvalid') });
          } else if (detail.field === 'body.title') {
            form.setError('title', {
              type: 'server',
              message: t('validation.maxLength', { max: TITLE_MAX }),
            });
          } else {
            unmatched = true;
          }
        }
        if (unmatched) setFormError(t('reports.form.invalid'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <Select
        label={t('reports.form.type')}
        placeholder={t('reports.form.typePlaceholder')}
        groups={REPORT_TYPE_GROUPS.map((group) => ({
          label: t(group.label),
          options: group.types.map((value) => ({ value, label: t(reportTypeLabel[value]) })),
        }))}
        help={type ? t(reportTypeHelp[type]) : undefined}
        error={errors.type?.message}
        {...form.register('type', {
          onChange: (event: { target: { value: string } }) => {
            const next = event.target.value;
            if (!periodTouched && isReportType(next)) form.setValue('range', defaultRange(next));
          },
        })}
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
      {type && PERIOD_TYPES.has(type) ? (
        <DateRangeFields
          value={{ range, from, to }}
          error={errors.from?.message}
          onChange={(next) => {
            if (next.range === 'all') return;
            setPeriodTouched(true);
            // After a first submit, check the dates again as they change.
            const validate = { shouldValidate: form.formState.isSubmitted };
            form.setValue('range', next.range, validate);
            form.setValue('from', next.from, validate);
            form.setValue('to', next.to, validate);
          }}
        />
      ) : null}
      <TextField
        label={t('reports.form.title')}
        optional
        maxLength={TITLE_MAX}
        autoComplete="off"
        help={t('reports.form.titleHelp')}
        error={errors.title?.message}
        {...form.register('title')}
      />
      <ReportOptionFields type={type} value={options} onChange={setOptions} />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={create.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={create.isPending}>
          {t('reports.create.submit')}
        </Button>
      </div>
    </form>
  );
}
