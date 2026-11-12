import { useT } from '@/shared/i18n/I18nContext';

export const MAIN_CONTENT_ID = 'main';

/** First focusable element on every page; jumps keyboard users past navigation. */
export function SkipLink() {
  const t = useT();
  return (
    <a
      href={`#${MAIN_CONTENT_ID}`}
      onClick={(event) => {
        const main = document.getElementById(MAIN_CONTENT_ID);
        if (!main) return;
        event.preventDefault();
        main.focus();
        main.scrollIntoView();
      }}
      className="sr-only rounded-md bg-surface px-4 py-3 font-medium text-fg shadow-overlay focus:not-sr-only focus:fixed focus:start-4 focus:top-4 focus:z-[60]"
    >
      {t('a11y.skipToContent')}
    </a>
  );
}
