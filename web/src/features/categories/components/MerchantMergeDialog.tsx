import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { FieldError } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { Merchant } from '@/shared/finance/types';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { merchantsApi, useMerchantList } from '../api';
import { organizeErrorMessage } from '../errors';
import { merchantMergeImpact } from '../labels';

/** The merchant that is kept (its ID and name). */
export interface MergeTarget {
  id: string;
  name: string;
}

interface MerchantMergeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  target: MergeTarget;
  /**
   * Fixed merchants to merge into `target` (e.g. "merge this merchant into
   * the one that already has the name"); without them the user picks
   * duplicates of `target` first.
   */
  sources?: readonly Merchant[];
  /** Called after a successful merge (the default just closes). */
  onMerged?: () => void;
}

/**
 * Merge merchants into `target`: choose them, review what moves (server
 * preview: transactions, other names, rules, schedules, budgets), then
 * confirm. A merge cannot be undone.
 */
export function MerchantMergeDialog({
  open,
  onOpenChange,
  target,
  sources,
  onMerged,
}: MerchantMergeDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('merchants.merge.title', { name: target.name })}
      description={
        sources
          ? t('merchants.merge.intoOtherDescription', { name: target.name })
          : t('merchants.merge.description', { name: target.name })
      }
      busy={pending}
      size="lg"
    >
      {open ? (
        <MergeBody
          target={target}
          fixedSources={sources}
          onPendingChange={setPending}
          onCancel={() => {
            onOpenChange(false);
          }}
          onMerged={() => {
            if (onMerged) onMerged();
            else onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function mergeFailure(error: unknown, t: Translate, locale: string): string {
  // A chosen merchant was merged or removed meanwhile.
  if (hasErrorCode(error, 'NOT_FOUND')) return t('merchants.merge.gone');
  return organizeErrorMessage(error, t, locale);
}

function MergeBody({
  target,
  fixedSources,
  onPendingChange,
  onCancel,
  onMerged,
}: {
  target: MergeTarget;
  fixedSources: readonly Merchant[] | undefined;
  onPendingChange: (pending: boolean) => void;
  onCancel: () => void;
  onMerged: () => void;
}) {
  const [selected, setSelected] = useState<ReadonlyMap<string, Merchant>>(
    () => new Map((fixedSources ?? []).map((merchant) => [merchant.id, merchant])),
  );
  const [reviewing, setReviewing] = useState(Boolean(fixedSources));
  if (reviewing) {
    return (
      <MergeReview
        target={target}
        chosen={[...selected.values()]}
        onPendingChange={onPendingChange}
        onBack={
          fixedSources
            ? onCancel
            : () => {
                setReviewing(false);
              }
        }
        backLabel={fixedSources ? 'cancel' : 'back'}
        onMerged={onMerged}
      />
    );
  }
  return (
    <MergePicker
      target={target}
      selected={selected}
      onSelectedChange={setSelected}
      onCancel={onCancel}
      onReview={() => {
        setReviewing(true);
      }}
    />
  );
}

/** Step 1: choose the duplicates (active and archived merchants, in pages). */
function MergePicker({
  target,
  selected,
  onSelectedChange,
  onCancel,
  onReview,
}: {
  target: MergeTarget;
  selected: ReadonlyMap<string, Merchant>;
  onSelectedChange: (next: ReadonlyMap<string, Merchant>) => void;
  onCancel: () => void;
  onReview: () => void;
}) {
  const { t } = useI18n();
  const errorId = useId();
  const [search, setSearch] = useState('');
  const q = useDebouncedValue(search.trim(), 300);
  const list = useMerchantList(q, 'all');
  const [selectError, setSelectError] = useState<string | null>(null);

  const candidates = (list.data?.pages.flatMap((page) => page.items) ?? []).filter(
    (merchant) => merchant.id !== target.id && merchant.status !== 'merged',
  );

  const toggle = (merchant: Merchant, checked: boolean) => {
    setSelectError(null);
    const next = new Map(selected);
    if (checked) next.set(merchant.id, merchant);
    else next.delete(merchant.id);
    onSelectedChange(next);
  };

  let results;
  if (list.isPending) {
    results = <LoadingState label={t('merchants.loading')} />;
  } else if (list.isError && candidates.length === 0) {
    results = (
      <ErrorState
        titleAs="p"
        title={t('merchants.error')}
        error={list.error}
        retrying={list.isFetching}
        onRetry={() => {
          void list.refetch();
        }}
      />
    );
  } else if (candidates.length === 0 && !list.hasNextPage) {
    results = <p className="py-4 text-center text-sm text-fg-muted">{t('merchants.merge.none')}</p>;
  } else {
    results = (
      <>
        <ul className="max-h-72 space-y-1 overflow-y-auto rounded-md border border-line p-2">
          {candidates.map((merchant) => (
            <li key={merchant.id}>
              <label className="flex min-h-11 cursor-pointer items-center gap-3 rounded-md px-2 text-sm text-fg hover:bg-surface-muted">
                <input
                  type="checkbox"
                  className="size-5 shrink-0 cursor-pointer accent-accent"
                  checked={selected.has(merchant.id)}
                  onChange={(event) => {
                    toggle(merchant, event.target.checked);
                  }}
                />
                <span className="min-w-0 flex-1">
                  {merchant.name}
                  <span className="block text-fg-muted">
                    {merchant.status === 'archived'
                      ? `${t('organize.transactionCount', { count: merchant.transaction_count })} · ${t('organize.archived')}`
                      : t('organize.transactionCount', { count: merchant.transaction_count })}
                  </span>
                </span>
              </label>
            </li>
          ))}
        </ul>
        <LoadMoreButton
          hasMore={list.hasNextPage}
          loading={list.isFetchingNextPage}
          failed={list.isFetchNextPageError}
          onLoadMore={() => {
            void list.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <div className="space-y-5">
      <TextField
        label={t('merchants.search')}
        type="search"
        optional
        autoComplete="off"
        maxLength={100}
        value={search}
        onChange={(event) => {
          setSearch(event.target.value);
        }}
      />
      <fieldset aria-describedby={selectError ? errorId : undefined} className="space-y-2">
        <legend className="mb-1.5 text-sm font-medium text-fg">
          {t('merchants.merge.legend')}
        </legend>
        {results}
        {selectError ? <FieldError id={errorId}>{selectError}</FieldError> : null}
      </fieldset>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button
          onClick={() => {
            if (selected.size === 0) {
              setSelectError(t('merchants.merge.selectRequired'));
              return;
            }
            onReview();
          }}
        >
          {t('merchants.merge.review')}
        </Button>
      </div>
    </div>
  );
}

/** Step 2: what the merge moves (server preview), then the confirmation. */
function MergeReview({
  target,
  chosen,
  onPendingChange,
  onBack,
  backLabel,
  onMerged,
}: {
  target: MergeTarget;
  chosen: readonly Merchant[];
  onPendingChange: (pending: boolean) => void;
  onBack: () => void;
  backLabel: 'back' | 'cancel';
  onMerged: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const sourceIds = chosen.map((merchant) => merchant.id);
  // The preview changes nothing, so it is read like data (fresh every time the review opens).
  const check = useQuery({
    queryKey: financeKeys.merchantMergePreview(target.id, sourceIds),
    queryFn: () => merchantsApi.mergePreview({ source_ids: sourceIds, target_id: target.id }),
    staleTime: 0,
    gcTime: 0,
    retry: false,
  });
  const merge = useMutation({
    mutationFn: () => merchantsApi.merge({ source_ids: sourceIds, target_id: target.id }),
    onSettled: () => invalidateFinance(queryClient),
  });

  const preview = check.data ?? null;
  const previewError = check.isError ? mergeFailure(check.error, t, formatLocale) : null;
  const impact = preview ? merchantMergeImpact(preview.affected, target.name, t) : [];

  return (
    <div className="space-y-5">
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      <div className="space-y-3 rounded-lg border border-line bg-surface-muted p-4 text-sm">
        <h3 className="font-semibold text-fg">
          {t('merchants.merge.confirmTitle', { count: chosen.length, name: target.name })}
        </h3>
        <ul className="list-disc space-y-1 ps-5 text-fg">
          {chosen.map((merchant) => (
            <li key={merchant.id}>
              {merchant.name} ·{' '}
              {t('organize.transactionCount', { count: merchant.transaction_count })}
            </li>
          ))}
        </ul>
        <section
          role="status"
          aria-label={t('merchants.merge.previewTitle')}
          className="space-y-2 border-t border-line pt-3"
        >
          <h4 className="font-semibold text-fg">{t('merchants.merge.previewTitle')}</h4>
          {check.isFetching ? (
            <p className="text-fg-muted">{t('merchants.merge.previewLoading')}</p>
          ) : null}
          {previewError && !check.isFetching ? <p className="text-danger">{previewError}</p> : null}
          {preview && !check.isFetching ? (
            impact.length > 0 ? (
              <>
                <p className="text-fg">
                  {t('merchants.merge.previewIntro', { name: target.name })}
                </p>
                <ul className="list-disc space-y-1 ps-5 text-fg">
                  {impact.map((line) => (
                    <li key={line.key}>{line.text}</li>
                  ))}
                </ul>
              </>
            ) : (
              <p className="text-fg">{t('merchants.merge.nothing')}</p>
            )
          ) : null}
        </section>
        <p className="flex items-start gap-2 text-fg-muted">
          <Icon name="alert-triangle" className="mt-0.5 size-4 shrink-0 text-warning" />
          {t('merchants.merge.confirmBody', { name: target.name })}
        </p>
      </div>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={merge.isPending} onClick={onBack}>
          {backLabel === 'back' ? t('common.back') : t('common.cancel')}
        </Button>
        {previewError ? (
          <Button
            variant="secondary"
            loading={check.isFetching}
            onClick={() => {
              void check.refetch();
            }}
          >
            {t('merchants.merge.previewAgain')}
          </Button>
        ) : null}
        <Button
          variant="danger"
          loading={merge.isPending}
          disabled={!preview || check.isFetching}
          onClick={() => {
            if (merge.isPending || !preview) return;
            setError(null);
            onPendingChange(true);
            merge.mutate(undefined, {
              onSuccess: () => {
                onPendingChange(false);
                toast.show({ tone: 'success', title: t('merchants.merge.done') });
                onMerged();
              },
              onError: (failure) => {
                onPendingChange(false);
                setError(mergeFailure(failure, t, formatLocale));
              },
            });
          }}
        >
          {t('merchants.merge.confirm')}
        </Button>
      </div>
    </div>
  );
}
