import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { Controller, useFieldArray, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts } from '@/shared/finance/reference';
import { groupOptions, useGroups } from '@/shared/finance/sharing';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { goalErrorMessage } from '../errors';
import { type GoalAmounts, type GoalFormValues, MAX_MILESTONES } from '../formValues';
import {
  CONTRIBUTION_SCHEDULES,
  GOAL_TYPES,
  PRIORITIES,
  goalTypeLabel,
  isGoalType,
  priorityLabel,
  scheduleLabel,
} from '../labels';

function buildSchema(t: Translate, locale: string, exponent: (currency: string) => number) {
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { error: t('goals.form.nameRequired') })
        .max(120, { error: t('validation.maxLength', { max: 120 }) }),
      goalType: z.string(),
      currency: z.string().regex(/^[A-Z]{3}$/, { error: t('validation.currencyRequired') }),
      target: z.string(),
      starting: z.string(),
      startDate: z.string(),
      targetDate: z.string(),
      schedule: z.string(),
      planned: z.string(),
      priority: z.string(),
      milestones: z.array(
        z.object({
          percent: z.string(),
          label: z
            .string()
            .trim()
            .max(80, { error: t('validation.maxLength', { max: 80 }) }),
        }),
      ),
      linkedAccountId: z.string(),
      groupId: z.string(),
      visibility: z.enum(['private', 'members']),
      reminders: z.boolean(),
      description: z.string().max(2000, { error: t('validation.maxLength', { max: 2000 }) }),
      notes: z.string().max(2000, { error: t('validation.maxLength', { max: 2000 }) }),
    })
    .superRefine((values, ctx) => {
      if (!isGoalType(values.goalType)) {
        ctx.addIssue({ code: 'custom', path: ['goalType'], message: t('goals.form.typeRequired') });
      }
      const digits = exponent(values.currency);
      const amount = (path: 'target' | 'starting' | 'planned', optional: boolean) =>
        checkAmount(ctx, {
          value: values[path],
          path,
          locale,
          currency: values.currency,
          exponent: digits,
          allowZero: path === 'starting',
          optional,
          t,
        });
      amount('target', false);
      amount('starting', true);
      // A contribution schedule needs its planned amount (the API refuses one without it).
      if (values.schedule !== 'none') amount('planned', false);

      if (!values.startDate) {
        ctx.addIssue({
          code: 'custom',
          path: ['startDate'],
          message: t('validation.dateRequired'),
        });
      } else if (!isLocalDate(values.startDate)) {
        ctx.addIssue({ code: 'custom', path: ['startDate'], message: t('validation.dateInvalid') });
      }
      if (values.targetDate) {
        if (!isLocalDate(values.targetDate)) {
          ctx.addIssue({
            code: 'custom',
            path: ['targetDate'],
            message: t('validation.dateInvalid'),
          });
        } else if (isLocalDate(values.startDate) && values.targetDate < values.startDate) {
          ctx.addIssue({
            code: 'custom',
            path: ['targetDate'],
            message: t('goals.form.dateOrder'),
          });
        }
      }

      const seen = new Set<number>();
      values.milestones.forEach((milestone, index) => {
        const text = milestone.percent.trim();
        const percent = Number(text);
        if (!/^\d{1,3}$/.test(text) || percent < 1 || percent > 100) {
          ctx.addIssue({
            code: 'custom',
            path: ['milestones', index, 'percent'],
            message: t('goals.form.milestonePercentInvalid'),
          });
        } else if (seen.has(percent)) {
          ctx.addIssue({
            code: 'custom',
            path: ['milestones', index, 'percent'],
            message: t('goals.form.milestoneDuplicate'),
          });
        } else {
          seen.add(percent);
        }
      });
    });
}

/** API field (without `body.`) -> form field. */
const serverFields = {
  name: 'name',
  goal_type: 'goalType',
  currency: 'currency',
  target_amount: 'target',
  starting_amount: 'starting',
  start_date: 'startDate',
  target_date: 'targetDate',
  contribution_schedule: 'schedule',
  planned_contribution: 'planned',
  priority: 'priority',
  linked_account_id: 'linkedAccountId',
  group_id: 'groupId',
  visibility: 'visibility',
  description: 'description',
  notes: 'notes',
} as const;

interface GoalFormProps {
  mode: 'create' | 'edit';
  initialValues: GoalFormValues;
  /** Set when editing: the goal's (fixed) currency. */
  lockedCurrency?: string;
  /**
   * Saves the validated values with their exact amounts (the page builds the
   * create body or the partial update); rejects with the API error so the
   * form can show it.
   */
  onSubmit: (values: GoalFormValues, amounts: GoalAmounts) => Promise<void>;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  submitLabel: string;
  secondaryAction?: ReactNode;
}

