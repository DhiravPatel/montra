import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { useGroup } from '../api';
import type { GroupDetail } from '../types';
import { GroupUnavailable } from './GroupUnavailable';

export function BackToGroups() {
  const t = useT();
  return (
    <p className="mb-2">
      <TextLink to={paths.groups}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('groups.backToList')}
      </TextLink>
    </p>
  );
}

function GroupSkeleton() {
  const t = useT();
  return (
    <LoadingState label={t('groups.detail.loading')}>
      <div className="space-y-6" aria-hidden="true">
        <Skeleton className="h-9 w-1/2" />
        <Skeleton className="h-11 w-full" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    </LoadingState>
  );
}

export interface GroupPageContext {
  group: GroupDetail;
  /** Reloads the group (after a conflict, a permission answer or a status change). */
  reload: () => void;
}

/**
 * Loads a group for its pages and shows the loading, not-found (non-members
 * get 404), permission and error states; renders `children` once loaded.
 */
export function GroupPage({
  groupId,
  title,
  children,
}: {
  groupId: string;
  /** Page heading while the group cannot be shown (never the group's name). */
  title: string;
  children: (context: GroupPageContext) => ReactNode;
}) {
  const t = useT();
  const query = useGroup(groupId);

  if (query.isPending) return <GroupSkeleton />;
  if (query.isError) {
    let problem;
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      problem = <GroupUnavailable groupId={groupId} />;
    } else if (hasErrorCode(query.error, 'FORBIDDEN')) {
      problem = <PermissionDenied titleAs="h2" />;
    } else {
      problem = (
        <ErrorState
          titleAs="h2"
          title={t('groups.detail.error')}
          error={query.error}
          retrying={query.isFetching}
          onRetry={() => {
            void query.refetch();
          }}
        />
      );
    }
    return (
      <>
        <BackToGroups />
        <PageHeader title={title} />
        {problem}
      </>
    );
  }

  return children({
    group: query.data,
    reload: () => {
      void query.refetch();
    },
  });
}
