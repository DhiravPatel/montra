import { NavLink, Outlet } from 'react-router';
import { MAIN_CONTENT_ID } from '@/shared/accessibility/SkipLink';
import { useAuth } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { defaultSignedInPath, paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { Logo } from './Logo';
import { PreferencesMenu } from './PreferencesMenu';
import { SiteFooter } from './SiteFooter';

const navLinkClasses =
  'rounded-md px-1 py-2 text-sm font-medium text-fg-muted hover:text-fg aria-[current=page]:text-fg aria-[current=page]:underline aria-[current=page]:underline-offset-8';

/** Layout for public pages: landing, information pages and auth flows. */
export function PublicLayout() {
  const t = useT();
  const { status } = useAuth();
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="border-b border-line bg-surface">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-2 sm:px-6">
          <Logo to={paths.landing} />
          <nav aria-label={t('nav.public')} className="hidden md:block">
            <ul className="flex items-center gap-6">
              <li>
                <NavLink to={paths.privacy} className={navLinkClasses}>
                  {t('nav.privacy')}
                </NavLink>
              </li>
              <li>
                <NavLink to={paths.securityInfo} className={navLinkClasses}>
                  {t('nav.securityInfo')}
                </NavLink>
              </li>
            </ul>
          </nav>
          <div className="flex items-center gap-1 sm:gap-2">
            <PreferencesMenu />
            {status === 'authenticated' ? (
              <ButtonLink to={defaultSignedInPath} size="sm">
                {t('nav.goToAccount')}
              </ButtonLink>
            ) : (
              <>
                <ButtonLink to={paths.signIn} variant="ghost" size="sm">
                  {t('nav.signIn')}
                </ButtonLink>
                {/* Hidden on small screens, where the page itself offers sign-up. */}
                <span className="hidden sm:block">
                  <ButtonLink to={paths.signUp} size="sm">
                    {t('nav.signUp')}
                  </ButtonLink>
                </span>
              </>
            )}
          </div>
        </div>
      </header>
      <main id={MAIN_CONTENT_ID} tabIndex={-1} className="flex-1 outline-none">
        <Outlet />
      </main>
      <SiteFooter />
    </div>
  );
}
