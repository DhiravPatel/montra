import { useId, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { FieldError, FieldHelp } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { TextField } from '@/shared/components/TextField';
import { useMerchant, useMerchantSearch } from '@/shared/finance/reference';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useT } from '@/shared/i18n/I18nContext';
import type { MerchantChoice } from '../formValues';

/** A chosen merchant's name (looked up when only its ID is known). */
function MerchantName({ choice }: { choice: MerchantChoice }) {
  const t = useT();
  const merchant = useMerchant(choice.name ? '' : choice.id);
  if (choice.name) return <>{choice.name}</>;
  if (merchant.data) return <>{merchant.data.name}</>;
  return <>{merchant.isPending ? t('common.loading') : t('budgets.form.merchantUnknown')}</>;
}

interface MerchantPickerProps {
  legend: string;
  help?: string;
  error?: string | undefined;
  value: readonly MerchantChoice[];
  onChange: (value: MerchantChoice[]) => void;
  /** Allow only one merchant (an allocation). */
  single?: boolean;
}

/** Search your merchants and pick one or more of them (by ID). */
export function MerchantPicker({
  legend,
  help,
  error,
  value,
  onChange,
  single = false,
}: MerchantPickerProps) {
  const t = useT();
  const id = useId();
  const [search, setSearch] = useState('');
  const debounced = useDebouncedValue(search.trim(), 250);
  const results = useMerchantSearch(debounced, debounced.length > 0);
  const chosen = new Set(value.map((choice) => choice.id));
  const suggestions = (results.data ?? [])
    .filter((merchant) => merchant.status === 'active' && !chosen.has(merchant.id))
    .slice(0, 6);
  const full = single && value.length > 0;
  const helpId = `${id}-help`;
  const errorId = `${id}-error`;
  return (
    <fieldset
      className="space-y-3"
      aria-describedby={
        [help ? helpId : null, error ? errorId : null].filter(Boolean).join(' ') || undefined
      }
    >
      <legend className="mb-1.5 text-sm font-medium text-fg">{legend}</legend>
      {help ? <FieldHelp id={helpId}>{help}</FieldHelp> : null}
      {value.length > 0 ? (
        <ul className="flex flex-wrap gap-2">
          {value.map((choice) => (
            <li
              key={choice.id}
              className="inline-flex min-h-9 items-center gap-1 rounded-full border border-line bg-surface-muted ps-3 text-sm text-fg"
            >
              <Icon name="shopping-bag" className="size-4 text-fg-muted" />
              <MerchantName choice={choice} />
              <IconButton
                icon="x"
                size="sm"
                label={t('budgets.form.merchantRemove', {
                  name: choice.name || t('budgets.form.merchantUnknown'),
                })}
                onClick={() => {
                  onChange(value.filter((item) => item.id !== choice.id));
                }}
              />
            </li>
          ))}
        </ul>
      ) : null}
      {full ? null : (
        <>
          <TextField
            label={t('budgets.form.merchantSearch')}
            type="search"
            optional
            autoComplete="off"
            maxLength={100}
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
            }}
          />
          {debounced ? (
            suggestions.length > 0 ? (
              <ul className="flex flex-wrap gap-2" aria-label={t('budgets.form.merchantMatches')}>
                {suggestions.map((merchant) => (
                  <li key={merchant.id}>
                    <Button
                      variant="secondary"
                      size="sm"
                      aria-label={t('budgets.form.merchantAdd', { name: merchant.name })}
                      onClick={() => {
                        onChange(
                          single
                            ? [{ id: merchant.id, name: merchant.name }]
                            : [...value, { id: merchant.id, name: merchant.name }],
                        );
                        setSearch('');
                      }}
                    >
                      <Icon name="plus" className="size-4" />
                      {merchant.name}
                    </Button>
                  </li>
                ))}
              </ul>
            ) : results.isFetching ? null : (
              <p role="status" className="text-sm text-fg-muted">
                {t('budgets.form.merchantNone')}
              </p>
            )
          ) : null}
        </>
      )}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </fieldset>
  );
}
