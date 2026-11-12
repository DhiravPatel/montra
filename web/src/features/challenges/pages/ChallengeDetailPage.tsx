import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import {
  formatDate,
  formatLocalDateRange,
  parseTimestamp,
  todayInTimeZone,
} from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { challengesApi } from '../api';
import { AboutCard } from '../components/AboutCard';
import { BackToChallenges } from '../components/BackLink';
import { ChallengeBadges } from '../components/ChallengeBadges';
import { CheckInCard } from '../components/CheckInCard';
import { EditChallengeDialog } from '../components/EditChallengeDialog';
import { JoinDialog } from '../components/JoinDialog';
import { LeaderboardCard } from '../components/LeaderboardCard';
import { ProgressCard } from '../components/ProgressCard';
import { SharingCard } from '../components/SharingCard';
import { challengeErrorMessage } from '../errors';
import { challengeChanged, challengeStale, useChallenge } from '../hooks';
import { challengeTypeLabel } from '../labels';
import type { Challenge } from '../types';

function DetailSkeleton() {
  return (
    <div className="space-y-6" aria-hidden="true">
      <Skeleton className="h-9 w-1/2" />
      <Skeleton className="h-40 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>
  );
}

function StateAlerts({ challenge }: { challenge: Challenge }) {
  const { t, formatLocale } = useI18n();
  const { timezone } = useCurrentUser();
  const me = challenge.me;
  const completed = parseTimestamp(me?.completed_at);
  if (challenge.status === 'cancelled') {
    return (
      <Alert tone="info" className="mb-6" title={t('challenges.detail.cancelledTitle')}>
        {t('challenges.detail.cancelledBody')}
      </Alert>
    );
  }
  return (
    <>
      {me?.status === 'completed' ? (
        <Alert tone="success" className="mb-6" title={t('challenges.detail.completedTitle')}>
          {completed
            ? t('challenges.detail.completedOn', {
                date: formatDate(completed, formatLocale, timezone),
              })
            : t('challenges.detail.completedBody')}
        </Alert>
      ) : null}
      {challenge.status === 'active' && challenge.ended ? (
        <Alert tone="info" className="mb-6" title={t('challenges.detail.endedTitle')}>
          {me && me.status !== 'left'
            ? t('challenges.detail.endedBody')
            : t('challenges.detail.endedClosed')}
        </Alert>
      ) : null}
    </>
  );
}

/** Join, rejoin or leave. Joining is optional and private by default. */
function TakePartCard({ challenge }: { challenge: Challenge }) {
  const { t, formatLocale } = useI18n();
  const { timezone } = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [joinOpen, setJoinOpen] = useState(false);
  const [leaveOpen, setLeaveOpen] = useState(false);
  const [leaveError, setLeaveError] = useState<string | null>(null);
  const leave = useMutation({ mutationFn: () => challengesApi.leave(challenge.id) });
  const me = challenge.me;
  const taking = me !== undefined && me.status !== 'left';
  const open = challenge.status === 'active' && !challenge.ended;
  const joined = parseTimestamp(me?.joined_at);

  const confirmLeave = () => {
    if (leave.isPending) return;
    setLeaveError(null);
    leave.mutate(undefined, {
      onSuccess: () => {
        void challengeStale(queryClient, challenge.id);
        toast.show({ tone: 'success', title: t('challenges.leave.done') });
        setLeaveOpen(false);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          // Already left elsewhere: show the latest state.
          void challengeStale(queryClient, challenge.id);
          setLeaveOpen(false);
          return;
        }
        setLeaveError(challengeErrorMessage(error, t));
      },
    });
  };

  let content;
  if (taking) {
    content = (
      <div className="space-y-4">
        <p className="text-sm text-fg">
          {joined
            ? t('challenges.takePart.joinedOn', {
                date: formatDate(joined, formatLocale, timezone),
              })
            : t('challenges.takePart.joined')}
        </p>
        <Button
          variant="secondary"
          onClick={() => {
            setLeaveError(null);
            setLeaveOpen(true);
          }}
        >
          <Icon name="log-out" className="size-4" />
          {t('challenges.leave.action')}
        </Button>
      </div>
    );
  } else if (open) {
    content = (
      <div className="space-y-4">
        <p className="text-sm text-fg-muted">
          {me?.status === 'left'
            ? t('challenges.takePart.left')
            : t('challenges.takePart.optional')}
        </p>
        <Button
          onClick={() => {
            setJoinOpen(true);
          }}
        >
          <Icon name="user-plus" className="size-4" />
          {me?.status === 'left' ? t('challenges.join.rejoinAction') : t('challenges.join.action')}
        </Button>
      </div>
    );
  } else {
    content = (
      <p className="text-sm text-fg-muted">
        {me?.status === 'left' ? t('challenges.takePart.left') : t('challenges.takePart.closed')}
      </p>
    );
  }

  return (
    <Card title={t('challenges.takePart.title')}>
      {content}
      <JoinDialog challenge={challenge} open={joinOpen} onOpenChange={setJoinOpen} />
      <ConfirmDialog
        open={leaveOpen}
        onOpenChange={(next) => {
          if (!next) setLeaveOpen(false);
        }}
        title={t('challenges.leave.title')}
        description={
          challenge.leaderboard_enabled
            ? `${t('challenges.leave.body')} ${t('challenges.leave.leaderboard')}`
            : t('challenges.leave.body')
        }
        confirmLabel={t('challenges.leave.confirm')}
        cancelLabel={t('challenges.leave.stay')}
        tone="primary"
        onConfirm={confirmLeave}
        pending={leave.isPending}
        error={leaveError}
      />
    </Card>
  );
}

