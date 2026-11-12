import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Spinner } from '@/shared/components/Spinner';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useInsightMutes } from '../api';
import { muteKey } from '../evidence';
import { MUTED_TYPES_HEADING_ID } from '../ids';
import { muteLabel, muteScopeLabel } from '../labels';
import type { InsightMute } from '../types';

interface MutedTypesCardProps {
  /** `muteKey` of the rule being unmuted. */
  pendingKey: string | null;
  /** Some insight action is running (clicks are ignored by the page). */
  locked: boolean;
  onUnmute: (mute: InsightMute) => void;
}

/** The mute rules in force (GET /insights/mutes), each with Unmute. */
export function MutedTypesCard({ pendingKey, locked, onUnmute }: MutedTypesCardProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const mutes = useInsightMutes();

  let content;
  if (mutes.isPending) {
    content = <LoadingState label={t('insights.muted.loading')} />;
  } else if (mutes.isError) {
    content = hasErrorCode(mutes.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('insights.muted.error')}
        error={mutes.error}
        retrying={mutes.isFetching}
        onRetry={() => {
          void mutes.refetch();
        }}
      />
    );
  } else if (mutes.data.length === 0) {
    content = (
      <p className="flex items-center gap-2 text-sm text-fg-muted">
        <Icon name="bell" className="size-4" />
        {t('insights.muted.empty')}
      </p>
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {mutes.data.map((mute) => {
          const key = muteKey(mute);
          const label = muteLabel(mute.subtype, t);
          const since = parseTimestamp(mute.created_at);
          const pending = pendingKey === key;
          return (
            <li
              key={key}
              className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <div className="min-w-0 flex-1 space-y-0.5">
                <p className="flex items-center gap-2 font-medium text-fg">
                  <Icon name="bell-off" className="size-4 text-fg-muted" />
                  {label}
                </p>
                <p className="text-sm text-fg-muted">
                  {[
                    t(muteScopeLabel(mute.subtype, mute.scope)),
                    since
                      ? t('insights.muted.since', {
                          date: formatDate(since, formatLocale, user.timezone),
                        })
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                {pending ? (
                  <p role="status" className="inline-flex items-center gap-2 text-sm text-fg-muted">
                    <Spinner size="sm" />
                    {t('insights.action.working')}
                  </p>
                ) : null}
                <Button
                  variant="secondary"
                  size="sm"
                  aria-disabled={locked || undefined}
                  aria-label={`${t('insights.action.unmute')}: ${label}`}
                  onClick={() => {
                    onUnmute(mute);
                  }}
                >
                  <Icon name="bell" className="size-4" />
                  {t('insights.action.unmute')}
                </Button>
              </div>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <section
      aria-labelledby={MUTED_TYPES_HEADING_ID}
      className="mt-8 rounded-xl border border-line bg-surface p-5 shadow-card sm:p-6"
    >
      <div className="mb-4 space-y-1">
        <h2
          id={MUTED_TYPES_HEADING_ID}
          tabIndex={-1}
          className="text-lg font-semibold text-fg outline-none"
        >
          {t('insights.muted.title')}
        </h2>
        <p className="text-sm text-fg-muted">{t('insights.muted.description')}</p>
      </div>
      {content}
    </section>
  );
}
