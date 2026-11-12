import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { transactionPath } from '@/shared/config/paths';
import { TransactionAmount } from '@/shared/finance/components/TransactionAmount';
import { transactionTitle } from '@/shared/finance/transactionDisplay';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useTransaction } from '@/features/transactions/api';
import { canMatch, canRecord } from '../labels';
import type { ReceiptDetail } from '../types';

interface ReceiptLinkCardProps {
  receipt: ReceiptDetail;
  onRecord: () => void;
  onMatch: () => void;
  onUnlink: () => void;
  unlinking: boolean;
}

/** The purchase this receipt belongs to: linked, or ways to record or find it. */
export function ReceiptLinkCard({
  receipt,
  onRecord,
  onMatch,
  onUnlink,
  unlinking,
}: ReceiptLinkCardProps) {
  const { t } = useI18n();
  if (receipt.transaction_id) {
    return (
      <Card title={t('receipts.link.title')}>
        <LinkedTransaction id={receipt.transaction_id} />
        <div className="mt-5 space-y-2 border-t border-line pt-4">
          <Button variant="secondary" size="sm" loading={unlinking} onClick={onUnlink}>
            <Icon name="x" className="size-4" />
            {t('receipts.link.unlink')}
          </Button>
          <p className="text-sm text-fg-muted">{t('receipts.link.unlinkHelp')}</p>
        </div>
      </Card>
    );
  }

  let content;
  if (receipt.status === 'discarded') {
    content = <p className="text-sm text-fg-muted">{t('receipts.link.discarded')}</p>;
  } else if (receipt.status === 'processing') {
    content = <p className="text-sm text-fg-muted">{t('receipts.link.processing')}</p>;
  } else {
    const ready = canRecord(receipt);
    content = (
      <div className="space-y-4">
        <p className="text-sm text-fg-muted">
          {ready ? t('receipts.link.readyHelp') : t('receipts.link.reviewFirst')}
        </p>
        <div className="flex flex-col gap-2">
          {ready ? (
            <Button onClick={onRecord}>
              <Icon name="plus" className="size-4" />
              {t('receipts.link.record')}
            </Button>
          ) : null}
          {canMatch(receipt) ? (
            <Button variant="secondary" onClick={onMatch}>
              <Icon name="link" className="size-4" />
              {t('receipts.link.match')}
            </Button>
          ) : null}
        </div>
      </div>
    );
  }
  return <Card title={t('receipts.link.title')}>{content}</Card>;
}

function LinkedTransaction({ id }: { id: string }) {
  const { t, formatLocale } = useI18n();
  const transaction = useTransaction(id);
  if (transaction.isPending) return <LoadingState label={t('receipts.link.loading')} />;
  if (transaction.isError) {
    return (
      <p className="text-sm text-fg-muted">
        {t('receipts.link.loadFailed')}{' '}
        <TextLink to={transactionPath(id)}>{t('receipts.link.open')}</TextLink>
      </p>
    );
  }
  const data = transaction.data;
  return (
    <div className="flex items-start gap-3">
      <span className="mt-0.5 inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
        <Icon name="link" className="size-4" />
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <TextLink to={transactionPath(id)}>{transactionTitle(data, t)}</TextLink>
        <p className="text-sm text-fg-muted">
          {[formatLocalDate(data.local_date, formatLocale), data.account_name].join(' · ')}
        </p>
        {data.status === 'voided' ? (
          <StatusBadge tone="neutral" icon="ban">
            {t('finance.txStatus.voided')}
          </StatusBadge>
        ) : null}
      </div>
      <TransactionAmount transaction={data} className="pt-0.5 text-end" />
    </div>
  );
}
