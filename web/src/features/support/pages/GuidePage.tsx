import type { ReactNode } from 'react';
import { useParams } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { guideIdFromSlug, type HelpGuideId, helpGuidesPath } from '@/shared/help/guides';
import { ServiceStatusLink } from '@/shared/help/HelpGuideLink';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { type GuideBlock, guideSections } from '../guides/content';

/** The screen each guide is about ("Where to do this"). */
const guideScreens: Readonly<Record<HelpGuideId, string>> = {
  gettingStarted: paths.accountNew,
  noBank: paths.integrations,
  balances: paths.accounts,
  budgets: paths.budgets,
  recurring: paths.bills,
  goals: paths.goals,
  groupBalances: paths.groups,
  imports: paths.imports,
  reconciliation: paths.accounts,
  privacy: paths.privacySettings,
  twoStep: paths.securitySettings,
  fairUse: paths.limits,
  troubleshooting: paths.notificationSettings,
};

/** Paragraphs as <p>, runs of list items as one <ul>. */
function Blocks({ blocks }: { blocks: readonly GuideBlock[] }) {
  const t = useT();
  const out: ReactNode[] = [];
  let items: GuideBlock[] = [];
  const flush = () => {
    if (items.length === 0) return;
    const run = items;
    items = [];
    out.push(
      <ul key={`list-${run[0]?.key ?? ''}`} className="list-disc space-y-1.5 ps-5">
        {run.map((item) => (
          <li key={item.key}>{t(item.key)}</li>
        ))}
      </ul>,
    );
  };
  for (const block of blocks) {
    if (block.kind === 'li') {
      items.push(block);
      continue;
    }
    flush();
    out.push(<p key={block.key}>{t(block.key)}</p>);
  }
  flush();
  return <>{out}</>;
}

/** One help guide (HELP-001): its sections, a contents list and the screen it is about. */
export function GuidePage() {
  const t = useT();
  const { guideId } = useParams();
  const id = guideIdFromSlug(guideId);
  useDocumentTitle(id ? t(`helpGuides.${id}.title`) : t('helpGuides.ui.title'));

  if (!id) {
    return (
      <>
        <PageHeader title={t('helpGuides.ui.title')} />
        <EmptyState
          icon="book-open"
          titleAs="h2"
          title={t('helpGuides.ui.notFound')}
          action={<ButtonLink to={helpGuidesPath}>{t('helpGuides.ui.back')}</ButtonLink>}
        />
      </>
    );
  }

  const sections = guideSections[id];
  return (
    <>
      <p className="mb-3">
        <TextLink to={helpGuidesPath} className="inline-flex min-h-11 items-center gap-1.5">
          <Icon name="arrow-left" className="size-4" />
          {t('helpGuides.ui.back')}
        </TextLink>
      </p>
      <PageHeader title={t(`helpGuides.${id}.title`)} description={t(`helpGuides.${id}.summary`)} />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_16rem] lg:items-start">
        <article className="min-w-0 space-y-6">
          {sections.map((section) => (
            <section
              key={section.id}
              id={section.id}
              aria-labelledby={`${section.id}-title`}
              className="scroll-mt-24 space-y-3 rounded-xl border border-line bg-surface p-5 text-fg shadow-card sm:p-6"
            >
              <h2 id={`${section.id}-title`} className="text-lg font-semibold">
                {t(section.title)}
              </h2>
              <div className="space-y-3 leading-relaxed text-fg-muted">
                <Blocks blocks={section.blocks} />
              </div>
            </section>
          ))}
        </article>
        <div className="space-y-4 lg:sticky lg:top-6">
          <nav aria-label={t('helpGuides.ui.onThisPage')}>
            <Card title={t('helpGuides.ui.onThisPage')}>
              <ul className="space-y-1 text-sm">
                {sections.map((section) => (
                  <li key={section.id}>
                    <a
                      href={`#${section.id}`}
                      className="inline-flex min-h-9 items-center font-medium text-accent underline underline-offset-4 decoration-1 hover:text-accent-hover"
                    >
                      {t(section.title)}
                    </a>
                  </li>
                ))}
              </ul>
            </Card>
          </nav>
          <Card title={t('helpGuides.ui.related')}>
            <ButtonLink to={guideScreens[id]} variant="secondary" className="w-full">
              {t(`helpGuides.${id}.link`)}
            </ButtonLink>
            {id === 'troubleshooting' ? <ServiceStatusLink className="mt-4" /> : null}
            <p className="mt-4 text-sm text-fg-muted">
              <TextLink to={paths.help}>{t('helpGuides.ui.contact')}</TextLink>
            </p>
          </Card>
        </div>
      </div>
    </>
  );
}
