import { useId, useState } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/shared/components/Menu';
import { Spinner } from '@/shared/components/Spinner';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { buttonClasses } from '@/shared/components/buttonStyles';
import { formatDate, formatLocalDateRange, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { relatedLinks } from '../evidence';
import { insightThanksId, insightTitleId } from '../ids';
import {
  feedbackGivenLabel,
  kindIcon,
  kindLabel,
  severityIcon,
  severityLabel,
  severityTone,
  statusIcon,
  statusLabel,
} from '../labels';
import { insightText } from '../messages';
import type { Insight, InsightActionInput, InsightFeedbackState } from '../types';
import { InsightFacts } from './InsightFacts';

/** Snooze choices offered (the API accepts 1 to 90 days). */
const SNOOZE_DAYS = [1, 7, 30] as const;

interface InsightCardProps {
  insight: Insight;
  /** Opened from a link to this insight: facts start expanded. */
  highlighted: boolean;
  /** An action for this insight is running. */
  busy: boolean;
  /**
   * Some insight action is running (one at a time). Controls stay focusable
   * (aria-disabled) so keyboard focus is not lost; the page ignores clicks.
   */
  locked: boolean;
  /** The person's recorded answer (from the insight, or just sent), if any. */
  feedback: InsightFeedbackState | null;
  feedbackBusy: boolean;
  onAction: (input: InsightActionInput) => void;
  onMute: () => void;
  onUnmute: () => void;
  onFeedback: (feedback: 'helpful' | 'not_helpful') => void;
  onReport: () => void;
}

/**
 * One rule-based insight: what was noticed, the explanation and evidence,
 * links to the records involved, and what the person can do about it.
 * Every action changes only the insight, never the records.
 */
export function InsightCard({
  insight,
  highlighted,
  busy,
  locked,
  feedback,
  feedbackBusy,
  onAction,
  onMute,
  onUnmute,
  onFeedback,
  onReport,
}: InsightCardProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const feedbackLabelId = useId();
  // Answering again replaces the earlier answer (the API keeps one per person);
  // the choice closes once a newer answer arrives.
  const [changingFrom, setChangingFrom] = useState<string | null>(null);
  const changing = changingFrom !== null && changingFrom === feedback?.updated_at;
  const text = insightText(insight, t, formatLocale);
  const titleId = insightTitleId(insight.id);
  const created = parseTimestamp(insight.created_at);
  const snoozedUntil = parseTimestamp(insight.snoozed_until);
  const links = relatedLinks(insight);
  const named = (action: string) => `${action}: ${insight.title}`;
  const inert = locked || undefined;
  const status =
    insight.status === 'snoozed' && snoozedUntil
      ? t('insights.status.snoozedUntil', {
          date: formatDate(snoozedUntil, formatLocale, user.timezone),
        })
      : t(statusLabel[insight.status]);

  return (
    <article
      aria-labelledby={titleId}
      aria-busy={busy || undefined}
      className="space-y-4 rounded-xl border border-line bg-surface p-5 shadow-card sm:p-6"
    >
      <div className="flex flex-wrap items-center gap-2">
        <StatusBadge tone={severityTone[insight.severity]} icon={severityIcon[insight.severity]}>
          {t(severityLabel[insight.severity])}
        </StatusBadge>
        <StatusBadge tone="neutral" icon={kindIcon[insight.kind]}>
          {t(kindLabel[insight.kind])}
        </StatusBadge>
        {insight.status === 'active' ? null : (
          <StatusBadge tone="neutral" icon={statusIcon[insight.status]}>
            {status}
          </StatusBadge>
        )}
      </div>

      <div className="space-y-1">
        <h3 id={titleId} tabIndex={-1} className="text-lg font-semibold text-fg outline-none">
          {text.title}
        </h3>
        <p className="text-sm text-fg-muted">
          {[
            created
              ? t('insights.noticed', { date: formatDate(created, formatLocale, user.timezone) })
              : null,
            insight.period_start && insight.period_end
              ? formatLocalDateRange(insight.period_start, insight.period_end, formatLocale)
              : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        </p>
      </div>

      <p className="text-fg">{text.body}</p>

      <Disclosure summary={t('insights.facts.toggle')} defaultOpen={highlighted}>
        <InsightFacts insight={insight} />
      </Disclosure>

      {links.length > 0 ? (
        <ul className="flex flex-wrap gap-x-5 gap-y-2 text-sm">
          {links.map((link) => (
            <li key={link.key}>
              <TextLink to={link.to} className="inline-flex min-h-9 items-center gap-1.5">
                <Icon name="arrow-right" className="size-4" />
                {t(link.labelKey)}
              </TextLink>
            </li>
          ))}
        </ul>
      ) : null}

      <div className="flex flex-wrap gap-2 border-t border-line pt-4">
        {insight.status === 'active' ? (
          <>
            <Button
              variant="secondary"
              size="sm"
              aria-disabled={inert}
              aria-label={named(t('insights.action.dismiss'))}
              onClick={() => {
                onAction({ action: 'dismiss' });
              }}
            >
              <Icon name="x" className="size-4" />
              {t('insights.action.dismiss')}
            </Button>
            <Menu>
              <MenuTrigger
                aria-disabled={inert}
                aria-label={named(t('insights.action.snooze'))}
                className={buttonClasses('secondary', 'sm')}
              >
                <Icon name="clock" className="size-4" />
                {t('insights.action.snooze')}
                <Icon name="chevron-down" className="size-4" />
              </MenuTrigger>
              <MenuContent align="start" label={t('insights.action.snoozeMenu')}>
                {SNOOZE_DAYS.map((days) => (
                  <MenuItem
                    key={days}
                    onSelect={() => {
                      onAction({ action: 'snooze', snooze_days: days });
                    }}
                  >
                    {t('insights.action.snoozeDays', { count: days })}
                  </MenuItem>
                ))}
              </MenuContent>
            </Menu>
            <Menu>
              <MenuTrigger
                aria-disabled={inert}
                aria-label={named(t('insights.action.more'))}
                className={buttonClasses('secondary', 'sm')}
              >
                <Icon name="more-horizontal" className="size-4" />
                {t('insights.action.more')}
              </MenuTrigger>
              <MenuContent align="start" label={t('insights.action.more')}>
                <MenuItem
                  icon="check-circle"
                  onSelect={() => {
                    onAction({ action: 'expected' });
                  }}
                >
                  {t('insights.action.expected')}
                </MenuItem>
                <MenuItem
                  icon="check"
                  onSelect={() => {
                    onAction({ action: 'resolved' });
                  }}
                >
                  {t('insights.action.resolved')}
                </MenuItem>
                <MenuItem icon="bell-off" onSelect={onMute}>
                  {t('insights.action.mute')}
                </MenuItem>
              </MenuContent>
            </Menu>
          </>
        ) : insight.status === 'muted' ? (
          <Button
            variant="secondary"
            size="sm"
            aria-disabled={inert}
            aria-label={named(t('insights.action.unmute'))}
            onClick={onUnmute}
          >
            <Icon name="bell" className="size-4" />
            {t('insights.action.unmute')}
          </Button>
        ) : (
          <Button
            variant="secondary"
            size="sm"
            aria-disabled={inert}
            aria-label={named(t('insights.action.reopen'))}
            onClick={() => {
              onAction({ action: 'reopen' });
            }}
          >
            <Icon name="rotate-ccw" className="size-4" />
            {t('insights.action.reopen')}
          </Button>
        )}
        {busy ? (
          <p role="status" className="inline-flex items-center gap-2 text-sm text-fg-muted">
            <Spinner size="sm" />
            {t('insights.action.working')}
          </p>
        ) : null}
      </div>

      {feedback && !changing ? (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
          <p
            id={insightThanksId(insight.id)}
            role="status"
            tabIndex={-1}
            className="flex items-center gap-2 text-sm text-fg-muted outline-none"
          >
            <Icon name="check-circle" className="size-4 text-success" />
            {t(feedbackGivenLabel[feedback.feedback])} {t('insights.feedback.thanks')}
          </p>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setChangingFrom(feedback.updated_at);
            }}
          >
            {t('insights.feedback.change')}
          </Button>
        </div>
      ) : (
        <div
          role="group"
          aria-labelledby={feedbackLabelId}
          className="flex flex-wrap items-center gap-2"
        >
          <p id={feedbackLabelId} className="me-1 text-sm text-fg-muted">
            {t('insights.feedback.question')}
          </p>
          <Button
            variant="ghost"
            size="sm"
            aria-disabled={feedbackBusy || undefined}
            onClick={() => {
              onFeedback('helpful');
            }}
          >
            <Icon name="check" className="size-4" />
            {t('insights.feedback.helpful')}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            aria-disabled={feedbackBusy || undefined}
            onClick={() => {
              onFeedback('not_helpful');
            }}
          >
            <Icon name="x" className="size-4" />
            {t('insights.feedback.notHelpful')}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            aria-disabled={feedbackBusy || undefined}
            onClick={onReport}
          >
            <Icon name="flag" className="size-4" />
            {t('insights.feedback.report')}
          </Button>
          {changing ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setChangingFrom(null);
              }}
            >
              {t('common.cancel')}
            </Button>
          ) : null}
        </div>
      )}
    </article>
  );
}
