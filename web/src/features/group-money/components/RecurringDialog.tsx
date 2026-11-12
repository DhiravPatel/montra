import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { type FieldPath, FormProvider, useForm, useWatch } from 'react-hook-form';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { FormAlert } from '@/shared/forms/FormAlert';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { RecurrenceFields } from '@/features/planning/components/RecurrenceFields';
import { groupMoneyApi } from '../api';
import { groupMoneyErrorMessage, groupRuleCode } from '../errors';
import { RECURRING_SPLIT_METHODS, categoryKeyOptions } from '../labels';
import type { People } from '../people';
import {
  type RecurringFormDeps,
  type RecurringFormValues,
  buildRecurringSchema,
  defaultRecurringValues,
  recurringToValues,
  recurringTotal,
  toRecurringInput,
  toRecurringUpdate,
} from '../recurringForm';
import { type SplitContext, serverFieldPath } from '../splitForm';
import type { GroupDetail, GroupRecurring } from '../types';
import { PayerFields } from './PayerFields';
import { SplitFields } from './SplitFields';

interface RecurringDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  group: GroupDetail;
  people: People;
  /** Edit this recurring expense; create a new one when omitted. */
  recurring?: GroupRecurring | null;
  onSaved: (saved: GroupRecurring) => void;
  /** A stale version: the page reloads the list (the form restarts from the latest one). */
  onConflict?: () => void;
}

