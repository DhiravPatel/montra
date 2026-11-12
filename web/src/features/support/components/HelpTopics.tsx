import type { ReactNode } from 'react';
import { Card } from '@/shared/components/Card';
import { Icon, type IconName } from '@/shared/components/Icon';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

interface Topic {
  id: string;
  icon: IconName;
  title: string;
  body: ReactNode;
  link: { to: string; label: string };
}

/** Short answers to the questions people ask most, each linking to the page it is about. */
export function HelpTopics() {
  const t = useT();
  const topics: Topic[] = [
    {
      id: 'money',
      icon: 'scale',
      title: t('support.topics.money.title'),
      body: (
        <ul className="list-disc space-y-1 ps-5">
          <li>{t('dashboard.notes.transfers')}</li>
          <li>{t('dashboard.notes.refunds')}</li>
          <li>{t('dashboard.notes.currencies')}</li>
          <li>{t('dashboard.notes.tracked')}</li>
        </ul>
      ),
      link: { to: paths.analytics, label: t('support.topics.money.link') },
    },
    {
      id: 'privacy',
      icon: 'lock',
      title: t('support.topics.privacy.title'),
      body: <p>{t('support.topics.privacy.body')}</p>,
      link: { to: paths.privacySettings, label: t('support.topics.privacy.link') },
    },
    {
      id: 'imports',
      icon: 'upload',
      title: t('support.topics.imports.title'),
      body: <p>{t('imports.description')}</p>,
      link: { to: paths.imports, label: t('support.topics.imports.link') },
    },
    {
      id: 'groups',
      icon: 'users',
      title: t('support.topics.groups.title'),
      body: <p>{t('groups.description')}</p>,
      link: { to: paths.groups, label: t('support.topics.groups.link') },
    },
  ];
  return (
    <Card title={t('support.topics.title')} description={t('support.topics.description')}>
      <ul className="grid gap-6 md:grid-cols-2">
        {topics.map((topic) => (
          <li key={topic.id} className="flex gap-3">
            <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
              <Icon name={topic.icon} className="size-5" />
            </span>
            <div className="min-w-0 space-y-2 text-sm text-fg-muted">
              <h3 className="text-base font-semibold text-fg">{topic.title}</h3>
              {topic.body}
              <p>
                <TextLink to={topic.link.to}>{topic.link.label}</TextLink>
              </p>
            </div>
          </li>
        ))}
      </ul>
      <p className="mt-6 border-t border-line pt-4 text-sm text-fg-muted">
        {t('support.topics.limits')}{' '}
        <TextLink to={paths.limits}>{t('support.topics.limitsLink')}</TextLink>
      </p>
      <p className="mt-2 text-sm text-fg-muted">
        {t('support.topics.moderation')}{' '}
        <TextLink to={paths.myModeration}>{t('support.topics.moderationLink')}</TextLink>
      </p>
    </Card>
  );
}
