import { useState } from 'react';
import { Link } from 'react-router';
import { useAuth, useCurrentUser } from '@/shared/auth/AuthContext';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuSeparator, MenuTrigger } from '@/shared/components/Menu';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { useAvatarPreview } from '@/features/settings/profileApi';

function initials(name: string): string {
  const letters = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => Array.from(part)[0] ?? '')
    .join('');
  return letters.toUpperCase() || '?';
}

/** Account menu: profile and preferences, security settings and sign out. */
export function UserMenu({ compact = false }: { compact?: boolean }) {
  const t = useT();
  const toast = useToast();
  const { signOut } = useAuth();
  const user = useCurrentUser();
  // The same cached data: URL as the profile screen (fetched only when there is a photo).
  const avatar = useAvatarPreview(user.avatar_file_id);
  const avatarSrc = user.avatar_file_id ? avatar.data?.src : null;
  const [signingOut, setSigningOut] = useState(false);

  const handleSignOut = () => {
    if (signingOut) return;
    setSigningOut(true);
    signOut('current')
      .catch((error: unknown) => {
        toast.show({
          tone: 'danger',
          title: t('auth.signOut.failed'),
          description: describeError(error, t),
        });
      })
      .finally(() => {
        setSigningOut(false);
      });
  };

  return (
    <Menu>
      <MenuTrigger
        // With the name and email shown, they must be part of the accessible
        // name (WCAG 2.5.3 Label in Name): "Account menu: Asha Rao asha@…".
        aria-label={compact ? t('userMenu.label') : undefined}
        className={cx(
          'inline-flex min-h-11 items-center gap-3 rounded-md border border-transparent text-start hover:bg-surface-muted',
          compact ? 'px-1.5' : 'w-full px-2 py-1.5',
        )}
      >
        {avatarSrc ? (
          // Decorative: the button is already named after the person, so the
          // photo adds no text (alt="") and the name keeps matching the label.
          <img
            src={avatarSrc}
            alt=""
            aria-hidden="true"
            className="size-8 shrink-0 rounded-full object-cover ring-1 ring-line"
          />
        ) : (
          /* Decorative initials (also the fallback while the photo loads or
             when it cannot be shown), drawn by CSS so they are not text
             content: the compact button is named only "Account menu", and
             visible text that is missing from a control's name fails WCAG
             2.5.3 Label in Name. */
          <span
            aria-hidden="true"
            data-initials={initials(user.display_name)}
            className="inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-accent-soft text-sm font-semibold text-accent before:content-[attr(data-initials)]"
          />
        )}
        {compact ? null : (
          <>
            <span className="min-w-0 flex-1">
              <span className="sr-only">{t('userMenu.label')}: </span>
              <span className="block truncate text-sm font-medium text-fg">
                {user.display_name}
              </span>
              <span className="block truncate text-xs text-fg-muted">{user.email}</span>
            </span>
            <Icon name="chevron-down" className="size-4 text-fg-muted" />
          </>
        )}
      </MenuTrigger>
      <MenuContent label={t('userMenu.label')}>
        <MenuItem asChild>
          <Link to={paths.profileSettings}>
            <Icon name="user" className="size-4" />
            {t('userMenu.profileSettings')}
          </Link>
        </MenuItem>
        <MenuItem asChild>
          <Link to={paths.securitySettings}>
            <Icon name="shield" className="size-4" />
            {t('nav.security')}
          </Link>
        </MenuItem>
        <MenuSeparator />
        <MenuItem icon="log-out" onSelect={handleSignOut} disabled={signingOut}>
          {signingOut ? t('auth.signOut.pending') : t('auth.signOut.action')}
        </MenuItem>
      </MenuContent>
    </Menu>
  );
}
