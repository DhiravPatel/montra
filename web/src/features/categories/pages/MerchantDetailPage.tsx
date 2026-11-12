import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { ExternalLink, TextLink } from '@/shared/components/TextLink';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { merchantPath, paths, withQuery } from '@/shared/config/paths';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { invalidateFinance } from '@/shared/finance/keys';
import { useCategories, useMerchant } from '@/shared/finance/reference';
import type { MerchantDetail } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { merchantsApi } from '../api';
import { MerchantEditDialog } from '../components/MerchantEditDialog';
import { MerchantMergeDialog, type MergeTarget } from '../components/MerchantMergeDialog';
import { MerchantSpendingCard } from '../components/MerchantSpendingCard';
import { organizeErrorMessage } from '../errors';
import { isWebAddress } from '../labels';

function DetailSkeleton() {
  return (
    <div className="space-y-6" aria-hidden="true">
      <Skeleton className="h-9 w-1/2" />
      <Skeleton className="h-64 w-full" />
      <Skeleton className="h-40 w-full" />
    </div>
  );
}

function DetailsCard({ merchant }: { merchant: MerchantDetail }) {
  const { t } = useI18n();
  const categories = useCategories(true);
  const category = merchant.default_category_id
    ? categoriesById(categories.data).get(merchant.default_category_id)
    : undefined;
  return (
    <Card title={t('merchants.details.title')}>
      <Facts>
        <Fact label={t('merchants.details.defaultCategory')}>
          {category ? categoryName(category, t) : t('merchants.details.none')}
        </Fact>
        <Fact label={t('merchants.details.website')}>
          {merchant.website && isWebAddress(merchant.website) ? (
            <ExternalLink href={merchant.website} newTab>
              {merchant.website}
            </ExternalLink>
          ) : (
            (merchant.website ?? t('merchants.details.none'))
          )}
        </Fact>
        <Fact label={t('merchants.details.notes')}>
          {merchant.notes ? (
            <span className="whitespace-pre-line">{merchant.notes}</span>
          ) : (
            t('merchants.details.none')
          )}
        </Fact>
      </Facts>
    </Card>
  );
}

/** Other spellings of the merchant name (e.g. from bank statements): add or remove. */
function AliasesCard({ merchant, editable }: { merchant: MerchantDetail; editable: boolean }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [alias, setAlias] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [removing, setRemoving] = useState<string | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const add = useMutation({
    mutationFn: (value: string) =>
      merchantsApi.addAlias({ alias: value, merchant_id: merchant.id }),
    onSuccess: () => invalidateFinance(queryClient),
  });
  const remove = useMutation({
    mutationFn: (value: string) =>
      merchantsApi.removeAlias({ alias: value, merchant_id: merchant.id }),
    onSettled: () => invalidateFinance(queryClient),
  });
  const submit = (event: { preventDefault: () => void }) => {
    event.preventDefault();
    if (add.isPending) return;
    const value = alias.trim();
    if (!value) {
      setError(t('merchants.aliases.required'));
      return;
    }
    if (value.length > 200) {
      setError(t('validation.maxLength', { max: 200 }));
      return;
    }
    setError(null);
    add.mutate(value, {
      onSuccess: () => {
        setAlias('');
        toast.show({ tone: 'success', title: t('merchants.aliases.done') });
      },
      onError: (failure) => {
        setError(organizeErrorMessage(failure, t, formatLocale));
      },
    });
  };
  return (
    <Card title={t('merchants.aliases.title')} description={t('merchants.aliases.description')}>
      {merchant.aliases.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('merchants.aliases.empty')}</p>
      ) : (
        <ul className="flex flex-wrap gap-2">
          {merchant.aliases.map((name) => (
            <li
              key={name}
              className="inline-flex items-center gap-1 rounded-full border border-line bg-surface-muted py-0.5 ps-3 pe-1 text-sm text-fg"
            >
              {name}
              {editable ? (
                <IconButton
                  icon="x"
                  size="sm"
                  label={t('merchants.aliases.removeLabel', { alias: name })}
                  onClick={() => {
                    setRemoveError(null);
                    setRemoving(name);
                  }}
                />
              ) : null}
            </li>
          ))}
        </ul>
      )}
      {editable ? (
        <form
          onSubmit={submit}
          noValidate
          className="mt-5 flex flex-col gap-3 sm:flex-row sm:items-start"
        >
          <TextField
            label={t('merchants.aliases.label')}
            help={t('merchants.aliases.help')}
            className="flex-1"
            maxLength={200}
            autoComplete="off"
            value={alias}
            error={error ?? undefined}
            onChange={(event) => {
              setAlias(event.target.value);
            }}
          />
          <Button type="submit" variant="secondary" loading={add.isPending} className="sm:mt-7">
            <Icon name="plus" className="size-4" />
            {t('merchants.aliases.add')}
          </Button>
        </form>
      ) : null}
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('merchants.aliases.removeTitle')}
        description={t('merchants.aliases.removeBody', {
          alias: removing ?? '',
          name: merchant.name,
        })}
        confirmLabel={t('merchants.aliases.removeConfirm')}
        pending={remove.isPending}
        error={removeError}
        onConfirm={() => {
          if (!removing || remove.isPending) return;
          setRemoveError(null);
          remove.mutate(removing, {
            onSuccess: () => {
              toast.show({ tone: 'success', title: t('merchants.aliases.removed') });
              setRemoving(null);
            },
            onError: (failure) => {
              if (hasErrorCode(failure, 'NOT_FOUND')) {
                // Removed elsewhere (or the merchant was merged): the page reloads.
                toast.show({ tone: 'info', title: t('merchants.aliases.alreadyRemoved') });
                setRemoving(null);
              } else {
                setRemoveError(organizeErrorMessage(failure, t, formatLocale));
              }
            },
          });
        }}
      />
    </Card>
  );
}