/** Creates or edits a recurring shared expense (rent, internet, a cleaner). */
export function RecurringDialog(props: RecurringDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  const [conflict, setConflict] = useState(false);
  return (
    <Dialog
      open={props.open}
      onOpenChange={(next) => {
        if (!next) setConflict(false);
        props.onOpenChange(next);
      }}
      title={
        props.recurring ? t('groupMoney.recurring.editTitle') : t('groupMoney.recurring.newTitle')
      }
      description={
        props.recurring ? t('groupMoney.recurring.editBody') : t('groupMoney.recurring.newBody')
      }
      busy={pending}
      size="lg"
    >
      {props.open && conflict ? (
        <Alert tone="warning" live="assertive" className="mb-5" title={t('finance.conflict.title')}>
          {t('groupMoney.recurring.conflict')}
        </Alert>
      ) : null}
      {props.open ? (
        <RecurringFormGate
          // Restart from the latest saved version after a conflict reload.
          key={props.recurring?.rule.version ?? 'new'}
          {...props}
          onPendingChange={setPending}
          onConflict={() => {
            setConflict(true);
            props.onConflict?.();
          }}
          onSaved={(saved) => {
            setConflict(false);
            props.onSaved(saved);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function RecurringFormGate(
  props: RecurringDialogProps & { onPendingChange: (p: boolean) => void },
) {
  const currencies = useCurrencies();
  if (currencies.isPending) return null;
  return (
    <RecurringForm {...props} exponent={exponentFor(currencies.data, props.group.base_currency)} />
  );
}

function RecurringForm({
  onOpenChange,
  group,
  people,
  recurring,
  onSaved,
  onConflict,
  onPendingChange,
  exponent,
}: RecurringDialogProps & { onPendingChange: (p: boolean) => void; exponent: number }) {
  const { t, formatLocale } = useI18n();
  const mode = recurring ? 'edit' : 'create';
  const currency = group.base_currency;
  // One key per draft: a retry after a lost answer replays the create instead of repeating it.
  const idempotency = useIdempotencyKey();
  const [formError, setFormError] = useState<string | null>(null);
  const deps: RecurringFormDeps = useMemo(
    () => ({ t, locale: formatLocale, currency, exponent, mode }),
    [t, formatLocale, currency, exponent, mode],
  );
  const schema = useMemo(() => buildRecurringSchema(deps), [deps]);
  const [initialValues] = useState(() => {
    const today = todayInTimeZone(group.timezone);
    return recurring
      ? recurringToValues(recurring, group, people.active, people.meId, formatLocale, today)
      : defaultRecurringValues(group, people.active, people.meId, today);
  });
  const form = useForm<RecurringFormValues, unknown, RecurringFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const { register, control, formState } = form;
  const errors = formState.errors;
  const amount = useWatch({ control, name: 'amount' });
  const total = recurringTotal(amount, deps);
  const context: SplitContext = { t, locale: formatLocale, currency, exponent };

  const save = useMutation({
    mutationFn: async (values: RecurringFormValues) => {
      if (recurring) {
        const { body } = toRecurringUpdate(values, deps, recurring.rule.version);
        return groupMoneyApi.updateRecurring(group.id, recurring.rule.id, body);
      }
      const { body } = toRecurringInput(values, deps);
      return groupMoneyApi.createRecurring(group.id, body, idempotency.key);
    },
  });

  const submit = form.handleSubmit(
    async (values) => {
      if (save.isPending) return;
      setFormError(null);
      onPendingChange(true);
      try {
        const saved = await save.mutateAsync(values);
        if (!recurring) idempotency.renew();
        onSaved(saved);
      } catch (error) {
        if (hasErrorCode(error, 'VERSION_CONFLICT')) {
          onConflict?.();
          return;
        }
        if (hasErrorCode(error, 'VALIDATION_ERROR')) {
          const rows = recurring
            ? toRecurringUpdate(values, deps, recurring.rule.version).rows
            : toRecurringInput(values, deps).rows;
          const plain: Readonly<Record<string, string>> = {
            name: 'name',
            amount: 'amount',
            description: 'description',
            category_key: 'categoryKey',
            split_method: 'splitMethod',
            start_date: 'schedule.startDate',
            end_date: 'schedule.endDate',
            max_occurrences: 'schedule.maxOccurrences',
            local_time: 'schedule.localTime',
            frequency: 'schedule.frequency',
            interval_count: 'schedule.intervalCount',
            interval_unit: 'schedule.intervalUnit',
            reminder_days_before: 'schedule.reminders',
          };
          const rest: string[] = [];
          for (const detail of error.details) {
            const path = detail.field
              ? serverFieldPath(detail.field, { ...rows, payerMode: values.payerMode }, plain)
              : null;
            if (path) {
              form.setError(path as FieldPath<RecurringFormValues>, {
                type: 'server',
                message: detail.message,
              });
            } else rest.push(detail.message);
          }
          setFormError(rest.length > 0 ? rest.join(' ') : t('groupMoney.form.fixErrors'));
          return;
        }
        const message = groupMoneyErrorMessage(error, t, formatLocale, {
          notFound: t('groupMoney.recurring.gone'),
          forbidden: t('groupMoney.recurring.forbidden'),
        });
        const code = groupRuleCode(error);
        if (code === 'split_mismatch') form.setError('checks.split', { type: 'server', message });
        if (code === 'payers_total_mismatch') {
          form.setError('checks.payers', { type: 'server', message });
        }
        setFormError(message);
      } finally {
        onPendingChange(false);
      }
    },
    () => {
      setFormError(t('groupMoney.form.fixErrors'));
    },
  );

  return (
    <FormProvider {...form}>
      <form onSubmit={submit} noValidate className="space-y-8">
        <FormAlert message={formError} />
        <fieldset className="space-y-5">
          <legend className="mb-1 text-base font-semibold text-fg">
            {t('groupMoney.form.details')}
          </legend>
          <TextField
            label={t('groupMoney.recurring.form.name')}
            help={t('groupMoney.recurring.form.nameHelp')}
            maxLength={120}
            autoComplete="off"
            error={errors.name?.message}
            {...register('name')}
          />
          <div className="grid gap-5 sm:grid-cols-2">
            <MoneyField
              label={t('groupMoney.recurring.form.amount')}
              currency={currency}
              error={errors.amount?.message}
              {...register('amount')}
            />
            <Select
              label={t('groupMoney.form.category')}
              optional
              placeholder={t('categories.uncategorized')}
              options={categoryKeyOptions(t, initialValues.categoryKey || undefined)}
              error={errors.categoryKey?.message}
              {...register('categoryKey')}
            />
          </div>
          <TextField
            label={t('groupMoney.recurring.form.description')}
            optional
            help={t('groupMoney.recurring.form.descriptionHelp')}
            maxLength={200}
            autoComplete="off"
            error={errors.description?.message}
            {...register('description')}
          />
          <Checkbox
            label={t('groupMoney.recurring.form.autoAdd')}
            description={t('groupMoney.recurring.form.autoAddHelp')}
            {...register('autoAdd')}
          />
        </fieldset>

        {mode === 'create' ? (
          <RecurrenceFields />
        ) : (
          <Alert tone="info">{t('groupMoney.recurring.form.scheduleFixed')}</Alert>
        )}

        <PayerFields people={people} total={total} context={context} allowAdder />
        <SplitFields
          people={people}
          total={total}
          context={context}
          methods={RECURRING_SPLIT_METHODS}
        />

        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={save.isPending}
            onClick={() => {
              onOpenChange(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={save.isPending}>
            {recurring ? t('common.save') : t('groupMoney.recurring.form.create')}
          </Button>
        </div>
      </form>
    </FormProvider>
  );
}
