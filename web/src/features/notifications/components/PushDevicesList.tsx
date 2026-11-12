import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { notificationsApi, usePushEndpoints } from '../api';
import { notificationsKeys } from '../keys';
import type { PushEndpoint } from '../types';

/** The name shown for a registration (its label, else a generic one by kind). */
function endpointName(endpoint: PushEndpoint, t: Translate): string {
  const label = endpoint.device_label?.trim();
  if (label) return label;
  return endpoint.kind === 'fcm'
    ? t('notifications.devices.kind.fcm')
    : t('notifications.devices.kind.webpush');
}

/**
 * The browsers and devices registered for push notifications
 * (GET /me/push-endpoints: never their endpoint URLs or keys). This
 * browser's registration is managed by the card's own switch; any other
 * one can be removed here. A registration the push service stopped
 * delivering to says so; registering again from that browser resumes it.
 */
export function PushDevicesList() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const endpoints = usePushEndpoints();
  const [removing, setRemoving] = useState<PushEndpoint | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const remove = useMutation({
    mutationFn: async (endpoint: PushEndpoint) => {
      try {
        await notificationsApi.removePush(endpoint.id);
      } catch (error) {
        // Already gone (removed elsewhere or its session ended): nothing left to do.
        if (!hasErrorCode(error, 'NOT_FOUND')) throw error;
      }
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: notificationsKeys.pushEndpoints() }),
  });

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setRemoveError(null);
    remove.mutate(removing, {
      onSuccess: () => {
        setRemoving(null);
        toast.show({ tone: 'success', title: t('notifications.devices.removed') });
      },
      onError: (error) => {
        setRemoveError(describeError(error, t));
      },
    });
  };

  let content;
  if (endpoints.isPending) {
    content = <LoadingState label={t('notifications.devices.loading')} />;
  } else if (endpoints.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('notifications.devices.error')}
        error={endpoints.error}
        retrying={endpoints.isFetching}
        onRetry={() => {
          void endpoints.refetch();
        }}
      />
    );
  } else if (endpoints.data.length === 0) {
    content = (
      <p className="flex items-center gap-2 text-sm text-fg-muted">
        <Icon name="monitor" className="size-4" />
        {t('notifications.devices.empty')}
      </p>
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {endpoints.data.map((endpoint) => {
          const name = endpointName(endpoint, t);
          const added = parseTimestamp(endpoint.created_at);
          const lastUsed = parseTimestamp(endpoint.last_used_at);
          const stopped = Boolean(endpoint.disabled_at);
          return (
            <li
              key={endpoint.id}
              className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
                <Icon
                  name={endpoint.kind === 'fcm' ? 'smartphone' : 'monitor'}
                  className="size-4"
                />
              </span>
              <div className="min-w-0 flex-1 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="font-medium break-words text-fg">{name}</p>
                  {endpoint.current_session ? (
                    <StatusBadge tone="info" icon="check-circle">
                      {t('notifications.devices.thisBrowser')}
                    </StatusBadge>
                  ) : null}
                  {stopped ? (
                    <StatusBadge tone="warning" icon="alert-triangle">
                      {t('notifications.devices.stopped')}
                    </StatusBadge>
                  ) : null}
                </div>
                <p className="text-sm text-fg-muted">
                  {[
                    added
                      ? t('notifications.devices.added', {
                          date: formatDateTime(added, formatLocale, user.timezone),
                        })
                      : null,
                    lastUsed
                      ? t('notifications.devices.lastUsed', {
                          date: formatDateTime(lastUsed, formatLocale, user.timezone),
                        })
                      : t('notifications.devices.neverUsed'),
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </p>
                {stopped ? (
                  <p className="text-sm text-fg-muted">{t('notifications.devices.stoppedHelp')}</p>
                ) : null}
              </div>
              {endpoint.current_session && !stopped ? null : (
                <Button
                  variant="secondary"
                  size="sm"
                  aria-label={t('notifications.devices.removeFor', { device: name })}
                  onClick={() => {
                    setRemoveError(null);
                    setRemoving(endpoint);
                  }}
                >
                  <Icon name="trash" className="size-4" />
                  {t('notifications.devices.remove')}
                </Button>
              )}
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <section
      aria-labelledby="notification-devices-heading"
      className="space-y-3 border-t border-line pt-4"
    >
      <div className="space-y-1">
        <h3 id="notification-devices-heading" className="text-base font-semibold text-fg">
          {t('notifications.devices.title')}
        </h3>
        <p className="text-sm text-fg-muted">{t('notifications.devices.description')}</p>
      </div>
      {content}
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open && !remove.isPending) setRemoving(null);
        }}
        title={t('notifications.devices.removeTitle')}
        description={
          removing
            ? t('notifications.devices.removeBody', { device: endpointName(removing, t) })
            : null
        }
        confirmLabel={t('notifications.devices.removeConfirm')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={removeError}
      />
    </section>
  );
}
