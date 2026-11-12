import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import type { Session } from '@/shared/api/types';
import { useAuth } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useNow } from '@/shared/hooks/useNow';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { securityApi, sessionsQueryKey, sortSessions } from '../api';
import { SessionItem } from './SessionItem';

function SessionsSkeleton() {
  return (
    <ul className="space-y-4" aria-hidden="true">
      {[0, 1, 2].map((key) => (
        <li key={key} className="flex gap-3">
          <Skeleton className="size-10" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-1/2" />
            <Skeleton className="h-3 w-3/4" />
          </div>
        </li>
      ))}
    </ul>
  );
}

/** Signed-in devices with per-device sign-out (spec §4.1 session list and revocation). */
export function SessionsCard() {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const { signOut } = useAuth();
  const now = useNow();
  const [target, setTarget] = useState<Session | null>(null);
  const [revokeError, setRevokeError] = useState<string | null>(null);
  const [signingOutCurrent, setSigningOutCurrent] = useState(false);

  const query = useQuery({
    queryKey: sessionsQueryKey,
    queryFn: ({ signal }) => securityApi.listSessions(signal),
    select: sortSessions,
  });

  const revoke = useMutation({
    mutationFn: (session: Session) => securityApi.revokeSession(session.id),
    onSettled: () => queryClient.invalidateQueries({ queryKey: sessionsQueryKey }),
  });

  const handleSignOut = (session: Session) => {
    if (!session.current) {
      setRevokeError(null);
      setTarget(session);
      return;
    }
    if (signingOutCurrent) return;
    setSigningOutCurrent(true);
    signOut('current')
      .catch((error: unknown) => {
        toast.show({
          tone: 'danger',
          title: t('auth.signOut.failed'),
          description: describeError(error, t),
        });
      })
      .finally(() => {
        setSigningOutCurrent(false);
      });
  };

  const confirmRevoke = () => {
    if (!target || revoke.isPending) return;
    const device = target.device_name ?? t('settings.sessions.unknownDevice');
    setRevokeError(null);
    revoke.mutate(target, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('settings.sessions.revoked', { device }) });
        setTarget(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('settings.sessions.alreadyEnded') });
          setTarget(null);
        } else {
          setRevokeError(describeError(error, t));
        }
      },
    });
  };

  let content;
  if (query.isPending) {
    content = (
      <LoadingState label={t('settings.sessions.loading')}>
        <SessionsSkeleton />
      </LoadingState>
    );
  } else if (query.isError) {
    content = hasErrorCode(query.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('settings.sessions.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  } else if (query.data.length === 0) {
    content = (
      <EmptyState
        icon="monitor"
        title={t('settings.sessions.empty.title')}
        description={t('settings.sessions.empty.body')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {query.data.map((session) => (
          <SessionItem
            key={session.id}
            session={session}
            now={now}
            onSignOut={handleSignOut}
            signingOut={session.current && signingOutCurrent}
          />
        ))}
      </ul>
    );
  }

  return (
    <Card
      title={t('settings.sessions.title')}
      description={t('settings.sessions.description')}
      actions={
        query.isSuccess ? (
          <Button
            variant="ghost"
            size="sm"
            loading={query.isFetching}
            onClick={() => {
              void query.refetch();
            }}
          >
            <Icon name="refresh" className="size-4" />
            {t('settings.sessions.refresh')}
          </Button>
        ) : null
      }
    >
      {content}
      <ConfirmDialog
        open={target !== null}
        onOpenChange={(open) => {
          if (!open) setTarget(null);
        }}
        title={t('settings.sessions.confirm.title')}
        description={t('settings.sessions.confirm.body', {
          device: target?.device_name ?? t('settings.sessions.unknownDevice'),
        })}
        confirmLabel={t('settings.sessions.signOutDevice')}
        onConfirm={confirmRevoke}
        pending={revoke.isPending}
        error={revokeError}
      />
    </Card>
  );
}
