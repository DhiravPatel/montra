import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { categoryName } from '@/shared/finance/categories';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Category, CategoryInput, CategoryKind, CategoryPatch } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { categoriesApi } from '../api';
import { nameTaken, organizeErrorMessage } from '../errors';
import { CATEGORY_KINDS, categoryKindLabel, isCategoryKind } from '../labels';
import { ColorField } from './ColorField';

interface Values {
  name: string;
  kind: string;
  parentId: string;
  color: string;
  includeInBudgets: boolean;
  /** Edit only: remove the saved icon (icons are shown in the Montra apps). */
  removeIcon: boolean;
}

export type CategoryDialogMode =
  { kind: 'create'; parent?: Category | null } | { kind: 'edit'; category: Category };

interface CategoryDialogProps {
  mode: CategoryDialogMode | null;
  onClose: () => void;
  /** Every category the user has (to offer parents and spot subcategories). */
  categories: readonly Category[];
}

/** Add a category or subcategory, or edit one (only changed fields are sent). */
export function CategoryDialog({ mode, onClose, categories }: CategoryDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  let title = t('organize.categories.create.title');
  if (mode?.kind === 'edit') title = t('organize.categories.edit.title');
  else if (mode?.parent) title = t('organize.categories.createSub.title');
  return (
    <Dialog
      open={mode !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={title}
      busy={pending}
    >
      {mode ? (
        <CategoryFormGate
          mode={mode}
          categories={categories}
          onPendingChange={setPending}
          onDone={onClose}
        />
      ) : null}
    </Dialog>
  );
}

/** After a version conflict the latest record is loaded and the form starts again from it. */
function CategoryFormGate(props: {
  mode: CategoryDialogMode;
  categories: readonly Category[];
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const [latest, setLatest] = useState<Category | null>(
    props.mode.kind === 'edit' ? props.mode.category : null,
  );
  const [conflict, setConflict] = useState(false);
  const [reloadError, setReloadError] = useState<string | null>(null);
  return (
    <>
      <FormAlert message={reloadError} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-5" title={t('finance.conflict.title')}>
          {t('organize.categories.changedElsewhere')}
        </Alert>
      ) : null}
      <CategoryForm
        key={latest ? `${latest.id}:${latest.version}` : 'new'}
        {...props}
        category={latest}
        onConflict={() => {
          setConflict(true);
          if (!latest) return;
          categoriesApi
            .get(latest.id)
            .then((fresh) => {
              setLatest(fresh);
              void invalidateFinance(queryClient);
            })
            .catch((error: unknown) => {
              setReloadError(
                hasErrorCode(error, 'NOT_FOUND')
                  ? t('organize.categories.notFound')
                  : describeError(error, t),
              );
            });
        }}
      />
    </>
  );
}

