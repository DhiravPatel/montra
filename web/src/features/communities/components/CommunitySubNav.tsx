import { SubNav } from '@/shared/components/SubNav';
import {
  communityModerationPath,
  communityPath,
  communitySettingsPath,
} from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/**
 * Tabs between a community's pages, for its owner, moderators and Montra
 * staff. Links keep the reference of the current address (ID or URL name)
 * so the current tab is marked.
 */
export function CommunitySubNav({ communityRef }: { communityRef: string }) {
  const t = useT();
  return (
    <SubNav
      label={t('communities.nav.label')}
      items={[
        {
          to: communityPath(communityRef),
          label: t('communities.nav.posts'),
          icon: 'message-square',
          end: true,
        },
        {
          to: communitySettingsPath(communityRef),
          label: t('communities.nav.settings'),
          icon: 'sliders',
        },
        {
          to: communityModerationPath(communityRef),
          label: t('communities.nav.moderation'),
          icon: 'shield',
        },
      ]}
    />
  );
}
