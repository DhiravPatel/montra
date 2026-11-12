import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/shared/components/Menu';
import { MoneyText } from '@/shared/components/MoneyText';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { TransactionPickerDialog } from '@/shared/finance/components/TransactionPickerDialog';
import { invalidateFinance } from '@/shared/finance/keys';
import type {
  Occurrence,
  OccurrenceAction,
  RecurringRuleDetail,
  TransactionType,
} from '@/shared/finance/types';
import { addDaysToLocalDate, formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { planningApi } from '../api';
import { planningErrorMessage } from '../errors';
import { isOpenOccurrence, occurrenceRowDate } from '../labels';
import { type OccurrenceDialogKind, OccurrenceDialog } from './OccurrenceDialogs';
import { MovedBadge, OccurrenceStatusBadge } from './StatusBadges';

type DialogState = { kind: OccurrenceDialogKind | 'link' | 'skip'; occurrence: Occurrence } | null;

const doneMessage: Readonly<Record<OccurrenceAction['action'], MessageKey>> = {
  confirm: 'recurring.occurrence.confirmed',
  postpone: 'recurring.occurrence.postponed',
  set_amount: 'recurring.occurrence.amountChanged',
  link_transaction: 'recurring.occurrence.linked',
  skip: 'recurring.occurrence.skipped',
  reopen: 'recurring.occurrence.reopened',
};

function linkTypes(kind: RecurringRuleDetail['kind']): TransactionType[] {
  if (kind === 'income') return ['income'];
  if (kind === 'transfer') return ['transfer'];
  return ['expense', 'group_expense'];
}

/**
 * Occurrences of a recurring item, newest first, with per-occurrence
 * actions. Every action sends an Idempotency-Key that is kept while the same
 * draft is retried and renewed after a success.
 */
export function RuleOccurrences({
  rule,
  editable,
}: {
  rule: RecurringRuleDetail;
  editable: boolean;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const idempotency = useIdempotencyKey();
  const [dialog, setDialog] = useState<DialogState>(null);
  const [dialogError, setDialogError] = useState<string | null>(null);
  const action = useMutation({
    mutationFn: ({ occurrence, body }: { occurrence: Occurrence; body: OccurrenceAction }) =>
      planningApi.occurrenceAction(occurrence.id, body, idempotency.key),
    onSettled: () => invalidateFinance(queryClient),
  });
  const currency = rule.currency ?? rule.amount?.currency ?? 'INR';
  const occurrences = rule.occurrences;

  const run = async (occurrence: Occurrence, body: OccurrenceAction) => {
    await action.mutateAsync({ occurrence, body });
    idempotency.renew();
    toast.show({ tone: 'success', title: t(doneMessage[body.action]) });
    setDialog(null);
  };

  const open = (kind: NonNullable<DialogState>['kind'], occurrence: Occurrence) => {
    setDialogError(null);
    setDialog({ kind, occurrence });
  };

  const runInline = (occurrence: Occurrence, body: OccurrenceAction) => {
    if (action.isPending) return;
    setDialogError(null);
    run(occurrence, body).catch((error: unknown) => {
      const message = planningErrorMessage(error, t, formatLocale);
      if (dialog) setDialogError(message);
      else
        toast.show({
          tone: 'danger',
          title: t('recurring.occurrence.failed'),
          description: message,
        });
    });
  };

  if (occurrences.length === 0) {
    return (
      <p className="text-sm text-fg-muted">
        {rule.next_occurrence
          ? t('recurring.occurrences.emptyNext', {
              date: formatLocalDate(rule.next_occurrence, formatLocale, 'long'),
            })
          : t('recurring.occurrences.empty')}
      </p>
    );
  }

  return (
    <>
      <ul className="divide-y divide-line">
        {occurrences.map((occurrence) => {
          const date = formatLocalDate(occurrenceRowDate(occurrence), formatLocale, 'long');
          const openNow = isOpenOccurrence(occurrence.status);
          const canReopen = occurrence.status === 'skipped';
          return (
            <li
              key={occurrence.id}
              className="flex flex-wrap items-center gap-x-4 gap-y-2 py-3 first:pt-0 last:pb-0"
            >
              <div className="min-w-0 flex-1 space-y-1">
                <p className="font-medium text-fg">{date}</p>
                <div className="flex flex-wrap items-center gap-2">
                  <OccurrenceStatusBadge status={occurrence.status} />
                  <MovedBadge occurrence={occurrence} />
                  {occurrence.transaction_id ? (
                    <TextLink to={transactionPath(occurrence.transaction_id)} className="text-sm">
                      {t('recurring.occurrence.viewTransaction')}
                    </TextLink>
                  ) : null}
                </div>
              </div>
              {occurrence.amount ? (
                <MoneyText money={occurrence.amount} className="font-medium text-fg" />
              ) : (
                <span className="text-sm text-fg-muted">{t('recurring.amountVaries')}</span>
              )}
              {editable && (openNow || canReopen) ? (
                <Menu modal={false}>
                  <MenuTrigger asChild>
                    <Button
                      variant="secondary"
                      size="sm"
                      aria-label={t('recurring.occurrence.actionsFor', { date })}
                    >
                      <Icon name="more-horizontal" className="size-4" />
                      {t('recurring.occurrence.actions')}
                    </Button>
                  </MenuTrigger>
                  <MenuContent>
                    {openNow ? (
                      <>
                        <MenuItem
                          icon="check"
                          onSelect={() => {
                            open('confirm', occurrence);
                          }}
                        >
                          {t('recurring.occurrence.confirm')}
                        </MenuItem>
                        <MenuItem
                          icon="link"
                          onSelect={() => {
                            open('link', occurrence);
                          }}
                        >
                          {t('recurring.occurrence.link')}
                        </MenuItem>
                        <MenuItem
                          icon="pencil"
                          onSelect={() => {
                            open('amount', occurrence);
                          }}
                        >
                          {t('recurring.occurrence.changeAmount')}
                        </MenuItem>
                        <MenuItem
                          icon="clock"
                          onSelect={() => {
                            open('postpone', occurrence);
                          }}
                        >
                          {t('recurring.occurrence.postpone')}
                        </MenuItem>
                        <MenuItem
                          icon="skip-forward"
                          onSelect={() => {
                            open('skip', occurrence);
                          }}
                        >
                          {t('recurring.occurrence.skip')}
                        </MenuItem>
                      </>
                    ) : (
                      <MenuItem
                        icon="undo"
                        onSelect={() => {
                          runInline(occurrence, { action: 'reopen' });
                        }}
                      >
                        {t('recurring.occurrence.reopen')}
                      </MenuItem>
                    )}
                  </MenuContent>
                </Menu>
              ) : null}
            </li>
          );
        })}
      </ul>

      {dialog &&
      (dialog.kind === 'confirm' || dialog.kind === 'postpone' || dialog.kind === 'amount') ? (
        <OccurrenceDialog
          kind={dialog.kind}
          occurrence={dialog.occurrence}
          currency={dialog.occurrence.amount?.currency ?? currency}
          needsAccount={!rule.account_id}
          pending={action.isPending}
          onClose={() => {
            setDialog(null);
          }}
          onSubmit={(body) => run(dialog.occurrence, body)}
        />
      ) : null}

      {dialog?.kind === 'link' ? (
        <TransactionPickerDialog
          open
          onOpenChange={(next) => {
            if (!next && !action.isPending) setDialog(null);
          }}
          title={t('recurring.occurrence.linkTitle')}
          description={t('recurring.occurrence.linkHelp', {
            date: formatLocalDate(dialog.occurrence.effective_date, formatLocale, 'long'),
          })}
          search={{
            types: linkTypes(rule.kind),
            from: addDaysToLocalDate(dialog.occurrence.effective_date, -45),
            to: addDaysToLocalDate(dialog.occurrence.effective_date, 45),
          }}
          confirmLabel={t('recurring.occurrence.linkConfirm')}
          pending={action.isPending}
          error={dialogError}
          onConfirm={(transactionId) => {
            runInline(dialog.occurrence, {
              action: 'link_transaction',
              transaction_id: transactionId,
            });
          }}
        />
      ) : null}

      <ConfirmDialog
        open={dialog?.kind === 'skip'}
        onOpenChange={(next) => {
          if (!next) setDialog(null);
        }}
        tone="primary"
        title={t('recurring.occurrence.skipTitle')}
        description={
          dialog
            ? t('recurring.occurrence.skipBody', {
                date: formatLocalDate(dialog.occurrence.effective_date, formatLocale, 'long'),
              })
            : ''
        }
        confirmLabel={t('recurring.occurrence.skipConfirm')}
        pending={action.isPending}
        error={dialogError}
        onConfirm={() => {
          if (dialog) runInline(dialog.occurrence, { action: 'skip' });
        }}
      />
    </>
  );
}
