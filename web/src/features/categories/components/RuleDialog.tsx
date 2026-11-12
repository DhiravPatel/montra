import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { type UseFormSetError, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { type ApiError, hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoriesById } from '@/shared/finance/categories';
import { TransactionListItem } from '@/shared/finance/components/TransactionListItem';
import { invalidateFinance } from '@/shared/finance/keys';
import { accountGroups, categoryOptions } from '@/shared/finance/options';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import type {
  Account,
  Category,
  CategoryRule,
  CategoryRuleInput,
  CategoryRulePreview,
} from '@/shared/finance/types';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { compareDecimal, decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { rulesApi } from '../api';
import { organizeErrorMessage } from '../errors';
import {
  RULE_APPLY_TO,
  RULE_FIELDS,
  RULE_MATCHES,
  RULE_TYPES,
  isRuleApplyTo,
  isRuleField,
  isRuleMatch,
  isRuleType,
  ruleApplyToLabel,
  ruleFieldLabel,
  ruleMatchLabel,
  ruleTypeLabel,
} from '../labels';

interface RuleValues {
  name: string;
  matchField: string;
  matchType: string;
  pattern: string;
  categoryId: string;
  type: string;
  accountId: string;
  currency: string;
  amountMin: string;
  amountMax: string;
  applyTo: string;
  priority: string;
  enabled: boolean;
}

export type RuleDialogMode = { kind: 'create' } | { kind: 'edit'; rule: CategoryRule };

/** The API's default priority (RuleInput.priority). */
const DEFAULT_PRIORITY = 100;

interface RuleDialogProps {
  mode: RuleDialogMode | null;
  onClose: () => void;
}

/** Create or replace a categorization rule, with a preview on the user's transactions. */
export function RuleDialog({ mode, onClose }: RuleDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={mode !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={
        mode?.kind === 'edit' ? t('categoryRules.edit.title') : t('categoryRules.create.title')
      }
      busy={pending}
      size="lg"
    >
      {mode ? <RuleFormGate mode={mode} onPendingChange={setPending} onDone={onClose} /> : null}
    </Dialog>
  );
}

/**
 * The selects need categories, accounts and currencies before the form
 * starts. After a version conflict the latest rule is loaded and the form
 * starts again from it.
 */
function RuleFormGate(props: {
  mode: RuleDialogMode;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const categories = useCategories();
  const accounts = useAccounts();
  const currencies = useCurrencies();
  const [latest, setLatest] = useState<CategoryRule | null>(
    props.mode.kind === 'edit' ? props.mode.rule : null,
  );
  const [conflict, setConflict] = useState(false);
  const [reloadError, setReloadError] = useState<string | null>(null);
  const failed = [categories, accounts, currencies].find((query) => query.isError);
  if (failed) {
    return (
      <ErrorState
        error={failed.error}
        onRetry={() => {
          void categories.refetch();
          void accounts.refetch();
          void currencies.refetch();
        }}
      />
    );
  }
  if (!categories.data || !accounts.data || !currencies.data) return <LoadingState />;
  return (
    <>
      <FormAlert message={reloadError} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-5" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <RuleForm
        key={latest ? `${latest.id}:${latest.version}` : 'new'}
        onPendingChange={props.onPendingChange}
        onDone={props.onDone}
        rule={latest}
        categories={categories.data}
        accounts={accounts.data}
        onConflict={() => {
          setConflict(true);
          if (!latest) return;
          // Reload this rule alone; the form starts again from the latest version.
          rulesApi
            .get(latest.id)
            .then((fresh) => {
              setLatest(fresh);
              void invalidateFinance(queryClient);
            })
            .catch((error: unknown) => {
              setReloadError(
                hasErrorCode(error, 'NOT_FOUND')
                  ? t('categoryRules.notFound')
                  : describeError(error, t),
              );
            });
        }}
      />
    </>
  );
}

/** Server validation messages for rule fields; an invalid pattern gets our own wording. */
function applyRuleErrors(
  error: ApiError,
  setError: UseFormSetError<RuleValues>,
  t: Translate,
): string[] {
  const fields: Readonly<Record<string, keyof RuleValues>> = {
    name: 'name',
    match_field: 'matchField',
    match_type: 'matchType',
    pattern: 'pattern',
    set_category_id: 'categoryId',
    transaction_type: 'type',
    account_id: 'accountId',
    currency: 'currency',
    amount_min: 'amountMin',
    amount_max: 'amountMax',
    apply_to: 'applyTo',
    priority: 'priority',
  };
  const rest: string[] = [];
  let focused = false;
  for (const detail of error.details) {
    const apiField = detail.field?.replace(/^body\.(rule\.)?/, '');
    const field = apiField ? fields[apiField] : undefined;
    if (!field) {
      rest.push(detail.message);
      continue;
    }
    const message = field === 'pattern' ? t('categoryRules.form.patternInvalid') : detail.message;
    setError(field, { type: 'server', message }, { shouldFocus: !focused });
    focused = true;
  }
  return rest;
}

function RuleForm({
  rule,
  categories,
  accounts,
  onPendingChange,
  onDone,
  onConflict,
}: {
  /** The rule being edited (null when adding one). */
  rule: CategoryRule | null;
  categories: readonly Category[];
  accounts: readonly Account[];
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
  onConflict: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const user = useCurrentUser();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const [onlyUncategorized, setOnlyUncategorized] = useState(true);
  const [preview, setPreview] = useState<CategoryRulePreview | null>(null);
  const [previewError, setPreviewError] = useState<unknown>(null);

  const schema = useMemo(
    () =>
      z
        .object({
          name: z
            .string()
            .trim()
            .min(1, { error: t('categoryRules.form.nameRequired') })
            .max(80, { error: t('validation.maxLength', { max: 80 }) }),
          matchField: z.string().refine(isRuleField),
          matchType: z.string().refine(isRuleMatch),
          pattern: z
            .string()
            .trim()
            .min(1, { error: t('categoryRules.form.patternRequired') })
            .max(200, { error: t('validation.maxLength', { max: 200 }) }),
          categoryId: z.string().min(1, { error: t('categoryRules.form.categoryRequired') }),
          type: z.string(),
          accountId: z.string(),
          currency: z.string(),
          amountMin: z.string(),
          amountMax: z.string(),
          applyTo: z.string().refine(isRuleApplyTo),
          // Optional: an empty priority uses the API default (100).
          priority: z
            .string()
            .trim()
            .refine(
              (value) => value === '' || (/^\d{1,5}$/.test(value) && Number(value) <= 10_000),
              { error: t('categoryRules.form.priorityInvalid') },
            ),
          enabled: z.boolean(),
        })
        .superRefine((values, ctx) => {
          const exponent = exponentFor(currencies.data, values.currency);
          const common = {
            locale: formatLocale,
            currency: values.currency,
            exponent,
            allowZero: true,
            optional: true,
            t,
          };
          const min = checkAmount(ctx, { ...common, value: values.amountMin, path: 'amountMin' });
          const max = checkAmount(ctx, { ...common, value: values.amountMax, path: 'amountMax' });
          if (min && max && compareDecimal(min, max) > 0) {
            ctx.addIssue({
              code: 'custom',
              path: ['amountMax'],
              message: t('categoryRules.form.amountOrder'),
            });
          }
        }),
    [t, formatLocale, currencies.data],
  );

  const form = useForm<RuleValues, unknown, RuleValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: rule?.name ?? '',
      matchField: rule?.match_field ?? 'any',
      matchType: rule?.match_type ?? 'contains',
      pattern: rule?.pattern ?? '',
      categoryId: rule?.set_category_id ?? '',
      type: rule?.transaction_type ?? '',
      accountId: rule?.account_id ?? '',
      // The bounds' currency (null without an amount condition: then the base currency).
      currency: rule?.currency ?? user.base_currency,
      amountMin: rule?.amount_min ? decimalToInput(rule.amount_min, formatLocale) : '',
      amountMax: rule?.amount_max ? decimalToInput(rule.amount_max, formatLocale) : '',
      applyTo: rule?.apply_to ?? 'all',
      priority: String(rule?.priority ?? DEFAULT_PRIORITY),
      enabled: rule?.enabled ?? true,
    },
  });
  const matchType = useWatch({ control: form.control, name: 'matchType' });
  const currency = useWatch({ control: form.control, name: 'currency' });

  const toInput = (values: RuleValues): CategoryRuleInput | null => {
    if (
      !isRuleField(values.matchField) ||
      !isRuleMatch(values.matchType) ||
      !isRuleApplyTo(values.applyTo)
    ) {
      return null;
    }
    const exponent = exponentFor(currencies.data, values.currency);
    const amount = (raw: string) => {
      if (!raw.trim()) return null;
      const result = normalizeDecimalInput(raw, formatLocale, { exponent, allowZero: true });
      return result.ok ? result.value : null;
    };
    const min = amount(values.amountMin);
    const max = amount(values.amountMax);
    const priority = values.priority.trim();
    return {
      name: values.name.trim(),
      match_field: values.matchField,
      match_type: values.matchType,
      pattern: values.pattern.trim(),
      set_category_id: values.categoryId,
      apply_to: values.applyTo,
      // Empty means the API default (100); the generated type requires the field.
      priority: priority ? Number(priority) : DEFAULT_PRIORITY,
      enabled: values.enabled,
      ...(isRuleType(values.type) ? { transaction_type: values.type } : {}),
      ...(values.accountId ? { account_id: values.accountId } : {}),
      ...(min ? { amount_min: min } : {}),
      ...(max ? { amount_max: max } : {}),
      ...(min || max ? { currency: values.currency } : {}),
    };
  };

  const save = useMutation({
    // A replace sends the version shown, so a concurrent edit is detected.
    mutationFn: (body: CategoryRuleInput) =>
      rule ? rulesApi.replace(rule.id, { ...body, version: rule.version }) : rulesApi.create(body),
    onSuccess: () => invalidateFinance(queryClient),
  });
  const check = useMutation({
    mutationFn: (body: CategoryRuleInput) =>
      rulesApi.preview({ only_uncategorized: onlyUncategorized, rule: body }),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    const body = toInput(values);
    if (save.isPending || !body) return;
    setFormError(null);
    onPendingChange(true);
    try {
      await save.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: rule ? t('categoryRules.edit.done') : t('categoryRules.create.done'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyRuleErrors(error, form.setError, t);
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        onConflict();
      } else if (hasErrorCode(error, 'NOT_FOUND')) {
        setFormError(t('categoryRules.notFound'));
      } else {
        setFormError(organizeErrorMessage(error, t, formatLocale));
      }
    }
  });

  const runPreview = form.handleSubmit((values) => {
    const body = toInput(values);
    if (check.isPending || !body) return;
    setPreviewError(null);
    check.mutate(body, {
      onSuccess: (result) => {
        setPreview(result);
      },
      onError: (error) => {
        setPreview(null);
        if (hasErrorCode(error, 'VALIDATION_ERROR')) {
          const rest = applyRuleErrors(error, form.setError, t);
          if (rest.length > 0) setPreviewError(error);
        } else {
          setPreviewError(error);
        }
      },
    });
  });

  const { errors } = form.formState;
  const byId = categoriesById(categories);

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('categoryRules.form.name')}
        help={t('categoryRules.form.nameHelp')}
        maxLength={80}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('categoryRules.form.field')}
          options={RULE_FIELDS.map((field) => ({ value: field, label: t(ruleFieldLabel[field]) }))}
          error={errors.matchField?.message}
          {...form.register('matchField')}
        />
        <Select
          label={t('categoryRules.form.matchType')}
          options={RULE_MATCHES.map((match) => ({ value: match, label: t(ruleMatchLabel[match]) }))}
          error={errors.matchType?.message}
          {...form.register('matchType')}
        />
      </div>
      <TextField
        label={t('categoryRules.form.pattern')}
        help={
          matchType === 'regex'
            ? t('categoryRules.form.patternRegexHelp')
            : t('categoryRules.form.patternHelp')
        }
        maxLength={200}
        autoComplete="off"
        spellCheck={false}
        error={errors.pattern?.message}
        {...form.register('pattern')}
      />
      <Select
        label={t('categoryRules.form.category')}
        placeholder={t('categoryRules.form.categoryPlaceholder')}
        options={categoryOptions(categories, t, formatLocale)}
        error={errors.categoryId?.message}
        {...form.register('categoryId')}
      />

      <fieldset className="space-y-5 rounded-lg border border-line p-4">
        <legend className="px-1 text-sm font-semibold text-fg">
          {t('categoryRules.form.conditions')}
        </legend>
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('categoryRules.form.type')}
            optional
            options={[
              { value: '', label: t('categoryRules.form.typeAny') },
              ...RULE_TYPES.map((type) => ({ value: type, label: t(ruleTypeLabel[type]) })),
            ]}
            error={errors.type?.message}
            {...form.register('type')}
          />
          <Select
            label={t('categoryRules.form.account')}
            optional
            placeholder={t('categoryRules.form.accountAny')}
            groups={accountGroups(accounts, t)}
            error={errors.accountId?.message}
            {...form.register('accountId')}
          />
        </div>
        <Select
          label={t('categoryRules.form.currency')}
          options={currencyOptions(currencies.data, formatLocale, currency)}
          error={errors.currency?.message}
          {...form.register('currency')}
        />
        <div className="grid gap-5 sm:grid-cols-2">
          <MoneyField
            label={t('categoryRules.form.amountMin')}
            currency={currency}
            optional
            error={errors.amountMin?.message}
            {...form.register('amountMin')}
          />
          <MoneyField
            label={t('categoryRules.form.amountMax')}
            currency={currency}
            optional
            error={errors.amountMax?.message}
            {...form.register('amountMax')}
          />
        </div>
        <div className="grid gap-5 sm:grid-cols-2">
          <Select
            label={t('categoryRules.form.applyTo')}
            options={RULE_APPLY_TO.map((value) => ({
              value,
              label: t(ruleApplyToLabel[value]),
            }))}
            error={errors.applyTo?.message}
            {...form.register('applyTo')}
          />
          <TextField
            label={t('categoryRules.form.priority')}
            help={t('categoryRules.form.priorityHelp')}
            optional
            inputMode="numeric"
            autoComplete="off"
            maxLength={5}
            error={errors.priority?.message}
            {...form.register('priority')}
          />
        </div>
        <Checkbox
          label={t('categoryRules.form.enabled')}
          description={t('categoryRules.form.enabledHelp')}
          {...form.register('enabled')}
        />
      </fieldset>

      <section
        aria-label={t('categoryRules.preview.title')}
        className="space-y-3 rounded-lg border border-line bg-surface-muted p-4"
      >
        <h3 className="text-sm font-semibold text-fg">{t('categoryRules.preview.title')}</h3>
        <Checkbox
          label={t('categoryRules.apply.onlyUncategorized')}
          checked={onlyUncategorized}
          onChange={(event) => {
            setOnlyUncategorized(event.target.checked);
            setPreview(null);
          }}
        />
        <Button
          variant="secondary"
          size="sm"
          loading={check.isPending}
          onClick={() => {
            void runPreview();
          }}
        >
          <Icon name="search" className="size-4" />
          {t('categoryRules.preview.action')}
        </Button>
        <div role="status" className="space-y-3 text-sm">
          {check.isPending ? (
            <p className="text-fg-muted">{t('categoryRules.preview.loading')}</p>
          ) : null}
          {previewError ? (
            <p className="text-danger">
              {t('categoryRules.preview.failed')}:{' '}
              {organizeErrorMessage(previewError, t, formatLocale)}
            </p>
          ) : null}
          {preview && !check.isPending ? (
            preview.match_count === 0 ? (
              <p className="text-fg">{t('categoryRules.preview.none')}</p>
            ) : (
              <p className="font-medium text-fg">
                {t('categoryRules.preview.count', { count: preview.match_count })}
              </p>
            )
          ) : null}
        </div>
        {preview && preview.sample.length > 0 && !check.isPending ? (
          <div className="space-y-2">
            <p className="text-sm text-fg-muted">{t('categoryRules.preview.sample')}</p>
            <ul className="divide-y divide-line rounded-md bg-surface px-3 py-2">
              {preview.sample.map((transaction) => (
                <TransactionListItem
                  key={transaction.id}
                  transaction={transaction}
                  categories={byId}
                />
              ))}
            </ul>
          </div>
        ) : null}
      </section>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={save.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={save.isPending}>
          {rule ? t('common.save') : t('categoryRules.create.submit')}
        </Button>
      </div>
    </form>
  );
}
