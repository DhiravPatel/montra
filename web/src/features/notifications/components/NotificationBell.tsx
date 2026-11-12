import { NavLink } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { useUnreadCount } from '../api';

/** Counts above this show as "99+" on the badge (the accessible name keeps the number). */
const BADGE_MAX = 99;

/**
 * A bell linking to the notification center with the unread count. The
 * count polls gently while the tab is visible and refreshes after reads.
 * The badge sits over the icon (no layout shift) and is hidden from
 * assistive tech: the link's accessible name carries the count instead.
 * `compact` is the small-screen header variant.
 */
export function NotificationBell({ compact = false }: { compact?: boolean }) {
  const { t, formatLocale } = useI18n();
  const unreadQuery = useUnreadCount();
  const unread = unreadQuery.isSuccess ? unreadQuery.data : null;

  let label: string;
  if (unread === null) label = t('notifications.bell.label');
  else if (unread === 0) label = t('notifications.bell.labelNone');
  else label = t('notifications.bell.labelCount', { count: unread });

  const badge =
    unread !== null && unread > 0
      ? unread > BADGE_MAX
        ? `${new Intl.NumberFormat(formatLocale).format(BADGE_MAX)}+`
        : new Intl.NumberFormat(formatLocale).format(unread)
      : null;

  return (
    <NavLink
      to={paths.notifications}
      aria-label={label}
      data-compact={compact ? '' : undefined}
      className={cx(
        'relative inline-flex size-11 shrink-0 items-center justify-center rounded-md border border-transparent text-fg-muted',
        'hover:bg-surface-muted hover:text-fg aria-[current=page]:bg-accent-soft aria-[current=page]:text-fg',
      )}
    >
      <Icon name="bell" />
      {badge ? (
        <span
          aria-hidden="true"
          className={cx(
            'pointer-events-none absolute end-0.5 top-0.5 inline-flex h-5 min-w-5 items-center justify-center rounded-full',
            // The accent color, not alarm red: unread updates are news, not warnings.
            'border-2 border-surface bg-accent px-1 text-[0.6875rem] leading-none font-semibold text-on-accent tabular-nums',
          )}
        >
          {badge}
        </span>
      ) : null}
    </NavLink>
  );
}
