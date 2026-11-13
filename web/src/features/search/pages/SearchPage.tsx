import { type SubmitEvent, useEffect, useId, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { Spinner } from '@/shared/components/Spinner';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { SavedFilters } from '@/shared/savedFilters/SavedFilters';
import { useT } from '@/shared/i18n/I18nContext';
import { useSearchResults } from '../api';
import { RecentSearches } from '../components/RecentSearches';
import { SearchResultSections } from '../components/SearchResultSections';
import { SEARCH_PAGE_INPUT_ID, sectionHeadingId } from '../ids';
import { scopeLabel, sortLabel } from '../labels';
import {
  fromSavedSearch,
  isSearchable,
  isSearchScope,
  isSearchSort,
  limitFor,
  normalizeQuery,
  queryLength,
  readSearchState,
  resultCount,
  SEARCH_DEBOUNCE_MS,
  SEARCH_MAX_LENGTH,
  SEARCH_MIN_LENGTH,
  SEARCH_SECTIONS,
  SEARCH_SORTS,
  type SavedSearch,
  type SearchLocationState,
  toSavedSearch,
} from '../query';
import { SEARCH_SHORTCUT, useSearchShortcut } from '../shortcut';
import type { RecentSearch, SearchRequest, SearchScope, SearchSection, SearchSort } from '../types';

/** The query being searched: typing searches after a pause; submitting also remembers it. */
interface ActiveQuery {
  q: string;
  save: boolean;
}

interface Initial {
  text: string;
  scope: SearchScope;
  sort: SearchSort;
  save: boolean;
  focus: boolean;
}

/** Reads the search handed over in history state (or an old `?q=` link, moved out of the URL below). */
function readInitial(state: unknown, search: string): Initial {
  const incoming = readSearchState(state);
  const params = new URLSearchParams(search);
  const legacyScope = params.get('scope');
  const text = incoming.q ?? params.get('q')?.slice(0, SEARCH_MAX_LENGTH) ?? '';
  return {
    text,
    scope: incoming.scope ?? (isSearchScope(legacyScope) ? legacyScope : 'all'),
    sort: incoming.sort ?? 'relevance',
    save: incoming.save === true,
    focus: incoming.focus === true,
  };
}

/** Focuses after the route announcer has moved focus to the page heading. */
function focusSoon(element: () => HTMLElement | null): () => void {
  let frame = window.requestAnimationFrame(() => {
    frame = window.requestAnimationFrame(() => {
      element()?.focus();
    });
  });
  return () => {
    window.cancelAnimationFrame(frame);
  };
}

/**
 * Global search (spec §4.20): results from GET /search grouped by type,
 * recent searches, and clearing them. The query is personal text: it lives
 * in component state and the history entry's state (so Back restores it),
 * never in the URL, the document title, logs or browser storage.
 */
export function SearchPage() {
  const t = useT();
  useDocumentTitle(t('search.title'));
  const location = useLocation();
  const navigate = useNavigate();
  const announce = useAnnounce();
  const inputRef = useRef<HTMLInputElement>(null);
  const helpId = useId();
  const [initial] = useState(() => readInitial(location.state, location.search));
  const [text, setText] = useState(initial.text);
  const [scope, setScope] = useState<SearchScope>(initial.scope);
  const [sort, setSort] = useState<SearchSort>(initial.sort);
  const [active, setActive] = useState<ActiveQuery>(() => ({
    q: normalizeQuery(initial.text),
    save: initial.save,
  }));
  // A new object per request, so asking twice for the same section still moves focus.
  const [showMoreFocus, setShowMoreFocus] = useState<{ section: SearchSection } | null>(null);

  const request: SearchRequest | null = isSearchable(active.q)
    ? { q: active.q, scope, limit: limitFor(scope), sort, save: active.save }
    : null;
  const results = useSearchResults(request);

  // Typing searches once the person pauses (earlier requests are aborted).
  useEffect(() => {
    const next = normalizeQuery(text);
    if (next === active.q) return;
    const timer = window.setTimeout(() => {
      setActive((previous) => (previous.q === next ? previous : { q: next, save: false }));
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      window.clearTimeout(timer);
    };
  }, [text, active.q]);

  // Keep the search in this history entry (Back/Forward restore it), never in the URL.
  useEffect(() => {
    const current = readSearchState(location.state);
    const synced =
      location.search === '' &&
      (current.q ?? '') === active.q &&
      (current.scope ?? 'all') === scope &&
      (current.sort ?? 'relevance') === sort &&
      current.save === undefined &&
      current.focus === undefined;
    if (synced) return;
    const state: SearchLocationState = {
      q: active.q,
      scope,
      ...(sort === 'relevance' ? {} : { sort }),
    };
    void navigate(paths.search, { replace: true, state, preventScrollReset: true });
  }, [active.q, scope, sort, location.search, location.state, navigate]);

  // Arriving from the search icon or the "/" key: start in the field.
  useEffect(() => {
    if (!initial.focus) return;
    return focusSoon(() => inputRef.current);
  }, [initial.focus]);

  // After "Show more", continue at that section's heading.
  useEffect(() => {
    if (!showMoreFocus) return;
    const { section } = showMoreFocus;
    return focusSoon(() => document.getElementById(sectionHeadingId(section)));
  }, [showMoreFocus]);

  useSearchShortcut(() => {
    const input = inputRef.current;
    if (!input) return false;
    input.focus();
    input.select();
    return true;
  });

  // Tell screen readers how many results the current search found.
  const ready = request !== null && results.isSuccess && !results.isPlaceholderData;
  const total = results.data ? resultCount(results.data) : 0;
  const requestKey = request ? JSON.stringify(request) : '';
  const announced = useRef('');
  useEffect(() => {
    if (!ready) return;
    const id = `${requestKey}|${String(results.dataUpdatedAt)}`;
    if (announced.current === id) return;
    announced.current = id;
    announce(
      total === 0 ? t('search.empty.announce') : t('search.results.announce', { count: total }),
    );
  }, [ready, requestKey, results.dataUpdatedAt, total, announce, t]);

  // Changing what or how to search runs the search again without remembering it twice.
  const stopSaving = () => {
    setActive((previous) => (previous.save ? { q: previous.q, save: false } : previous));
  };

  const changeScope = (next: SearchScope) => {
    setScope(next);
    stopSaving();
  };

  const changeSort = (next: SearchSort) => {
    setSort(next);
    stopSaving();
  };

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    const q = normalizeQuery(text);
    if (!isSearchable(q)) {
      inputRef.current?.focus();
      return;
    }
    setActive({ q, save: true });
  };

  const runRecent = (recent: RecentSearch) => {
    const q = normalizeQuery(recent.query);
    setText(q);
    setScope(isSearchScope(recent.scope) ? recent.scope : 'all');
    setActive({ q, save: true });
    inputRef.current?.focus();
  };

  // Running a saved search remembers it in recent searches, like submitting it.
  const runSaved = (saved: SavedSearch) => {
    setText(saved.q);
    setScope(saved.scope);
    setSort(saved.sort);
    setActive({ q: saved.q, save: true });
  };

  const showMore = (section: SearchSection) => {
    changeScope(section);
    setShowMoreFocus({ section });
  };

  const typed = normalizeQuery(text);
  const tooShort = typed !== '' && queryLength(typed) < SEARCH_MIN_LENGTH;

  let content;
  if (request === null) {
    content = (
      <RecentSearches
        onRun={runRecent}
        onCleared={() => {
          inputRef.current?.focus();
        }}
      />
    );
  } else if (results.isError) {
    content = hasErrorCode(results.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h2" />
    ) : (
      <ErrorState
        titleAs="h2"
        title={t('search.error')}
        error={results.error}
        retrying={results.isFetching}
        onRetry={() => {
          void results.refetch();
        }}
      />
    );
  } else if (!results.data) {
    content = <LoadingState label={t('search.loading')} />;
  } else {
    const data = results.data;
    const count = resultCount(data);
    content = (
      <div aria-busy={results.isPlaceholderData || undefined} className="space-y-4">
        <div className="flex flex-wrap items-center gap-3 text-sm text-fg-muted">
          <p>{t('search.results.summary', { count, query: data.query })}</p>
          {isSearchSort(data.sort) && data.sort !== 'relevance' ? (
            <p>{t('search.results.sortedBy', { order: t(sortLabel[data.sort]) })}</p>
          ) : null}
          {results.isPlaceholderData ? (
            <p className="inline-flex items-center gap-2">
              <Spinner size="sm" />
              {t('search.updating')}
            </p>
          ) : null}
        </div>
        {count === 0 ? (
          <EmptyState
            icon="search"
            titleAs="h2"
            title={t('search.empty.title', { query: data.query })}
            description={t('search.empty.body')}
            action={
              scope === 'all' ? null : (
                <Button
                  variant="secondary"
                  onClick={() => {
                    changeScope('all');
                  }}
                >
                  {t('search.empty.searchEverything')}
                </Button>
              )
            }
          />
        ) : (
          <SearchResultSections results={data} scope={scope} onShowMore={showMore} />
        )}
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title={t('search.title')}
        description={t('search.description')}
        actions={
          <SavedFilters
            scope="search"
            current={toSavedSearch(text, scope, sort) as Readonly<Record<string, unknown>> | null}
            parse={fromSavedSearch}
            onApply={runSaved}
          />
        }
      />
      <form
        role="search"
        aria-label={t('search.form.label')}
        onSubmit={submit}
        className="mb-6 rounded-xl border border-line bg-surface p-4 shadow-card sm:p-5"
      >
        <div className="flex flex-col gap-3 md:flex-row md:items-end">
          <div className="min-w-0 flex-1 space-y-1.5">
            <label htmlFor={SEARCH_PAGE_INPUT_ID} className="block text-sm font-medium text-fg">
              {t('search.field.label')}
            </label>
            <div className="relative">
              <Icon
                name="search"
                className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-fg-muted"
              />
              <input
                ref={inputRef}
                id={SEARCH_PAGE_INPUT_ID}
                type="search"
                value={text}
                onChange={(event) => {
                  setText(event.target.value);
                }}
                maxLength={SEARCH_MAX_LENGTH}
                autoComplete="off"
                enterKeyHint="search"
                spellCheck={false}
                placeholder={t('search.field.placeholder')}
                aria-describedby={helpId}
                aria-keyshortcuts={SEARCH_SHORTCUT}
                className="block min-h-11 w-full rounded-md border border-line-strong bg-surface py-2 ps-10 pe-3 text-base text-fg placeholder:text-fg-muted"
              />
            </div>
          </div>
          <Select
            label={t('search.scope.label')}
            value={scope}
            onChange={(event) => {
              const next = event.target.value;
              if (isSearchScope(next)) changeScope(next);
            }}
            options={(['all', ...SEARCH_SECTIONS] as const).map((value) => ({
              value,
              label: t(scopeLabel[value]),
            }))}
            className="md:w-56"
          />
          <Select
            label={t('search.sort.label')}
            value={sort}
            onChange={(event) => {
              const next = event.target.value;
              if (isSearchSort(next)) changeSort(next);
            }}
            options={SEARCH_SORTS.map((value) => ({ value, label: t(sortLabel[value]) }))}
            className="md:w-44"
          />
          <Button type="submit">
            <Icon name="search" className="size-4" />
            {t('search.submit')}
          </Button>
        </div>
        <p id={helpId} className="mt-2 text-sm text-fg-muted">
          {tooShort ? t('search.tooShort') : t('search.field.help')}
        </p>
      </form>
      {content}
    </>
  );
}
