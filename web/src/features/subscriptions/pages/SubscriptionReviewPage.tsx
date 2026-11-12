import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, subscriptionPath, withQuery } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { DetectionCandidate } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type DetectionStatus, subscriptionsApi, useDetections } from '../api';
import { ConfirmDetectionDialog } from '../components/ConfirmDetectionDialog';
import { SubscriptionsSubNav } from '../components/SubscriptionsSubNav';
import {
  DETECTION_STATUSES,
  cadenceLabel,
  detectionReasons,
  detectionStatusLabel,
  formatConfidence,
  isDetectionStatus,
} from '../labels';

/**
 * Possible subscriptions found in the user's transactions by a rule-based
 * check (regular dates and similar amounts). Nothing is added until the
 * user confirms one; dismissed ones are not suggested again.
 */
export function SubscriptionReviewPage() {
  const { t } = useI18n();
  useDocumentTitle(t('subscriptions.review.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [params, setParams] = useSearchParams();
  const raw = params.get('status') ?? '';
  const status: DetectionStatus = isDetectionStatus(raw) ? raw : 'pending';
  const list = useDetections(status);
  const [confirming, setConfirming] = useState<DetectionCandidate | null>(null);
  const [dismissing, setDismissing] = useState<DetectionCandidate | null>(null);
  const [dismissError, setDismissError] = useState<string | null>(null);

  const refresh = useMutation({ mutationFn: () => subscriptionsApi.refreshDetections() });
  const dismiss = useMutation({
    mutationFn: (candidate: DetectionCandidate) => subscriptionsApi.dismissDetection(candidate.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const setStatus = (next: DetectionStatus) => {
    setParams(
      (current) => {
        const updated = new URLSearchParams(current);
        if (next === 'pending') updated.delete('status');
        else updated.set('status', next);
        return updated;
      },
      { replace: true },
    );
  };

  const lookAgain = () => {
    if (refresh.isPending) return;
    refresh.mutate(undefined, {
      onSuccess: () => {
        toast.show({
          tone: 'info',
          title: t('subscriptions.review.refreshStarted'),
          description: t('subscriptions.review.refreshBody'),
        });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('subscriptions.review.refreshFailed'),
          description: describeError(error, t),
        });
      },
    });
  };

  const confirmDismiss = () => {
    if (!dismissing || dismiss.isPending) return;
    setDismissError(null);
    dismiss.mutate(dismissing, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('subscriptions.review.dismissed') });
        setDismissing(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'CONFLICT') || hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('subscriptions.review.alreadyHandled') });
          setDismissing(null);
        } else {
          setDismissError(describeError(error, t));
        }
      },
    });
  };

  let content;
  if (list.isPending) {
    content = <LoadingState label={t('subscriptions.review.loading')} />;
  } else if (list.isError) {
    content = hasErrorCode(list.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('subscriptions.review.error')}
        error={list.error}
        retrying={list.isFetching}
        onRetry={() => {
          void list.refetch();
        }}
      />
    );
  } else if (list.data.length === 0) {
    content =
      status === 'pending' ? (
        <EmptyState
          icon="search"
          title={t('subscriptions.review.emptyTitle')}
          description={t('subscriptions.review.emptyBody')}
          action={
            <Button variant="secondary" loading={refresh.isPending} onClick={lookAgain}>
              <Icon name="refresh" className="size-4" />
              {t('subscriptions.review.refresh')}
            </Button>
          }
        />
      ) : (
        <EmptyState
          icon="inbox"
          title={
            status === 'confirmed'
              ? t('subscriptions.review.emptyConfirmed')
              : t('subscriptions.review.emptyDismissed')
          }
        />
      );
  } else {
    content = (
      <ul className="space-y-4">
        {list.data.map((candidate) => (
          <DetectionItem
            key={candidate.id}
            candidate={candidate}
            onConfirm={() => {
              setConfirming(candidate);
            }}
            onDismiss={() => {
              setDismissError(null);
              setDismissing(candidate);
            }}
          />
        ))}
      </ul>
    );
  }

  return (
    <>
      <PageHeader
        title={t('subscriptions.review.title')}
        description={t('subscriptions.review.description')}
        actions={
          <Button variant="secondary" loading={refresh.isPending} onClick={lookAgain}>
            <Icon name="refresh" className="size-4" />
            {t('subscriptions.review.refresh')}
          </Button>
        }
      />
      <SubscriptionsSubNav />
      <Disclosure summary={t('subscriptions.review.howTitle')} className="mb-6">
        <div className="space-y-2 text-sm text-fg-muted">
          <p>{t('subscriptions.review.how1')}</p>
          <p>{t('subscriptions.review.how2')}</p>
        </div>
      </Disclosure>
      <Card
        title={t(detectionStatusLabel[status])}
        actions={
          <RadioGroup
            legend={t('subscriptions.review.filter')}
            hideLegend
            value={status}
            onChange={setStatus}
            options={DETECTION_STATUSES.map((value) => ({
              value,
              label: t(detectionStatusLabel[value]),
            }))}
          />
        }
      >
        {content}
      </Card>
      <ConfirmDetectionDialog
        candidate={confirming}
        onOpenChange={(open) => {
          if (!open) setConfirming(null);
        }}
        onConfirmed={(subscription) => {
          setConfirming(null);
          toast.show({ tone: 'success', title: t('subscriptions.review.confirmed') });
          void navigate(subscriptionPath(subscription.id));
        }}
        onStale={() => {
          void queryClient.invalidateQueries({ queryKey: financeKeys.detections(status) });
        }}
      />
      <ConfirmDialog
        open={dismissing !== null}
        onOpenChange={(open) => {
          if (!open) setDismissing(null);
        }}
        title={t('subscriptions.review.dismissTitle')}
        description={t('subscriptions.review.dismissBody', {
          name: dismissing?.merchant_label ?? '',
        })}
        confirmLabel={t('subscriptions.review.dismiss')}
        onConfirm={confirmDismiss}
        pending={dismiss.isPending}
        error={dismissError}
      />
    </>
  );
}