/** One merchant: spending history, details, other names, merge and archive. */
export function MerchantDetailPage() {
  const { t, formatLocale } = useI18n();
  const { merchantId = '' } = useParams();
  useDocumentTitle(t('merchants.detail.documentTitle'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useMerchant(merchantId);
  const [editOpen, setEditOpen] = useState(false);
  const [mergeOpen, setMergeOpen] = useState(false);
  const [mergeInto, setMergeInto] = useState<MergeTarget | null>(null);
  const [archiving, setArchiving] = useState(false);
  const [statusError, setStatusError] = useState<string | null>(null);
  const status = useMutation({
    mutationFn: ({ archived, version }: { archived: boolean; version: number }) =>
      merchantsApi.update(merchantId, { archived, version }),
    // Also after a refusal, so a stale version is replaced by the latest one.
    onSettled: () => invalidateFinance(queryClient),
  });

  const back = (
    <p className="mb-2">
      <TextLink to={paths.merchants}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('merchants.back')}
      </TextLink>
    </p>
  );

  if (query.isPending) {
    return (
      <LoadingState label={t('merchants.detail.loading')}>
        <DetailSkeleton />
      </LoadingState>
    );
  }
  if (query.isError) {
    let state;
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      state = (
        <EmptyState
          titleAs="h2"
          icon="shopping-bag"
          title={t('merchants.detail.notFound')}
          description={t('merchants.detail.notFoundBody')}
          action={<ButtonLink to={paths.merchants}>{t('merchants.back')}</ButtonLink>}
        />
      );
    } else if (hasErrorCode(query.error, 'FORBIDDEN')) {
      state = <PermissionDenied titleAs="h2" />;
    } else {
      state = (
        <ErrorState
          titleAs="h2"
          title={t('merchants.detail.error')}
          error={query.error}
          retrying={query.isFetching}
          onRetry={() => {
            void query.refetch();
          }}
        />
      );
    }
    return (
      <>
        {back}
        {state}
      </>
    );
  }

  const merchant = query.data;
  const archived = merchant.status === 'archived';
  const merged = merchant.status === 'merged';
  const details = [
    t('organize.transactionCount', { count: merchant.transaction_count }),
    merchant.last_used_on
      ? t('merchants.lastUsed', { date: formatLocalDate(merchant.last_used_on, formatLocale) })
      : null,
  ].filter(Boolean);

  const setArchived = (next: boolean) => {
    if (status.isPending) return;
    setStatusError(null);
    status.mutate(
      { archived: next, version: merchant.version },
      {
        onSuccess: () => {
          toast.show({
            tone: 'success',
            title: next ? t('merchants.archive.done') : t('merchants.unarchive.done'),
          });
          setArchiving(false);
        },
        onError: (error) => {
          const stale = hasErrorCode(error, 'VERSION_CONFLICT');
          const message = stale
            ? t('merchants.status.reloaded')
            : organizeErrorMessage(error, t, formatLocale);
          if (next && !stale) setStatusError(message);
          else {
            setArchiving(false);
            toast.show({
              tone: stale ? 'warning' : 'danger',
              title: stale ? t('finance.conflict.title') : t('merchants.status.failed'),
              description: message,
            });
          }
        },
      },
    );
  };

  return (
    <>
      {back}
      <PageHeader
        title={merchant.name}
        description={details.join(' · ')}
        actions={
          <>
            <ButtonLink
              to={withQuery(paths.transactions, { merchant_id: merchant.id, range: 'all' })}
              variant="secondary"
            >
              <Icon name="list" className="size-4" />
              {t('organize.viewTransactions')}
            </ButtonLink>
            {merged ? null : (
              <Button
                variant="secondary"
                onClick={() => {
                  setEditOpen(true);
                }}
              >
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </Button>
            )}
          </>
        }
      />
      {archived ? (
        <Alert tone="info" className="mb-6" title={t('merchants.detail.archivedTitle')}>
          {t('merchants.detail.archivedBody')}
        </Alert>
      ) : null}
      {merged ? (
        <Alert tone="info" className="mb-6" title={t('merchants.detail.mergedTitle')}>
          <p>{t('merchants.detail.mergedBody')}</p>
          {merchant.merged_into_id ? (
            <p>
              <TextLink to={merchantPath(merchant.merged_into_id)}>
                {t('merchants.detail.openMergedInto')}
              </TextLink>
            </p>
          ) : null}
        </Alert>
      ) : null}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <MerchantSpendingCard spending={merchant.spending} />
          <AliasesCard merchant={merchant} editable={!merged} />
        </div>
        <div className="space-y-6">
          <DetailsCard merchant={merchant} />
          {merged ? null : (
            <Card
              title={t('merchants.manage.title')}
              description={t('merchants.manage.description')}
            >
              <div className="flex flex-col gap-3">
                <Button
                  variant="secondary"
                  onClick={() => {
                    setMergeOpen(true);
                  }}
                >
                  <Icon name="git-merge" className="size-4" />
                  {t('merchants.merge.action')}
                </Button>
                {archived ? (
                  <Button
                    variant="secondary"
                    loading={status.isPending}
                    onClick={() => {
                      setArchived(false);
                    }}
                  >
                    <Icon name="archive-restore" className="size-4" />
                    {t('merchants.unarchive.action')}
                  </Button>
                ) : (
                  <Button
                    variant="secondary"
                    onClick={() => {
                      setStatusError(null);
                      setArchiving(true);
                    }}
                  >
                    <Icon name="archive" className="size-4" />
                    {t('merchants.archive.action')}
                  </Button>
                )}
                {archived ? (
                  <StatusBadge icon="archive">{t('organize.archived')}</StatusBadge>
                ) : null}
              </div>
            </Card>
          )}
        </div>
      </div>
      <MerchantEditDialog
        open={editOpen}
        onOpenChange={setEditOpen}
        merchant={merchant}
        onMergeInto={(target) => {
          setEditOpen(false);
          setMergeInto(target);
        }}
      />
      <MerchantMergeDialog
        open={mergeOpen}
        onOpenChange={setMergeOpen}
        target={{ id: merchant.id, name: merchant.name }}
      />
      {mergeInto ? (
        <MerchantMergeDialog
          open
          onOpenChange={(open) => {
            if (!open) setMergeInto(null);
          }}
          target={mergeInto}
          sources={[merchant]}
          onMerged={() => {
            const target = mergeInto.id;
            setMergeInto(null);
            // This merchant is now part of the other one.
            void navigate(merchantPath(target));
          }}
        />
      ) : null}
      <ConfirmDialog
        open={archiving}
        onOpenChange={setArchiving}
        title={t('merchants.archive.title')}
        description={t('merchants.archive.body', { name: merchant.name })}
        confirmLabel={t('merchants.archive.confirm')}
        pending={status.isPending}
        error={statusError}
        onConfirm={() => {
          setArchived(true);
        }}
      />
    </>
  );
}
