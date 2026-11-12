import { useState } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { describeActivity } from '../activity';
import { useGroupActivity } from '../api';
import type { GroupDetail } from '../types';

/** Events shown at first; "Show older activity" reveals more (and loads older pages). */
const FIRST = 10;
const STEP = 20;

/** The group's activity log, newest first, with paging into older events. */
export function ActivityCard({ group }: { group: GroupDetail }) {
  const { t, formatLocale } = useI18n();
  const me = useCurrentUser();
  const announce = useAnnounce();
  const activity = useGroupActivity(group.id);
  const [visible, setVisible] = useState(FIRST);

  let content;
  if (activity.isPending) {
    content = <LoadingState label={t('groups.activity.loading')} />;
  } else if (activity.isLoadingError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('groups.activity.error')}
        error={activity.error}
        retrying={activity.isFetching}
        onRetry={() => {
          void activity.refetch();
        }}
      />
    );
  } else {
    const events = activity.data.pages.flatMap((page) => page.events);
    const shown = events.slice(0, visible);
    const more = events.length > visible || activity.hasNextPage;
    const showMore = async () => {
      if (activity.isFetchingNextPage) return;
      if (events.length <= visible && activity.hasNextPage) {
        const result = await activity.fetchNextPage();
        if (result.isError) return;
      }
      setVisible((count) => count + STEP);
      announce(t('groups.activity.more'));
    };
    content =
      events.length === 0 ? (
        <EmptyState titleAs="p" icon="history" title={t('groups.activity.empty')} />
      ) : (
        <div className="space-y-4">
          <ol className="divide-y divide-line">
            {shown.map((event) => {
              const line = describeActivity(event, {
                groupId: group.id,
                members: group.members,
                myId: me.id,
                t,
                locale: formatLocale,
              });
              const when = parseTimestamp(event.created_at);
              return (
                <li key={event.id} className="flex gap-3 py-3 first:pt-0 last:pb-0">
                  <Icon name={line.icon} className="mt-0.5 size-4 shrink-0 text-fg-muted" />
                  <div className="min-w-0 space-y-0.5">
                    <p className="text-sm break-words text-fg">
                      {line.to ? <TextLink to={line.to}>{line.text}</TextLink> : line.text}
                    </p>
                    {when ? (
                      <p className="text-xs text-fg-muted">
                        <time dateTime={event.created_at}>
                          {formatDateTime(when, formatLocale, me.timezone)}
                        </time>
                      </p>
                    ) : null}
                  </div>
                </li>
              );
            })}
          </ol>
          {activity.isFetchNextPageError ? (
            <p role="alert" className="flex items-start gap-1.5 text-sm text-danger">
              <Icon name="alert-circle" className="mt-0.5 size-4 shrink-0" />
              {t('groups.activity.moreFailed')}
            </p>
          ) : null}
          {more ? (
            <Button
              variant="secondary"
              size="sm"
              loading={activity.isFetchingNextPage}
              onClick={() => {
                void showMore();
              }}
            >
              {t('groups.activity.showMore')}
            </Button>
          ) : null}
        </div>
      );
  }

  return (
    <Card title={t('groups.activity.title')} description={t('groups.activity.description')}>
      {content}
    </Card>
  );
}
