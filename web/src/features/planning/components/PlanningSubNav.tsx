import { SubNav } from '@/shared/components/SubNav';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/** Upcoming (calendar), bills and recurring items are three views of planning. */
export function PlanningSubNav() {
  const t = useT();
  return (
    <SubNav
      label={t('planning.subnav.label')}
      items={[
        { to: paths.planning, label: t('planning.subnav.upcoming'), icon: 'calendar', end: true },
        { to: paths.bills, label: t('planning.subnav.bills'), icon: 'receipt' },
        { to: paths.recurring, label: t('planning.subnav.recurring'), icon: 'repeat' },
      ]}
    />
  );
}
