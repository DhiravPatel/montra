import type { ReactNode } from 'react';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { memberStatusLabel } from '../labels';
import type { GroupMember } from '../types';
import { RoleBadge } from './GroupBadges';

/** Initials for the avatar placeholder (no profile photos are loaded here). */
function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => Array.from(part)[0] ?? '')
    .join('')
    .toUpperCase();
}

/** One member: name, username, role and when they joined or left. */
export function MemberRow({
  member,
  isMe,
  timezone,
  children,
}: {
  member: GroupMember;
  isMe: boolean;
  timezone: string;
  /** Actions for this member (settings page). */
  children?: ReactNode;
}) {
  const { t, formatLocale } = useI18n();
  const joined = parseTimestamp(member.joined_at);
  const left = parseTimestamp(member.left_at);
  const when =
    member.status === 'active'
      ? joined
        ? t('groups.members.joined', { date: formatDate(joined, formatLocale, timezone) })
        : null
      : left
        ? t('groups.members.leftOn', { date: formatDate(left, formatLocale, timezone) })
        : null;
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center">
      <div className="flex min-w-0 flex-1 gap-3">
        <span
          aria-hidden="true"
          className="inline-flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-muted text-sm font-semibold text-fg-muted"
        >
          {initials(member.display_name)}
        </span>
        <div className="min-w-0 space-y-1">
          <p className="font-medium break-words text-fg">
            {member.display_name}
            {isMe ? (
              <span className="font-normal text-fg-muted"> {t('groups.members.you')}</span>
            ) : null}
          </p>
          {member.username || when ? (
            <p className="text-sm break-words text-fg-muted">
              {[member.username ? `@${member.username}` : null, when].filter(Boolean).join(' · ')}
            </p>
          ) : null}
          <div className="flex flex-wrap gap-2">
            {member.status === 'active' ? (
              <RoleBadge role={member.role} />
            ) : (
              <StatusBadge tone="neutral" icon="log-out">
                {t(memberStatusLabel[member.status])}
              </StatusBadge>
            )}
          </div>
        </div>
      </div>
      {children ? <div className="flex shrink-0 flex-wrap gap-2">{children}</div> : null}
    </li>
  );
}
