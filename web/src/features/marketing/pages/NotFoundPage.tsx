import { ButtonLink } from '@/shared/components/Button';
import { PageHeader } from '@/shared/components/PageHeader';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';

export function NotFoundPage() {
  const t = useT();
  useDocumentTitle(t('notFound.title'));
  return (
    <div className="mx-auto max-w-2xl px-4 py-16 sm:px-6">
      <PageHeader title={t('notFound.title')} description={t('notFound.description')} />
      <ButtonLink to={paths.landing} variant="secondary">
        {t('notFound.home')}
      </ButtonLink>
    </div>
  );
}
