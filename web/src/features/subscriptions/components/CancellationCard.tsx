import { useMutation, useQueryClient } from '@tanstack/react-query';
import { hasErrorCode } from '@/shared/api/errors';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { ExternalLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { SubscriptionDetail } from '@/shared/finance/types';
import { useI18n } from '@/shared/i18n/I18nContext';
import { subscriptionsApi } from '../api';
import { subscriptionErrorMessage } from '../errors';

interface StepChange {
  index: number;
  done: boolean;
}

/**
 * How to cancel: the provider's page, the user's instructions and a
 * checklist they can tick off. Montra never cancels anything itself.
 */
export function CancellationCard({
  subscription,
  editable,
  onReload,
}: {
  subscription: SubscriptionDetail;
  editable: boolean;
  /** Reload the subscription (after a version conflict). */
  onReload: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  // One step at a time, with the version on screen (PATCH …/cancellation-checklist/{index}).
  const save = useMutation({
    mutationFn: ({ index, done }: StepChange) =>
      subscriptionsApi.updateChecklistItem(subscription.id, index, {
        done,
        version: subscription.version,
      }),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.subscription(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });
  const url = subscription.cancellation_url;
  const instructions = subscription.cancellation_instructions;
  const checklist = subscription.cancellation_checklist;
  const nothing = !url && !instructions && checklist.length === 0;

  const toggle = (index: number, done: boolean) => {
    if (save.isPending) return;
    save.mutate(
      { index, done },
      {
        onError: (error) => {
          // Changed elsewhere (or the step no longer exists): show the latest version.
          if (hasErrorCode(error, 'VERSION_CONFLICT') || hasErrorCode(error, 'NOT_FOUND')) {
            toast.show({
              tone: 'warning',
              title: t('finance.conflict.title'),
              description: t('subscriptions.cancellation.conflict'),
            });
            onReload();
            return;
          }
          toast.show({
            tone: 'danger',
            title: t('subscriptions.cancellation.saveFailed'),
            description: subscriptionErrorMessage(error, t, formatLocale),
          });
        },
      },
    );
  };

  return (
    <Card
      title={t('subscriptions.cancellation.title')}
      description={t('subscriptions.cancellation.description')}
    >
      {nothing ? (
        <p className="text-sm text-fg-muted">
          {editable
            ? t('subscriptions.cancellation.emptyEditable')
            : t('subscriptions.cancellation.empty')}
        </p>
      ) : (
        <div className="space-y-4">
          {url ? (
            <p className="text-sm">
              <ExternalLink href={url} newTab>
                {t('subscriptions.cancellation.openPage')}
              </ExternalLink>
            </p>
          ) : null}
          {instructions ? (
            <p className="text-sm whitespace-pre-line text-fg">{instructions}</p>
          ) : null}
          {checklist.length > 0 ? (
            <fieldset className="space-y-2" aria-busy={save.isPending || undefined}>
              <legend className="text-sm font-medium text-fg">
                {t('subscriptions.cancellation.checklist')}
              </legend>
              {checklist.map((entry, index) => (
                <Checkbox
                  // Items have no IDs; text plus position is stable enough here.
                  key={`${String(index)}-${entry.item}`}
                  label={entry.item}
                  checked={entry.done}
                  disabled={!editable || save.isPending}
                  onChange={(event) => {
                    toggle(index, event.target.checked);
                  }}
                />
              ))}
            </fieldset>
          ) : null}
        </div>
      )}
    </Card>
  );
}
