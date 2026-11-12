import { Card } from '@/shared/components/Card';
import { Icon, type IconName } from '@/shared/components/Icon';
import { type Tone, toneText } from '@/shared/components/tones';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { standingFrom } from '../standing';
import type { ModerationAction } from '../types';

interface Line {
  id: string;
  tone: Tone;
  icon: IconName;
  title: string;
  body: string;
}

/**
 * Where you stand right now, from the decisions the API lists for you:
 * account-wide limits set by the Montra team, then community ones.
 */
export function StandingCard({
  actions,
  now,
  timeZone,
}: {
  actions: readonly ModerationAction[];
  now: number;
  timeZone: string;
}) {
  const { t, formatLocale } = useI18n();
  const standing = standingFrom(actions, now);
  const until = (iso: string | null) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale, timeZone) : null;
  };
  const lines: Line[] = [];
  if (standing.account) {
    const end = until(standing.account.until);
    lines.push({
      id: 'account',
      tone: 'warning',
      icon: standing.account.action === 'ban' ? 'ban' : 'clock',
      title:
        standing.account.action === 'ban'
          ? t('moderation.standing.accountBan')
          : t('moderation.standing.accountRestrict'),
      body: end ? t('moderation.standing.until', { date: end }) : t('moderation.standing.noEnd'),
    });
  }
  if (standing.bannedFrom > 0) {
    lines.push({
      id: 'banned',
      tone: 'warning',
      icon: 'ban',
      title: t('moderation.standing.bannedFrom', { count: standing.bannedFrom }),
      body: t('moderation.standing.bannedFromBody'),
    });
  }
  if (standing.restrictedIn > 0) {
    lines.push({
      id: 'restricted',
      tone: 'warning',
      icon: 'clock',
      title: t('moderation.standing.restrictedIn', { count: standing.restrictedIn }),
      body: t('moderation.standing.restrictedInBody'),
    });
  }
  if (lines.length === 0) {
    lines.push({
      id: 'good',
      tone: 'success',
      icon: 'check-circle',
      title: t('moderation.standing.good'),
      body: t('moderation.standing.goodBody'),
    });
  }

  return (
    <Card title={t('moderation.standing.title')} description={t('moderation.standing.description')}>
      <ul className="space-y-4">
        {lines.map((line) => (
          <li key={line.id} className="flex items-start gap-3">
            <Icon name={line.icon} className={cx('mt-0.5', toneText[line.tone])} />
            <div className="min-w-0">
              <p className="font-medium text-fg">{line.title}</p>
              <p className="text-sm text-fg-muted">{line.body}</p>
            </div>
          </li>
        ))}
      </ul>
    </Card>
  );
}
