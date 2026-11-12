import type { Session } from '@/shared/api/types';
import { Button } from '@/shared/components/Button';
import { Icon, type IconName } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDateTime, formatRelativeTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';

const clientKind: Record<Session['client_kind'], { icon: IconName; label: MessageKey }> = {
  web: { icon: 'monitor', label: 'settings.sessions.client.web' },
  android: { icon: 'smartphone', label: 'settings.sessions.client.android' },
  ios: { icon: 'smartphone', label: 'settings.sessions.client.ios' },
  unknown: { icon: 'monitor', label: 'settings.sessions.client.unknown' },
};

interface SessionItemProps {
  session: Session;
  now: number;
  onSignOut: (session: Session) => void;
  signingOut?: boolean;
}

export function SessionItem({ session, now, onSignOut, signingOut = false }: SessionItemProps) {
  const { t, rich, formatLocale } = useI18n();
  const kind = clientKind[session.client_kind];
  const device = session.device_name ?? t('settings.sessions.unknownDevice');
  const lastSeen = parseTimestamp(session.last_seen_at);
  const created = parseTimestamp(session.created_at);
  const actionLabel = session.current
    ? t('auth.signOut.action')
    : t('settings.sessions.signOutDevice');

  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex min-w-0 gap-3">
        <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
          <Icon name={kind.icon} />
        </span>
        <div className="min-w-0 space-y-0.5">
          <p className="flex flex-wrap items-center gap-2 font-medium text-fg">
            <span className="break-words">{device}</span>
            {session.current ? (
              <StatusBadge tone="success" icon="check-circle">
                {t('settings.sessions.thisDevice')}
              </StatusBadge>
            ) : null}
          </p>
          <p className="text-sm text-fg-muted">
            {t(kind.label)}
            {lastSeen ? (
              <>
                {' · '}
                {rich(
                  'settings.sessions.lastActive',
                  { time: (text) => <time dateTime={session.last_seen_at}>{text}</time> },
                  { when: formatRelativeTime(lastSeen, formatLocale, now) },
                )}
              </>
            ) : null}
          </p>
          <p className="text-sm text-fg-muted">
            {created
              ? rich(
                  'settings.sessions.signedIn',
                  { time: (text) => <time dateTime={session.created_at}>{text}</time> },
                  { when: formatDateTime(created, formatLocale) },
                )
              : null}
            {session.mfa_verified ? (
              <span className="ms-2 inline-flex items-center gap-1">
                <Icon name="shield-check" className="size-4 text-success" />
                {t('settings.sessions.mfaVerified')}
              </span>
            ) : null}
          </p>
        </div>
      </div>
      <Button
        variant="secondary"
        size="sm"
        loading={signingOut}
        className="self-start sm:self-center"
        // Unique name per row; starts with the visible text (WCAG 2.5.3 label in name).
        aria-label={`${actionLabel}: ${device}`}
        onClick={() => {
          onSignOut(session);
        }}
      >
        {actionLabel}
      </Button>
    </li>
  );
}
