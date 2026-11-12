import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { type Path, useFieldArray, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { type Currency, currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { receiptsApi } from '../api';
import { receiptErrorMessage } from '../errors';
import {
  type ReviewValues,
  MAX_LINE_ITEMS,
  TEXT_LIMITS,
  emptyLine,
  isReceiptTime,
  lineIsBlank,
  normalizeQuantity,
  paymentHintIsSafe,
  reviewDefaults,
  toReviewRequest,
} from '../formValues';
import { reviewedValues, warningMessages } from '../labels';
import type { ReceiptDetail, ReceiptReviewInput } from '../types';

interface ReceiptReviewFormProps {
  receipt: ReceiptDetail;
  /** The receipt changed elsewhere (409 VERSION_CONFLICT): reload it. */
  onConflict: () => void;
  onSaved: () => void;
}

/**
 * Manual review: the person types (or corrects) every value from the
 * receipt. Each save is stored as a new version; earlier versions are kept.
 * Currencies are needed first for the currency choice and amount precision.
 */
export function ReceiptReviewForm(props: ReceiptReviewFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  if (currencies.isPending) return <LoadingState label={t('receipts.review.loading')} />;
  if (currencies.isError) {
    return (
      <ErrorState
        titleAs="p"
        title={t('receipts.review.loadFailed')}
        error={currencies.error}
        retrying={currencies.isFetching}
        onRetry={() => {
          void currencies.refetch();
        }}
      />
    );
  }
  return <ReviewForm {...props} currencies={currencies.data} />;
}

type AmountField = 'subtotal' | 'tax' | 'tip' | 'discount';
type LineAmountField = 'unitPrice' | 'amount' | 'tax';

const BREAKDOWN: readonly AmountField[] = ['subtotal', 'tax', 'tip', 'discount'];
const LINE_AMOUNTS: readonly LineAmountField[] = ['unitPrice', 'amount', 'tax'];

function ReviewForm({
  receipt,
  currencies,
  onConflict,
  onSaved,
}: ReceiptReviewFormProps & { currencies: Currency[] }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const reviewed = reviewedValues(receipt);
  const today = todayInTimeZone(user.timezone);

  const schema = useMemo(
    () =>
      z
        .object({
          merchant: z
            .string()
            .trim()
            .max(TEXT_LIMITS.merchant, {
              error: t('validation.maxLength', { max: TEXT_LIMITS.merchant }),
            }),
          date: z.string(),
          time: z.string(),
          currency: z.string().min(1, { error: t('receipts.review.errors.currency') }),
          total: z.string(),
          subtotal: z.string(),
          tax: z.string(),
          tip: z.string(),
          discount: z.string(),
          paymentHint: z
            .string()
            .trim()
            .max(TEXT_LIMITS.paymentHint, {
              error: t('validation.maxLength', { max: TEXT_LIMITS.paymentHint }),
            })
            .refine(paymentHintIsSafe, { error: t('receipts.review.errors.paymentHint') }),
          receiptNumber: z
            .string()
            .trim()
            .max(TEXT_LIMITS.receiptNumber, {
              error: t('validation.maxLength', { max: TEXT_LIMITS.receiptNumber }),
            }),
          lines: z
            .array(
              z.object({
                description: z.string(),
                quantity: z.string(),
                unitPrice: z.string(),
                amount: z.string(),
                tax: z.string(),
              }),
            )
            .max(MAX_LINE_ITEMS),
        })
        .superRefine((values, ctx) => {
          const issue = (path: string, message: string) => {
            ctx.addIssue({ code: 'custom', path: [path], message });
          };
          if (!values.date) issue('date', t('validation.dateRequired'));
          else if (!isLocalDate(values.date)) issue('date', t('validation.dateInvalid'));
          else if (values.date > today) issue('date', t('receipts.review.errors.futureDate'));
          if (values.time && !isReceiptTime(values.time)) {
            issue('time', t('receipts.review.errors.time'));
          }
          const rules = {
            locale: formatLocale,
            currency: values.currency,
            exponent: exponentFor(currencies, values.currency),
            t,
          };
          checkAmount(ctx, { ...rules, value: values.total, path: 'total' });
          for (const field of BREAKDOWN) {
            checkAmount(ctx, {
              ...rules,
              value: values[field],
              path: field,
              optional: true,
              allowZero: true,
            });
          }
          for (const [index, line] of values.lines.entries()) {
            if (lineIsBlank(line)) continue;
            if (line.description.trim().length > TEXT_LIMITS.lineDescription) {
              issue(
                `lines.${index}.description`,
                t('validation.maxLength', { max: TEXT_LIMITS.lineDescription }),
              );
            }
            if (line.quantity.trim() && normalizeQuantity(line.quantity, formatLocale) === null) {
              issue(`lines.${index}.quantity`, t('receipts.review.errors.quantity'));
            }
            for (const field of LINE_AMOUNTS) {
              checkAmount(ctx, {
                ...rules,
                value: line[field],
                path: `lines.${index}.${field}`,
                optional: true,
                allowZero: true,
              });
            }
          }
        }),
    [t, formatLocale, currencies, today],
  );

  const form = useForm<ReviewValues, unknown, ReviewValues>({
    resolver: zodResolver(schema),
    defaultValues: reviewDefaults(reviewed, user.base_currency, formatLocale),
  });
  const lines = useFieldArray({ control: form.control, name: 'lines' });
  const currency = useWatch({ control: form.control, name: 'currency' });

  const mutation = useMutation({
    mutationFn: (body: ReceiptReviewInput) => receiptsApi.review(receipt.id, body),
    onSuccess: () => invalidateFinance(queryClient),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const request = toReviewRequest(
      values,
      receipt.version,
      formatLocale,
      exponentFor(currencies, values.currency),
    );
    if (!request) return;
    try {
      await mutation.mutateAsync(request.body);
      toast.show({ tone: 'success', title: t('receipts.review.saved') });
      onSaved();
    } catch (error) {
      if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        onConflict();
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const fields: Record<string, Path<ReviewValues>> = {
          merchant_name: 'merchant',
          receipt_date: 'date',
          receipt_time: 'time',
          currency: 'currency',
          total: 'total',
          subtotal: 'subtotal',
          tax: 'tax',
          tip: 'tip',
          discount: 'discount',
          payment_hint: 'paymentHint',
          receipt_number: 'receiptNumber',
        };
        for (const [sent, index] of request.lineIndexes.entries()) {
          fields[`line_items[${sent}].description`] = `lines.${index}.description`;
          fields[`line_items[${sent}].quantity`] = `lines.${index}.quantity`;
          fields[`line_items[${sent}].unit_price`] = `lines.${index}.unitPrice`;
          fields[`line_items[${sent}].amount`] = `lines.${index}.amount`;
          fields[`line_items[${sent}].tax`] = `lines.${index}.tax`;
        }
        const rest = applyServerErrors(error, form.setError, fields);
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(receiptErrorMessage(error, 'review', t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  const warnings = reviewed ? warningMessages(reviewed, t, formatLocale) : [];
  const breakdownLabel: Readonly<Record<AmountField, string>> = {
    subtotal: t('receipts.fields.subtotal'),
    tax: t('receipts.fields.tax'),
    tip: t('receipts.fields.tip'),
    discount: t('receipts.fields.discount'),
  };

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-6">
      <FormAlert message={formError} />
      {warnings.length > 0 ? (
        <Alert tone="warning" title={t('receipts.review.warningsTitle')}>
          <ul className="list-disc space-y-1 ps-5">
            {warnings.map((warning) => (
              <li key={warning}>{warning}</li>
            ))}
          </ul>
        </Alert>
      ) : null}
      <p className="text-sm text-fg-muted">{t('receipts.review.intro')}</p>
      <div className="grid gap-5 sm:grid-cols-2">
        <TextField
          label={t('receipts.fields.merchant')}
          optional
          maxLength={TEXT_LIMITS.merchant}
          autoComplete="off"
          error={errors.merchant?.message}
          className="sm:col-span-2"
          {...form.register('merchant')}
        />
        <TextField
          label={t('receipts.fields.date')}
          type="date"
          max={today}
          error={errors.date?.message}
          {...form.register('date')}
        />
        <TextField
          label={t('receipts.fields.time')}
          type="time"
          optional
          error={errors.time?.message}
          {...form.register('time')}
        />
        <Select
          label={t('receipts.fields.currency')}
          options={currencyOptions(currencies, formatLocale, reviewed?.currency)}
          error={errors.currency?.message}
          {...form.register('currency')}
        />
        <MoneyField
          label={t('receipts.fields.total')}
          currency={currency || null}
          help={t('receipts.review.totalHelp')}
          error={errors.total?.message}
          {...form.register('total')}
        />
      </div>

      <section aria-labelledby="receipt-breakdown" className="space-y-4">
        <h3 id="receipt-breakdown" className="text-sm font-semibold text-fg">
          {t('receipts.review.breakdown')}
        </h3>
        <div className="grid gap-5 sm:grid-cols-2">
          {BREAKDOWN.map((field) => (
            <MoneyField
              key={field}
              label={breakdownLabel[field]}
              currency={currency || null}
              optional
              error={errors[field]?.message}
              {...form.register(field)}
            />
          ))}
          <TextField
            label={t('receipts.fields.paymentHint')}
            help={t('receipts.review.paymentHintHelp')}
            optional
            maxLength={TEXT_LIMITS.paymentHint}
            autoComplete="off"
            error={errors.paymentHint?.message}
            {...form.register('paymentHint')}
          />
          <TextField
            label={t('receipts.fields.receiptNumber')}
            optional
            maxLength={TEXT_LIMITS.receiptNumber}
            autoComplete="off"
            error={errors.receiptNumber?.message}
            {...form.register('receiptNumber')}
          />
        </div>
      </section>

      <section aria-labelledby="receipt-items" className="space-y-4">
        <div className="space-y-1">
          <h3 id="receipt-items" className="text-sm font-semibold text-fg">
            {t('receipts.fields.lineItems')}{' '}
            <span className="font-normal text-fg-muted">({t('common.optional')})</span>
          </h3>
          <p className="text-sm text-fg-muted">{t('receipts.review.itemsHelp')}</p>
        </div>
        {lines.fields.map((field, index) => {
          const lineErrors = errors.lines?.[index];
          return (
            <fieldset key={field.id} className="space-y-4 rounded-lg border border-line p-4">
              <legend className="px-1 text-sm font-medium text-fg">
                {t('receipts.review.item', { number: index + 1 })}
              </legend>
              <TextField
                label={t('receipts.fields.description')}
                optional
                maxLength={TEXT_LIMITS.lineDescription}
                autoComplete="off"
                error={lineErrors?.description?.message}
                {...form.register(`lines.${index}.description`)}
              />
              <div className="grid gap-4 sm:grid-cols-2">
                <TextField
                  label={t('receipts.fields.quantity')}
                  optional
                  inputMode="decimal"
                  autoComplete="off"
                  error={lineErrors?.quantity?.message}
                  {...form.register(`lines.${index}.quantity`)}
                />
                <MoneyField
                  label={t('receipts.fields.unitPrice')}
                  currency={currency || null}
                  optional
                  error={lineErrors?.unitPrice?.message}
                  {...form.register(`lines.${index}.unitPrice`)}
                />
                <MoneyField
                  label={t('receipts.fields.lineAmount')}
                  currency={currency || null}
                  optional
                  error={lineErrors?.amount?.message}
                  {...form.register(`lines.${index}.amount`)}
                />
                <MoneyField
                  label={t('receipts.fields.lineTax')}
                  currency={currency || null}
                  optional
                  error={lineErrors?.tax?.message}
                  {...form.register(`lines.${index}.tax`)}
                />
              </div>
              <Button
                variant="ghost"
                size="sm"
                aria-label={t('receipts.review.removeItemLabel', { number: index + 1 })}
                onClick={() => {
                  lines.remove(index);
                }}
              >
                <Icon name="trash" className="size-4" />
                {t('receipts.review.removeItem')}
              </Button>
            </fieldset>
          );
        })}
        {lines.fields.length < MAX_LINE_ITEMS ? (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              lines.append(emptyLine());
            }}
          >
            <Icon name="plus" className="size-4" />
            {t('receipts.review.addItem')}
          </Button>
        ) : (
          <p className="text-sm text-fg-muted">
            {t('receipts.review.itemsLimit', { max: MAX_LINE_ITEMS })}
          </p>
        )}
      </section>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button type="submit" loading={mutation.isPending}>
          {reviewed ? t('receipts.review.saveChanges') : t('receipts.review.save')}
        </Button>
      </div>
    </form>
  );
}
