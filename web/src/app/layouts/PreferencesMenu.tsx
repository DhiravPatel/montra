import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { useAuth } from '@/shared/auth/AuthContext';
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
import { useToast } from '@/shared/components/toast/ToastContext';
import { preferencesQueryKey } from '@/shared/finance/keys';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { isSupportedLanguage, languageEndonyms, supportedLanguages } from '@/shared/i18n/languages';
import { isThemePreference, type ThemePreference, useTheme } from '@/shared/theme/ThemeContext';

/**
 * Signed in, the theme is an account preference: save it so every device
 * follows it (see AccountDisplayPreferences). Signed out, it stays on this
 * device only.
 */
function useSaveTheme() {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const { status } = useAuth();
  const save = useMutation({
    mutationFn: (theme: ThemePreference) =>
      apiData(api.PATCH('/me/preferences', { body: { theme } })),
    onSuccess: (preferences) => {
      queryClient.setQueryData(preferencesQueryKey, preferences);
    },
    onError: (error) => {
      toast.show({
        tone: 'warning',
        title: t('preferences.themeNotSaved'),
        description: describeError(error, t),
      });
    },
  });
  return (theme: ThemePreference) => {
    if (status === 'authenticated') save.mutate(theme);
  };
}

/** Theme (system/light/dark) and interface language. */
export function PreferencesMenu() {
  const { t, lang, setLanguage } = useI18n();
  const { preference, setPreference } = useTheme();
  const saveTheme = useSaveTheme();
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
            if (!isThemePreference(value) || value === preference) return;
            setPreference(value);
            saveTheme(value);
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
