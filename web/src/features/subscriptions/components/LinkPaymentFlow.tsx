import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { newIdempotencyKey } from '@/shared/api/idempotency';
import type { Money } from '@/shared/api/types';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { useToast } from '@/shared/components/toast/ToastContext';
import {
  type PickerSuggestion,
  TransactionPickerDialog,
} from '@/shared/finance/components/TransactionPickerDialog';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { SubscriptionDetail, SubscriptionPaymentInput } from '@/shared/finance/types';
import { compareDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { subscriptionsApi, useSubscriptionPaymentCandidates } from '../api';
import { subscriptionErrorMessage } from '../errors';
import { candidateReasonLabels, candidateTiming } from '../labels';

interface LinkPaymentFlowProps {
  subscription: SubscriptionDetail;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

interface PriceChoice {
  transactionId: string;
  charged: Pick<Money, 'amount' | 'currency'>;
}

function paymentError(error: unknown, t: Translate, locale: string): string {
  if (hasErrorCode(error, 'VALIDATION_ERROR')) return t('subscriptions.payments.invalid');
  return subscriptionErrorMessage(error, t, locale);
}

/**
 * Records a payment by linking an expense that is already in the ledger
 * (nothing new is recorded). When the charge differs from the tracked price
 * the user chooses whether the price changed; the old price stays in the
 * history either way.
 */
export function LinkPaymentFlow({ subscription, open, onOpenChange }: LinkPaymentFlowProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const formatMoney = useFormatMoney();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const [checking, setChecking] = useState(false);
  const [choice, setChoice] = useState<PriceChoice | null>(null);
  // One Idempotency-Key per attempted request body, kept while it is retried.
  const keys = useRef(new Map<string, string>());

  // Ranked by the API: unlinked expenses at the same merchant or name, close
  // to the price and to the expected renewal date.
  const candidates = useSubscriptionPaymentCandidates(subscription.id, open);
  const linked = subscription.payments.map((payment) => payment.transaction_id);
  const suggested: PickerSuggestion[] = (candidates.data ?? []).map((candidate) => {
    const note = candidateTiming(candidate, t, formatLocale);
    return {
      transactionId: candidate.transaction_id,
      localDate: candidate.local_date,
      amount: candidate.amount,
      accountName: candidate.account_name,
      title: candidate.merchant ?? candidate.description ?? t('subscriptions.payments.untitled'),
      reasons: candidateReasonLabels(candidate, t),
      ...(note ? { note } : {}),
    };
  });

  const record = useMutation({
    mutationFn: (body: SubscriptionPaymentInput) => {
      const id = `${body.transaction_id}:${body.update_price ? 'price' : 'keep'}`;
      let key = keys.current.get(id);
      if (!key) {
        key = newIdempotencyKey();
        keys.current.set(id, key);
      }
      return subscriptionsApi.recordPayment(subscription.id, body, key);
    },
    onSuccess: (updated) => {
      keys.current.clear();
      queryClient.setQueryData(financeKeys.subscription(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });

  const close = () => {
    setError(null);
    setChoice(null);
    onOpenChange(false);
  };

  const send = (transactionId: string, updatePrice: boolean) => {
    setError(null);
    record.mutate(
      { transaction_id: transactionId, update_price: updatePrice },
      {
        onSuccess: () => {
          toast.show({
            tone: 'success',
            title: updatePrice
              ? t('subscriptions.payments.linkedPriceUpdated')
              : t('subscriptions.payments.linked'),
          });
          close();
        },
        onError: (failure) => {
          setChoice(null);
          setError(paymentError(failure, t, formatLocale));
          if (hasErrorCode(failure, 'DUPLICATE')) {
            // Linked meanwhile: refresh the suggestions and the payment history.
            void queryClient.invalidateQueries({
              queryKey: financeKeys.subscription(subscription.id),
            });
          }
        },
      },
    );
  };

  const choose = async (transactionId: string) => {
    if (record.isPending || checking) return;
    setError(null);
    setChecking(true);
    try {
      // Compare the charge with the tracked price (exact decimals). Suggestions
      // carry their amount; a transaction found by searching is read first.
      const suggestion = candidates.data?.find((item) => item.transaction_id === transactionId);
      const charged = suggestion
        ? suggestion.amount
        : (await subscriptionsApi.transaction(transactionId)).amount;
      setChecking(false);
      if (charged.currency !== subscription.amount.currency) {
        setError(
          t('subscriptions.payments.currencyMismatch', {
            currency: subscription.amount.currency,
          }),
        );
        return;
      }
      if (compareDecimal(charged.amount, subscription.amount.amount) !== 0) {
        setChoice({ transactionId, charged });
        return;
      }
      send(transactionId, false);
    } catch (failure) {
      setChecking(false);
      setError(subscriptionErrorMessage(failure, t, formatLocale));
    }
  };

  return (
    <>
      <TransactionPickerDialog
        open={open && choice === null}
        onOpenChange={(next) => {
          if (!next) close();
        }}
        title={t('subscriptions.payments.pickTitle')}
        description={t('subscriptions.payments.pickBody', { name: subscription.name })}
        suggestions={suggested}
        suggestionsLoading={candidates.isLoading}
        suggestionsEmptyText={
          candidates.isError
            ? t('subscriptions.payments.candidatesFailed')
            : candidates.isSuccess
              ? t('subscriptions.payments.noCandidates')
              : undefined
        }
        search={{ types: ['expense', 'group_expense'] }}
        excludeIds={linked}
        confirmLabel={t('subscriptions.payments.pickConfirm')}
        onConfirm={(transactionId) => {
          void choose(transactionId);
        }}
        pending={record.isPending || checking}
        error={error}
      />
      <Dialog
        open={open && choice !== null}
        onOpenChange={(next) => {
          if (!next) setChoice(null);
        }}
        title={t('subscriptions.payments.priceTitle')}
        description={
          choice
            ? t('subscriptions.payments.priceBody', {
                charged: formatMoney(choice.charged),
                price: formatMoney(subscription.amount),
              })
            : undefined
        }
        busy={record.isPending}
        size="sm"
      >
        {choice ? (
          <div className="space-y-4">
            <p className="text-sm text-fg-muted">{t('subscriptions.payments.priceHistoryNote')}</p>
            <div className="flex flex-col gap-3">
              <Button
                loading={record.isPending && record.variables.update_price === true}
                disabled={record.isPending}
                onClick={() => {
                  send(choice.transactionId, true);
                }}
              >
                {t('subscriptions.payments.updatePrice', { amount: formatMoney(choice.charged) })}
              </Button>
              <Button
                variant="secondary"
                loading={record.isPending && record.variables.update_price === false}
                disabled={record.isPending}
                onClick={() => {
                  send(choice.transactionId, false);
                }}
              >
                {t('subscriptions.payments.keepPrice', {
                  amount: formatMoney(subscription.amount),
                })}
              </Button>
              <Button
                variant="ghost"
                disabled={record.isPending}
                onClick={() => {
                  setChoice(null);
                }}
              >
                {t('subscriptions.payments.chooseAnother')}
              </Button>
            </div>
          </div>
        ) : null}
      </Dialog>
    </>
  );
}
