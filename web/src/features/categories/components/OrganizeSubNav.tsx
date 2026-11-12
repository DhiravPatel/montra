import { SubNav } from '@/shared/components/SubNav';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

/** Categories, rules, tags and merchants are four views of one "organize" area. */
export function OrganizeSubNav() {
  const t = useT();
  return (
    <SubNav
      label={t('organize.subnav.label')}
      items={[
        { to: paths.categories, label: t('organize.subnav.categories'), icon: 'folder', end: true },
        { to: paths.categoryRules, label: t('organize.subnav.rules'), icon: 'sliders' },
        { to: paths.tags, label: t('organize.subnav.tags'), icon: 'tag' },
        { to: paths.merchants, label: t('organize.subnav.merchants'), icon: 'shopping-bag' },
      ]}
    />
  );
}
