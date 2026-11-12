import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { useController, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { fieldProblems, splitFieldProblems, useCommunityError } from '../errors';
import { VISIBILITIES, visibilityHelp, visibilityLabel } from '../labels';
import { looksSecret } from '../text/userText';
import { type CommunityFormValues, parseTopics } from '../communityFormValues';
import type { CommunityVisibility } from '../types';

const NAME_MAX = 80;
const DESCRIPTION_MAX = 2000;
const RULES_MAX = 4000;
const MAX_TOPICS = 10;
const TOPIC_MAX = 30;
const SLUG = /^[a-z0-9-]{3,60}$/u;
const TOPIC = /^[a-z0-9][a-z0-9 -]*$/u;

function chars(text: string): number {
  return Array.from(text).length;
}

function buildSchema(t: Translate) {
  const safeText = (max: number) =>
    z
      .string()
      .refine((value) => chars(value.trim()) <= max, {
        error: t('validation.maxLength', { max }),
      })
      .refine((value) => !looksSecret(value), { error: t('communities.field.secret') });
  return z.object({
    name: z
      .string()
      .refine((value) => chars(value.trim()) >= 3, { error: t('communities.form.nameRequired') })
      .refine((value) => chars(value.trim()) <= NAME_MAX, {
        error: t('validation.maxLength', { max: NAME_MAX }),
      })
      .refine((value) => !looksSecret(value), { error: t('communities.field.secret') }),
    slug: z.string().refine((value) => !value.trim() || SLUG.test(value.trim().toLowerCase()), {
      error: t('communities.form.slugInvalid'),
    }),
    description: safeText(DESCRIPTION_MAX),
    rules: safeText(RULES_MAX),
    topics: z.string().superRefine((value, ctx) => {
      const topics = parseTopics(value);
      if (topics.length > MAX_TOPICS) {
        ctx.addIssue({
          code: 'custom',
          message: t('communities.form.topicsTooMany', { max: MAX_TOPICS }),
        });
        return;
      }
      if (topics.some((topic) => topic.length > TOPIC_MAX || !TOPIC.test(topic))) {
        ctx.addIssue({ code: 'custom', message: t('communities.field.topics') });
      }
    }),
    visibility: z.enum(VISIBILITIES),
  });
}

/** API field (without `body.`) -> form field. */
const serverFields = {
  name: 'name',
  slug: 'slug',
  description: 'description',
  rules: 'rules',
  topics: 'topics',
  visibility: 'visibility',
} as const;

interface CommunityFormProps {
  mode: 'create' | 'edit';
  initialValues: CommunityFormValues;
  /** Only the owner chooses who can join; moderators see it read-only. */
  canChangeVisibility: boolean;
  /** Saves; rejects with the API error so the form can show it. */
  onSubmit: (values: CommunityFormValues) => Promise<void>;
  submitLabel: string;
  secondaryAction?: ReactNode;
}

/** Name, web address (when creating), description, rules, topics and who can join. */
export function CommunityForm({
  mode,
  initialValues,
  canChangeVisibility,
  onSubmit,
  submitLabel,
  secondaryAction,
}: CommunityFormProps) {
  const t = useT();
  const describe = useCommunityError();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const schema = useMemo(() => buildSchema(t), [t]);
  const form = useForm<CommunityFormValues, unknown, CommunityFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const visibility = useController({ control: form.control, name: 'visibility' });

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    setFormError(null);
    setSubmitting(true);
    try {
      await onSubmit(values);
    } catch (error) {
      const problems = fieldProblems(error, t);
      if (problems.length > 0) {
        const { byField, rest } = splitFieldProblems(problems, serverFields);
        let focused = false;
        for (const [field, message] of Object.entries(byField) as [
          keyof CommunityFormValues,
          string,
        ][]) {
          form.setError(field, { type: 'server', message }, { shouldFocus: !focused });
          focused = true;
        }
        setFormError(rest.length > 0 ? rest.join(' ') : null);
      } else if (mode === 'create' && hasErrorCode(error, 'CONFLICT')) {
        form.setError(
          'slug',
          { type: 'server', message: t('communities.field.slugTaken') },
          { shouldFocus: true },
        );
      } else {
        setFormError(describe(error, { codes: { CONFLICT: 'communities.form.conflict' } }));
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
        label={t('communities.form.name')}
        help={t('communities.form.nameHelp')}
        maxLength={NAME_MAX}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      {mode === 'create' ? (
        <TextField
          label={t('communities.form.slug')}
          help={t('communities.form.slugHelp')}
          optional
          maxLength={60}
          autoComplete="off"
          autoCapitalize="none"
          spellCheck={false}
          error={errors.slug?.message}
          {...form.register('slug')}
        />
      ) : null}
      <TextArea
        label={t('communities.form.description')}
        help={t('communities.form.descriptionHelp')}
        optional
        rows={4}
        maxLength={DESCRIPTION_MAX}
        error={errors.description?.message}
        {...form.register('description')}
      />
      <TextArea
        label={t('communities.form.rules')}
        help={t('communities.form.rulesHelp')}
        optional
        rows={5}
        maxLength={RULES_MAX}
        error={errors.rules?.message}
        {...form.register('rules')}
      />
      <TextField
        label={t('communities.form.topics')}
        help={t('communities.form.topicsHelp')}
        optional
        autoComplete="off"
        error={errors.topics?.message}
        {...form.register('topics')}
      />
      <RadioGroup<CommunityVisibility>
        legend={t('communities.form.visibility')}
        variant="cards"
        value={visibility.field.value}
        disabled={!canChangeVisibility}
        onChange={(value) => {
          visibility.field.onChange(value);
        }}
        options={VISIBILITIES.map((value) => ({
          value,
          label: t(visibilityLabel[value]),
          description: t(visibilityHelp[value]),
        }))}
        help={canChangeVisibility ? undefined : t('communities.form.visibilityOwnerOnly')}
        error={errors.visibility?.message}
      />
      <Alert tone="info">{t('communities.form.safety')}</Alert>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        {secondaryAction}
        <Button type="submit" loading={submitting}>
          {submitLabel}
        </Button>
      </div>
    </form>
  );
}
