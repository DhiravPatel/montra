import { Outlet } from 'react-router';
import { MAIN_CONTENT_ID } from '@/shared/accessibility/SkipLink';
import { paths } from '@/shared/config/paths';
import { Logo } from './Logo';
import { PreferencesMenu } from './PreferencesMenu';
import { UserMenu } from './UserMenu';

/** Signed-in layout without the main navigation, for guided flows such as onboarding. */
export function FocusLayout() {
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="border-b border-line bg-surface">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-3 px-4 py-1 sm:px-6">
          <Logo to={paths.dashboard} />
          <div className="flex items-center gap-1">
            <PreferencesMenu />
            <UserMenu compact />
          </div>
        </div>
      </header>
      <main
        id={MAIN_CONTENT_ID}
        tabIndex={-1}
        className="flex-1 px-4 pt-6 pb-16 outline-none sm:px-6 lg:pt-10"
      >
        <Outlet />
      </main>
    </div>
  );
}
