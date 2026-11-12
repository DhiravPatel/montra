import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Controller, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { MoneyText } from '@/shared/components/MoneyText';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select, type SelectOption } from '@/shared/components/Select';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Account } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatLocalDate, isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { reconciliationApi } from '../api';
import { reconciliationErrorMessage } from '../errors';
import type { BalanceKind, Reconciliation, ReconciliationInput } from '../types';

interface Values {
  date: string;
  kind: BalanceKind;
  balance: string;
  importId: string;
  notes: string;
}

interface ReconcileFormProps {
  account: Account;
  /** This account's statement imports, to link the check to one (optional). */
  importOptions: readonly SelectOption[];
  /** The statement import chosen on the page (also scopes the suggestions). */
  importId: string;
  onImportChange: (importId: string) => void;
}

/**
 * Checks the account against a statement: the user enters the statement
 * date and closing balance; the server computes the ledger balance on that
 * date and the difference, and marks transactions reconciled when they agree.
 */
export function ReconcileForm({
  account,
  importOptions,
  importId,
  onImportChange,
}: ReconcileFormProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  const announce = useAnnounce();
  const formatMoney = useFormatMoney();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const [result, setResult] = useState<Reconciliation | null>(null);
  const liability = account.is_liability;
  const exponent = exponentFor(currencies.data, account.currency);

  const schema = useMemo(
    () =>
      z
        .object({
          date: z.string(),
          kind: z.enum(['balance', 'amount_owed']),
          balance: z.string(),
          importId: z.string(),
          notes: z
            .string()
            .trim()
            .max(1000, { error: t('validation.maxLength', { max: 1000 }) }),
        })
        .superRefine((values, ctx) => {
          if (!values.date) {
            ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateRequired') });
          } else if (!isLocalDate(values.date)) {
            ctx.addIssue({ code: 'custom', path: ['date'], message: t('validation.dateInvalid') });
          }
          checkAmount(ctx, {
            value: values.balance,
            path: 'balance',
            locale: formatLocale,
            currency: account.currency,
            exponent,
            allowNegative: true,
            allowZero: true,
            t,
          });
        }),
    [t, formatLocale, account.currency, exponent],
  );

  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      date: todayInTimeZone(user.timezone),
      kind: liability ? 'amount_owed' : 'balance',
      balance: '',
      importId,
      notes: '',
    },
  });
  const kind = useWatch({ control: form.control, name: 'kind' });

  const mutation = useMutation({
    mutationFn: (body: ReconciliationInput) => reconciliationApi.reconcile(account.id, body),
    // A balanced check marks transactions reconciled: refresh history and lists (not awaited,
    // so the result shows at once).
    onSuccess: () => {
      void invalidateFinance(queryClient);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const exact = normalizeDecimalInput(values.balance, formatLocale, {
      exponent,
      allowNegative: true,
      allowZero: true,
    });
    if (!exact.ok) return;
    const notes = values.notes.trim();
    const body: ReconciliationInput = {
      statement_date: values.date,
      statement_balance: exact.value,
      ...(liability ? { balance_kind: values.kind } : {}),
      ...(values.importId ? { import_batch_id: values.importId } : {}),
      ...(notes ? { notes } : {}),
    };
    try {
      const outcome = await mutation.mutateAsync(body);
      setResult(outcome);
      announce(
        outcome.status === 'balanced'
          ? t('reconciliation.result.announceBalanced')
          : t('reconciliation.result.announceUnbalanced', {
              difference: formatMoney(outcome.difference, { signDisplay: 'exceptZero' }),
            }),
      );
    } catch (error) {
      setResult(null);
      if (hasErrorCode(error, 'VALIDATION_ERROR') && error.details.length > 0) {
        const rest = applyServerErrors(error, form.setError, {
          statement_date: 'date',
          statement_balance: 'balance',
          balance_kind: 'kind',
          import_batch_id: 'importId',
          notes: 'notes',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(reconciliationErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  return (
    <div className="space-y-6">
      <form onSubmit={onSubmit} noValidate className="space-y-5">
        <FormAlert message={formError} />
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            label={t('reconciliation.form.date')}
            type="date"
            help={t('reconciliation.form.dateHelp')}
            error={errors.date?.message}
            {...form.register('date')}
          />
          <Controller
            control={form.control}
            name="importId"
            render={({ field }) => (
              <Select
                label={t('reconciliation.form.import')}
                optional
                help={t('reconciliation.form.importHelp')}
                options={[
                  { value: '', label: t('reconciliation.form.noImport') },
                  ...importOptions,
                ]}
                name={field.name}
                value={field.value}
                onBlur={field.onBlur}
                onChange={(event) => {
                  field.onChange(event.target.value);
                  onImportChange(event.target.value);
                }}
                error={errors.importId?.message}
              />
            )}
          />
        </div>
        {liability ? (
          <Controller
            control={form.control}
            name="kind"
            render={({ field }) => (
              <RadioGroup
                legend={t('reconciliation.form.kind')}
                variant="cards"
                value={field.value}
                onChange={field.onChange}
                error={errors.kind?.message}
                options={[
                  {
                    value: 'amount_owed',
                    label: t('reconciliation.form.kindOwed'),
                    description: t('reconciliation.form.kindOwedHelp'),
                  },
                  {
                    value: 'balance',
                    label: t('reconciliation.form.kindBalance'),
                    description: t('reconciliation.form.kindBalanceHelp'),
                  },
                ]}
              />
            )}
          />
        ) : null}
        <MoneyField
          label={
            liability && kind === 'amount_owed'
              ? t('reconciliation.form.owed')
              : t('reconciliation.form.balance')
          }
          currency={account.currency}
          help={
            liability && kind === 'amount_owed'
              ? t('reconciliation.form.owedHelp')
              : t('reconciliation.form.balanceHelp')
          }
          error={errors.balance?.message}
          {...form.register('balance')}
        />
        <TextArea
          label={t('reconciliation.form.notes')}
          optional
          maxLength={1000}
          error={errors.notes?.message}
          {...form.register('notes')}
        />
        <div className="flex justify-end">
          <Button type="submit" loading={mutation.isPending}>
            <Icon name="scale" className="size-4" />
            {t('reconciliation.form.submit')}
          </Button>
        </div>
      </form>
      {result ? <ReconcileResult result={result} liability={liability} /> : null}
    </div>
  );
}

/** The server's answer: both balances, the difference and what changed. */
export function ReconcileResult({
  result,
  liability,
}: {
  result: Reconciliation;
  liability: boolean;
}) {
  const { t, formatLocale } = useI18n();
  const balanced = result.status === 'balanced';
  return (
    <section
      aria-labelledby="reconcile-result-title"
      className="space-y-4 rounded-lg border border-line p-4"
    >
      <div className="flex flex-wrap items-center gap-3">
        <h3 id="reconcile-result-title" className="text-base font-semibold text-fg">
          {t('reconciliation.result.title', {
            date: formatLocalDate(result.statement_date, formatLocale, 'long'),
          })}
        </h3>
        <StatusBadge
          tone={balanced ? 'success' : 'warning'}
          icon={balanced ? 'check-circle' : 'alert-triangle'}
        >
          {balanced ? t('reconciliation.status.balanced') : t('reconciliation.status.unbalanced')}
        </StatusBadge>
      </div>
      <Facts>
        <Fact label={t('reconciliation.result.statement')}>
          <MoneyText money={result.statement_balance} />
        </Fact>
        <Fact label={t('reconciliation.result.ledger')}>
          <MoneyText money={result.ledger_balance} />
        </Fact>
        <Fact label={t('reconciliation.result.difference')}>
          <MoneyText money={result.difference} signDisplay="exceptZero" className="font-semibold" />
        </Fact>
      </Facts>
      {liability ? (
        <p className="text-sm text-fg-muted">{t('reconciliation.result.liabilityNote')}</p>
      ) : null}
      {balanced ? (
        <Alert tone="success" title={t('reconciliation.result.balancedTitle')}>
          <p>{t('reconciliation.result.reconciledCount', { count: result.reconciled_count })}</p>
        </Alert>
      ) : (
        <Alert tone="warning" title={t('reconciliation.result.unbalancedTitle')}>
          <p>{t('reconciliation.result.unbalancedBody')}</p>
        </Alert>
      )}
      <ul className="list-disc space-y-1 ps-5 text-sm text-fg">
        <li>
          {t('reconciliation.result.unreconciled', { count: result.unreconciled_transactions })}
        </li>
        {result.import_batch_id ? (
          <li>
            {t('reconciliation.result.unmatchedRows', { count: result.unmatched_statement_rows })}
          </li>
        ) : null}
      </ul>
    </section>
  );
}
