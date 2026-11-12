import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { type Resolver, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { PasswordField } from '@/shared/components/PasswordField';
import { Select } from '@/shared/components/Select';
import { TextLink } from '@/shared/components/TextLink';
import { TextField } from '@/shared/components/TextField';
import { appConfig } from '@/shared/config/env';
import { paths } from '@/shared/config/paths';
import { selectableCurrencies, useCurrencies } from '@/shared/currency/api';
import { currencyName, defaultCurrencyForLocale } from '@/shared/currency/currencies';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { localeDisplayName } from '@/shared/formatting/names';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { browserLocales } from '@/shared/i18n/languages';
import type { Translate } from '@/shared/i18n/types';
import { emailSchema, newPasswordSchema } from '@/shared/validation/schemas';
import { authApi, type RegisterRequest } from '../api';
import { AuthCard } from '../components/AuthCard';
import { CheckEmailPanel } from '../components/CheckEmailPanel';
import { PasswordRequirements } from '@/shared/forms/PasswordRequirements';
import { RetryAfterNotice } from '../components/RetryAfterNotice';
import { useRetryAfter } from '../hooks/useRetryAfter';
import { browserTimeZone, toApiLocale } from '../registrationDefaults';

interface SignUpValues {
  displayName: string;
  email: string;
  password: string;
  currency: string;
  acceptTerms: boolean;
  confirmAdult: boolean;
}

function buildSchema(t: Translate, email: string, currencyCodes: ReadonlySet<string>) {
  return z.object({
    displayName: z
      .string()
      .trim()
      .min(1, { error: t('validation.displayNameRequired') })
      .max(80, { error: t('validation.displayNameTooLong') }),
    email: emailSchema(t),
    password: newPasswordSchema(t, () => email),
    currency: z
      .string()
      .refine((code) => currencyCodes.has(code), { error: t('validation.currencyRequired') }),
    acceptTerms: z.boolean().refine((value) => value, { error: t('validation.acceptTerms') }),
    confirmAdult: z.boolean().refine((value) => value, { error: t('validation.confirmAdult') }),
  });
}

/** API field (without `body.`) -> form field. */
const serverFields = {
  display_name: 'displayName',
  email: 'email',
  password: 'password',
  currency: 'currency',
  accept_terms: 'acceptTerms',
  confirm_adult: 'confirmAdult',
} as const;

export function SignUpPage() {
  const { t, rich, formatLocale } = useI18n();
  const [submittedEmail, setSubmittedEmail] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const [focusRequest, setFocusRequest] = useState(0);
  const retry = useRetryAfter();

  useDocumentTitle(submittedEmail ? t('auth.checkEmail.title') : t('auth.signUp.title'));

  const apiLocale = useMemo(() => toApiLocale(formatLocale), [formatLocale]);
  const timeZone = useMemo(() => browserTimeZone(), []);
  const currencies = useCurrencies();
  const selectable = useMemo(() => selectableCurrencies(currencies.data), [currencies.data]);
  const selectableCodes = useMemo(
    () => new Set(selectable.map((currency) => currency.code)),
    [selectable],
  );
  const currencyOptions = useMemo(
    () =>
      selectable
        .map((currency) => ({
          value: currency.code,
          label: `${currencyName(currency.code, formatLocale, currency.name)} (${currency.code})`,
        }))
        .sort((a, b) => a.label.localeCompare(b.label, formatLocale)),
    [selectable, formatLocale],
  );
  // Locale-based suggestion, used only if the API lists it as selectable.
  const suggestedCurrency = useMemo(() => {
    const suggestion = defaultCurrencyForLocale(browserLocales()[0] ?? formatLocale);
    return suggestion && selectableCodes.has(suggestion) ? suggestion : null;
  }, [selectableCodes, formatLocale]);

  // The password rules depend on the email, so the schema is built per validation.
  const resolver = useCallback<Resolver<SignUpValues, unknown, SignUpValues>>(
    (values, context, options) =>
      zodResolver(buildSchema(t, values.email, selectableCodes))(values, context, options),
    [t, selectableCodes],
  );

  const form = useForm<SignUpValues, unknown, SignUpValues>({
    resolver,
    defaultValues: {
      displayName: '',
      email: '',
      password: '',
      currency: '',
      acceptTerms: false,
      confirmAdult: false,
    },
  });
  const [password, email] = useWatch({ control: form.control, name: ['password', 'email'] });

  const mutation = useMutation({ ...sensitiveMutation, mutationFn: authApi.register });

  // Preselect the suggestion once the list arrives, unless the user already chose.
  useEffect(() => {
    if (!suggestedCurrency) return;
    if (form.getValues('currency') === '' && !form.getFieldState('currency').isDirty) {
      form.setValue('currency', suggestedCurrency);
    }
  }, [suggestedCurrency, form]);

  // Move focus to the new heading when the step changes (not on first render).
  useEffect(() => {
    if (focusRequest > 0) headingRef.current?.focus();
  }, [focusRequest]);

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || retry.blocked) return;
    setFormError(null);
    const body: RegisterRequest = {
      display_name: values.displayName,
      email: values.email,
      password: values.password,
      currency: values.currency,
      accept_terms: values.acceptTerms,
      confirm_adult: values.confirmAdult,
      terms_version: appConfig.legal.termsVersion,
      privacy_version: appConfig.legal.privacyVersion,
      ...(apiLocale ? { locale: apiLocale } : {}),
      ...(timeZone ? { timezone: timeZone } : {}),
    };
    try {
      await mutation.mutateAsync(body);
      form.resetField('password');
      setSubmittedEmail(values.email);
      setFocusRequest((count) => count + 1);
    } catch (error) {
      retry.capture(error);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const termsChanged = error.details.some(
          (detail) =>
            detail.field === 'body.terms_version' || detail.field === 'body.privacy_version',
        );
        const rest = applyServerErrors(error, form.setError, serverFields);
        if (termsChanged) setFormError(t('auth.signUp.termsUpdated'));
        else if (rest.length > 0) setFormError(rest.join(' '));
        else if (error.details.length === 0) setFormError(t('errors.VALIDATION_ERROR'));
      } else if (hasErrorCode(error, 'FORBIDDEN')) {
        setFormError(t('auth.signUp.closed'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  const { errors } = form.formState;

  if (submittedEmail) {
    return (
      <AuthCard headingRef={headingRef} title={t('auth.checkEmail.title')}>
        <CheckEmailPanel
          email={submittedEmail}
          onUseDifferentEmail={() => {
            setSubmittedEmail(null);
            setFocusRequest((count) => count + 1);
          }}
        />
      </AuthCard>
    );
  }

  const detected = [apiLocale ? localeDisplayName(apiLocale, formatLocale) : null, timeZone]
    .filter(Boolean)
    .join(' · ');

  return (
    <AuthCard
      headingRef={headingRef}
      title={t('auth.signUp.title')}
      description={t('auth.signUp.description')}
      footer={
        <p>
          {t('auth.signUp.haveAccount')} <TextLink to={paths.signIn}>{t('nav.signIn')}</TextLink>
        </p>
      }
    >
      <form onSubmit={onSubmit} noValidate className="space-y-5">
        <FormAlert message={formError} />
        <TextField
          label={t('auth.fields.displayName')}
          help={t('auth.fields.displayNameHelp')}
          autoComplete="name"
          maxLength={80}
          error={errors.displayName?.message}
          {...form.register('displayName')}
        />
        <TextField
          label={t('auth.fields.email')}
          type="email"
          autoComplete="email"
          inputMode="email"
          spellCheck={false}
          error={errors.email?.message}
          {...form.register('email')}
        />
        <PasswordField
          label={t('auth.fields.newPassword')}
          autoComplete="new-password"
          help={<PasswordRequirements password={password} email={email} />}
          error={errors.password?.message}
          {...form.register('password')}
        />
        <Select
          label={t('auth.fields.currency')}
          help={t('auth.fields.currencyHelp')}
          placeholder={
            currencies.isPending ? t('currency.loading') : t('auth.fields.currencyPlaceholder')
          }
          options={currencyOptions}
          disabled={!currencies.isSuccess}
          aria-busy={currencies.isPending || undefined}
          error={errors.currency?.message}
          {...form.register('currency')}
        />
        {currencies.isError ? (
          <Alert tone="danger" live="polite" title={t('currency.loadFailed')}>
            <Button
              variant="secondary"
              size="sm"
              loading={currencies.isFetching}
              onClick={() => {
                void currencies.refetch();
              }}
            >
              {t('common.retry')}
            </Button>
          </Alert>
        ) : null}
        {detected ? (
          <p className="text-sm text-fg-muted">{t('auth.signUp.detected', { detected })}</p>
        ) : null}
        <fieldset className="space-y-4">
          <legend className="sr-only">{t('auth.signUp.agreements')}</legend>
          <Checkbox
            label={rich('auth.signUp.acceptTerms', {
              terms: (text) => (
                <TextLink to={paths.terms} target="_blank" rel="noopener">
                  {text}
                  <span className="sr-only"> {t('common.opensInNewTab')}</span>
                </TextLink>
              ),
              privacy: (text) => (
                <TextLink to={paths.privacy} target="_blank" rel="noopener">
                  {text}
                  <span className="sr-only"> {t('common.opensInNewTab')}</span>
                </TextLink>
              ),
            })}
            error={errors.acceptTerms?.message}
            {...form.register('acceptTerms')}
          />
          <Checkbox
            label={t('auth.signUp.confirmAdult')}
            error={errors.confirmAdult?.message}
            {...form.register('confirmAdult')}
          />
        </fieldset>
        <Button type="submit" className="w-full" loading={mutation.isPending}>
          {t('auth.signUp.submit')}
        </Button>
        <RetryAfterNotice seconds={retry.remaining} />
      </form>
    </AuthCard>
  );
}
