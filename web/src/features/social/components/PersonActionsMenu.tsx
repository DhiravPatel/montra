import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuSeparator, MenuTrigger } from '@/shared/components/Menu';
import { useT } from '@/shared/i18n/I18nContext';
import { useSocialActions } from '../actions/SocialActionsContext';
import type { PersonRef } from '../types';

const triggerClasses =
  'inline-flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-md border border-line-strong ' +
  'text-fg hover:bg-surface-muted';

/**
 * Mute, unmute and block for one person. Profiles say whether you muted
 * someone (`muted`), so only the opposite choice is offered; both are
 * offered when a profile does not say.
 */
export function PersonActionsMenu({ person }: { person: PersonRef }) {
  const t = useT();
  const actions = useSocialActions();
  const muted = person.muted;
  const muting = actions.isMuting(person.user_id);
  return (
    <Menu>
      <MenuTrigger
        className={triggerClasses}
        aria-label={t('social.actionsFor', { name: person.display_name })}
      >
        <Icon name="more-horizontal" />
      </MenuTrigger>
      <MenuContent label={t('social.actionsFor', { name: person.display_name })}>
        {muted === true ? null : (
          <MenuItem
            icon="bell-off"
            disabled={muting}
            onSelect={() => {
              actions.setMuted(person, true);
            }}
          >
            {t('social.mute.action')}
          </MenuItem>
        )}
        {muted === false ? null : (
          <MenuItem
            icon="bell"
            disabled={muting}
            onSelect={() => {
              actions.setMuted(person, false);
            }}
          >
            {t('social.unmute.action')}
          </MenuItem>
        )}
        <MenuSeparator />
        <MenuItem
          icon="ban"
          tone="danger"
          onSelect={() => {
            actions.confirmBlock(person);
          }}
        >
          {t('social.block.action')}
        </MenuItem>
      </MenuContent>
    </Menu>
  );
}
