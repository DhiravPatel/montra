import { Component, type ReactNode } from 'react';
import { browserLocales, detectLanguage, resolveFormatLocale } from '@/shared/i18n/languages';
import { createTranslator } from '@/shared/i18n/translate';

interface State {
  failed: boolean;
}

/**
 * Last-resort boundary around the providers. It cannot rely on app context,
 * so it builds its own translator. Error details are not displayed or logged
 * here (they may contain user data); React reports them in development.
 */
export class AppErrorBoundary extends Component<{ children: ReactNode }, State> {
  override state: State = { failed: false };

  static getDerivedStateFromError(): State {
    return { failed: true };
  }

  // No componentDidCatch reporting yet: add one only with a privacy-reviewed
  // error reporter (spec §16: never send personal or financial data).

  override render(): ReactNode {
    if (!this.state.failed) return this.props.children;
    const lang = detectLanguage(browserLocales());
    const t = createTranslator(lang, resolveFormatLocale(lang, browserLocales()));
    return (
      <main id="main" className="mx-auto max-w-lg px-4 py-20 text-center">
        <h1 className="text-2xl font-semibold text-fg">{t('states.crash.title')}</h1>
        <p className="mt-3 text-fg-muted">{t('states.crash.description')}</p>
        <button
          type="button"
          className="mt-6 inline-flex min-h-11 items-center rounded-md border border-transparent bg-accent px-4 text-sm font-medium text-on-accent hover:bg-accent-hover"
          onClick={() => {
            window.location.reload();
          }}
        >
          {t('states.crash.reload')}
        </button>
      </main>
    );
  }
}
