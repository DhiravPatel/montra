import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { formatDateTime } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { useI18n } from '@/shared/i18n/I18nContext';
import { isOwner, restrictionEnd } from '../access';
import type { Community } from '../types';

/**
 * Why someone cannot take part right now, in calm words: the community is
 * archived or suspended, a request is waiting, or a moderator limited or
 * banned them (with the way to see why and appeal).
 */
export function CommunityNotices({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const now = useNow();
  const until = restrictionEnd(community.restricted_until, now);
  const appealLink = (
    <TextLink to={paths.myModeration}>{t('communities.notice.appealLink')}</TextLink>
  );
  return (
    <div className="mb-6 space-y-4 empty:hidden">
      {community.status === 'archived' ? (
        <Alert tone="warning" title={t('communities.notice.archived.title')}>
          {isOwner(community)
            ? t('communities.notice.archived.ownerBody')
            : t('communities.notice.archived.body')}
        </Alert>
      ) : null}
      {community.status === 'suspended' ? (
        <Alert tone="warning" title={t('communities.notice.suspended.title')}>
          {t('communities.notice.suspended.body')}
        </Alert>
      ) : null}
      {community.my_status === 'pending' ? (
        <Alert tone="info" title={t('communities.notice.pending.title')}>
          {t('communities.notice.pending.body')}
        </Alert>
      ) : null}
      {community.my_status === 'banned' ? (
        <Alert tone="warning" title={t('communities.notice.banned.title')}>
          <p>{t('communities.notice.banned.body')}</p>
          <p>{appealLink}</p>
        </Alert>
      ) : null}
      {until && community.my_status === 'active' ? (
        <Alert
          tone="warning"
          title={t('communities.notice.restricted.title', {
            date: formatDateTime(until, formatLocale, user.timezone),
          })}
        >
          <p>{t('communities.notice.restricted.body')}</p>
          <p>{appealLink}</p>
        </Alert>
      ) : null}
    </div>
  );
}