function CategoryForm({
  mode,
  category,
  categories,
  onDone,
  onPendingChange,
  onConflict,
}: {
  mode: CategoryDialogMode;
  category: Category | null;
  categories: readonly Category[];
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
  onConflict: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const parent = mode.kind === 'create' ? (mode.parent ?? null) : null;
  // Starter names are shown in the interface language; only a real change renames.
  const initialName = category ? categoryName(category, t) : '';
  const hasChildren = category
    ? categories.some((item) => item.parent_id === category.id && item.status !== 'merged')
    : false;

  const schema = useMemo(
    () =>
      z.object({
        name: z
          .string()
          .trim()
          .min(1, { error: t('organize.categories.form.nameRequired') })
          .max(60, { error: t('validation.maxLength', { max: 60 }) }),
        kind: z.string().refine(isCategoryKind),
        parentId: z.string(),
        color: z.string(),
        includeInBudgets: z.boolean(),
        removeIcon: z.boolean(),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: initialName,
      kind: category?.kind ?? parent?.kind ?? 'expense',
      parentId: category?.parent_id ?? parent?.id ?? '',
      color: category?.color ?? '',
      includeInBudgets: category?.include_in_budgets ?? true,
      removeIcon: false,
    },
  });

  const mutation = useMutation({
    mutationFn: (body: CategoryInput | CategoryPatch) =>
      category
        ? categoriesApi.update(category.id, body as CategoryPatch)
        : categoriesApi.create(body as CategoryInput),
    onSuccess: () => invalidateFinance(queryClient),
  });

  // Top-level categories only (one level of subcategories), plus the current parent if inactive.
  const parentChoices = categories
    .filter(
      (item) =>
        !item.parent_id &&
        item.id !== category?.id &&
        (item.status === 'active' || item.id === category?.parent_id),
    )
    .sort((a, b) => categoryName(a, t).localeCompare(categoryName(b, t), formatLocale))
    .map((item) => ({ value: item.id, label: categoryName(item, t) }));

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || !isCategoryKind(values.kind)) return;
    setFormError(null);
    const name = values.name.trim();
    const kind: CategoryKind = values.kind;
    let body: CategoryInput | CategoryPatch;
    if (category) {
      const patch: CategoryPatch = { version: category.version };
      if (name !== initialName) patch.name = name;
      if (kind !== category.kind) patch.kind = kind;
      if (values.includeInBudgets !== category.include_in_budgets) {
        patch.include_in_budgets = values.includeInBudgets;
      }
      if (values.color.toUpperCase() !== (category.color ?? '').toUpperCase()) {
        // An emptied color is removed; a new one replaces it.
        if (values.color) patch.color = values.color;
        else patch.clear_color = true;
      }
      if (category.icon && values.removeIcon) patch.icon = '';
      if (!hasChildren && values.parentId !== (category.parent_id ?? '')) {
        if (values.parentId) patch.parent_id = values.parentId;
        else patch.clear_parent = true;
      }
      if (Object.keys(patch).length === 1) {
        onDone();
        return;
      }
      body = patch;
    } else {
      body = {
        name,
        kind,
        include_in_budgets: values.includeInBudgets,
        ...(values.parentId ? { parent_id: values.parentId } : {}),
        ...(values.color ? { color: values.color } : {}),
      };
    }
    onPendingChange(true);
    try {
      await mutation.mutateAsync(body);
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: category ? t('organize.categories.edit.done') : t('organize.categories.create.done'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      const code = domainRuleCode(error)?.code;
      const taken = nameTaken(error);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          name: 'name',
          kind: 'kind',
          parent_id: 'parentId',
          color: 'color',
          clear_color: 'color',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        onConflict();
      } else if (taken || hasErrorCode(error, 'CONFLICT')) {
        form.setError(
          'name',
          {
            type: 'server',
            message: taken?.name
              ? t('organize.categories.form.duplicateNamed', { name: taken.name })
              : t('organize.categories.form.duplicate'),
          },
          { shouldFocus: true },
        );
      } else if (code === 'category_depth' || code === 'parent_category_archived') {
        form.setError(
          'parentId',
          { type: 'server', message: organizeErrorMessage(error, t, formatLocale) },
          { shouldFocus: true },
        );
      } else if (hasErrorCode(error, 'NOT_FOUND')) {
        setFormError(t('organize.categories.notFound'));
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
        label={t('organize.categories.form.name')}
        maxLength={60}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <Controller
        control={form.control}
        name="kind"
        render={({ field }) => (
          <RadioGroup
            legend={t('organize.categories.form.kind')}
            value={isCategoryKind(field.value) ? field.value : 'expense'}
            onChange={field.onChange}
            options={CATEGORY_KINDS.map((kind) => ({
              value: kind,
              label: t(categoryKindLabel[kind]),
            }))}
          />
        )}
      />
      <Select
        label={t('organize.categories.form.parent')}
        options={[{ value: '', label: t('organize.categories.form.parentNone') }, ...parentChoices]}
        disabled={hasChildren}
        help={
          hasChildren
            ? t('organize.categories.form.parentLocked')
            : t('organize.categories.form.parentHelp')
        }
        error={errors.parentId?.message}
        {...form.register('parentId')}
      />
      <Controller
        control={form.control}
        name="color"
        render={({ field }) => (
          <ColorField value={field.value} onChange={field.onChange} saved={category?.color} />
        )}
      />
      <Checkbox
        label={t('organize.categories.form.budgets')}
        description={t('organize.categories.form.budgetsHelp')}
        {...form.register('includeInBudgets')}
      />
      {category?.icon ? (
        <Checkbox
          label={t('organize.categories.form.removeIcon')}
          description={t('organize.categories.form.removeIconHelp')}
          {...form.register('removeIcon')}
        />
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {category ? t('common.save') : t('organize.categories.create.submit')}
        </Button>
      </div>
    </form>
  );
}
