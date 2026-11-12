import type { SelectGroup, SelectOption } from '@/shared/components/Select';
import type { Translate } from '@/shared/i18n/types';
import { categoryName, categoryTree } from './categories';
import {
  ACCOUNT_TYPES,
  accountTypeGroupLabel,
  isPaymentNetwork,
  networkLabel,
  paymentKindLabel,
} from './labels';
import type { Account, Category, PaymentMethod } from './types';

/** "HDFC Credit ••4821 (INR)": enough to tell accounts apart without balances. */
export function accountOptionLabel(account: Account): string {
  const masked = account.masked_number ? ` ••${account.masked_number}` : '';
  return `${account.name}${masked} (${account.currency})`;
}

/** Accounts grouped by type for a select, in the API's display order. */
export function accountGroups(accounts: readonly Account[], t: Translate): SelectGroup[] {
  const byOrder = [...accounts].sort(
    (a, b) => a.display_order - b.display_order || a.name.localeCompare(b.name),
  );
  const known = new Set<string>(ACCOUNT_TYPES);
  const groups: SelectGroup[] = ACCOUNT_TYPES.map((type) => ({
    label: t(accountTypeGroupLabel[type]),
    options: byOrder
      .filter((account) => account.account_type === type)
      .map((account) => ({ value: account.id, label: accountOptionLabel(account) })),
  }));
  const others = byOrder.filter((account) => !known.has(account.account_type));
  if (others.length > 0) {
    groups.push({
      label: t('finance.accountGroup.custom'),
      options: others.map((account) => ({ value: account.id, label: accountOptionLabel(account) })),
    });
  }
  return groups.filter((group) => group.options.length > 0);
}

/** Categories as "Parent" and "Parent › Child" options (selectable at both levels). */
export function categoryOptions(
  categories: readonly Category[],
  t: Translate,
  locale: string,
  filter?: (category: Category) => boolean,
): SelectOption[] {
  const options: SelectOption[] = [];
  for (const node of categoryTree(categories, t, locale, filter)) {
    const parent = categoryName(node.category, t);
    options.push({ value: node.category.id, label: parent });
    for (const child of node.children) {
      options.push({ value: child.id, label: `${parent} › ${categoryName(child, t)}` });
    }
  }
  return options;
}

export function paymentMethodLabel(method: PaymentMethod, t: Translate): string {
  const network = method.network
    ? isPaymentNetwork(method.network)
      ? t(networkLabel[method.network])
      : method.network
    : null;
  const details = [network, method.masked_hint ?? null].filter(Boolean);
  return details.length > 0 ? `${method.label} (${details.join(' ')})` : method.label;
}

export function paymentMethodOptions(
  methods: readonly PaymentMethod[],
  t: Translate,
): SelectOption[] {
  return methods
    .filter((method) => !method.archived_at)
    .map((method) => ({
      value: method.id,
      label: `${paymentMethodLabel(method, t)} · ${t(paymentKindLabel[method.kind])}`,
    }));
}
