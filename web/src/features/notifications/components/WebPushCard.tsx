import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { notificationsApi, usePushConfig, usePushEndpoints } from '../api';
import { notificationsKeys } from '../keys';
import {
  PushPermissionError,
  PushServiceUnsupportedError,
  PushWorkerError,
  browserPushSupported,
  deviceLabel,
  findBrowserSubscription,
  requestNotificationPermission,
  serverPushKey,
  subscribeBrowser,
} from '../push/browserPush';
import type { PushEndpoint, WebPushConfig } from '../types';
import { PushDevicesList } from './PushDevicesList';

/** This browser's own state, detected locally (no request to Montra). */
type BrowserState =
  { kind: 'unsupported' } | { kind: 'blocked' } | { kind: 'ready'; subscribed: boolean };

async function detectBrowser(): Promise<BrowserState> {
  if (!browserPushSupported()) return { kind: 'unsupported' };
  const permission = Notification.permission;
  if (permission === 'denied') return { kind: 'blocked' };
  const subscription =
    permission === 'granted' ? await findBrowserSubscription().catch(() => null) : null;
  return { kind: 'ready', subscribed: subscription !== null };
}

/** This session's browser registration, as the server lists it. */
function thisSessionEndpoint(endpoints: readonly PushEndpoint[] | undefined) {
  return endpoints?.find((endpoint) => endpoint.current_session && endpoint.kind === 'webpush');
}

function registerSubscription(subscription: PushSubscription): Promise<string> {
  return notificationsApi.registerPush({
    kind: 'webpush',
    subscription: subscription.toJSON(),
    device_label: deviceLabel(),
  });
}

/**
 * Subscribes this browser with the server's key and registers it for this
 * session. The permission prompt was already requested from the click
 * (passed in as a promise). If Montra refuses the registration, the browser
 * subscription is removed again so the page never claims notifications
 * that will not arrive.
 */
async function turnOnBrowserPush(
  permissionRequest: Promise<NotificationPermission>,
  config: WebPushConfig,
) {
  const permission = await permissionRequest;
  if (permission !== 'granted') throw new PushPermissionError(permission);
  const key = serverPushKey(config);
  if (!key) throw new PushServiceUnsupportedError();
  let subscription = await subscribeBrowser(key);
  try {
    return await registerSubscription(subscription);
  } catch (error) {
    if (hasErrorCode(error, 'CONFLICT')) {
      // This browser's subscription is registered to another Montra
      // account: start a fresh one (a new endpoint) for this account.
      subscription = await subscribeBrowser(key, { fresh: true });
      try {
        return await registerSubscription(subscription);
      } catch (retryError) {
        await subscription.unsubscribe().catch(() => false);
        throw retryError;
      }
    }
    await subscription.unsubscribe().catch(() => false);
    if (hasErrorCode(error, 'VALIDATION_ERROR')) throw new PushServiceUnsupportedError();
    throw error;
  }
}

/**
 * Removes this session's registration from Montra (by the ID the server
 * lists for it), then unsubscribes the browser.
 */
async function turnOffBrowserPush(registration: PushEndpoint | undefined) {
  if (registration) {
    try {
      await notificationsApi.removePush(registration.id);
    } catch (error) {
      if (!hasErrorCode(error, 'NOT_FOUND')) throw error;
    }
  }
  const subscription = await findBrowserSubscription();
  if (subscription) await subscription.unsubscribe();
}

interface PushProblem {
  tone: 'warning' | 'danger' | 'info';
  message: string;
  /** The browser just blocked notifications (the announced message replaces the state text). */
  blocked?: boolean;
}

function describePushProblem(error: unknown, t: Translate): PushProblem {
  if (error instanceof PushPermissionError) {
    return error.permission === 'denied'
      ? { tone: 'warning', message: t('notifications.push.blockedNow'), blocked: true }
      : { tone: 'info', message: t('notifications.push.dismissed') };
  }
  if (error instanceof PushServiceUnsupportedError) {
    return { tone: 'warning', message: t('notifications.push.serviceUnsupported') };
  }
  if (error instanceof PushWorkerError) {
    return { tone: 'danger', message: t('notifications.push.workerFailed') };
  }
  if (isApiError(error)) return { tone: 'danger', message: describeError(error, t) };
  return { tone: 'danger', message: t('notifications.push.browserFailed') };
}

/**
 * Browser notifications for this browser: an explicit opt-in (the
 * permission prompt appears only after the click), clear states for
 * unsupported, unavailable on this server and blocked, a way to turn them
 * off, and the list of browsers and devices registered on the account.
 *
 * Registrations belong to the sign-in session that made them (a shared
 * browser never keeps another person's notifications), so after signing
 * in again the card notices that this browser is subscribed but not
 * registered for this session and offers to register it again.
 */
