import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Tag, TagBody, TagPatch } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { tagsApi } from '../api';
import { nameTaken, organizeErrorMessage } from '../errors';
import { ColorField } from './ColorField';

interface Values {
  name: string;
  color: string;
}

export type TagDialogMode = { kind: 'create' } | { kind: 'edit'; tag: Tag };

/** Create a tag, or rename/recolor one (only the changed fields are sent, with `version`). */
export function TagDialog({ mode, onClose }: { mode: TagDialogMode | null; onClose: () => void }) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={mode !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={mode?.kind === 'edit' ? t('tags.edit.title') : t('tags.create.title')}
      busy={pending}
    >
      {mode ? (
        <TagFormGate
          tag={mode.kind === 'edit' ? mode.tag : null}
          onPendingChange={setPending}
          onDone={onClose}
        />
      ) : null}
    </Dialog>
  );
}

/** After a version conflict the latest tag is loaded and the form starts again from it. */
function TagFormGate(props: {
  tag: Tag | null;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const [latest, setLatest] = useState<Tag | null>(props.tag);
  const [conflict, setConflict] = useState(false);
  const [reloadError, setReloadError] = useState<string | null>(null);
  return (
    <>
      <FormAlert message={reloadError} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-5" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <TagForm
        key={latest ? `${latest.id}:${latest.version}` : 'new'}
        {...props}
        tag={latest}
        onConflict={() => {
          setConflict(true);
          if (!latest) return;
          // Reload this tag alone; the form starts again from the latest version.
          tagsApi
            .get(latest.id)
            .then((fresh) => {
              setLatest(fresh);
              void invalidateFinance(queryClient);
            })
            .catch((error: unknown) => {
              setReloadError(
                hasErrorCode(error, 'NOT_FOUND') ? t('tags.notFound') : describeError(error, t),
              );
            });
        }}
      />
    </>
  );
}

function TagForm({
  tag,
  onPendingChange,
  onDone,
  onConflict,
}: {
  tag: Tag | null;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
  onConflict: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z.object({
        name: z
          .string()
          .trim()
          .min(1, { error: t('tags.form.nameRequired') })
          .max(40, { error: t('validation.maxLength', { max: 40 }) }),
        color: z.string(),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: { name: tag?.name ?? '', color: tag?.color ?? '' },
  });
  const mutation = useMutation({
    mutationFn: (body: TagBody | TagPatch) =>
      tag ? tagsApi.update(tag.id, body as TagPatch) : tagsApi.create(body),
    onSuccess: () => invalidateFinance(queryClient),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    const name = values.name.trim();
    let body: TagBody | TagPatch;
    if (tag) {
      const patch: TagPatch = { version: tag.version };
      if (name !== tag.name) patch.name = name;
      const saved = (tag.color ?? '').toUpperCase();
      if (values.color.toUpperCase() !== saved) {
        // An emptied color is removed; a new one replaces it.
        if (values.color) patch.color = values.color;
        else patch.clear_color = true;
      }
      if (Object.keys(patch).length === 1) {
        onDone();
        return;
      }
      body = patch;
    } else {
      body = { name, ...(values.color ? { color: values.color } : {}) };
    }
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({ tone: 'success', title: tag ? t('tags.edit.done') : t('tags.create.done') });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          name: 'name',
          color: 'color',
          clear_color: 'color',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        onConflict();
      } else if (nameTaken(error) || hasErrorCode(error, 'CONFLICT')) {
        form.setError(
          'name',
          { type: 'server', message: t('tags.form.duplicate') },
          { shouldFocus: true },
        );
      } else if (hasErrorCode(error, 'NOT_FOUND')) {
        setFormError(t('tags.notFound'));
      } else {
        setFormError(organizeErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        label={t('tags.form.name')}
        maxLength={40}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <Controller
        control={form.control}
        name="color"
        render={({ field }) => (
          <ColorField value={field.value} onChange={field.onChange} saved={tag?.color} />
        )}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {tag ? t('common.save') : t('tags.create.submit')}
        </Button>
      </div>
    </form>
  );
}
