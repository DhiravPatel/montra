import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router';
import { MAIN_CONTENT_ID } from './SkipLink';
import { useAnnounce } from './AnnouncerContext';

/**
 * On client-side navigation, announces the new page title and moves focus
 * to the page heading (or main region) so keyboard and screen-reader users
 * start at the new content. The first render keeps the browser default.
 */
export function RouteAnnouncer() {
  const { pathname } = useLocation();
  const announce = useAnnounce();
  const previous = useRef<string | null>(null);

  useEffect(() => {
    if (previous.current === null) {
      previous.current = pathname;
      return;
    }
    if (previous.current === pathname) return;
    previous.current = pathname;
    // Wait a frame so the new page has rendered and set its title.
    const frame = window.requestAnimationFrame(() => {
      const target =
        document.querySelector<HTMLElement>('[data-page-heading]') ??
        document.getElementById(MAIN_CONTENT_ID);
      target?.focus({ preventScroll: true });
      announce(document.title);
    });
    return () => {
      window.cancelAnimationFrame(frame);
    };
  }, [pathname, announce]);

  return null;
}
