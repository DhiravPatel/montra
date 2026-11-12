import { useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { receiptPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useReceipts } from '../api';
import { AddReceiptDialog } from '../components/AddReceiptDialog';
import { ReceiptStatusBadge } from '../components/ReceiptStatusBadge';
import { formatAddedOn } from '../format';
import {
  RECEIPT_STATUS_FILTERS,
  type ReceiptFilterChoice,
  isReceiptStatusFilter,
  receiptFilterLabel,
  reviewedValues,
} from '../labels';
import type { Receipt } from '../types';

function ReceiptRow({ receipt }: { receipt: Receipt }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const values = reviewedValues(receipt);
  const added = formatAddedOn(receipt.created_at, formatLocale, user.timezone);
  const addedText = added ? t('receipts.list.added', { date: added }) : null;
  const details = [
    values?.receipt_date ? formatLocalDate(values.receipt_date, formatLocale) : addedText,
    t('receipts.list.pages', { count: receipt.files.length }),
  ].filter(Boolean);
  return (
    <li className="flex items-start gap-3 py-3 first:pt-0 last:pb-0">
      <span className="mt-0.5 inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name="receipt" className="size-4" />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <Link
          to={receiptPath(receipt.id)}
          className="font-medium text-fg underline-offset-4 hover:underline"
        >
          {values?.merchant_name ?? t('receipts.untitled')}
        </Link>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        <div className="flex flex-wrap gap-1.5">
          <ReceiptStatusBadge status={receipt.status} />
          {receipt.duplicate_of_id ? (
            <StatusBadge tone="warning" icon="copy">
              {t('receipts.duplicate.badge')}
            </StatusBadge>
          ) : null}
        </div>
      </div>
      {values?.total ? (
        <MoneyText money={values.total} className="shrink-0 pt-0.5 text-end font-medium" />
      ) : null}
    </li>
  );
}

/** The receipt inbox (spec §4.9): add photos or PDFs, then review, link or record them. */
export function ReceiptsPage() {
  const { t } = useI18n();
  useDocumentTitle(t('receipts.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const requested = searchParams.get('status');
  const status: ReceiptFilterChoice = isReceiptStatusFilter(requested) ? requested : '';
  const receipts = useReceipts(status);
  const [adding, setAdding] = useState(false);

  const addButton = (
    <Button
      onClick={() => {
        setAdding(true);
      }}
    >
      <Icon name="plus" className="size-4" />
      {t('receipts.add.action')}
    </Button>
  );

  const loaded = receipts.data?.pages.flatMap((page) => page.items) ?? [];

  let content;
  if (receipts.isPending) {
    content = <LoadingState label={t('receipts.list.loading')} />;
  } else if (receipts.isError && !receipts.isFetchNextPageError) {
    content = hasErrorCode(receipts.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('receipts.list.error')}
        error={receipts.error}
        retrying={receipts.isFetching}
        onRetry={() => {
          void receipts.refetch();
        }}
      />
    );
  } else if (loaded.length === 0) {
    content =
      status === '' ? (
        <EmptyState
          icon="receipt"
          title={t('receipts.empty.title')}
          description={t('receipts.empty.body')}
          action={addButton}
        />
      ) : (
        <EmptyState
          icon="filter"
          title={t('receipts.empty.filteredTitle')}
          description={t('receipts.empty.filteredBody')}
        />
      );
  } else {
    content = (
      <>
        <p className="mb-4 text-sm text-fg-muted">
          {receipts.hasNextPage
            ? t('receipts.list.countMore', { count: loaded.length })
            : t('receipts.list.count', { count: loaded.length })}
        </p>
        <ul className="divide-y divide-line">
          {loaded.map((receipt) => (
            <ReceiptRow key={receipt.id} receipt={receipt} />
          ))}
        </ul>
        <LoadMoreButton
          hasMore={receipts.hasNextPage}
          loading={receipts.isFetchingNextPage}
          failed={receipts.isFetchNextPageError}
          onLoadMore={() => {
            void receipts.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t('receipts.title')}
        description={t('receipts.description')}
        actions={addButton}
      />
      <Card
        title={t('receipts.list.title')}
        description={t('receipts.list.description')}
        actions={
          <Select
            label={t('receipts.filter.label')}
            className="w-full sm:w-56"
            value={status}
            onChange={(event) => {
              const next = event.target.value;
              setSearchParams(next ? { status: next } : {}, { replace: true });
            }}
            options={RECEIPT_STATUS_FILTERS.map((filter) => ({
              value: filter,
              label: t(receiptFilterLabel(filter)),
            }))}
          />
        }
      >
        {content}
      </Card>
      <AddReceiptDialog
        open={adding}
        onOpenChange={setAdding}
        onCreated={(created, mode) => {
          setAdding(false);
          const first = created[0];
          if (mode === 'pages' && created.length === 1 && first) {
            toast.show({
              tone: 'success',
              title: t('receipts.add.done'),
              description: t('receipts.add.doneBody'),
            });
            void navigate(receiptPath(first.id));
          } else {
            toast.show({
              tone: 'success',
              title: t('receipts.add.doneMany', { count: created.length }),
            });
          }
        }}
      />
    </>
  );
}
