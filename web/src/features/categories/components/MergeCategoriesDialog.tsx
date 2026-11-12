import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { FieldError } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import { categoryOptions } from '@/shared/finance/options';
import type { Category, CategoryMergeResult } from '@/shared/finance/types';
import { useI18n } from '@/shared/i18n/I18nContext';
import { categoriesApi } from '../api';
import { organizeErrorMessage } from '../errors';
import { mergeImpact } from '../labels';

interface MergeCategoriesDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  categories: readonly Category[];
}

/** Merge categories: choose, check what moves (server preview), then confirm. */
export function MergeCategoriesDialog({
  open,
  onOpenChange,
  categories,
}: MergeCategoriesDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('organize.merge.title')}
      description={t('organize.merge.description')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <MergeForm
          categories={categories}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function MergeForm({
  categories,
  onPendingChange,
  onDone,
}: {
  categories: readonly Category[];
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const sourcesId = useId();
  const [targetId, setTargetId] = useState('');
  const [sourceIds, setSourceIds] = useState<ReadonlySet<string>>(new Set());
  const [preview, setPreview] = useState<CategoryMergeResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [targetError, setTargetError] = useState<string | null>(null);
  const [sourcesError, setSourcesError] = useState<string | null>(null);

  const active = categories.filter((category) => category.status === 'active');
  const options = categoryOptions(active, t, formatLocale);
  const labels = new Map(options.map((option) => [option.value, option.label]));
  const sources = options.filter((option) => option.value !== targetId);

  const check = useMutation({
    mutationFn: () =>
      categoriesApi.merge({ source_ids: [...sourceIds], target_id: targetId, preview: true }),
  });
  const merge = useMutation({
    mutationFn: () =>
      categoriesApi.merge({ source_ids: [...sourceIds], target_id: targetId, preview: false }),
    // Also after a refusal (e.g. a category merged elsewhere), so the choices are current.
    onSettled: () => invalidateFinance(queryClient),
  });

  if (active.length < 2) {
    return (
      <div className="space-y-5">
        <Alert tone="info">{t('organize.merge.notEnough')}</Alert>
        <div className="flex justify-end">
          <Button variant="secondary" onClick={onDone}>
            {t('common.close')}
          </Button>
        </div>
      </div>
    );
  }

  // Any change to the selection needs a fresh preview before merging.
  const changeSelection = (update: () => void) => {
    update();
    setPreview(null);
    setError(null);
  };

  const runPreview = () => {
    if (check.isPending) return;
    setTargetError(targetId ? null : t('organize.merge.targetRequired'));
    setSourcesError(sourceIds.size > 0 ? null : t('organize.merge.sourcesRequired'));
    if (!targetId || sourceIds.size === 0) return;
    setError(null);
    check.mutate(undefined, {
      onSuccess: (result) => {
        setPreview(result);
      },
      onError: (failure) => {
        setError(organizeErrorMessage(failure, t, formatLocale));
      },
    });
  };

  const runMerge = () => {
    if (merge.isPending || !preview) return;
    setError(null);
    onPendingChange(true);
    merge.mutate(undefined, {
      onSuccess: () => {
        onPendingChange(false);
        toast.show({ tone: 'success', title: t('organize.merge.done') });
        onDone();
      },
      onError: (failure) => {
        onPendingChange(false);
        setError(organizeErrorMessage(failure, t, formatLocale));
      },
    });
  };

  const targetName = labels.get(targetId) ?? '';
  const impact = preview ? mergeImpact(preview.affected, targetName, t) : [];

  return (
    <div className="space-y-5">
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      <Select
        label={t('organize.merge.target')}
        placeholder={t('organize.merge.targetPlaceholder')}
        options={options}
        value={targetId}
        error={targetError ?? undefined}
        onChange={(event) => {
          const next = event.target.value;
          changeSelection(() => {
            setTargetId(next);
            setTargetError(null);
            setSourceIds((current) => new Set([...current].filter((id) => id !== next)));
          });
        }}
      />
      <fieldset
        className="space-y-2"
        aria-describedby={sourcesError ? `${sourcesId}-error` : undefined}
      >
        <legend className="mb-1.5 text-sm font-medium text-fg">
          {t('organize.merge.sources')}
        </legend>
        {targetId ? null : (
          <p className="text-sm text-fg-muted">{t('organize.merge.chooseTargetFirst')}</p>
        )}
        <ul className="max-h-64 space-y-1 overflow-y-auto rounded-md border border-line p-2">
          {sources.map((option) => (
            <li key={option.value}>
              <label className="flex min-h-11 cursor-pointer items-center gap-3 rounded-md px-2 text-sm text-fg hover:bg-surface-muted">
                <input
                  type="checkbox"
                  className="size-5 shrink-0 cursor-pointer accent-accent"
                  checked={sourceIds.has(option.value)}
                  disabled={!targetId}
                  onChange={(event) => {
                    const { checked } = event.target;
                    changeSelection(() => {
                      setSourcesError(null);
                      setSourceIds((current) => {
                        const next = new Set(current);
                        if (checked) next.add(option.value);
                        else next.delete(option.value);
                        return next;
                      });
                    });
                  }}
                />
                {option.label}
              </label>
            </li>
          ))}
        </ul>
        {sourcesError ? <FieldError id={`${sourcesId}-error`}>{sourcesError}</FieldError> : null}
      </fieldset>

      {preview ? (
        <section
          role="status"
          aria-label={t('organize.merge.previewTitle')}
          className="space-y-3 rounded-lg border border-line bg-surface-muted p-4 text-sm"
        >
          <h3 className="font-semibold text-fg">{t('organize.merge.previewTitle')}</h3>
          {impact.length > 0 ? (
            <>
              <p className="text-fg">{t('organize.merge.previewIntro', { target: targetName })}</p>
              <ul className="list-disc space-y-1 ps-5 text-fg">
                {impact.map((line) => (
                  <li key={line.key}>{line.text}</li>
                ))}
              </ul>
            </>
          ) : (
            <p className="text-fg">{t('organize.merge.nothing')}</p>
          )}
          <p className="flex items-start gap-2 text-fg-muted">
            <Icon name="alert-triangle" className="mt-0.5 size-4 shrink-0 text-warning" />
            {t('organize.merge.warning')}
          </p>
        </section>
      ) : null}

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={merge.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        {preview ? (
          <Button variant="danger" loading={merge.isPending} onClick={runMerge}>
            {t('organize.merge.confirm')}
          </Button>
        ) : (
          <Button loading={check.isPending} onClick={runPreview}>
            {t('organize.merge.preview')}
          </Button>
        )}
      </div>
    </div>
  );
}
