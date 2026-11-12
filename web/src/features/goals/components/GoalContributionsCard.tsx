import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { LoadMoreButton } from '@/shared/finance/components/LoadMoreButton';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { Goal, GoalContribution } from '@/shared/finance/types';
import { formatBasisPoints, formatLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { canContribute, canRecordPlanned } from '../access';
import { goalsApi, useGoalContributions } from '../api';
import { fallbackExportName, saveCsvFile } from '../download';
import { contributionErrorMessage } from '../errors';
import {
  contributionKindIcon,
  contributionKindLabel,
  contributionStatusIcon,
  contributionStatusLabel,
  contributionStatusTone,
} from '../labels';
import { RecordContributionDialog } from './RecordContributionDialog';

function ContributionAmount({ contribution }: { contribution: GoalContribution }) {
  const { t, formatLocale } = useI18n();
  if (contribution.amount) {
    return (
      <MoneyText
        money={contribution.amount}
        className={cx('font-medium', contribution.voided && 'line-through')}
      />
    );
  }
  if (contribution.percent_bp !== undefined) {
    return (
      <span className="font-medium">
        {t('goals.card.percent', {
          percent: formatBasisPoints(contribution.percent_bp, formatLocale),
        })}
      </span>
    );
  }
  return <span className="text-sm text-fg-muted">{t('goals.contributions.hidden')}</span>;
}

export function GoalContributionsCard({
  goal,
  onAdd,
}: {
  goal: Goal;
  /** Opens the contribution dialog (owned by the page so the header can open it too). */
  onAdd: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const query = useGoalContributions(goal.id);
  const [voiding, setVoiding] = useState<GoalContribution | null>(null);
  const [voidError, setVoidError] = useState<string | null>(null);
  const [recording, setRecording] = useState<GoalContribution | null>(null);
  const allowed = canContribute(goal);

  const voidMutation = useMutation({
    mutationFn: (contribution: GoalContribution) =>
      goalsApi.voidContribution(goal.id, contribution.id),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.goal(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });
  const exportMutation = useMutation({
    mutationFn: () => goalsApi.exportCsv(goal.id),
  });

  const confirmVoid = () => {
    if (!voiding || voidMutation.isPending) return;
    setVoidError(null);
    voidMutation.mutate(voiding, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('goals.contributions.void.done') });
        setVoiding(null);
      },
      onError: (error) => {
        setVoidError(contributionErrorMessage(error, t, formatLocale));
      },
    });
  };

  const download = () => {
    if (exportMutation.isPending) return;
    exportMutation.mutate(undefined, {
      onSuccess: ({ csv, fileName }) => {
        // The server's neutral name (with your local date); never the goal's name.
        saveCsvFile(fileName ?? fallbackExportName(todayInTimeZone(user.timezone)), csv);
        toast.show({ tone: 'success', title: t('goals.contributions.exportDone') });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('goals.contributions.exportFailed'),
          description: describeError(error, t),
        });
      },
    });
  };

  // A failed "Load more" keeps the loaded pages on screen (with a retry below them).
  const contributions = query.data?.pages.flatMap((page) => page.items) ?? [];
  let content;
  if (query.isPending) {
    content = <LoadingState label={t('goals.contributions.loading')} />;
  } else if (query.isError && !query.isFetchNextPageError) {
    content = hasErrorCode(query.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('goals.contributions.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  } else if (contributions.length === 0) {
    content = (
      <EmptyState
        titleAs="p"
        icon="target"
        title={t('goals.contributions.empty')}
        description={t('goals.contributions.emptyBody')}
        action={
          allowed ? (
            <Button onClick={onAdd}>
              <Icon name="plus" className="size-4" />
              {t('goals.contributions.add')}
            </Button>
          ) : undefined
        }
      />
    );
  } else {
    content = (
      <>
        <ul className="divide-y divide-line">
          {contributions.map((contribution) => {
            const date = formatLocalDate(contribution.contributed_on, formatLocale);
            const who = contribution.mine
              ? t('goals.contributions.you')
              : (contribution.display_name ?? t('goals.members.hiddenName'));
            return (
              <li
                key={contribution.id}
                className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start"
              >
                <span
                  className={cx(
                    'inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted',
                    contribution.voided && 'opacity-60',
                  )}
                >
                  <Icon name={contributionKindIcon[contribution.kind]} className="size-4" />
                </span>
                <div className="min-w-0 flex-1 space-y-1">
                  <p className={cx('font-medium text-fg', contribution.voided && 'line-through')}>
                    {t(contributionKindLabel[contribution.kind])}
                    <span className="font-normal text-fg-muted"> · {who}</span>
                  </p>
                  <p className="text-sm text-fg-muted">{date}</p>
                  {contribution.note ? (
                    <p className="text-sm break-words text-fg">{contribution.note}</p>
                  ) : null}
                  <div className="flex flex-wrap items-center gap-2">
                    {contribution.voided ? (
                      <StatusBadge tone="neutral" icon="ban">
                        {t('goals.contributions.voided')}
                      </StatusBadge>
                    ) : (
                      <StatusBadge
                        tone={contributionStatusTone[contribution.status]}
                        icon={contributionStatusIcon[contribution.status]}
                      >
                        {t(contributionStatusLabel[contribution.status])}
                      </StatusBadge>
                    )}
                    {contribution.mine && contribution.transaction_id ? (
                      <TextLink
                        to={transactionPath(contribution.transaction_id)}
                        className="text-sm"
                      >
                        {t('goals.contributions.viewTransaction')}
                      </TextLink>
                    ) : null}
                  </div>
                </div>
                <div className="flex shrink-0 flex-wrap items-center gap-3 sm:flex-col sm:items-end">
                  <ContributionAmount contribution={contribution} />
                  {canRecordPlanned(goal, contribution) ? (
                    <Button
                      variant="secondary"
                      size="sm"
                      aria-label={t('goals.record.label', { date })}
                      onClick={() => {
                        setRecording(contribution);
                      }}
                    >
                      <Icon name="check" className="size-4" />
                      {t('goals.record.action')}
                    </Button>
                  ) : null}
                  {contribution.mine && !contribution.voided && goal.access !== 'viewer' ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={t('goals.contributions.void.label', { date })}
                      onClick={() => {
                        setVoidError(null);
                        setVoiding(contribution);
                      }}
                    >
                      <Icon name="ban" className="size-4" />
                      {t('goals.contributions.void.action')}
                    </Button>
                  ) : null}
                </div>
              </li>
            );
          })}
        </ul>
        <LoadMoreButton
          hasMore={query.hasNextPage}
          loading={query.isFetchingNextPage}
          failed={query.isFetchNextPageError}
          onLoadMore={() => {
            void query.fetchNextPage();
          }}
        />
      </>
    );
  }

  return (
    <>
      <Card
        title={t('goals.contributions.title')}
        actions={
          <>
            {allowed ? (
              <Button size="sm" onClick={onAdd}>
                <Icon name="plus" className="size-4" />
                {t('goals.contributions.add')}
              </Button>
            ) : null}
            <Button
              variant="secondary"
              size="sm"
              loading={exportMutation.isPending}
              onClick={download}
            >
              <Icon name="download" className="size-4" />
              {t('goals.contributions.export')}
            </Button>
          </>
        }
      >
        {content}
      </Card>
      <RecordContributionDialog
        goal={goal}
        contribution={recording}
        onClose={() => {
          setRecording(null);
        }}
      />
      <ConfirmDialog
        open={voiding !== null}
        onOpenChange={(open) => {
          if (!open) setVoiding(null);
        }}
        title={t('goals.contributions.void.title')}
        description={t('goals.contributions.void.body')}
        confirmLabel={t('goals.contributions.void.confirm')}
        onConfirm={confirmVoid}
        pending={voidMutation.isPending}
        error={voidError}
      />
    </>
  );
}
