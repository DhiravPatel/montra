import { type ComponentProps, useId } from 'react';
import { TextField } from '@/shared/components/TextField';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useT } from '@/shared/i18n/I18nContext';
import { useMerchantSearch } from '../reference';

interface MerchantFieldProps extends Omit<ComponentProps<'input'>, 'children' | 'list'> {
  /** Current text, used to look up suggestions. */
  search: string;
  error?: string | undefined;
}

/**
 * Free-text merchant with suggestions from your merchants. The API resolves
 * the name to an existing merchant or alias, or creates one.
 */
export function MerchantField({ search, error, ...inputProps }: MerchantFieldProps) {
  const t = useT();
  const listId = useId();
  const debounced = useDebouncedValue(search, 250);
  const suggestions = useMerchantSearch(debounced, debounced.trim().length > 0);
  const names = (suggestions.data ?? [])
    .filter((merchant) => merchant.status === 'active')
    .map((merchant) => merchant.name);
  return (
    <>
      <TextField
        label={t('finance.merchant.label')}
        help={t('finance.merchant.help')}
        optional
        maxLength={120}
        autoComplete="off"
        list={listId}
        error={error}
        {...inputProps}
      />
      <datalist id={listId}>
        {names.map((name) => (
          <option key={name} value={name} />
        ))}
      </datalist>
    </>
  );
}
