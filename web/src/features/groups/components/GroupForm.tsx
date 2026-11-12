import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { useController, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, useCurrencies } from '@/shared/currency/api';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { isLocalDate } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { groupErrorMessage } from '../errors';
import { type GroupFormValues, type ValidGroupValues, validGroupValues } from '../formValues';
import {
  GROUP_TYPES,
  SPLIT_METHODS,
  groupTypeDescription,
  groupTypeLabel,
  hasTripDetails,
  splitMethodLabel,
} from '../labels';

const NAME_MAX = 80;
const DESCRIPTION_MAX = 1000;
const RULES_MAX = 2000;
const DESTINATION_MAX = 120;

function buildSchema(t: Translate) {
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { error: t('groups.form.nameRequired') })
        .max(NAME_MAX, { error: t('validation.maxLength', { max: NAME_MAX }) }),
      groupType: z.string(),
      description: z
        .string()
        .max(DESCRIPTION_MAX, { error: t('validation.maxLength', { max: DESCRIPTION_MAX }) }),
      baseCurrency: z.string().regex(/^[A-Z]{3}$/, { error: t('groups.form.currencyRequired') }),
      timezone: z.string().min(1, { error: t('groups.form.timezoneRequired') }),
      defaultSplitMethod: z.string(),
      simplifyDebts: z.boolean(),
      allowMemberInvites: z.boolean(),
      requireJoinApproval: z.boolean(),
      rules: z.string().max(RULES_MAX, { error: t('validation.maxLength', { max: RULES_MAX }) }),
      startDate: z.string(),
      endDate: z.string(),
      destination: z
        .string()
        .max(DESTINATION_MAX, { error: t('validation.maxLength', { max: DESTINATION_MAX }) }),
    })
    .superRefine((values, ctx) => {
      if (!validGroupValues(values)) {
        ctx.addIssue({
          code: 'custom',
          path: ['groupType'],
          message: t('groups.form.typeRequired'),
        });
        return;
      }
      if (!hasTripDetails(values.groupType)) return;
      const startOk = !values.startDate || isLocalDate(values.startDate);
      const endOk = !values.endDate || isLocalDate(values.endDate);
      if (!startOk) {
        ctx.addIssue({ code: 'custom', path: ['startDate'], message: t('validation.dateInvalid') });
      }
      if (!endOk) {
        ctx.addIssue({ code: 'custom', path: ['endDate'], message: t('validation.dateInvalid') });
      }
      if (startOk && endOk && values.startDate && values.endDate) {
        // Calendar dates compare as strings.
        if (values.endDate < values.startDate) {
          ctx.addIssue({ code: 'custom', path: ['endDate'], message: t('validation.dateOrder') });
        }
      }
    });
}

/** API field (without `body.`) -> form field. */
const serverFields = {
  name: 'name',
  group_type: 'groupType',
  description: 'description',
  base_currency: 'baseCurrency',
  timezone: 'timezone',
  default_split_method: 'defaultSplitMethod',
  require_join_approval: 'requireJoinApproval',
  rules: 'rules',
  start_date: 'startDate',
  end_date: 'endDate',
  destination: 'destination',
} as const;

function supportedTimeZones(): string[] {
  try {
    return Intl.supportedValuesOf('timeZone');
  } catch {
    return [];
  }
}

/** IANA zones the browser knows, plus the current choice and UTC. */
function timeZoneOptions(current: string) {
  return [...new Set([current, ...supportedTimeZones(), 'UTC'].filter(Boolean))]
    .sort()
    .map((zone) => ({ value: zone, label: zone.replaceAll('_', ' ') }));
}

interface GroupFormProps {
  mode: 'create' | 'edit';
  initialValues: GroupFormValues;
  /** Saves; rejects with the API error so the form can show it. */
  onSubmit: (values: ValidGroupValues) => Promise<void>;
  /** Return true when the page handled an error itself (e.g. a version conflict). */
  onError?: (error: unknown) => boolean;
  submitLabel: string;
  secondaryAction?: ReactNode;
}

/** Renders once the currency list has loaded, so the currency select shows its value. */
export function GroupForm(props: GroupFormProps) {
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
  return <GroupFormInner {...props} />;
}

