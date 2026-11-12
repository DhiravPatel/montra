import { Outlet, ScrollRestoration } from 'react-router';
import { RouteAnnouncer } from '@/shared/accessibility/RouteAnnouncer';
import { SkipLink } from '@/shared/accessibility/SkipLink';

export function RootLayout() {
  return (
    <>
      <SkipLink />
      <RouteAnnouncer />
      <ScrollRestoration />
      <Outlet />
    </>
  );
}
