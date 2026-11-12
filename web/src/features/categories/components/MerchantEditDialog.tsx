import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { categoryName } from '@/shared/finance/categories';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { categoryOptions } from '@/shared/finance/options';
import { useCategories } from '@/shared/finance/reference';
import type { Category, MerchantDetail, MerchantPatch } from '@/shared/finance/types';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useI18n } from '@/shared/i18n/I18nContext';
import { merchantsApi } from '../api';
import { nameTaken, organizeErrorMessage } from '../errors';
import { isWebAddress } from '../labels';
import type { MergeTarget } from './MerchantMergeDialog';

interface Values {
  name: string;
  website: string;
  defaultCategoryId: string;
  notes: string;
}

interface MerchantEditDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The merchant as last loaded (its `version` is sent with the change). */
  merchant: MerchantDetail;
  /** Offer to merge into the merchant that already has the new name. */
  onMergeInto?: (target: MergeTarget) => void;
}

/** Correct a merchant's name, website, notes and default category (changed fields only). */
export function MerchantEditDialog({
  open,
  onOpenChange,
  merchant,
  onMergeInto,
}: MerchantEditDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('merchants.edit.title')}
      busy={pending}
    >
      {open ? (
        <MerchantFormGate
          merchant={merchant}
          onPendingChange={setPending}
          onMergeInto={onMergeInto}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

/**
 * The category select needs the categories first, so it can show the saved
 * choice. After a version conflict the merchant is reloaded and the form
 * starts again from the latest values (keyed by version).
 */
function MerchantFormGate(props: {
  merchant: MerchantDetail;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
  onMergeInto: ((target: MergeTarget) => void) | undefined;
}) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const categories = useCategories(true);
  const [conflict, setConflict] = useState(false);
  if (categories.isError) {
    return (
      <ErrorState
        title={t('organize.categories.error')}
        error={categories.error}
        onRetry={() => {
          void categories.refetch();
        }}
      />
    );
  }
  if (categories.isPending) return <LoadingState label={t('organize.categories.loading')} />;
  return (
    <>
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-5" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <MerchantForm
        key={props.merchant.version}
        {...props}
        categories={categories.data}
        onConflict={() => {
          setConflict(true);
          void queryClient.invalidateQueries({ queryKey: financeKeys.merchant(props.merchant.id) });
        }}
      />
    </>
  );
}

function MerchantForm({
  merchant,
  categories,
  onPendingChange,
  onDone,
  onConflict,
  onMergeInto,
}: {
  merchant: MerchantDetail;
  categories: readonly Category[];
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
  onConflict: () => void;
  onMergeInto: ((target: MergeTarget) => void) | undefined;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const [taken, setTaken] = useState<MergeTarget | null>(null);
  const schema = useMemo(
    () =>
      z.object({
        name: z
          .string()
          .trim()
          .min(1, { error: t('merchants.form.nameRequired') })
          .max(120, { error: t('validation.maxLength', { max: 120 }) }),
        website: z
          .string()
          .trim()
          .max(200, { error: t('validation.maxLength', { max: 200 }) })
          .refine((value) => value === '' || isWebAddress(value), {
            error: t('merchants.form.websiteInvalid'),
          }),
        defaultCategoryId: z.string(),
        notes: z.string().max(1000, { error: t('validation.maxLength', { max: 1000 }) }),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: merchant.name,
      website: merchant.website ?? '',
      defaultCategoryId: merchant.default_category_id ?? '',
      notes: merchant.notes ?? '',
    },
  });
  const mutation = useMutation({
    mutationFn: (body: MerchantPatch) => merchantsApi.update(merchant.id, body),
    onSuccess: () => invalidateFinance(queryClient),
  });

  // Active categories, plus the saved default even if it was archived meanwhile.
  const choices = categories.filter(
    (category) => category.status === 'active' || category.id === merchant.default_category_id,
  );

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    setTaken(null);
    const patch: MerchantPatch = {};
    const name = values.name.trim();
    const website = values.website.trim();
    if (name !== merchant.name) patch.name = name;
    // An empty website or notes value clears it.
    if (website !== (merchant.website ?? '')) patch.website = website;
    if (values.notes !== (merchant.notes ?? '')) patch.notes = values.notes;
    if (values.defaultCategoryId !== (merchant.default_category_id ?? '')) {
      if (values.defaultCategoryId) patch.default_category_id = values.defaultCategoryId;
      else patch.clear_default_category = true;
    }
    if (Object.keys(patch).length === 0) {
      onDone();
      return;
    }
    // The version shown, so a concurrent change is detected.
    patch.version = merchant.version;
    onPendingChange(true);
    try {
      await mutation.mutateAsync(patch);
      onPendingChange(false);
      toast.show({ tone: 'success', title: t('merchants.edit.done') });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          name: 'name',
          website: 'website',
          default_category_id: 'defaultCategoryId',
          notes: 'notes',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else if (hasErrorCode(error, 'VERSION_CONFLICT')) {
        onConflict();
      } else if (nameTaken(error)) {
        // 409 name_taken: offer to merge into the merchant that has the name.
        const other = nameTaken(error);
        const otherName = other?.name ?? name;
        form.setError(
          'name',
          { type: 'server', message: t('merchants.form.nameTaken', { name: otherName }) },
          { shouldFocus: true },
        );
        if (other?.merchantId && other.merchantId !== merchant.id) {
          setTaken({ id: other.merchantId, name: otherName });
        }
      } else if (hasErrorCode(error, 'NOT_FOUND')) {
        setFormError(t('merchants.detail.notFoundBody'));
      } else {
        setFormError(organizeErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {taken && onMergeInto ? (
        <Alert tone="info" title={t('merchants.form.mergeOfferTitle', { name: taken.name })}>
          <p>{t('merchants.form.mergeOfferBody', { name: taken.name })}</p>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              onMergeInto(taken);
            }}
          >
            <Icon name="git-merge" className="size-4" />
            {t('merchants.form.mergeOfferAction', { name: taken.name })}
          </Button>
        </Alert>
      ) : null}
      <TextField
        label={t('merchants.form.name')}
        maxLength={120}
        autoComplete="off"
        error={errors.name?.message}
        {...form.register('name')}
      />
      <TextField
        label={t('merchants.form.website')}
        help={t('merchants.form.websiteHelp')}
        type="url"
        inputMode="url"
        optional
        maxLength={200}
        autoComplete="off"
        error={errors.website?.message}
        {...form.register('website')}
      />
      <Select
        label={t('merchants.form.defaultCategory')}
        help={t('merchants.form.defaultCategoryHelp')}
        optional
        placeholder={t('common.none')}
        options={categoryOptions(choices, t, formatLocale).concat(
          choices
            .filter((category) => category.status !== 'active')
            .map((category) => ({ value: category.id, label: categoryName(category, t) })),
        )}
        error={errors.defaultCategoryId?.message}
        {...form.register('defaultCategoryId')}
      />
      <TextArea
        label={t('merchants.form.notes')}
        optional
        maxLength={1000}
        error={errors.notes?.message}
        {...form.register('notes')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('common.save')}
        </Button>
      </div>
    </form>
  );
}
