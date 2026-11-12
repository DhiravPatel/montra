import { Icon } from '@/shared/components/Icon';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/** Back to the challenges list. */
export function BackToChallenges() {
  const t = useT();
  return (
    <p className="mb-2">
      <TextLink to={paths.challenges}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {t('challenges.backToList')}
      </TextLink>
    </p>
  );
}
