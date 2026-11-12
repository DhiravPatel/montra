import { SubNav } from '@/shared/components/SubNav';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/** Your subscriptions and the ones found in your transactions. */
export function SubscriptionsSubNav() {
  const t = useT();
  return (
    <SubNav
      label={t('subscriptions.subnav.label')}
      items={[
        {
          to: paths.subscriptions,
          label: t('subscriptions.subnav.list'),
          icon: 'repeat',
          end: true,
        },
        {
          to: paths.subscriptionReview,
          label: t('subscriptions.subnav.review'),
          icon: 'search',
        },
      ]}
    />
  );
}
