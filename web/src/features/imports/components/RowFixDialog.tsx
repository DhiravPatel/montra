import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { applyCodedServerErrors } from '@/shared/finance/fieldErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate } from '@/shared/formatting/dates';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useI18n } from '@/shared/i18n/I18nContext';
import { importsApi } from '../api';
import { importErrorMessage, isStateConflict } from '../errors';
import { importKeys } from '../keys';
import { fieldHint } from '../reasons';
import type { Direction, ImportBatch, ImportRow, ImportRowUpdate } from '../types';

/** The form field that holds the value the server says to correct. */
const fieldFor: Readonly<Record<NonNullable<ImportRow['error_field']>, keyof Values | null>> = {
  posted_date: 'date',
  amount: 'amount',
  description: 'description',
  category_id: null,
};

interface Values {
  date: string;
  direction: Direction | '';
  amount: string;
  description: string;
}

interface RowFixDialogProps {
  batch: ImportBatch;
  /** The row being corrected; null keeps the dialog closed. */
  row: ImportRow | null;
  onClose: () => void;
}

/**
 * Corrects a row's date, amount, direction and description before it is
 * imported (or before failed rows are retried). The server re-checks it and
 * marks it ready.
 */
export function RowFixDialog({ batch, row, onClose }: RowFixDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={row !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={row ? t('imports.fix.title', { number: row.row_number }) : ''}
      description={t('imports.fix.description')}
      busy={pending}
    >
      {row ? (
        <RowFixForm
          key={row.id}
          batch={batch}
          row={row}
          onPendingChange={setPending}
          onDone={onClose}
        />
      ) : null}
    </Dialog>
  );
}

function RowFixForm({
  batch,
  row,
  onPendingChange,
  onDone,
}: {
  batch: ImportBatch;
  row: ImportRow;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const currency = batch.currency;
  const [formError, setFormError] = useState<string | null>(null);

  const schema = useMemo(
    () =>
      z
        .object({
          date: z.string(),
          direction: z.enum(['inflow', 'outflow', '']),
          amount: z.string(),
          description: z
            .string()
            .trim()
            .max(500, { error: t('validation.maxLength', { max: 500 }) }),
        })
        .superRefine((values, ctx) => {
          if (!values.date) {
            ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateRequired') });
          } else if (!isLocalDate(values.date)) {
            ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateInvalid') });
          }
          if (!values.direction) {
            ctx.addIssue({
              code: 'custom',
              path: ['direction'],
              message: t('imports.fix.directionRequired'),
            });
          }
          checkAmount(ctx, {
            value: values.amount,
            path: 'amount',
            locale: formatLocale,
            currency,
            exponent: exponentFor(currencies.data, currency),
            t,
          });
        }),
    [t, formatLocale, currency, currencies.data],
  );

  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      date: row.posted_date ?? '',
      direction: row.direction ?? '',
      amount: row.amount ? decimalToInput(row.amount.amount, formatLocale) : '',
      description: row.description ?? '',
    },
  });

  const mutation = useMutation({
    mutationFn: (body: ImportRowUpdate) => importsApi.updateRow(batch.id, row.id, body),
    onSettled: () => queryClient.invalidateQueries({ queryKey: importKeys.batch(batch.id) }),
  });

  // Start on the value the server named (`error_field`), when it named one.
  const focusField = row.error_field ? fieldFor[row.error_field] : null;
  const { setFocus } = form;
  useEffect(() => {
    if (focusField) setFocus(focusField);
  }, [focusField, setFocus]);
  const hint = fieldHint(row.error_field, t);

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || !values.direction) return;
    setFormError(null);
    const exact = normalizeDecimalInput(values.amount, formatLocale, {
      exponent: exponentFor(currencies.data, currency),
    });
    if (!exact.ok) return;
    const description = values.description.trim();
    const body: ImportRowUpdate = {
      posted_date: values.date,
      amount: exact.value,
      direction: values.direction,
      ...(description ? { description } : {}),
    };
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title:
          row.status === 'failed'
            ? t('imports.fix.doneFailed', { number: row.row_number })
            : t('imports.fix.done', { number: row.row_number }),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR') && error.details.length > 0) {
        const rest = applyCodedServerErrors(
          error,
          form.setError,
          {
            posted_date: 'date',
            amount: 'amount',
            direction: 'direction',
            description: 'description',
          },
          t,
        );
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        setFormError(t('imports.fix.needsAll'));
      } else if (isStateConflict(error)) {
        toast.show({ tone: 'warning', title: importErrorMessage(error, t, formatLocale) });
        onDone();
      } else {
        setFormError(importErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  const cells = row.raw.filter((cell) => cell.trim() !== '');

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {hint ? (
        <p className="flex items-start gap-1.5 text-sm text-fg">
          <Icon name="info" className="mt-0.5 size-4 shrink-0 text-fg-muted" />
          <span>{hint}</span>
        </p>
      ) : null}
      {cells.length > 0 ? (
        <div className="rounded-md border border-line bg-surface-muted p-3 text-sm">
          <p className="font-medium text-fg">{t('imports.fix.asRead')}</p>
          <p className="mt-1 break-words text-fg-muted">{cells.join(' · ')}</p>
        </div>
      ) : null}
      <TextField
        label={t('imports.fix.date')}
        type="date"
        error={errors.date?.message}
        {...form.register('date')}
      />
      <Controller
        control={form.control}
        name="direction"
        render={({ field }) => (
          <RadioGroup
            legend={t('imports.fix.direction')}
            value={field.value}
            onChange={field.onChange}
            error={errors.direction?.message}
            options={[
              { value: 'outflow', label: t('finance.direction.outflow') },
              { value: 'inflow', label: t('finance.direction.inflow') },
            ]}
          />
        )}
      />
      <MoneyField
        label={t('imports.fix.amount')}
        currency={currency}
        help={t('imports.fix.amountHelp')}
        error={errors.amount?.message}
        {...form.register('amount')}
      />
      <TextField
        label={t('imports.fix.descriptionLabel')}
        optional
        maxLength={500}
        autoComplete="off"
        error={errors.description?.message}
        {...form.register('description')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('imports.fix.submit')}
        </Button>
      </div>
    </form>
  );
}
