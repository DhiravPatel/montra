import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/** Shown until you have a username: friends find each other by username. */
export function UsernameCallout({ onChoose }: { onChoose: () => void }) {
  const t = useT();
  return (
    <Alert tone="info" title={t('social.username.calloutTitle')} className="mb-6">
      <p>{t('social.username.calloutBody')}</p>
      <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
        <Button size="sm" variant="secondary" onClick={onChoose}>
          {t('social.username.calloutAction')}
        </Button>
        <TextLink to={paths.account}>{t('social.username.profileLink')}</TextLink>
      </div>
    </Alert>
  );
}
