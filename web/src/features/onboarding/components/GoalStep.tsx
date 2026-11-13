import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { invalidateFinance } from '@/shared/finance/keys';
import type { GoalInput } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalsApi } from '@/features/goals/api';
import { goalErrorMessage } from '@/features/goals/errors';
import { GOAL_TYPES, goalTypeLabel, isGoalType } from '@/features/goals/labels';
import { StepActions } from './StepActions';
import type { StepProps } from './types';

interface GoalStepValues {
  name: string;
  goalType: string;
  target: string;
  targetDate: string;
}

/** API field (without `body.`) -> form field. */
const serverFields = {
  name: 'name',
  goal_type: 'goalType',
  target_amount: 'target',
  target_date: 'targetDate',
} as const;

/**
 * An optional first savings goal (spec §4.1): a name, a type, a target in
 * the main currency and an optional date, created with `POST /goals`. More
 * (a plan, milestones, sharing) can be added from the goal's page later.
 */
export function GoalStep(props: StepProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  if (currencies.isError) {
    return (
      <ErrorState
        title={t('currency.loadFailed')}
        error={currencies.error}
        retrying={currencies.isFetching}
        onRetry={() => {
          void currencies.refetch();
        }}
      />
    );
  }
  if (currencies.isPending) return <LoadingState label={t('currency.loading')} />;
  return <GoalStepForm {...props} />;
}

function GoalStepForm({ preferences, onNext, onBack, advancing }: StepProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const [today] = useState(() => todayInTimeZone(user.timezone));
  const currency = preferences.base_currency;
  const exponent = exponentFor(currencies.data, currency);
  // One key per draft: a retry after a lost response replays the first
  // result instead of creating the goal twice; a new key only after a success.
  const idempotency = useIdempotencyKey();
  const create = useMutation({
    mutationFn: (input: GoalInput) => goalsApi.create(input, idempotency.key),
    onSuccess: () => {
      idempotency.renew();
      void invalidateFinance(queryClient);
    },
  });

  const schema = useMemo(
    () =>
      z
        .object({
          name: z
            .string()
            .trim()
            .min(1, { error: t('goals.form.nameRequired') })
            .max(120, { error: t('validation.maxLength', { max: 120 }) }),
          goalType: z.string(),
          target: z.string(),
          targetDate: z.string(),
        })
        .superRefine((values, ctx) => {
          if (!isGoalType(values.goalType)) {
            ctx.addIssue({
              code: 'custom',
              path: ['goalType'],
              message: t('goals.form.typeRequired'),
            });
          }
          checkAmount(ctx, {
            value: values.target,
            path: 'target',
            locale: formatLocale,
            currency,
            exponent,
            t,
          });
          if (values.targetDate) {
            if (!isLocalDate(values.targetDate)) {
              ctx.addIssue({
                code: 'custom',
                path: ['targetDate'],
                message: t('validation.dateInvalid'),
              });
            } else if (values.targetDate < today) {
              // The goal starts today, and a target date cannot come before its start.
              ctx.addIssue({
                code: 'custom',
                path: ['targetDate'],
                message: t('onboarding.goals.datePast'),
              });
            }
          }
        }),
    [t, formatLocale, currency, exponent, today],
  );
  const form = useForm<GoalStepValues, unknown, GoalStepValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', goalType: '', target: '', targetDate: '' },
  });
  const { errors } = form.formState;

  const onSubmit = form.handleSubmit(async (values) => {
    if (create.isPending || advancing) return;
    setFormError(null);
    // Already validated by the schema: this yields the exact canonical decimal string.
    const target = normalizeDecimalInput(values.target, formatLocale, { exponent });
    if (!target.ok || !isGoalType(values.goalType)) return;
    try {
      const goal = await create.mutateAsync({
        name: values.name.trim(),
        goal_type: values.goalType,
        currency,
        target_amount: target.value,
        ...(values.targetDate ? { target_date: values.targetDate } : {}),
      });
      toast.show({ tone: 'success', title: t('onboarding.goals.created', { name: goal.name }) });
      onNext('completed');
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, serverFields);
        setFormError(
          rest.length > 0
            ? rest.join(' ')
            : error.details.length === 0
              ? t('errors.VALIDATION_ERROR')
              : null,
        );
      } else {
        setFormError(goalErrorMessage(error, t, formatLocale));
      }
    }
  });

  return (
    <form noValidate onSubmit={onSubmit} className="space-y-6">
      <FormAlert message={formError} />
      <p className="text-fg">{t('onboarding.goals.body')}</p>
      <TextField
        label={t('goals.form.name')}
        help={t('goals.form.nameHelp')}
        maxLength={120}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <Select
        label={t('goals.form.type')}
        placeholder={t('goals.form.typePlaceholder')}
        options={GOAL_TYPES.map((type) => ({ value: type, label: t(goalTypeLabel[type]) }))}
        error={errors.goalType?.message}
        {...form.register('goalType')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <MoneyField
          label={t('goals.form.target')}
          currency={currency}
          help={t('onboarding.goals.currencyHelp', { currency })}
          error={errors.target?.message}
          {...form.register('target')}
        />
        <TextField
          label={t('goals.form.targetDate')}
          type="date"
          optional
          min={today}
          help={t('goals.form.targetDateHelp')}
          error={errors.targetDate?.message}
          {...form.register('targetDate')}
        />
      </div>
      <StepActions
        onBack={onBack}
        onSkip={() => {
          onNext('skipped');
        }}
        primaryLabel={t('onboarding.goals.submit')}
        primaryType="submit"
        pending={create.isPending || advancing}
      />
    </form>
  );
}
