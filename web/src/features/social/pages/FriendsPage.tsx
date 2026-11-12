import { useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { PageHeader } from '@/shared/components/PageHeader';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { SocialActionsProvider } from '../actions/SocialActionsProvider';
import { BlockedMutedPanel } from '../components/BlockedMutedPanel';
import { FindPeoplePanel } from '../components/FindPeoplePanel';
import { FriendsPanel } from '../components/FriendsPanel';
import { PrivacyPanel } from '../components/PrivacyPanel';
import { RequestsPanel } from '../components/RequestsPanel';
import { type SectionTab, SectionTabPanels, SectionTabs } from '../components/SectionTabs';
import { UsernameCallout } from '../components/UsernameCallout';
import { useFriendRequests } from '../hooks';
import { splitRequests } from '../people';

const TAB_IDS = ['friends', 'requests', 'find', 'blocked', 'privacy'] as const;
type FriendsTab = (typeof TAB_IDS)[number];

function isFriendsTab(value: string | null): value is FriendsTab {
  return TAB_IDS.some((id) => id === value);
}

/**
 * Friends (spec §4.15): private by default. People find each other only by
 * exact username, see only minimal profiles (name, username), and never see
 * each other's money. The tab is kept in the URL (`?tab=`, an enum only).
 */
export function FriendsPage() {
  const t = useT();
  useDocumentTitle(t('social.title'));
  const user = useCurrentUser();
  const [params, setParams] = useSearchParams();
  const requested = params.get('tab');
  const tab: FriendsTab = isFriendsTab(requested) ? requested : 'friends';
  const panelRef = useRef<HTMLDivElement>(null);
  const [focusUsername, setFocusUsername] = useState(false);
  const requests = useFriendRequests();
  const waiting = requests.data ? splitRequests(requests.data, user.id).incoming.length : 0;

  const selectTab = (next: FriendsTab) => {
    setFocusUsername(false);
    setParams(next === 'friends' ? {} : { tab: next }, { replace: true });
  };

  const tabs: SectionTab<FriendsTab>[] = [
    { id: 'friends', label: t('social.tabs.friends'), icon: 'users' },
    {
      id: 'requests',
      label: t('social.tabs.requests'),
      icon: 'inbox',
      count: { value: waiting, spoken: t('social.tabs.waiting', { count: waiting }) },
    },
    { id: 'find', label: t('social.tabs.find'), icon: 'user-plus' },
    { id: 'blocked', label: t('social.tabs.blocked'), icon: 'ban' },
    { id: 'privacy', label: t('social.tabs.privacy'), icon: 'shield' },
  ];

  let panel;
  switch (tab) {
    case 'requests':
      panel = (
        <RequestsPanel
          onFindPeople={() => {
            selectTab('find');
          }}
        />
      );
      break;
    case 'find':
      panel = (
        <FindPeoplePanel
          onShowRequests={() => {
            selectTab('requests');
          }}
        />
      );
      break;
    case 'blocked':
      panel = <BlockedMutedPanel />;
      break;
    case 'privacy':
      panel = <PrivacyPanel focusUsername={focusUsername} />;
      break;
    default:
      panel = (
        <FriendsPanel
          onFindPeople={() => {
            selectTab('find');
          }}
        />
      );
  }

  return (
    <SocialActionsProvider focusFallbackRef={panelRef}>
      <PageHeader title={t('social.title')} description={t('social.description')} />
      {user.username || tab === 'privacy' ? null : (
        <UsernameCallout
          onChoose={() => {
            selectTab('privacy');
            setFocusUsername(true);
          }}
        />
      )}
      <SectionTabs
        label={t('social.tabs.label')}
        idPrefix="friends"
        tabs={tabs}
        selected={tab}
        onSelect={selectTab}
      />
      <SectionTabPanels idPrefix="friends" tabs={tabs} selected={tab} panelRef={panelRef}>
        {panel}
      </SectionTabPanels>
    </SocialActionsProvider>
  );
}
