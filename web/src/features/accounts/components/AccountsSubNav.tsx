import { NavLink } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';

const tabClasses =
  'inline-flex min-h-11 items-center gap-2 border-b-4 border-transparent px-1 text-sm font-medium text-fg-muted ' +
  'hover:text-fg aria-[current=page]:border-accent aria-[current=page]:font-semibold aria-[current=page]:text-fg';

/** Accounts and payment methods are two views of the same area. */
export function AccountsSubNav() {
  const t = useT();
  return (
    <nav aria-label={t('accounts.subnav.label')} className="mb-6 border-b border-line">
      <ul className="flex gap-6">
        <li>
          <NavLink to={paths.accounts} end className={tabClasses}>
            <Icon name="wallet" className="size-4" />
            {t('accounts.subnav.accounts')}
          </NavLink>
        </li>
        <li>
          <NavLink to={paths.paymentMethods} className={tabClasses}>
            <Icon name="credit-card" className="size-4" />
            {t('accounts.subnav.paymentMethods')}
          </NavLink>
        </li>
      </ul>
    </nav>
  );
}
