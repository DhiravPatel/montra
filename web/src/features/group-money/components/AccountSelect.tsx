import { Select } from '@/shared/components/Select';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { accountGroups } from '@/shared/finance/options';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import { useT } from '@/shared/i18n/I18nContext';

interface AccountSelectProps {
  /** Only accounts in this currency (the group currency) can hold a group record. */
  currency: string;
  label: string;
  value: string;
  onChange: (accountId: string) => void;
  help?: string;
  error?: string | undefined;
  optional?: boolean;
  /** First, empty choice (e.g. "Don't record it"). */
  placeholder?: string;
}

/**
 * One of the signed-in person's own active accounts in the group currency,
 * for their personal record of a group expense or settlement. Other
 * members' accounts and records are never shown.
 */
export function AccountSelect({
  currency,
  label,
  value,
  onChange,
  help,
  error,
  optional,
  placeholder,
}: AccountSelectProps) {
  const t = useT();
  const accounts = useAccounts();
  if (accounts.isPending) {
    return <p className="text-sm text-fg-muted">{t('groupMoney.account.loading')}</p>;
  }
  if (accounts.isError) {
    return <p className="text-sm text-fg-muted">{t('groupMoney.account.loadError')}</p>;
  }
  const choices = writableAccounts(accounts.data).filter(
    (account) => account.currency === currency,
  );
  if (choices.length === 0) {
    return (
      <p className="text-sm text-fg-muted">
        {t('groupMoney.account.none', { currency })}{' '}
        <TextLink to={paths.accountNew}>{t('groupMoney.account.add')}</TextLink>
      </p>
    );
  }
  return (
    <Select
      label={label}
      optional={optional}
      placeholder={placeholder}
      groups={accountGroups(choices, t)}
      value={value}
      help={help}
      error={error}
      onChange={(event) => {
        onChange(event.target.value);
      }}
    />
  );
}
