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

function initials(name: string): string {
  const letters = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => Array.from(part)[0] ?? '')
    .join('');
  return letters.toUpperCase() || '?';
}

/** Account menu: security settings and sign out. */
export function UserMenu({ compact = false }: { compact?: boolean }) {
  const t = useT();
  const toast = useToast();
  const { signOut } = useAuth();
  const user = useCurrentUser();
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
        aria-label={t('userMenu.label')}
        className={cx(
          'inline-flex min-h-11 items-center gap-3 rounded-md border border-transparent text-start hover:bg-surface-muted',
          compact ? 'px-1.5' : 'w-full px-2 py-1.5',
        )}
      >
        <span
          aria-hidden="true"
          className="inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-accent-soft text-sm font-semibold text-accent"
        >
          {initials(user.display_name)}
        </span>
        {compact ? null : (
          <>
            <span className="min-w-0 flex-1">
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