export function WebPushCard() {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [problem, setProblem] = useState<PushProblem | null>(null);
  const browser = useQuery({
    queryKey: notificationsKeys.browserPush(),
    queryFn: detectBrowser,
    staleTime: 0,
    refetchOnWindowFocus: true,
    retry: false,
  });
  const supported = browser.isSuccess && browser.data.kind !== 'unsupported';
  const config = usePushConfig(supported);
  const serverConfig = config.data;
  const endpoints = usePushEndpoints();
  const registration = thisSessionEndpoint(endpoints.data);
  const registered = registration !== undefined && !registration.disabled_at;

  const refresh = () =>
    Promise.all([
      queryClient.invalidateQueries({ queryKey: notificationsKeys.browserPush() }),
      queryClient.invalidateQueries({ queryKey: notificationsKeys.pushEndpoints() }),
    ]);

  const enable = useMutation({
    mutationFn: ({
      permission,
      serverConfig,
    }: {
      permission: Promise<NotificationPermission>;
      serverConfig: WebPushConfig;
    }) => turnOnBrowserPush(permission, serverConfig),
    onSettled: refresh,
  });
  const disable = useMutation({
    mutationFn: () => turnOffBrowserPush(registration),
    onSettled: refresh,
  });
  const busy = enable.isPending || disable.isPending;

  const turnOn = (serverConfig: WebPushConfig) => {
    if (busy) return;
    setProblem(null);
    // Ask from the click itself: browsers only show the prompt during a user
    // gesture. An already granted permission needs no prompt.
    const permission =
      Notification.permission === 'granted'
        ? Promise.resolve<NotificationPermission>('granted')
        : requestNotificationPermission();
    enable.mutate(
      { permission, serverConfig },
      {
        onSuccess: () => {
          toast.show({ tone: 'success', title: t('notifications.push.turnedOn') });
        },
        onError: (error) => {
          setProblem(describePushProblem(error, t));
        },
      },
    );
  };

  const turnOff = () => {
    if (busy) return;
    setProblem(null);
    disable.mutate(undefined, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('notifications.push.turnedOff') });
      },
      onError: (error) => {
        setProblem(describePushProblem(error, t));
      },
    });
  };

  let body;
  if (browser.isPending) {
    body = <LoadingState label={t('notifications.push.checking')} />;
  } else if (browser.isError || browser.data.kind === 'unsupported') {
    body = (
      <Alert tone="info" title={t('notifications.push.unsupported.title')}>
        {t('notifications.push.unsupported.body')}
      </Alert>
    );
  } else if (config.isError) {
    body = (
      <ErrorState
        titleAs="p"
        title={t('notifications.push.configError')}
        error={config.error}
        retrying={config.isFetching}
        onRetry={() => {
          void config.refetch();
        }}
      />
    );
  } else if (serverConfig === undefined || endpoints.isPending) {
    body = <LoadingState label={t('notifications.push.checking')} />;
  } else if (!serverConfig.available || !serverPushKey(serverConfig)) {
    body = (
      <Alert tone="neutral" title={t('notifications.push.notConfigured.title')}>
        {t('notifications.push.notConfigured.body')}
      </Alert>
    );
  } else if (browser.data.kind === 'blocked') {
    // Right after the prompt was refused, the announced message already says this.
    body = problem?.blocked ? null : (
      <Alert tone="warning" title={t('notifications.push.blocked.title')}>
        {t('notifications.push.blocked.body')}
      </Alert>
    );
  } else if (browser.data.subscribed && registered) {
    body = (
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-1">
          <StatusBadge tone="success" icon="check-circle">
            {t('notifications.push.on')}
          </StatusBadge>
          <p className="text-sm text-fg-muted">{t('notifications.push.onHelp')}</p>
        </div>
        <Button variant="secondary" loading={disable.isPending} onClick={turnOff}>
          <Icon name="bell-off" className="size-4" />
          {t('notifications.push.turnOff')}
        </Button>
      </div>
    );
  } else if (browser.data.subscribed) {
    // Subscribed in the browser, but not registered for this sign-in
    // session (it ended, or the push service stopped delivering).
    body = (
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-1">
          <StatusBadge tone="warning" icon="alert-triangle">
            {t('notifications.push.reregister.title')}
          </StatusBadge>
          <p className="text-sm text-fg-muted">
            {registration?.disabled_at
              ? t('notifications.push.reregister.stoppedBody')
              : t('notifications.push.reregister.body')}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button
            loading={enable.isPending}
            onClick={() => {
              turnOn(serverConfig);
            }}
          >
            <Icon name="bell" className="size-4" />
            {t('notifications.push.reregister.action')}
          </Button>
          <Button variant="secondary" loading={disable.isPending} onClick={turnOff}>
            <Icon name="bell-off" className="size-4" />
            {t('notifications.push.turnOff')}
          </Button>
        </div>
      </div>
    );
  } else {
    body = (
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-1">
          <StatusBadge tone="neutral" icon="bell-off">
            {t('notifications.push.off')}
          </StatusBadge>
          <p className="text-sm text-fg-muted">{t('notifications.push.offHelp')}</p>
        </div>
        <Button
          loading={enable.isPending}
          onClick={() => {
            turnOn(serverConfig);
          }}
        >
          <Icon name="bell" className="size-4" />
          {t('notifications.push.turnOn')}
        </Button>
      </div>
    );
  }

  return (
    <Card title={t('notifications.push.title')} description={t('notifications.push.description')}>
      <div className="space-y-4">
        {problem ? (
          <Alert
            tone={problem.tone}
            live="assertive"
            title={problem.blocked ? t('notifications.push.blocked.title') : undefined}
          >
            {problem.message}
          </Alert>
        ) : null}
        {body}
        <p className="text-sm text-fg-muted">{t('notifications.push.sessionNote')}</p>
        <PushDevicesList />
      </div>
    </Card>
  );
}
