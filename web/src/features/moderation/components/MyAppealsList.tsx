import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { affectedTitle } from '../labels';
import type { ModerationAppeal } from '../types';
import { AppealStatus } from './MyActionsList';

/**
 * The reviews you asked for (GET /me/moderation/appeals), newest first:
 * the decision each is about, what you wrote, and the outcome once someone
 * other than the moderator who acted has decided.
 */
export function MyAppealsList({
  appeals,
  timeZone,
}: {
  appeals: readonly ModerationAppeal[];
  timeZone: string;
}) {
  const { t, formatLocale } = useI18n();
  const format = (iso: string | undefined) => {
    const date = parseTimestamp(iso);
    return date ? formatDateTime(date, formatLocale, timeZone) : null;
  };
  return (
    <ul className="divide-y divide-line">
      {appeals.map((appeal) => {
        const acted = format(appeal.action.created_at);
        return (
          <li key={appeal.id} className="space-y-2 py-4 first:pt-0 last:pb-0">
            <div className="space-y-1">
              <h3 className="font-medium text-fg">
                {t('moderation.appeals.about', { what: t(affectedTitle(appeal.action)) })}
              </h3>
              <p className="text-sm text-fg-muted">
                {[
                  appeal.community_id
                    ? t('moderation.mine.inCommunity')
                    : t('moderation.mine.byMontra'),
                  acted,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            </div>
            {appeal.action.reason ? (
              <p className="text-sm text-fg">
                <span className="font-medium">{t('moderation.mine.reason')}</span>{' '}
                <span className="break-words whitespace-pre-line">{appeal.action.reason}</span>
              </p>
            ) : null}
            <p className="text-sm text-fg">
              <span className="font-medium">{t('moderation.appeals.yourStatement')}</span>{' '}
              <span className="break-words whitespace-pre-line">{appeal.statement}</span>
            </p>
            <AppealStatus appeal={appeal} format={format} />
          </li>
        );
      })}
    </ul>
  );
}