/** Edit and cancel, for the person who created the challenge. */
function ManageCard({ challenge }: { challenge: Challenge }) {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [editOpen, setEditOpen] = useState(false);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const cancel = useMutation({ mutationFn: () => challengesApi.cancel(challenge.id) });
  const active = challenge.status === 'active';
  const cancellable = active || challenge.status === 'draft';
  if (!cancellable) return null;

  const confirmCancel = () => {
    if (cancel.isPending) return;
    setCancelError(null);
    cancel.mutate(undefined, {
      onSuccess: (updated) => {
        void challengeChanged(queryClient, updated);
        toast.show({ tone: 'success', title: t('challenges.cancel.done') });
        setCancelOpen(false);
      },
      onError: (error) => {
        setCancelError(challengeErrorMessage(error, t));
      },
    });
  };

  return (
    <Card title={t('challenges.manage.title')} description={t('challenges.manage.description')}>
      <div className="flex flex-col gap-3">
        {active ? (
          <Button
            variant="secondary"
            onClick={() => {
              setEditOpen(true);
            }}
          >
            <Icon name="pencil" className="size-4" />
            {t('challenges.edit.action')}
          </Button>
        ) : null}
        <Button
          variant="secondary"
          onClick={() => {
            setCancelError(null);
            setCancelOpen(true);
          }}
        >
          <Icon name="x-circle" className="size-4" />
          {t('challenges.cancel.action')}
        </Button>
      </div>
      <EditChallengeDialog challenge={challenge} open={editOpen} onOpenChange={setEditOpen} />
      <ConfirmDialog
        open={cancelOpen}
        onOpenChange={(next) => {
          if (!next) setCancelOpen(false);
        }}
        title={t('challenges.cancel.title')}
        description={t('challenges.cancel.body')}
        confirmLabel={t('challenges.cancel.confirm')}
        cancelLabel={t('challenges.cancel.keep')}
        onConfirm={confirmCancel}
        pending={cancel.isPending}
        error={cancelError}
      />
    </Card>
  );
}

/** A note where the leaderboard would be, while you are not on it. */
function LeaderboardNote({ challenge }: { challenge: Challenge }) {
  const { t } = useI18n();
  const taking = challenge.me !== undefined && challenge.me.status !== 'left';
  return (
    <Card title={t('challenges.leaderboard.title')}>
      <p className="text-sm text-fg-muted">
        {taking ? t('challenges.leaderboard.optIn') : t('challenges.leaderboard.joinFirst')}
      </p>
    </Card>
  );
}

/** One challenge: your progress and check-ins, milestones, sharing and the opt-in leaderboard. */
export function ChallengeDetailPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('challenges.detail.documentTitle'));
  const { challengeId = '' } = useParams();
  const user = useCurrentUser();
  const today = todayInTimeZone(user.timezone);
  const query = useChallenge(challengeId);

  if (query.isPending) {
    return (
      <LoadingState label={t('challenges.detail.loading')}>
        <DetailSkeleton />
      </LoadingState>
    );
  }
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="flag"
          title={t('challenges.detail.notFound')}
          description={t('challenges.detail.notFoundBody')}
          action={<ButtonLink to={paths.challenges}>{t('challenges.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('challenges.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const challenge = query.data;
  const me = challenge.me && challenge.me.status !== 'left' ? challenge.me : null;
  const canCheckIn = me !== null && challenge.status !== 'cancelled';
  const shared = challenge.visibility !== 'private';
  const onLeaderboard =
    me !== null && challenge.leaderboard_enabled && me.share_progress && me.show_on_leaderboard;
  // Explain the opt-in only where someone can still act on it.
  const explainLeaderboard =
    challenge.leaderboard_enabled &&
    !onLeaderboard &&
    challenge.status === 'active' &&
    (me !== null || !challenge.ended);
  const details = [
    t(challengeTypeLabel(challenge.challenge_type)),
    formatLocalDateRange(challenge.starts_on, challenge.ends_on, formatLocale),
  ];

  return (
    <>
      <BackToChallenges />
      <PageHeader title={challenge.title} description={details.join(' · ')} />
      <div className="mb-6">
        <ChallengeBadges challenge={challenge} today={today} />
      </div>
      <StateAlerts challenge={challenge} />
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          {me ? <ProgressCard challenge={challenge} me={me} /> : null}
          {canCheckIn ? <CheckInCard challenge={challenge} me={me} today={today} /> : null}
          {onLeaderboard ? <LeaderboardCard challenge={challenge} /> : null}
          {explainLeaderboard ? <LeaderboardNote challenge={challenge} /> : null}
          <AboutCard challenge={challenge} />
        </div>
        <div className="space-y-6">
          <TakePartCard challenge={challenge} />
          {me && shared && challenge.status !== 'cancelled' ? (
            <SharingCard challenge={challenge} me={me} />
          ) : null}
          {me && !shared ? (
            <Card title={t('challenges.sharing.title')}>
              <p className="text-sm text-fg-muted">{t('challenges.sharing.privateChallenge')}</p>
            </Card>
          ) : null}
          {challenge.mine ? <ManageCard challenge={challenge} /> : null}
        </div>
      </div>
    </>
  );
}
