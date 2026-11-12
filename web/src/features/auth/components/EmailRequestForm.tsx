import { zodResolver } from '@hookform/resolvers/zod';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { TextField } from '@/shared/components/TextField';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { emailSchema } from '@/shared/validation/schemas';
import { useRetryAfter } from '../hooks/useRetryAfter';
import { RetryAfterNotice } from './RetryAfterNotice';

interface EmailRequestFormProps {
  submitLabel: string;
  /** Performs the request; resolves when the API accepted it. */
  onRequest: (email: string) => Promise<unknown>;
  onAccepted: (email: string) => void;
}

/** Single-email form for enumeration-safe requests (reset link, new verification link). */
export function EmailRequestForm({ submitLabel, onRequest, onAccepted }: EmailRequestFormProps) {
  const t = useT();
  const [formError, setFormError] = useState<string | null>(null);
  const retry = useRetryAfter();
  const schema = useMemo(() => z.object({ email: emailSchema(t) }), [t]);
  const form = useForm<{ email: string }, unknown, { email: string }>({
    resolver: zodResolver(schema),
    defaultValues: { email: '' },
  });

  const onSubmit = form.handleSubmit(async ({ email }) => {
    if (retry.blocked) return;
    setFormError(null);
    try {
      await onRequest(email);
      onAccepted(email);
    } catch (error) {
      retry.capture(error);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, { email: 'email' });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('auth.fields.email')}
        type="email"
        autoComplete="email"
        inputMode="email"
        spellCheck={false}
        error={form.formState.errors.email?.message}
        {...form.register('email')}
      />
      <Button type="submit" className="w-full" loading={form.formState.isSubmitting}>
        {submitLabel}
      </Button>
      <RetryAfterNotice seconds={retry.remaining} />
    </form>
  );
}
