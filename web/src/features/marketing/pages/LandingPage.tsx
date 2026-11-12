import { useAuth } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Icon, type IconName } from '@/shared/components/Icon';
import { defaultSignedInPath, paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';

const principles: readonly { icon: IconName; title: MessageKey; body: MessageKey }[] = [
  {
    icon: 'check-circle',
    title: 'landing.principle.free.title',
    body: 'landing.principle.free.body',
  },
  {
    icon: 'lock',
    title: 'landing.principle.private.title',
    body: 'landing.principle.private.body',
  },
  { icon: 'key', title: 'landing.principle.manual.title', body: 'landing.principle.manual.body' },
  {
    icon: 'shield-check',
    title: 'landing.principle.secure.title',
    body: 'landing.principle.secure.body',
  },
];

export function LandingPage() {
  const t = useT();
  const { status } = useAuth();
  useDocumentTitle(t('landing.documentTitle'));

  return (
    <div>
      <section className="border-b border-line bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 lg:py-24">
          <p className="text-sm font-semibold uppercase tracking-wide text-accent">
            {t('landing.eyebrow')}
          </p>
          <h1
            tabIndex={-1}
            data-page-heading=""
            className="mt-3 max-w-3xl text-4xl font-semibold tracking-tight text-fg outline-none sm:text-5xl"
          >
            {t('landing.title')}
          </h1>
          <p className="mt-5 max-w-2xl text-lg text-fg-muted">{t('landing.subtitle')}</p>
          <div className="mt-8 flex flex-wrap gap-3">
            {status === 'authenticated' ? (
              <ButtonLink to={defaultSignedInPath}>{t('nav.goToAccount')}</ButtonLink>
            ) : (
              <>
                <ButtonLink to={paths.signUp}>{t('landing.cta.signUp')}</ButtonLink>
                <ButtonLink to={paths.signIn} variant="secondary">
                  {t('nav.signIn')}
                </ButtonLink>
              </>
            )}
          </div>
        </div>
      </section>

      <section
        aria-labelledby="principles-heading"
        className="mx-auto max-w-6xl px-4 py-14 sm:px-6"
      >
        <h2 id="principles-heading" className="text-2xl font-semibold text-fg">
          {t('landing.principles.title')}
        </h2>
        <ul className="mt-8 grid gap-6 sm:grid-cols-2">
          {principles.map((item) => (
            <li
              key={item.title}
              className="flex gap-4 rounded-xl border border-line bg-surface p-5 shadow-card"
            >
              <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-accent-soft text-accent">
                <Icon name={item.icon} />
              </span>
              <div>
                <h3 className="font-semibold text-fg">{t(item.title)}</h3>
                <p className="mt-1 text-sm text-fg-muted">{t(item.body)}</p>
              </div>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="status-heading" className="mx-auto max-w-6xl px-4 pb-16 sm:px-6">
        <div className="rounded-xl border border-line bg-surface-muted p-6">
          <h2 id="status-heading" className="text-lg font-semibold text-fg">
            {t('landing.status.title')}
          </h2>
          <p className="mt-2 max-w-3xl text-fg-muted">{t('landing.status.body')}</p>
        </div>
      </section>
    </div>
  );
}
