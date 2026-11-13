import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { helpGuidePath, helpGuidesPath, helpTopics } from '@/shared/help/guides';
import { ServiceStatusLink } from '@/shared/help/HelpGuideLink';
import { useT } from '@/shared/i18n/I18nContext';

/** The guides listed by topic on the help page, with search on the guides page. */
export function HelpGuidesCard() {
  const t = useT();
  return (
    <Card
      title={t('helpGuides.ui.title')}
      description={t('helpGuides.ui.description')}
      actions={
        <TextLink to={helpGuidesPath} className="inline-flex min-h-11 items-center gap-1.5">
          <Icon name="search" className="size-4" />
          {t('helpGuides.ui.searchAll')}
        </TextLink>
      }
    >
      <div className="grid gap-6 md:grid-cols-2">
        {helpTopics.map((topic) => (
          <section key={topic.id} aria-labelledby={`help-topic-${topic.id}`} className="space-y-2">
            <h3 id={`help-topic-${topic.id}`} className="text-base font-semibold text-fg">
              {t(`helpGuides.topic.${topic.id}`)}
            </h3>
            <ul className="space-y-1.5 text-sm">
              {topic.guides.map((id) => (
                <li key={id} className="flex gap-2">
                  <Icon name="book-open" className="mt-0.5 size-4 shrink-0 text-fg-muted" />
                  <TextLink to={helpGuidePath(id)}>{t(`helpGuides.${id}.title`)}</TextLink>
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
      <div className="mt-6 space-y-2 border-t border-line pt-4 text-sm text-fg-muted">
        <ServiceStatusLink />
        <p>
          {t('support.topics.moderation')}{' '}
          <TextLink to={paths.myModeration}>{t('support.topics.moderationLink')}</TextLink>
        </p>
      </div>
    </Card>
  );
}
