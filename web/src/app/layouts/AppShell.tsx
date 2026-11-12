import { useId } from 'react';
import { NavLink, Outlet, matchPath, useLocation, useMatches } from 'react-router';
import { MAIN_CONTENT_ID } from '@/shared/accessibility/SkipLink';
import { ReauthProvider } from '@/shared/auth/reauth/ReauthProvider';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/shared/components/Menu';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { Logo } from './Logo';
import { type NavSection, mobileMoreItemsFor, mobileTabs, navigationFor } from './navigation';
import { NotificationBell } from '@/features/notifications/components/NotificationBell';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { HeaderSearch } from '@/features/search/components/HeaderSearch';
import { PreferencesMenu } from './PreferencesMenu';
import { UserMenu } from './UserMenu';

const sidebarLink =
  'flex min-h-11 items-center gap-3 rounded-md border-s-4 border-transparent px-3 text-sm font-medium text-fg-muted ' +
  'hover:bg-surface-muted hover:text-fg aria-[current=page]:border-accent aria-[current=page]:bg-accent-soft ' +
  'aria-[current=page]:font-semibold aria-[current=page]:text-fg';

const bottomLink =
  'flex min-h-14 flex-1 flex-col items-center justify-center gap-0.5 border-t-4 border-transparent px-2 text-xs font-medium ' +
  'text-fg-muted aria-[current=page]:border-accent aria-[current=page]:font-semibold aria-[current=page]:text-fg';

function SidebarSection({ section }: { section: NavSection }) {
  const t = useT();
  const headingId = useId();
  return (
    <div className="space-y-1">
      <p
        id={headingId}
        className="px-3 pt-3 pb-1 text-xs font-semibold tracking-wide text-fg-muted uppercase"
      >
        {t(section.labelKey)}
      </p>
      <ul aria-labelledby={headingId} className="space-y-1">
        {section.items.map((item) => (
          <li key={item.id}>
            <NavLink to={item.to} className={sidebarLink}>
              <Icon name={item.icon} />
              {t(item.labelKey)}
            </NavLink>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Small screens: the destinations that do not fit the bottom bar. */
function MoreMenu() {
  const mobileMoreItems = mobileMoreItemsFor(useCurrentUser().platform_role);
  const t = useT();
  const { pathname } = useLocation();
  const current = mobileMoreItems.some((item) =>
    matchPath({ path: item.to, end: false }, pathname),
  );
  return (
    <Menu>
      <MenuTrigger
        className={cx(
          bottomLink,
          'w-full cursor-pointer',
          current && 'border-accent font-semibold text-fg',
        )}
      >
        <Icon name="more-horizontal" />
        {t('nav.more')}
      </MenuTrigger>
      <MenuContent label={t('nav.moreMenu')}>
        {mobileMoreItems.map((item) => (
          <MenuItem key={item.id} asChild>
            <NavLink to={item.to} className="flex items-center gap-2">
              <Icon name={item.icon} className="size-4" />
              {t(item.labelKey)}
            </NavLink>
          </MenuItem>
        ))}
      </MenuContent>
    </Menu>
  );
}

/**
 * Signed-in layout: sidebar on desktop, top bar + bottom navigation on small
 * screens. The current page is marked with aria-current plus a bar and bold
 * text, not color alone.
 */
/** Routes set `handle: { wide: true }` for data-dense screens (dashboard, lists). */
function useWideLayout(): boolean {
  return useMatches().some(
    (match) =>
      typeof match.handle === 'object' &&
      match.handle !== null &&
      'wide' in match.handle &&
      match.handle.wide === true,
  );
}

export function AppShell() {
  const t = useT();
  const wide = useWideLayout();
  const sections = navigationFor(useCurrentUser().platform_role);
  return (
    <ReauthProvider>
      <div className="min-h-dvh md:flex">
        <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 flex-col border-e border-line bg-surface md:flex">
          <div className="flex items-center justify-between gap-2 px-4 py-3">
            <Logo to={paths.dashboard} />
            <NotificationBell />
          </div>
          <div className="px-3 pb-2 empty:hidden">
            <HeaderSearch />
          </div>
          <nav aria-label={t('nav.main')} className="flex-1 space-y-2 overflow-y-auto px-3 pb-2">
            {sections.map((section) => (
              <SidebarSection key={section.id} section={section} />
            ))}
          </nav>
          <div className="flex items-center gap-1 border-t border-line p-3">
            <div className="min-w-0 flex-1">
              <UserMenu />
            </div>
            <PreferencesMenu />
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-30 flex items-center justify-between border-b border-line bg-surface px-3 py-1 md:hidden">
            <Logo to={paths.dashboard} />
            <div className="flex items-center gap-1">
              <HeaderSearch compact />
              <NotificationBell compact />
              <PreferencesMenu />
              <UserMenu compact />
            </div>
          </header>
          <main
            id={MAIN_CONTENT_ID}
            tabIndex={-1}
            className="flex-1 px-4 pt-6 pb-28 outline-none sm:px-6 md:pb-12 lg:px-10 lg:pt-10"
          >
            <div className={wide ? 'mx-auto max-w-6xl' : 'mx-auto max-w-4xl'}>
              <Outlet />
            </div>
          </main>
        </div>

        <nav
          aria-label={t('nav.main')}
          className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-surface pb-[env(safe-area-inset-bottom)] md:hidden"
        >
          <ul className="flex">
            {mobileTabs.map((item) => (
              <li key={item.id} className="flex flex-1">
                <NavLink to={item.to} className={bottomLink}>
                  <Icon name={item.icon} />
                  {t(item.labelKey)}
                </NavLink>
              </li>
            ))}
            <li className="flex flex-1">
              <MoreMenu />
            </li>
          </ul>
        </nav>
      </div>
    </ReauthProvider>
  );
}
