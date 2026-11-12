import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { ExternalLink, TextLink } from '@/shared/components/TextLink';
import { TextField } from '@/shared/components/TextField';
import { appConfig } from '@/shared/config/env';
import { paths } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useCountdown } from '@/shared/hooks/useCountdown';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { formatWait } from '@/shared/i18n/formatWait';
import { useT } from '@/shared/i18n/I18nContext';
import { emailSchema } from '@/shared/validation/schemas';
import { supportApi } from '../api';
import { SafetyNotice } from '../components/SafetyNotice';
import { CONTACT_KINDS, kindHelp, kindLabel } from '../labels';
import { BODY_MAX, SUBJECT_MAX, messageFields, supportErrorMessage } from '../requestForm';
import type { ContactKind } from '../types';

interface Values {
  kind: string;
  email: string;
  subject: string;
  body: string;
}

function isContactKind(value: unknown): value is ContactKind {
  return typeof value === 'string' && (CONTACT_KINDS as readonly string[]).includes(value);
}

/** Tracks a Retry-After deadline so the form waits calmly instead of failing again. */
function useRetryAfter() {
  const [deadline, setDeadline] = useState<number | null>(null);
  const remaining = useCountdown(deadline);
  const capture = useCallback((error: unknown) => {
    if (isApiError(error) && error.retryAfterSeconds) {
      setDeadline(Date.now() + error.retryAfterSeconds * 1000);
    }
  }, []);
  return { remaining, blocked: remaining > 0, capture };
}

interface Sent {
  reference: string;
  email: string;
}

function Confirmation({ sent, signedIn }: { sent: Sent; signedIn: boolean }) {
  const t = useT();
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    // The form is gone: move focus to the confirmation so keyboard and
    // screen-reader users land on it (this also announces it).
    heading.current?.focus();
  }, []);
  return (
    <div className="space-y-5">
      <h2
        ref={heading}
        tabIndex={-1}
        className="flex items-center gap-2 text-lg font-semibold text-fg outline-none"
      >
        <Icon name="check-circle" className="size-5 text-success" />
        {t('support.contact.sent.title')}
      </h2>
      <p className="text-fg">{t('support.contact.sent.body', { email: sent.email })}</p>
      <p className="text-fg">
        {t('support.contact.sent.reference')}{' '}
        <code className="font-mono font-semibold select-all">{sent.reference}</code>
      </p>
      <p className="text-sm text-fg-muted">{t('support.contact.sent.next')}</p>
      <ButtonLink to={signedIn ? paths.help : paths.landing} variant="secondary">
        {signedIn ? t('support.backToHelp') : t('support.contact.sent.home')}
      </ButtonLink>
    </div>
  );
}

/**
 * Contact support without signing in (for example when you can't sign in).
 * Public: works signed out, sends no tokens, and is rate limited by the API.
 */
