import { zodResolver } from '@hookform/resolvers/zod';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import type { Occurrence, OccurrenceAction } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatLocalDate, isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { planningErrorMessage } from '../errors';

export type OccurrenceDialogKind = 'confirm' | 'postpone' | 'amount';

interface OccurrenceDialogProps {
  kind: OccurrenceDialogKind;
  occurrence: Occurrence;
  /** The rule's currency (amounts are in it). */
  currency: string;
  /** Recording needs an account when the rule has none. */
  needsAccount: boolean;
  pending: boolean;
  onSubmit: (body: OccurrenceAction) => Promise<void>;
  onClose: () => void;
}

const titles = {
  confirm: 'recurring.occurrence.confirmTitle',
  postpone: 'recurring.occurrence.postponeTitle',
  amount: 'recurring.occurrence.amountTitle',
} as const;

/** Record, postpone or re-price one occurrence of a recurring item. */
export function OccurrenceDialog(props: OccurrenceDialogProps) {
  const { t, formatLocale } = useI18n();
  const date = formatLocalDate(props.occurrence.effective_date, formatLocale, 'long');
  return (
    <Dialog
      open
      onOpenChange={(open) => {
        if (!open && !props.pending) props.onClose();
      }}
      title={t(titles[props.kind])}
      description={t('recurring.occurrence.dueOn', { date })}
      busy={props.pending}
    >
      <OccurrenceDialogGate {...props} />
    </Dialog>
  );
}

function OccurrenceDialogGate(props: OccurrenceDialogProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts();
  const failed = [currencies, accounts].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        titleAs="p"
        title={t('recurring.form.loadFailed')}
        error={failed.error}
        onRetry={() => {
          void failed.refetch();
        }}
      />
    );
  }
  if (currencies.isPending || accounts.isPending) {
    return <LoadingState label={t('recurring.form.loading')} />;
  }
  return <OccurrenceForm {...props} />;
}

interface Values {
  amount: string;
  date: string;
  accountId: string;
}

function OccurrenceForm({
  kind,
  occurrence,
  currency,
  needsAccount,
  pending,
  onSubmit,
  onClose,
}: OccurrenceDialogProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const formatMoney = useFormatMoney();
  const currencies = useCurrencies();
  const accounts = useAccounts();
  const [formError, setFormError] = useState<string | null>(null);
  const exponent = exponentFor(currencies.data, currency);
  const today = todayInTimeZone(user.timezone);
  const expected = occurrence.amount;
  const choices = writableAccounts(accounts.data).filter(
    (account) => account.currency === currency,
  );

  const schema = useMemo(
    () =>
      z
        .object({ amount: z.string(), date: z.string(), accountId: z.string() })
        .superRefine((values, ctx) => {
          if (kind === 'postpone') {
            if (!isLocalDate(values.date)) {
              ctx.addIssue({
                code: 'custom',
                path: ['date'],
                message: t('validation.dateInvalid'),
              });
            } else if (values.date <= occurrence.effective_date) {
              ctx.addIssue({
                code: 'custom',
                path: ['date'],
                message: t('recurring.occurrence.postponeLater'),
              });
            }
            return;
          }
          checkAmount(ctx, {
            value: values.amount,
            path: 'amount',
            locale: formatLocale,
            currency,
            exponent,
            // Recording may use the expected amount; changing the amount needs one.
            optional: kind === 'confirm' && Boolean(expected),
            t,
          });
          if (kind === 'confirm') {
            if (values.date && !isLocalDate(values.date)) {
              ctx.addIssue({
                code: 'custom',
                path: ['date'],
                message: t('validation.dateInvalid'),
              });
            }
            if (needsAccount && !values.accountId) {
              ctx.addIssue({
                code: 'custom',
                path: ['accountId'],
                message: t('recurring.occurrence.accountRequired'),
              });
            }
          }
        }),
    [t, formatLocale, kind, occurrence.effective_date, currency, exponent, expected, needsAccount],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      amount: '',
      // Recording: the due date, or today when recording early (like the API's default).
      date:
        kind === 'confirm'
          ? occurrence.effective_date <= today
            ? occurrence.effective_date
            : today
          : '',
      accountId: choices.length === 1 ? (choices[0]?.id ?? '') : '',
    },
  });
  const { errors } = form.formState;

  const submit = form.handleSubmit(async (values) => {
    if (pending) return;
    setFormError(null);
    const amount = values.amount.trim()
      ? normalizeDecimalInput(values.amount, formatLocale, { exponent })
      : null;
    let body: OccurrenceAction;
    if (kind === 'postpone') {
      body = { action: 'postpone', postpone_to: values.date };
    } else if (kind === 'amount') {
      if (!amount?.ok) return;
      body = { action: 'set_amount', amount: amount.value };
    } else {
      body = {
        action: 'confirm',
        ...(amount?.ok ? { amount: amount.value } : {}),
        ...(values.date ? { date: values.date } : {}),
        ...(needsAccount && values.accountId ? { account_id: values.accountId } : {}),
      };
    }
    try {
      await onSubmit(body);
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          amount: 'amount',
          date: 'date',
          postpone_to: 'date',
          account_id: 'accountId',
        });
        setFormError(rest.length > 0 ? rest.join(' ') : null);
      } else {
        setFormError(planningErrorMessage(error, t, formatLocale));
      }
    }
  });

  const submitLabel =
    kind === 'confirm'
      ? t('recurring.occurrence.confirmSubmit')
      : kind === 'postpone'
        ? t('recurring.occurrence.postponeSubmit')
        : t('recurring.occurrence.amountSubmit');

  return (
    <form onSubmit={submit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {kind === 'postpone' ? (
        <TextField
          label={t('recurring.occurrence.postponeTo')}
          type="date"
          min={occurrence.effective_date}
          error={errors.date?.message}
          {...form.register('date')}
        />
      ) : (
        <MoneyField
          label={
            kind === 'amount'
              ? t('recurring.occurrence.newAmount')
              : t('recurring.occurrence.amount')
          }
          currency={currency}
          optional={kind === 'confirm' && Boolean(expected)}
          help={
            kind === 'confirm' && expected
              ? t('recurring.occurrence.amountDefault', { amount: formatMoney(expected) })
              : undefined
          }
          error={errors.amount?.message}
          {...form.register('amount')}
        />
      )}
      {kind === 'confirm' ? (
        <>
          <TextField
            label={t('recurring.occurrence.date')}
            type="date"
            help={t('recurring.occurrence.dateHelp')}
            error={errors.date?.message}
            {...form.register('date')}
          />
          {needsAccount ? (
            <Select
              label={t('recurring.occurrence.account')}
              placeholder={t('recurring.form.accountChoose')}
              groups={accountGroups(choices, t)}
              error={errors.accountId?.message}
              {...form.register('accountId')}
            />
          ) : null}
        </>
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={pending} onClick={onClose}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={pending}>
          {submitLabel}
        </Button>
      </div>
    </form>
  );
}
