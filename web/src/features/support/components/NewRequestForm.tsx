import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import { supportApi } from '../api';
import { supportKeys } from '../keys';
import { REQUEST_KINDS, isRequestKind, kindHelp, kindLabel } from '../labels';
import { BODY_MAX, SUBJECT_MAX, messageFields, supportErrorMessage } from '../requestForm';
import type { SupportRequest } from '../types';
import { SafetyNotice } from './SafetyNotice';

interface Values {
  kind: string;
  subject: string;
  body: string;
}

interface NewRequestFormProps {
  /** Prefilled subject (a follow-up to an earlier request). */
  initialSubject?: string;
  onCreated: (request: SupportRequest) => void;
}

/** Contact support while signed in: replies arrive in the request's thread in Montra. */
export function NewRequestForm({ initialSubject = '', onCreated }: NewRequestFormProps) {
  const t = useT();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z.object({
        kind: z.string().refine(isRequestKind, { error: t('support.form.kindRequired') }),
        ...messageFields(t),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: { kind: '', subject: initialSubject, body: '' },
  });
  const kind = useWatch({ control: form.control, name: 'kind' });
  const mutation = useMutation({
    mutationFn: supportApi.create,
    onSuccess: (created) => {
      queryClient.setQueryData(supportKeys.request(created.id), created);
      void queryClient.invalidateQueries({ queryKey: supportKeys.mine() });
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || !isRequestKind(values.kind)) return;
    setFormError(null);
    try {
      const created = await mutation.mutateAsync({
        kind: values.kind,
        subject: values.subject,
        body: values.body,
      });
      form.reset({ kind: '', subject: '', body: '' });
      onCreated(created);
    } catch (error) {
      setFormError(
        supportErrorMessage(error, t, form.setError, {
          kind: 'kind',
          subject: 'subject',
          body: 'body',
        }),
      );
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <SafetyNotice />
      <FormAlert message={formError} />
      <Select
        label={t('support.form.kind')}
        placeholder={t('support.form.kindPlaceholder')}
        options={REQUEST_KINDS.map((value) => ({ value, label: t(kindLabel[value]) }))}
        help={isRequestKind(kind) ? t(kindHelp[kind]) : t('support.form.kindHelp')}
        error={errors.kind?.message}
        {...form.register('kind')}
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
      <div className="flex justify-end">
        <Button type="submit" loading={mutation.isPending}>
          <Icon name="mail" className="size-4" />
          {t('support.form.submit')}
        </Button>
      </div>
    </form>
  );
}
