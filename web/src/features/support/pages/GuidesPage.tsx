import { useEffect, useMemo, useRef, useState } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { type HelpGuideId, helpGuidePath, helpTopics } from '@/shared/help/guides';
import { ServiceStatusLink } from '@/shared/help/HelpGuideLink';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { searchGuides, searchWords } from '../guides/search';

function GuideItem({ id }: { id: HelpGuideId }) {
  const { t } = useI18n();
  return (
    <li className="space-y-1 py-3">
      <TextLink to={helpGuidePath(id)} className="text-base">
        {t(`helpGuides.${id}.title`)}
      </TextLink>
      <p className="text-sm text-fg-muted">{t(`helpGuides.${id}.summary`)}</p>
    </li>
  );
}

/** All help guides, listed by topic and searchable by their text in the interface language. */
export function GuidesPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('helpGuides.ui.browseTitle'));
  const announce = useAnnounce();
  const [query, setQuery] = useState('');
  const debounced = useDebouncedValue(query, 200);
  const searching = searchWords(debounced, formatLocale).length > 0;
  const matches = useMemo(
    () => searchGuides(debounced, t, formatLocale),
    [debounced, t, formatLocale],
  );

  const announced = useRef('');
  useEffect(() => {
    if (!searching) {
      announced.current = '';
      return;
    }
    const message =
      matches.length === 0
        ? t('helpGuides.ui.noResults', { query: debounced.trim() })
        : t('helpGuides.ui.resultCount', { count: matches.length });
    if (announced.current === message) return;
    announced.current = message;
    announce(message);
  }, [searching, matches.length, debounced, announce, t]);

  let content;
  if (!searching) {
    content = (
      <div className="space-y-6">
        {helpTopics.map((topic) => (
          <Card key={topic.id} title={t(`helpGuides.topic.${topic.id}`)}>
            <ul className="-my-3 divide-y divide-line">
              {topic.guides.map((id) => (
                <GuideItem key={id} id={id} />
              ))}
            </ul>
          </Card>
        ))}
      </div>
    );
  } else if (matches.length === 0) {
    content = (
      <EmptyState
        icon="search"
        titleAs="h2"
        title={t('helpGuides.ui.noResults', { query: debounced.trim() })}
        action={<TextLink to={paths.help}>{t('helpGuides.ui.contact')}</TextLink>}
      />
    );
  } else {
    content = (
      <Card title={t('helpGuides.ui.resultCount', { count: matches.length })}>
        <ul className="-my-3 divide-y divide-line">
          {matches.map((id) => (
            <GuideItem key={id} id={id} />
          ))}
        </ul>
      </Card>
    );
  }

  return (
    <>
      <PageHeader
        title={t('helpGuides.ui.browseTitle')}
        description={t('helpGuides.ui.description')}
      />
      <div role="search" className="mb-6 max-w-xl">
        <TextField
          type="search"
          label={t('helpGuides.ui.search')}
          help={t('helpGuides.ui.searchHelp')}
          value={query}
          maxLength={100}
          autoComplete="off"
          onChange={(event) => {
            setQuery(event.target.value);
          }}
        />
      </div>
      {content}
      <div className="mt-6 space-y-2">
        <ServiceStatusLink />
        <p className="text-sm text-fg-muted">
          <TextLink to={paths.help}>{t('helpGuides.ui.contact')}</TextLink>
        </p>
      </div>
    </>
  );
}
