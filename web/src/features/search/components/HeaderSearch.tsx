import { type SubmitEvent, useId, useRef, useState } from 'react';
import { NavLink, useMatch, useNavigate } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { SEARCH_PAGE_INPUT_ID } from '../ids';
import { normalizeQuery, SEARCH_MAX_LENGTH, type SearchLocationState } from '../query';
import { isRendered, SEARCH_SHORTCUT, useSearchShortcut } from '../shortcut';

const fieldClasses =
  'peer block min-h-11 w-full rounded-md border border-line-strong bg-surface py-2 ps-9 pe-9 text-base text-fg ' +
  'placeholder:text-fg-muted';

const iconLinkClasses =
  'inline-flex size-11 shrink-0 items-center justify-center rounded-md border border-transparent text-fg-muted ' +
  'hover:bg-surface-muted hover:text-fg aria-[current=page]:bg-accent-soft aria-[current=page]:text-fg';

/**
 * Global search entry in the app shell: a search field in the sidebar, or
 * (compact, small-screen header) a link to the search page. "/" outside a
 * text field moves to whichever entry is visible.
 *
 * The query never goes into the URL: it travels to /search in the history
 * entry's state, so it stays out of the address bar, browser history list,
 * bookmarks, referrers and server logs.
 */
export function HeaderSearch({ compact = false }: { compact?: boolean }) {
  const t = useT();
  const navigate = useNavigate();
  const onSearchPage = useMatch(paths.search) !== null;
  const inputRef = useRef<HTMLInputElement>(null);
  const linkRef = useRef<HTMLAnchorElement>(null);
  const inputId = useId();
  const [text, setText] = useState('');

  // The search page has its own field and shortcut.
  useSearchShortcut(() => {
    if (compact) {
      if (!isRendered(linkRef.current)) return false;
      void navigate(paths.search, { state: { focus: true } satisfies SearchLocationState });
      return true;
    }
    const input = inputRef.current;
    if (!isRendered(input)) return false;
    input.focus();
    input.select();
    return true;
  }, !onSearchPage);

  if (compact) {
    return (
      <NavLink
        ref={linkRef}
        to={paths.search}
        state={{ focus: true } satisfies SearchLocationState}
        aria-label={t('search.header.open')}
        aria-keyshortcuts={SEARCH_SHORTCUT}
        className={iconLinkClasses}
        onClick={(event) => {
          // Already searching: go to the field instead of adding another history entry.
          const field = onSearchPage ? document.getElementById(SEARCH_PAGE_INPUT_ID) : null;
          if (field) {
            event.preventDefault();
            field.focus();
          }
        }}
      >
        <Icon name="search" />
      </NavLink>
    );
  }

  // On the search page its own field takes over (no second search landmark).
  if (onSearchPage) return null;

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    const q = normalizeQuery(text);
    setText('');
    const state: SearchLocationState = q ? { q, save: true } : { focus: true };
    void navigate(paths.search, { state });
  };

  return (
    <form role="search" aria-label={t('search.header.label')} onSubmit={submit}>
      <label htmlFor={inputId} className="sr-only">
        {t('search.header.label')}
      </label>
      <div className="relative">
        <Icon
          name="search"
          className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-muted"
        />
        <input
          ref={inputRef}
          id={inputId}
          type="search"
          value={text}
          onChange={(event) => {
            setText(event.target.value);
          }}
          maxLength={SEARCH_MAX_LENGTH}
          autoComplete="off"
          enterKeyHint="search"
          placeholder={t('search.header.placeholder')}
          aria-keyshortcuts={SEARCH_SHORTCUT}
          className={fieldClasses}
        />
        <kbd
          aria-hidden="true"
          className={cx(
            'pointer-events-none absolute end-2 top-1/2 -translate-y-1/2 rounded border border-line',
            'bg-surface-muted px-1.5 font-mono text-xs text-fg-muted',
            'peer-focus:hidden peer-[:not(:placeholder-shown)]:hidden',
          )}
        >
          {SEARCH_SHORTCUT}
        </kbd>
      </div>
    </form>
  );
}
