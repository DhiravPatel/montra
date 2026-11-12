import { Icon } from '@/shared/components/Icon';
import {
  Menu,
  MenuContent,
  MenuLabel,
  MenuRadioGroup,
  MenuRadioItem,
  MenuSeparator,
  MenuTrigger,
} from '@/shared/components/Menu';
import { useI18n } from '@/shared/i18n/I18nContext';
import { isSupportedLanguage, languageEndonyms, supportedLanguages } from '@/shared/i18n/languages';
import { isThemePreference, useTheme } from '@/shared/theme/ThemeContext';

/** Theme (system/light/dark) and interface language. */
export function PreferencesMenu() {
  const { t, lang, setLanguage } = useI18n();
  const { preference, setPreference } = useTheme();
  return (
    <Menu>
      <MenuTrigger
        aria-label={t('preferences.menu')}
        className="inline-flex size-11 items-center justify-center rounded-md border border-transparent text-fg-muted hover:bg-surface-muted hover:text-fg"
      >
        <Icon name={preference === 'dark' ? 'moon' : preference === 'light' ? 'sun' : 'globe'} />
      </MenuTrigger>
      <MenuContent label={t('preferences.menu')}>
        <MenuLabel>{t('preferences.theme')}</MenuLabel>
        <MenuRadioGroup
          value={preference}
          onValueChange={(value) => {
            if (isThemePreference(value)) setPreference(value);
          }}
        >
          <MenuRadioItem value="system" icon="monitor">
            {t('preferences.theme.system')}
          </MenuRadioItem>
          <MenuRadioItem value="light" icon="sun">
            {t('preferences.theme.light')}
          </MenuRadioItem>
          <MenuRadioItem value="dark" icon="moon">
            {t('preferences.theme.dark')}
          </MenuRadioItem>
        </MenuRadioGroup>
        <MenuSeparator />
        <MenuLabel>{t('preferences.language')}</MenuLabel>
        <MenuRadioGroup
          value={lang}
          onValueChange={(value) => {
            if (isSupportedLanguage(value)) setLanguage(value);
          }}
        >
          {supportedLanguages.map((code) => (
            <MenuRadioItem key={code} value={code}>
              <span lang={code}>{languageEndonyms[code]}</span>
            </MenuRadioItem>
          ))}
        </MenuRadioGroup>
      </MenuContent>
    </Menu>
  );
}