function DetectionItem({
  candidate,
  onConfirm,
  onDismiss,
}: {
  candidate: DetectionCandidate;
  onConfirm: () => void;
  onDismiss: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const evidence = candidate.evidence;
  const long = (value: string) => formatLocalDate(value, formatLocale, 'long');
  // Localized from reason_codes (the English `reasons` are not shown).
  const reasons = detectionReasons(evidence, t, formatLocale);
  return (
    <li className="rounded-lg border border-line p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <h3 className="font-semibold text-fg">{candidate.merchant_label}</h3>
          <p className="text-sm text-fg-muted">
            {t(cadenceLabel[candidate.cadence])} · {t('subscriptions.review.typical')}{' '}
            <MoneyText money={candidate.amount} className="font-medium text-fg" />{' '}
            {t('subscriptions.review.tolerance')} <MoneyText money={candidate.amount_tolerance} />
          </p>
        </div>
        <StatusBadge tone="info" icon="bar-chart">
          {t('subscriptions.review.confidence', {
            percent: formatConfidence(candidate.confidence_bp, formatLocale),
          })}
        </StatusBadge>
      </div>
      <ul className="mt-3 space-y-1 text-sm text-fg">
        {reasons.length > 0 ? (
          reasons.map((reason) => <li key={reason}>{reason}</li>)
        ) : (
          <li>{t('subscriptions.review.evidence.charges', { count: evidence.charge_count })}</li>
        )}
        <li>
          {t('subscriptions.review.evidence.last', { date: long(evidence.last_charge_date) })}
        </li>
        {candidate.next_expected_date ? (
          <li>
            {t('subscriptions.review.evidence.next', {
              date: long(candidate.next_expected_date),
            })}
          </li>
        ) : null}
      </ul>
      <div className="mt-4 flex flex-wrap items-center gap-3">
        {candidate.status === 'pending' ? (
          <>
            <Button
              size="sm"
              aria-label={`${t('subscriptions.review.confirm')}: ${candidate.merchant_label}`}
              onClick={onConfirm}
            >
              <Icon name="check" className="size-4" />
              {t('subscriptions.review.confirm')}
            </Button>
            <Button
              size="sm"
              variant="secondary"
              aria-label={`${t('subscriptions.review.dismiss')}: ${candidate.merchant_label}`}
              onClick={onDismiss}
            >
              <Icon name="x" className="size-4" />
              {t('subscriptions.review.dismiss')}
            </Button>
          </>
        ) : (
          <StatusBadge
            tone={candidate.status === 'confirmed' ? 'success' : 'neutral'}
            icon={candidate.status === 'confirmed' ? 'check-circle' : 'x-circle'}
          >
            {candidate.status === 'confirmed'
              ? t('subscriptions.review.statusConfirmed')
              : t('subscriptions.review.statusDismissed')}
          </StatusBadge>
        )}
        {candidate.merchant_id ? (
          <TextLink to={withQuery(paths.transactions, { merchant_id: candidate.merchant_id })}>
            {t('subscriptions.review.seeCharges')}
          </TextLink>
        ) : null}
      </div>
    </li>
  );
}
