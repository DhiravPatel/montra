import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { GroupSubNav } from '@/features/groups/components/GroupSubNav';
import { useMoneyGroup } from '../api';
import { isReadOnlyGroup } from '../people';
import type { GroupDetail } from '../types';

interface GroupMoneyPageProps {
  groupId: string;
  /** The page's h1 (a page name or the record's own title; never in the document title). */
  title: string;
  /** A link above the heading back to the list this page belongs to. */
  back?: { to: string; label: string };
  actions?: (group: GroupDetail) => ReactNode;
  children: (group: GroupDetail) => ReactNode;
}

/**
 * Frame for every group money page: loads the group (members, currency,
 * role, status), shows the group's tabs, and the loading, not-found
 * (non-members get 404), permission and error states. Archived groups are
 * read-only and say so.
 */
export function GroupMoneyPage({ groupId, title, back, actions, children }: GroupMoneyPageProps) {
  const t = useT();
  const query = useMoneyGroup(groupId);
  const group = query.data;

  let body: ReactNode;
  if (query.isPending) {
    body = <LoadingState label={t('groupMoney.page.loading')} />;
  } else if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      body = (
        <EmptyState
          titleAs="h2"
          icon="users"
          title={t('groupMoney.page.notFound')}
          description={t('groupMoney.page.notFoundBody')}
          action={<ButtonLink to={paths.groups}>{t('groupMoney.page.backToGroups')}</ButtonLink>}
        />
      );
    } else if (hasErrorCode(query.error, 'FORBIDDEN')) {
      body = <PermissionDenied titleAs="h2" />;
    } else {
      body = (
        <ErrorState
          titleAs="h2"
          title={t('groupMoney.page.error')}
          error={query.error}
          retrying={query.isFetching}
          onRetry={() => {
            void query.refetch();
          }}
        />
      );
    }
  } else {
    body = (
      <>
        {isReadOnlyGroup(query.data) ? (
          <Alert tone="info" className="mb-6" title={t('groupMoney.page.archivedTitle')}>
            {t('groupMoney.page.archivedBody')}
          </Alert>
        ) : null}
        {children(query.data)}
      </>
    );
  }

  return (
    <>
      {back ? (
        <p className="mb-2">
          <TextLink to={back.to}>
            <Icon name="arrow-left" className="me-1 inline size-4" />
            {back.label}
          </TextLink>
        </p>
      ) : null}
      <PageHeader
        title={title}
        description={group?.name}
        actions={group && actions ? actions(group) : undefined}
      />
      {group ? <GroupSubNav groupId={groupId} /> : null}
      {body}
    </>
  );
}