function GroupFormInner({
  mode,
  initialValues,
  onSubmit,
  onError,
  submitLabel,
  secondaryAction,
}: GroupFormProps) {
  const { t, formatLocale } = useI18n();
  const currencies = useCurrencies();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const schema = useMemo(() => buildSchema(t), [t]);
  const form = useForm<GroupFormValues, unknown, GroupFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const typeField = useController({ control: form.control, name: 'groupType' });
  const groupType = useWatch({ control: form.control, name: 'groupType' });
  const trip = hasTripDetails(groupType);
  const zones = useMemo(() => timeZoneOptions(initialValues.timezone), [initialValues.timezone]);
  const currencyChoices = currencyOptions(
    currencies.data,
    formatLocale,
    initialValues.baseCurrency,
  );

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    const valid = validGroupValues(values);
    if (!valid) return;
    setFormError(null);
    setSubmitting(true);
    try {
      await onSubmit(valid);
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
      } else if (domainRuleCode(error)?.code === 'currency_locked') {
        form.setError(
          'baseCurrency',
          { type: 'server', message: t('groups.rule.currency_locked') },
          { shouldFocus: true },
        );
      } else {
        setFormError(mode === 'edit' ? groupErrorMessage(error, t) : describeError(error, t));
      }
    } finally {
      setSubmitting(false);
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onValid} noValidate className="space-y-6">
      <FormAlert message={formError} />
      <TextField
        label={t('groups.form.name')}
        help={t('groups.form.nameHelp')}
        maxLength={NAME_MAX}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <RadioGroup
        legend={t('groups.form.type')}
        variant="cards"
        value={typeField.field.value}
        onChange={(value) => {
          typeField.field.onChange(value);
        }}
        options={GROUP_TYPES.map((type) => ({
          value: type,
          label: t(groupTypeLabel[type]),
          description: t(groupTypeDescription[type]),
        }))}
        error={errors.groupType?.message}
      />
      {trip ? (
        <fieldset className="space-y-5 rounded-lg border border-line p-4">
          <legend className="px-1 text-sm font-medium text-fg">
            {t('groups.form.tripDetails')}
          </legend>
          <p className="text-sm text-fg-muted">{t('groups.form.tripReminders')}</p>
          <div className="grid gap-5 sm:grid-cols-2">
            <TextField
              type="date"
              label={t('groups.form.startDate')}
              optional
              error={errors.startDate?.message}
              {...form.register('startDate')}
            />
            <TextField
              type="date"
              label={t('groups.form.endDate')}
              optional
              error={errors.endDate?.message}
              {...form.register('endDate')}
            />
          </div>
          <TextField
            label={t('groups.form.destination')}
            optional
            maxLength={DESTINATION_MAX}
            autoComplete="off"
            error={errors.destination?.message}
            {...form.register('destination')}
          />
        </fieldset>
      ) : null}
      <TextArea
        label={t('groups.form.description')}
        optional
        maxLength={DESCRIPTION_MAX}
        error={errors.description?.message}
        {...form.register('description')}
      />
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('groups.form.currency')}
          help={mode === 'edit' ? t('groups.form.currencyHelpEdit') : t('groups.form.currencyHelp')}
          options={currencyChoices}
          error={errors.baseCurrency?.message}
          {...form.register('baseCurrency')}
        />
        <Select
          label={t('groups.form.timezone')}
          help={t('groups.form.timezoneHelp')}
          options={zones}
          error={errors.timezone?.message}
          {...form.register('timezone')}
        />
      </div>
      <Select
        label={t('groups.form.split')}
        help={t('groups.form.splitHelp')}
        options={SPLIT_METHODS.map((method) => ({
          value: method,
          label: t(splitMethodLabel[method]),
        }))}
        error={errors.defaultSplitMethod?.message}
        {...form.register('defaultSplitMethod')}
      />
      <div className="space-y-4">
        <Checkbox
          label={t('groups.form.simplify')}
          description={t('groups.form.simplifyHelp')}
          {...form.register('simplifyDebts')}
        />
        <Checkbox
          label={t('groups.form.memberInvites')}
          description={t('groups.form.memberInvitesHelp')}
          {...form.register('allowMemberInvites')}
        />
        <Checkbox
          label={t('groups.form.joinApproval')}
          description={t('groups.form.joinApprovalHelp')}
          {...form.register('requireJoinApproval')}
        />
      </div>
      <TextArea
        label={t('groups.form.rules')}
        help={t('groups.form.rulesHelp')}
        optional
        rows={4}
        maxLength={RULES_MAX}
        error={errors.rules?.message}
        {...form.register('rules')}
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
