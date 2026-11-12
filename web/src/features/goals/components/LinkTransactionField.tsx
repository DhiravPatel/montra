import { useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { TransactionPickerDialog } from '@/shared/finance/components/TransactionPickerDialog';
import { financeKeys } from '@/shared/finance/keys';
import { transactionTitle } from '@/shared/finance/transactionDisplay';
import type { Transaction, TransactionType } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';

type Kind = 'contribution' | 'withdrawal';

/** Where the money for a contribution (or a withdrawal) usually shows up in the ledger. */
const SEARCH_TYPES: Readonly<Record<Kind, readonly TransactionType[]>> = {
  contribution: ['transfer', 'expense'],
  withdrawal: ['transfer', 'income'],
};

interface LinkTransactionFieldProps {
  kind: Kind;
  linked: Transaction | null;
  onLinkedChange: (transaction: Transaction | null) => void;
}

/**
 * Optional link to the ledger transaction that moved the money: the
 * contribution then counts as verified (each transaction counts once).
 */
export function LinkTransactionField({ kind, linked, onLinkedChange }: LinkTransactionFieldProps) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const headingId = useId();
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickerPending, setPickerPending] = useState(false);
  const [pickerError, setPickerError] = useState<string | null>(null);

  const choose = async (transactionId: string) => {
    setPickerError(null);
    setPickerPending(true);
    try {
      const transaction = await queryClient.query({
        queryKey: financeKeys.transaction(transactionId),
        queryFn: ({ signal }) =>
          apiData(
            api.GET('/transactions/{id}', { params: { path: { id: transactionId } }, signal }),
          ),
      });
      onLinkedChange(transaction);
      setPickerOpen(false);
    } catch (error) {
      setPickerError(describeError(error, t));
    } finally {
      setPickerPending(false);
    }
  };

  const openPicker = () => {
    setPickerError(null);
    setPickerOpen(true);
  };

  return (
    <section aria-labelledby={headingId} className="space-y-2">
      <h3 id={headingId} className="text-sm font-medium text-fg">
        {t('goals.contribute.link')}{' '}
        <span className="font-normal text-fg-muted">({t('common.optional')})</span>
      </h3>
      <p className="text-sm text-fg-muted">{t('goals.contribute.linkHelp')}</p>
      {linked ? (
        <div className="flex flex-wrap items-start gap-3 rounded-md border border-line p-3 text-sm">
          <Icon name="link" className="mt-0.5 size-4 text-fg-muted" />
          <div className="min-w-0 flex-1">
            <p className="font-medium text-fg">{transactionTitle(linked, t)}</p>
            <p className="text-fg-muted">
              {[formatLocalDate(linked.local_date, formatLocale), linked.account_name].join(' · ')}
            </p>
            <p className="text-fg-muted">{t('goals.contribute.linkedVerified')}</p>
          </div>
          <MoneyText money={linked.amount} className="font-medium" />
          <div className="flex w-full flex-wrap gap-2">
            <Button variant="secondary" size="sm" onClick={openPicker}>
              {t('goals.contribute.changeTransaction')}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                onLinkedChange(null);
              }}
            >
              {t('goals.contribute.removeTransaction')}
            </Button>
          </div>
        </div>
      ) : (
        <Button variant="secondary" size="sm" onClick={openPicker}>
          <Icon name="link" className="size-4" />
          {t('goals.contribute.chooseTransaction')}
        </Button>
      )}
      <TransactionPickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        title={t('goals.contribute.pickerTitle')}
        description={t('goals.contribute.pickerDescription')}
        search={{ types: SEARCH_TYPES[kind] }}
        confirmLabel={t('goals.contribute.pickerConfirm')}
        pending={pickerPending}
        error={pickerError}
        onConfirm={(transactionId) => {
          void choose(transactionId);
        }}
      />
    </section>
  );
}