export function ContactPage() {
  const t = useT();
  useDocumentTitle(t('support.contact.title'));
  const { status } = useAuth();
  const signedIn = status === 'authenticated';
  const [formError, setFormError] = useState<string | null>(null);
  const [sent, setSent] = useState<Sent | null>(null);
  const retry = useRetryAfter();
  const schema = useMemo(
    () =>
      z.object({
        kind: z.string().refine(isContactKind, { error: t('support.form.kindRequired') }),
        email: emailSchema(t),
        ...messageFields(t),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: { kind: '', email: '', subject: '', body: '' },
  });
  const kind = useWatch({ control: form.control, name: 'kind' });
  const mutation = useMutation({ mutationFn: supportApi.contact });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || retry.blocked || !isContactKind(values.kind)) return;
    setFormError(null);
    try {
      const result = await mutation.mutateAsync({
        kind: values.kind,
        contact_email: values.email,
        subject: values.subject,
        body: values.body,
      });
      setSent({ reference: result.reference, email: values.email });
    } catch (error) {
      retry.capture(error);
      if (
        hasErrorCode(error, 'VALIDATION_ERROR') &&
        error.details.some((detail) => detail.field === 'body.captcha_token')
      ) {
        // The API asks for a security check this app doesn't offer yet: point to email instead.
        setFormError(t('support.contact.captcha', { email: appConfig.supportEmail }));
        return;
      }
      setFormError(
        supportErrorMessage(
          error,
          t,
          form.setError,
          { kind: 'kind', subject: 'subject', body: 'body', contactEmail: 'email' },
          { contact: true },
        ),
      );
    }
  });

  const { errors } = form.formState;
  return (
    <div className="mx-auto w-full max-w-2xl px-4 py-10 sm:py-16">
      <h1
        tabIndex={-1}
        data-page-heading=""
        className="text-2xl font-semibold tracking-tight text-fg outline-none sm:text-3xl"
      >
        {t('support.contact.title')}
      </h1>
      <p className="mt-2 text-fg-muted">{t('support.contact.description')}</p>
      <div className="mt-6 rounded-xl border border-line bg-surface p-6 shadow-card sm:p-8">
        {sent ? (
          <Confirmation sent={sent} signedIn={signedIn} />
        ) : (
          <form onSubmit={onSubmit} noValidate className="space-y-5">
            {signedIn ? (
              <Alert tone="info" title={t('support.contact.signedIn.title')}>
                <p>
                  {t('support.contact.signedIn.body')}{' '}
                  <TextLink to={paths.help}>{t('support.contact.signedIn.link')}</TextLink>
                </p>
              </Alert>
            ) : null}
            <SafetyNotice />
            <FormAlert message={formError} />
            <Select
              label={t('support.form.kind')}
              placeholder={t('support.form.kindPlaceholder')}
              options={CONTACT_KINDS.map((value) => ({ value, label: t(kindLabel[value]) }))}
              help={isContactKind(kind) ? t(kindHelp[kind]) : t('support.form.kindHelp')}
              error={errors.kind?.message}
              {...form.register('kind')}
            />
            {kind === 'security' ? (
              <p className="text-sm text-fg-muted">
                {t('support.contact.securityEmail')}{' '}
                <ExternalLink href={`mailto:${appConfig.securityEmail}`}>
                  {appConfig.securityEmail}
                </ExternalLink>
              </p>
            ) : null}
            <TextField
              label={t('support.contact.email')}
              help={t('support.contact.emailHelp')}
              type="email"
              autoComplete="email"
              inputMode="email"
              spellCheck={false}
              error={errors.email?.message}
              {...form.register('email')}
            />
            <TextField
              label={t('support.form.subject')}
              maxLength={SUBJECT_MAX}
              autoComplete="off"
              error={errors.subject?.message}
              {...form.register('subject')}
            />
            <TextArea
              label={t('support.form.body')}
              help={t('support.form.bodyHelp')}
              rows={6}
              maxLength={BODY_MAX}
              autoComplete="off"
              error={errors.body?.message}
              {...form.register('body')}
            />
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              {retry.remaining > 0 ? (
                // Silent countdown: the error above was already announced.
                <p className="text-sm text-fg-muted" aria-live="off">
                  {t('support.contact.retryIn', { wait: formatWait(t, retry.remaining) })}
                </p>
              ) : (
                <span />
              )}
              <Button
                type="submit"
                loading={mutation.isPending}
                // Stays focusable while waiting; submitting is ignored until the wait ends.
                // (This prop replaces the button's own, so it covers `loading` too.)
                aria-disabled={retry.blocked || mutation.isPending || undefined}
                className="sm:ms-auto"
              >
                <Icon name="mail" className="size-4" />
                {t('support.contact.submit')}
              </Button>
            </div>
          </form>
        )}
      </div>
      {signedIn ? null : (
        <p className="mt-6 text-center text-sm text-fg-muted">
          {t('support.contact.signInHint')} <TextLink to={paths.signIn}>{t('nav.signIn')}</TextLink>
        </p>
      )}
    </div>
  );
}