/**
 * Renders once currencies, accounts and groups have loaded, so the selects
 * show the saved choices.
 */
export function GoalForm(props: GoalFormProps) {
  const { t } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const groups = useGroups();
  const failed = currencies.isError
    ? { title: t('currency.loadFailed'), query: currencies }
    : accounts.isError
      ? { title: t('accounts.list.error'), query: accounts }
      : groups.isError
        ? { title: t('states.error.title'), query: groups }
        : null;
  if (failed) {
    return (
      <ErrorState
        title={failed.title}
        error={failed.query.error}
        retrying={failed.query.isFetching}
        onRetry={() => {
          void failed.query.refetch();
        }}
      />
    );
  }
  if (currencies.isPending || accounts.isPending || groups.isPending) {
    return <LoadingState label={t('common.loading')} />;
  }
  return <GoalFormInner {...props} />;
}

function GoalFormInner({
  mode,
  initialValues,
  lockedCurrency,
  onSubmit,
  onError,
  submitLabel,
  secondaryAction,
}: GoalFormProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const accounts = useAccounts(true);
  const groups = useGroups();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const schema = useMemo(
    () => buildSchema(t, formatLocale, (code) => exponentFor(currencies.data, code)),
    [t, formatLocale, currencies.data],
  );
  const form = useForm<GoalFormValues, unknown, GoalFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const milestones = useFieldArray({ control: form.control, name: 'milestones' });
  const [currency, schedule, groupId] = useWatch({
    control: form.control,
    name: ['currency', 'schedule', 'groupId'],
  });

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    const exponent = exponentFor(currencies.data, values.currency);
    // Already validated by the schema; this yields the exact canonical strings.
    const canonical = (raw: string) => {
      if (!raw.trim()) return null;
      const result = normalizeDecimalInput(raw, formatLocale, { exponent, allowZero: true });
      return result.ok ? result.value : null;
    };
    const target = canonical(values.target);
    if (!target) return;
    setSubmitting(true);
    try {
      await onSubmit(values, {
        target,
        starting: canonical(values.starting),
        planned: canonical(values.planned),
      });
    } catch (error) {
      if (onError?.(error)) return;
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
    } finally {
      setSubmitting(false);
    }
  });

  const { errors } = form.formState;
  const keepCurrency = lockedCurrency ?? initialValues.currency;
  const accountChoices = (accounts.data ?? []).filter(
    (account) =>
      (account.owned && account.status === 'active') ||
      account.id === initialValues.linkedAccountId,
  );
  const plannedLabel = t('goals.form.planned');
  const groupChoices = groupOptions(groups.data);
  if (initialValues.groupId && !groupChoices.some((o) => o.value === initialValues.groupId)) {
    // Keep a linked group that is no longer active, so saving does not unlink it.
    groupChoices.push({ value: initialValues.groupId, label: t('goals.form.groupInactive') });
  }

  return (
    <form onSubmit={onValid} noValidate className="space-y-6">
      <FormAlert message={formError} />
      <TextField
        label={t('goals.form.name')}
        help={t('goals.form.nameHelp')}
        maxLength={120}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('goals.form.type')}
          placeholder={t('goals.form.typePlaceholder')}
          options={GOAL_TYPES.map((type) => ({ value: type, label: t(goalTypeLabel[type]) }))}
          error={errors.goalType?.message}
          {...form.register('goalType')}
        />
        <Select
          label={t('goals.form.currency')}
          placeholder={t('auth.fields.currencyPlaceholder')}
          options={currencyOptions(currencies.data, formatLocale, keepCurrency)}
          disabled={mode === 'edit'}
          help={mode === 'edit' ? t('goals.form.currencyLocked') : undefined}
          error={errors.currency?.message}
          {...form.register('currency')}
        />
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <MoneyField
          label={t('goals.form.target')}
          currency={currency || null}
          error={errors.target?.message}
          {...form.register('target')}
        />
        <MoneyField
          label={t('goals.form.starting')}
          currency={currency || null}
          optional
          help={t('goals.form.startingHelp')}
          error={errors.starting?.message}
          {...form.register('starting')}
        />
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <TextField
          label={t('goals.form.startDate')}
          type="date"
          error={errors.startDate?.message}
          {...form.register('startDate')}
        />
        <TextField
          label={t('goals.form.targetDate')}
          type="date"
          optional
          help={t('goals.form.targetDateHelp')}
          error={errors.targetDate?.message}
          {...form.register('targetDate')}
        />
      </div>

      <fieldset className="space-y-5 rounded-lg border border-line p-4">
        <legend className="px-1 text-sm font-semibold text-fg">{t('goals.form.plan')}</legend>
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('goals.form.schedule')}
            options={CONTRIBUTION_SCHEDULES.map((value) => ({
              value,
              label: t(scheduleLabel[value]),
            }))}
            error={errors.schedule?.message}
            {...form.register('schedule')}
          />
          {schedule !== 'none' ? (
            <MoneyField
              label={plannedLabel}
              currency={currency || null}
              help={t('goals.form.plannedHelp')}
              error={errors.planned?.message}
              {...form.register('planned')}
            />
          ) : null}
        </div>
        <Select
          label={t('goals.form.priority')}
          help={t('goals.form.priorityHelp')}
          options={PRIORITIES.map((value) => ({
            value: String(value),
            label: t(priorityLabel(value)),
          }))}
          error={errors.priority?.message}
          {...form.register('priority')}
        />
        <Checkbox
          label={t('goals.form.reminders')}
          description={t('goals.form.remindersHelp')}
          {...form.register('reminders')}
        />
      </fieldset>

      <fieldset className="space-y-4 rounded-lg border border-line p-4">
        <legend className="px-1 text-sm font-semibold text-fg">{t('goals.form.milestones')}</legend>
        <p className="text-sm text-fg-muted">{t('goals.form.milestonesHelp')}</p>
        {milestones.fields.length === 0 ? (
          <p className="text-sm text-fg-muted">{t('goals.form.noMilestones')}</p>
        ) : (
          <ul className="space-y-3">
            {milestones.fields.map((field, index) => {
              const number = index + 1;
              return (
                <li key={field.id} className="grid items-start gap-3 sm:grid-cols-[8rem_1fr_auto]">
                  <TextField
                    label={t('goals.form.milestonePercent', { index: number })}
                    inputMode="numeric"
                    maxLength={3}
                    autoComplete="off"
                    error={errors.milestones?.[index]?.percent?.message}
                    {...form.register(`milestones.${index}.percent`)}
                  />
                  <TextField
                    label={t('goals.form.milestoneLabel', { index: number })}
                    optional
                    maxLength={80}
                    autoComplete="off"
                    error={errors.milestones?.[index]?.label?.message}
                    {...form.register(`milestones.${index}.label`)}
                  />
                  <IconButton
                    icon="trash"
                    label={t('goals.form.removeMilestone', { index: number })}
                    className="sm:mt-7"
                    onClick={() => {
                      milestones.remove(index);
                    }}
                  />
                </li>
              );
            })}
          </ul>
        )}
        {milestones.fields.length < MAX_MILESTONES ? (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              milestones.append({ percent: '', label: '' });
            }}
          >
            <Icon name="plus" className="size-4" />
            {t('goals.form.addMilestone')}
          </Button>
        ) : null}
      </fieldset>

      <Select
        label={t('goals.form.linkedAccount')}
        optional
        placeholder={t('common.none')}
        groups={accountGroups(accountChoices, t)}
        help={t('goals.form.linkedAccountHelp')}
        error={errors.linkedAccountId?.message}
        {...form.register('linkedAccountId')}
      />
      <Select
        label={t('goals.form.group')}
        optional
        placeholder={t('common.none')}
        options={groupChoices}
        help={t('goals.form.groupHelp')}
        error={errors.groupId?.message}
        {...form.register('groupId')}
      />
      {groupId ? (
        <Controller
          control={form.control}
          name="visibility"
          render={({ field }) => (
            <RadioGroup
              legend={t('goals.form.visibility')}
              variant="cards"
              value={field.value}
              onChange={field.onChange}
              options={[
                {
                  value: 'private',
                  label: t('goals.visibility.private'),
                  description: t('goals.visibility.privateHelp'),
                },
                {
                  value: 'members',
                  label: t('goals.visibility.members'),
                  description: t('goals.visibility.membersHelp'),
                },
              ]}
            />
          )}
        />
      ) : null}
      <TextArea
        label={t('goals.form.descriptionField')}
        optional
        maxLength={2000}
        error={errors.description?.message}
        {...form.register('description')}
      />
      <TextArea
        label={t('goals.form.notes')}
        optional
        maxLength={2000}
        error={errors.notes?.message}
        {...form.register('notes')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        {secondaryAction}
        <Button type="submit" loading={submitting}>
          {submitLabel}
        </Button>
      </div>
    </form>
  );
}
