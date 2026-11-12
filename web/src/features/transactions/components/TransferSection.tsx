import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyText } from '@/shared/components/MoneyText';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { accountPath, transactionPath } from '@/shared/config/paths';
import { useAccounts } from '@/shared/finance/reference';
import type { Transaction } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useTransfer } from '../api';

/** Both legs of a transfer, its fee and exchange rate (spec §18 "Transfer"). */
export function TransferSection({ transaction }: { transaction: Transaction }) {
  const { t, formatLocale } = useI18n();
  const transfer = useTransfer(transaction.transfer_id);
  const accounts = useAccounts(true);
  const name = (id: string) =>
    accounts.data?.find((account) => account.id === id)?.name ??
    t('transactions.transfer.unknownAccount');

  let content;
  if (transfer.isPending) {
    content = <LoadingState label={t('transactions.transfer.loading')} />;
  } else if (transfer.isError) {
    content = (
      <ErrorState
        title={t('transactions.transfer.error')}
        error={transfer.error}
        onRetry={() => {
          void transfer.refetch();
        }}
      />
    );
  } else {
    const data = transfer.data;
    const isFeeLeg = data.fee_transaction_id === transaction.id;
    content = (
      <>
        {isFeeLeg ? (
          <p className="mb-4 text-sm text-fg-muted">{t('transactions.transfer.feeLeg')}</p>
        ) : null}
        <Facts>
          <Fact label={t('transactions.transfer.from')}>
            <TextLink to={accountPath(data.from_account_id)}>{name(data.from_account_id)}</TextLink>
            {' · '}
            <MoneyText money={data.from_amount} />
          </Fact>
          <Fact label={t('transactions.transfer.to')}>
            <TextLink to={accountPath(data.to_account_id)}>{name(data.to_account_id)}</TextLink>
            {' · '}
            <MoneyText money={data.to_amount} />
          </Fact>
          {data.fx_rate ? (
            <Fact label={t('transactions.transfer.rate')}>
              {t('transactions.transfer.rateValue', {
                from: data.from_amount.currency,
                rate: data.fx_rate,
                to: data.to_amount.currency,
              })}
            </Fact>
          ) : null}
          {data.fee ? (
            <Fact label={t('transactions.transfer.fee')}>
              <MoneyText money={data.fee} />
              {data.fee_transaction_id && data.fee_transaction_id !== transaction.id ? (
                <>
                  {' · '}
                  <TextLink to={transactionPath(data.fee_transaction_id)}>
                    {t('transactions.transfer.viewFee')}
                  </TextLink>
                </>
              ) : null}
            </Fact>
          ) : null}
          <Fact label={t('transactions.form.date')}>
            {formatLocalDate(data.local_date, formatLocale, 'long')}
          </Fact>
          {data.description ? (
            <Fact label={t('transactions.form.description')}>{data.description}</Fact>
          ) : null}
          {data.notes ? (
            <Fact label={t('transactions.form.notes')}>
              <span className="whitespace-pre-line">{data.notes}</span>
            </Fact>
          ) : null}
          <Fact label={t('transactions.detail.status')}>
            {data.status === 'voided' ? (
              <StatusBadge tone="neutral" icon="ban">
                {t('finance.txStatus.voided')}
              </StatusBadge>
            ) : (
              <StatusBadge tone="success" icon="check-circle">
                {t('finance.txStatus.posted')}
              </StatusBadge>
            )}
          </Fact>
          <Fact label={t('transactions.transfer.legs')}>
            <span className="flex flex-wrap gap-x-4 gap-y-1">
              {data.from_transaction_id !== transaction.id ? (
                <TextLink to={transactionPath(data.from_transaction_id)}>
                  {t('transactions.transfer.viewOut')}
                </TextLink>
              ) : null}
              {data.to_transaction_id !== transaction.id ? (
                <TextLink to={transactionPath(data.to_transaction_id)}>
                  {t('transactions.transfer.viewIn')}
                </TextLink>
              ) : null}
            </span>
          </Fact>
        </Facts>
        <p className="mt-4 text-sm text-fg-muted">{t('transactions.transfer.excluded')}</p>
      </>
    );
  }
  return <Card title={t('transactions.transfer.title')}>{content}</Card>;
}
