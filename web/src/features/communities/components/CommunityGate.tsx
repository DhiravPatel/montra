import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { communityPath, paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { useCommunity } from '../api';
import type { Community } from '../types';

export function BackToCommunities() {
  const t = useT();
  return (
    <p className="mb-2">
      <TextLink to={paths.communities}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('communities.backToList')}
      </TextLink>
    </p>
  );
}

/** Link back to a community's main page (its name is community content, shown as text). */
export function BackToCommunity({ community }: { community: Pick<Community, 'id' | 'name'> }) {
  const t = useT();
  return (
    <p className="mb-2">
      <TextLink to={communityPath(community.id)}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('communities.backTo', { name: community.name })}
      </TextLink>
    </p>
  );
}

function CommunitySkeleton() {
  const t = useT();
  return (
    <LoadingState label={t('communities.detail.loading')}>
      <div className="space-y-6" aria-hidden="true">
        <Skeleton className="h-9 w-1/2" />
        <Skeleton className="h-5 w-1/3" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    </LoadingState>
  );
}

/** A community the API answers 404 for: invitation only, removed, or a wrong address. */
export function CommunityUnavailable() {
  const t = useT();
  return (
    <EmptyState
      titleAs="h2"
      icon="users"
      title={t('communities.unavailable.title')}
      description={t('communities.unavailable.body')}
      action={<ButtonLink to={paths.communities}>{t('communities.backToList')}</ButtonLink>}
    />
  );
}

export interface CommunityContext {
  community: Community;
  /** Reloads the community (after a permission answer or a membership change elsewhere). */
  reload: () => void;
}

/**
 * Loads a community by ID or URL name for its pages, with the loading,
 * not-found, permission and error states; renders `children` once loaded.
 */
export function CommunityGate({
  communityRef,
  title,
  children,
}: {
  communityRef: string;
  /** Page heading while the community cannot be shown (never its name). */
  title: string;
  children: (context: CommunityContext) => ReactNode;
}) {
  const t = useT();
  const query = useCommunity(communityRef);

  if (query.isPending) return <CommunitySkeleton />;
  if (query.isError) {
    let problem;
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      problem = <CommunityUnavailable />;
    } else if (hasErrorCode(query.error, 'FORBIDDEN')) {
      problem = <PermissionDenied titleAs="h2" />;
    } else {
      problem = (
        <ErrorState
          titleAs="h2"
          title={t('communities.detail.error')}
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
        <BackToCommunities />
        <PageHeader title={title} />
        {problem}
      </>
    );
  }

  return children({
    community: query.data,
    reload: () => {
      void query.refetch();
    },
  });
}
