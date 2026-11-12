import { Link } from 'react-router';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDateTime, formatRelativeTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { categoryIcon, categoryLabelKey } from '../categories';
import { notificationLink } from '../links';
import type { AppNotification } from '../types';

interface NotificationItemProps {
  notification: AppNotification;
  /** A change to this notification is being saved. */
  pending: boolean;
  now: number;
  timeZone: string;
  onOpen: (notification: AppNotification) => void;
  onToggleRead: (notification: AppNotification) => void;
  onToggleArchive: (notification: AppNotification) => void;
}

/**
 * One notification. Unread ones are marked with a "New" badge (icon and
 * text) and a bolder title, never by color alone. Titles and bodies are
 * server-written summaries, rendered as plain text.
 */
export function NotificationItem({
  notification,
  pending,
  now,
  timeZone,
  onOpen,
  onToggleRead,
  onToggleArchive,
}: NotificationItemProps) {
  const { t, formatLocale } = useI18n();
  const unread = !notification.read_at;
  const archived = Boolean(notification.archived_at);
  const link = notificationLink(notification);
  const created = parseTimestamp(notification.created_at);

  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start">
      <div className="flex min-w-0 flex-1 gap-3">
        <span
          className={cx(
            'inline-flex size-10 shrink-0 items-center justify-center rounded-lg',
            unread ? 'bg-accent-soft text-accent' : 'bg-surface-muted text-fg-muted',
          )}
        >
          <Icon name={categoryIcon(notification.category)} />
        </span>
        <div className="min-w-0 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            {unread ? (
              <StatusBadge tone="info" icon="bell">
                {t('notifications.item.new')}
              </StatusBadge>
            ) : null}
            <p className={cx('break-words text-fg', unread ? 'font-semibold' : 'font-medium')}>
              {link ? (
                <Link
                  to={link}
                  onClick={() => {
                    onOpen(notification);
                  }}
                  className="underline decoration-1 underline-offset-4 hover:decoration-2"
                >
                  {notification.title}
                </Link>
              ) : (
                notification.title
              )}
            </p>
          </div>
          {notification.body ? (
            <p className="text-sm break-words text-fg-muted">{notification.body}</p>
          ) : null}
          <p className="text-xs text-fg-muted">
            {t(categoryLabelKey(notification.category))}
            {created ? (
              <>
                {' · '}
                <time
                  dateTime={notification.created_at}
                  title={formatDateTime(created, formatLocale, timeZone)}
                >
                  {formatRelativeTime(created, formatLocale, now)}
                </time>
              </>
            ) : null}
          </p>
        </div>
      </div>
      <div className="flex shrink-0 flex-wrap gap-2 ps-13 sm:ps-0">
        <Button
          variant="secondary"
          size="sm"
          loading={pending}
          aria-label={`${unread ? t('notifications.item.markRead') : t('notifications.item.markUnread')}: ${notification.title}`}
          onClick={() => {
            onToggleRead(notification);
          }}
        >
          <Icon name={unread ? 'check-circle' : 'bell'} className="size-4" />
          {unread ? t('notifications.item.markRead') : t('notifications.item.markUnread')}
        </Button>
        <Button
          variant="ghost"
          size="sm"
          loading={pending}
          aria-label={`${archived ? t('notifications.item.unarchive') : t('notifications.item.archive')}: ${notification.title}`}
          onClick={() => {
            onToggleArchive(notification);
          }}
        >
          <Icon name={archived ? 'archive-restore' : 'archive'} className="size-4" />
          {archived ? t('notifications.item.unarchive') : t('notifications.item.archive')}
        </Button>
      </div>
    </li>
  );
}
