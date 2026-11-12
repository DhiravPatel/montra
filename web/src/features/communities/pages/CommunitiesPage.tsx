import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { useCommunityList } from '../api';
import { CommunityRow } from '../components/CommunityRow';
import { InvitationsToYouCard } from '../components/InvitationsToYouCard';

const SEARCH_MAX = 80;
const TOPIC_MAX = 30;

function CreateAction() {
  const t = useT();
  return (
    <ButtonLink to={paths.communityNew}>
      <Icon name="plus" className="size-4" />
      {t('communities.create.action')}
    </ButtonLink>
  );
}

/** Communities you joined or asked to join (active and pending). */
function YourCommunities() {
  const t = useT();
  const mine = useCommunityList({ q: '', topic: '', mine: true });

  let content;
  if (mine.isPending) {
    content = <LoadingState label={t('communities.mine.loading')} />;
  } else if (mine.isError) {
    content = hasErrorCode(mine.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('communities.mine.error')}
        error={mine.error}
        retrying={mine.isFetching}
        onRetry={() => {
          void mine.refetch();
        }}
      />
    );
  } else if (mine.data.length === 0) {
    content = (
      <EmptyState
        titleAs="p"
        icon="users"
        title={t('communities.mine.empty')}
        description={t('communities.mine.emptyBody')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {mine.data.map((community) => (
          <CommunityRow key={community.id} community={community} />
        ))}
      </ul>
    );
  }
  return <Card title={t('communities.mine.title')}>{content}</Card>;
}

/** Search public and private communities by name or description, and filter by topic. */
function Discover() {
  const t = useT();
  const [search, setSearch] = useState('');
  const [topic, setTopic] = useState('');
  const q = useDebouncedValue(search.trim(), 300);
  const topicFilter = useDebouncedValue(topic.trim().toLowerCase(), 300);
  const list = useCommunityList({ q, topic: topicFilter, mine: false });
  const filtered = Boolean(q || topicFilter);

  let content;
  if (list.isPending) {
    content = <LoadingState label={t('communities.discover.loading')} />;
  } else if (list.isError) {
    content = hasErrorCode(list.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('communities.discover.error')}
        error={list.error}
        retrying={list.isFetching}
        onRetry={() => {
          void list.refetch();
        }}
      />
    );
  } else if (list.data.length === 0) {
    content = filtered ? (
      <EmptyState
        titleAs="p"
        icon="search"
        title={t('communities.discover.noMatches')}
        description={t('communities.discover.noMatchesBody')}
        action={
          <Button
            variant="secondary"
            onClick={() => {
              setSearch('');
              setTopic('');
            }}
          >
            {t('communities.discover.clear')}
          </Button>
        }
      />
    ) : (
      <EmptyState
        titleAs="p"
        icon="users"
        title={t('communities.discover.empty')}
        description={t('communities.discover.emptyBody')}
        action={<CreateAction />}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line" aria-busy={list.isFetching || undefined}>
        {list.data.map((community) => (
          <CommunityRow key={community.id} community={community} onTopic={setTopic} />
        ))}
      </ul>
    );
  }

  return (
    <Card
      title={t('communities.discover.title')}
      description={t('communities.discover.description')}
    >
      <div className="space-y-5">
        <div className="flex flex-wrap items-end gap-3">
          <TextField
            type="search"
            className="min-w-56 flex-[2]"
            label={t('communities.discover.search')}
            aria-required={false}
            maxLength={SEARCH_MAX}
            autoComplete="off"
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
            }}
          />
          <TextField
            className="min-w-40 flex-1"
            label={t('communities.discover.topic')}
            help={t('communities.discover.topicHelp')}
            aria-required={false}
            maxLength={TOPIC_MAX}
            autoComplete="off"
            value={topic}
            onChange={(event) => {
              setTopic(event.target.value);
            }}
          />
          {filtered ? (
            <Button
              variant="ghost"
              onClick={() => {
                setSearch('');
                setTopic('');
              }}
            >
              {t('communities.discover.clear')}
            </Button>
          ) : null}
        </div>
        {content}
      </div>
    </Card>
  );
}

/**
 * Communities: invitations waiting for you, the ones you are in, discovery
 * with search and topics, and joining with a link. Communities are about
 * sharing experience; they never see anyone's accounts or transactions.
 */
export function CommunitiesPage() {
  const t = useT();
  useDocumentTitle(t('communities.title'));
  return (
    <>
      <PageHeader
        title={t('communities.title')}
        description={t('communities.description')}
        actions={<CreateAction />}
      />
      <div className="space-y-6">
        <InvitationsToYouCard />
        <YourCommunities />
        <Discover />
        <Card title={t('communities.joinByLink.title')}>
          <div className="space-y-2 text-sm text-fg-muted">
            <p>{t('communities.joinByLink.body')}</p>
            <p>
              <TextLink to={paths.communityJoin}>{t('communities.joinByLink.paste')}</TextLink>
            </p>
          </div>
        </Card>
      </div>
    </>
  );
}
