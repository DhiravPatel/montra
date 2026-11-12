import { useId, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { Select } from '@/shared/components/Select';
import { TextField } from '@/shared/components/TextField';
import { currencyOptions, exponentFor, useCurrencies } from '@/shared/currency/api';
import { categoryName } from '@/shared/finance/categories';
import { DateRangeFields } from '@/shared/finance/components/DateRangeFields';
import {
  TRANSACTION_TYPES,
  sortLabel,
  transactionSourceLabel,
  transactionTypeLabel,
} from '@/shared/finance/labels';
import { accountGroups, categoryOptions, paymentMethodLabel } from '@/shared/finance/options';
import {
  useAccounts,
  useCategories,
  useMerchant,
  useMerchantSearch,
  usePaymentMethods,
  useTags,
} from '@/shared/finance/reference';
import type { TransactionType } from '@/shared/finance/types';
import { decimalIssueMessage } from '@/shared/forms/decimalField';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { useDebouncedValue } from '@/shared/hooks/useDebouncedValue';
import { useI18n } from '@/shared/i18n/I18nContext';
import {
  countActiveFilters,
  emptyPrivateFilters,
  emptyUrlFilters,
  type PrivateFilters,
  type UrlFilters,
} from '../filters';

interface TransactionFiltersProps {
  url: UrlFilters;
  onUrlChange: (next: UrlFilters) => void;
  /** Search text and amount bounds (memory only). */
  search: string;
  onSearchChange: (value: string) => void;
  amounts: PrivateFilters;
  onAmountsChange: (next: PrivateFilters) => void;
  defaultCurrency: string;
}

const SOURCES = (
  Object.keys(transactionSourceLabel) as (keyof typeof transactionSourceLabel)[]
).filter((source) => source !== '');

/** Select value for "Uncategorized" (not a category ID). */
const UNCATEGORIZED = '__uncategorized';

function Chip({
  label,
  onRemove,
  removeLabel,
}: {
  label: string;
  onRemove: () => void;
  removeLabel: string;
}) {
  return (
    <li className="inline-flex min-h-9 items-center gap-1 rounded-full border border-line-strong bg-surface-muted ps-3 text-sm text-fg">
      {label}
      <button
        type="button"
        aria-label={removeLabel}
        onClick={onRemove}
        className="inline-flex size-9 items-center justify-center rounded-full text-fg-muted hover:text-fg"
      >
        <Icon name="x" className="size-4" />
      </button>
    </li>
  );
}

/** Search, period, sort and the detailed filters, with removable chips for what's applied. */
export function TransactionFilters({
  url,
  onUrlChange,
  search,
  onSearchChange,
  amounts,
  onAmountsChange,
  defaultCurrency,
}: TransactionFiltersProps) {
  const { t, formatLocale } = useI18n();
  const panelId = useId();
  const [open, setOpen] = useState(false);
  const accounts = useAccounts(true);
  const categories = useCategories(true);
  const tags = useTags();
  const methods = usePaymentMethods(true);
  const currencies = useCurrencies();
  const [merchantSearch, setMerchantSearch] = useState('');
  const debouncedMerchant = useDebouncedValue(merchantSearch, 250);
  const merchants = useMerchantSearch(debouncedMerchant, open);
  const selectedMerchant = useMerchant(url.merchantId);
  const [minRaw, setMinRaw] = useState(amounts.minAmount);
  const [maxRaw, setMaxRaw] = useState(amounts.maxAmount);
  const [amountErrors, setAmountErrors] = useState<{ min?: string; max?: string }>({});
  const currency = amounts.currency || defaultCurrency;
  const active = countActiveFilters(url, amounts);

  const set = (patch: Partial<UrlFilters>) => {
    onUrlChange({ ...url, ...patch });
  };

  /** Validates both bounds for a currency and updates the filter once (never from stale props). */
  const applyAmounts = (min: string, max: string, nextCurrency: string) => {
    const exponent = exponentFor(currencies.data, nextCurrency);
    const read = (raw: string): { value: string; error?: string } => {
      if (!raw.trim()) return { value: '' };
      const result = normalizeDecimalInput(raw, formatLocale, { exponent, allowZero: true });
      return result.ok
        ? { value: result.value }
        : { value: '', error: decimalIssueMessage(result.issue, t, nextCurrency, exponent) };
    };
    const low = read(min);
    const high = read(max);
    setAmountErrors({ min: low.error, max: high.error });
    onAmountsChange({
      q: amounts.q,
      currency: nextCurrency,
      // A bound that is not valid for this currency is left out (its error is shown).
      minAmount: low.value,
      maxAmount: high.value,
    });
  };

  const accountName = (id: string) =>
    accounts.data?.find((account) => account.id === id)?.name ?? id;
  const category = (id: string) => {
    const found = categories.data?.find((item) => item.id === id);
    return found ? categoryName(found, t) : t('transactions.filters.unknownCategory');
  };
  const tagName = (id: string) => tags.data?.find((tag) => tag.id === id)?.name ?? id;
  const methodName = (id: string) => {
    const found = methods.data?.find((method) => method.id === id);
    return found ? paymentMethodLabel(found, t) : id;
  };

  const chips: { key: string; label: string; remove: () => void }[] = [];
  for (const type of url.types) {
    chips.push({
      key: `type-${type}`,
      label: `${t('transactions.filters.type')}: ${t(transactionTypeLabel[type])}`,
      remove: () => {
        set({ types: url.types.filter((item) => item !== type) });
      },
    });
  }
  for (const id of url.accountIds) {
    chips.push({
      key: `account-${id}`,
      label: `${t('transactions.filters.account')}: ${accountName(id)}`,
      remove: () => {
        set({ accountIds: url.accountIds.filter((item) => item !== id) });
      },
    });
  }
  if (url.uncategorized) {
    chips.push({
      key: 'uncategorized',
      label: `${t('transactions.filters.category')}: ${t('categories.uncategorized')}`,
      remove: () => {
        set({ uncategorized: false });
      },
    });
  }
  for (const id of url.categoryIds) {
    chips.push({
      key: `category-${id}`,
      label: `${t('transactions.filters.category')}: ${category(id)}`,
      remove: () => {
        set({ categoryIds: url.categoryIds.filter((item) => item !== id) });
      },
    });
  }
  for (const id of url.tagIds) {
    chips.push({
      key: `tag-${id}`,
      label: `${t('transactions.filters.tag')}: ${tagName(id)}`,
      remove: () => {
        set({ tagIds: url.tagIds.filter((item) => item !== id) });
      },
    });
  }
  if (url.merchantId) {
    chips.push({
      key: 'merchant',
      label: `${t('transactions.filters.merchant')}: ${selectedMerchant.data?.name ?? t('common.loading')}`,
      remove: () => {
        set({ merchantId: '' });
      },
    });
  }
  if (url.paymentMethodId) {
    chips.push({
      key: 'method',
      label: `${t('transactions.filters.paymentMethod')}: ${methodName(url.paymentMethodId)}`,
      remove: () => {
        set({ paymentMethodId: '' });
      },
    });
  }
  if (url.direction) {
    chips.push({
      key: 'direction',
      label: t(
        url.direction === 'inflow' ? 'finance.direction.inflow' : 'finance.direction.outflow',
      ),
      remove: () => {
        set({ direction: '' });
      },
    });
  }
  if (url.source) {
    chips.push({
      key: 'source',
      label: `${t('transactions.filters.source')}: ${t(transactionSourceLabel[url.source])}`,
      remove: () => {
        set({ source: '' });
      },
    });
  }
  if (url.status) {
    chips.push({
      key: 'status',
      label: `${t('transactions.filters.status')}: ${t(`transactions.filters.status.${url.status}`)}`,
      remove: () => {
        set({ status: '' });
      },
    });
  }
  if (amounts.minAmount || amounts.maxAmount) {
    chips.push({
      key: 'amount',
      label: t('transactions.filters.amountChip'),
      remove: () => {
        setMinRaw('');
        setMaxRaw('');
        onAmountsChange({ ...emptyPrivateFilters });
      },
    });
  }

  const merchantOptions = (merchants.data ?? []).map((merchant) => ({
    value: merchant.id,
    label: merchant.name,
  }));
  if (
    url.merchantId &&
    selectedMerchant.data &&
    !merchantOptions.some((option) => option.value === url.merchantId)
  ) {
    merchantOptions.unshift({ value: url.merchantId, label: selectedMerchant.data.name });
  }

  return (
    <section
      aria-label={t('transactions.filters.label')}
      className="mb-6 rounded-xl border border-line bg-surface p-4 shadow-card sm:p-5"
    >
      <div className="flex flex-wrap items-start gap-3">
        <TextField
          label={t('transactions.filters.search')}
          help={t('transactions.filters.searchHelp')}
          type="search"
          value={search}
          maxLength={100}
          autoComplete="off"
          className="min-w-56 flex-[2]"
          onChange={(event) => {
            onSearchChange(event.target.value);
          }}
        />
        <div className="flex-[3]">
          <DateRangeFields
            allowAll
            value={{ range: url.range, from: url.from, to: url.to }}
            onChange={(value) => {
              set({ range: value.range, from: value.from, to: value.to });
            }}
          />
        </div>
        <Select
          label={t('transactions.filters.sort')}
          value={url.sort}
          className="min-w-44"
          options={(Object.keys(sortLabel) as (keyof typeof sortLabel)[]).map((sort) => ({
            value: sort,
            label: t(sortLabel[sort]),
          }))}
          onChange={(event) => {
            const sort = event.target.value;
            if (sort in sortLabel) set({ sort: sort as keyof typeof sortLabel });
          }}
        />
        {/* Offset by a label's height so the button lines up with the inputs. */}
        <Button
          variant="secondary"
          className="sm:mt-[26px]"
          aria-expanded={open}
          aria-controls={panelId}
          onClick={() => {
            setOpen((value) => !value);
          }}
        >
          <Icon name="filter" className="size-4" />
          {active > 0
            ? t('transactions.filters.moreCount', { count: active })
            : t('transactions.filters.more')}
        </Button>
      </div>

      <div id={panelId} hidden={!open} className="mt-5 border-t border-line pt-5">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Select
            label={t('transactions.filters.type')}
            optional
            placeholder={t('transactions.filters.anyType')}
            value={url.types.length === 1 ? url.types[0] : ''}
            options={TRANSACTION_TYPES.map((type) => ({
              value: type,
              label: t(transactionTypeLabel[type]),
            }))}
            onChange={(event) => {
              const value = event.target.value;
              set({
                types: (TRANSACTION_TYPES as string[]).includes(value)
                  ? [value as TransactionType]
                  : [],
              });
            }}
          />
          <Select
            label={t('transactions.filters.account')}
            optional
            placeholder={t('transactions.filters.anyAccount')}
            value={url.accountIds.length === 1 ? url.accountIds[0] : ''}
            groups={accountGroups(accounts.data ?? [], t)}
            onChange={(event) => {
              set({ accountIds: event.target.value ? [event.target.value] : [] });
            }}
          />
          <Select
            label={t('transactions.filters.category')}
            optional
            placeholder={t('transactions.filters.anyCategory')}
            help={t('transactions.filters.categoryHelp')}
            value={
              url.uncategorized
                ? UNCATEGORIZED
                : url.categoryIds.length === 1
                  ? url.categoryIds[0]
                  : ''
            }
            options={[
              { value: UNCATEGORIZED, label: t('categories.uncategorized') },
              ...categoryOptions(
                (categories.data ?? []).map((item) => ({ ...item, status: 'active' as const })),
                t,
                formatLocale,
              ),
            ]}
            onChange={(event) => {
              const value = event.target.value;
              if (value === UNCATEGORIZED) set({ uncategorized: true, categoryIds: [] });
              else set({ uncategorized: false, categoryIds: value ? [value] : [] });
            }}
          />
          <Select
            label={t('transactions.filters.tag')}
            optional
            placeholder={t('transactions.filters.anyTag')}
            value={url.tagIds.length === 1 ? url.tagIds[0] : ''}
            options={(tags.data ?? []).map((tag) => ({ value: tag.id, label: tag.name }))}
            onChange={(event) => {
              set({ tagIds: event.target.value ? [event.target.value] : [] });
            }}
          />
          <div className="space-y-2">
            <TextField
              label={t('transactions.filters.merchantSearch')}
              optional
              type="search"
              value={merchantSearch}
              maxLength={100}
              autoComplete="off"
              onChange={(event) => {
                setMerchantSearch(event.target.value);
              }}
            />
            <Select
              label={t('transactions.filters.merchant')}
              optional
              placeholder={t('transactions.filters.anyMerchant')}
              value={url.merchantId}
              options={merchantOptions}
              onChange={(event) => {
                set({ merchantId: event.target.value });
              }}
            />
          </div>
          <Select
            label={t('transactions.filters.paymentMethod')}
            optional
            placeholder={t('transactions.filters.anyPaymentMethod')}
            value={url.paymentMethodId}
            options={(methods.data ?? []).map((method) => ({
              value: method.id,
              label: paymentMethodLabel(method, t),
            }))}
            onChange={(event) => {
              set({ paymentMethodId: event.target.value });
            }}
          />
          <Select
            label={t('transactions.filters.direction')}
            optional
            placeholder={t('transactions.filters.anyDirection')}
            value={url.direction}
            options={[
              { value: 'inflow', label: t('finance.direction.inflow') },
              { value: 'outflow', label: t('finance.direction.outflow') },
            ]}
            onChange={(event) => {
              const value = event.target.value;
              set({ direction: value === 'inflow' || value === 'outflow' ? value : '' });
            }}
          />
          <Select
            label={t('transactions.filters.source')}
            optional
            placeholder={t('finance.source.any')}
            value={url.source}
            options={SOURCES.map((source) => ({
              value: source,
              label: t(transactionSourceLabel[source]),
            }))}
            onChange={(event) => {
              const value = event.target.value;
              set({
                source: (SOURCES as string[]).includes(value)
                  ? (value as UrlFilters['source'])
                  : '',
              });
            }}
          />
          <Select
            label={t('transactions.filters.status')}
            optional
            placeholder={t('transactions.filters.status.default')}
            value={url.status}
            options={(['posted', 'pending', 'draft', 'voided', 'all'] as const).map((status) => ({
              value: status,
              label: t(`transactions.filters.status.${status}`),
            }))}
            onChange={(event) => {
              const value = event.target.value;
              const allowed = ['posted', 'pending', 'draft', 'voided', 'all'];
              set({ status: allowed.includes(value) ? (value as UrlFilters['status']) : '' });
            }}
          />
        </div>
        <fieldset className="mt-5">
          <legend className="mb-1.5 text-sm font-medium text-fg">
            {t('transactions.filters.amount')}
          </legend>
          <p className="mb-3 text-sm text-fg-muted">{t('transactions.filters.amountHelp')}</p>
          <div className="grid gap-4 sm:grid-cols-3">
            <Select
              label={t('common.currency')}
              value={currency}
              options={currencyOptions(currencies.data, formatLocale, currency)}
              onChange={(event) => {
                applyAmounts(minRaw, maxRaw, event.target.value);
              }}
            />
            <MoneyField
              label={t('transactions.filters.minAmount')}
              currency={currency}
              optional
              value={minRaw}
              error={amountErrors.min}
              onChange={(event) => {
                setMinRaw(event.target.value);
              }}
              onBlur={() => {
                applyAmounts(minRaw, maxRaw, currency);
              }}
            />
            <MoneyField
              label={t('transactions.filters.maxAmount')}
              currency={currency}
              optional
              value={maxRaw}
              error={amountErrors.max}
              onChange={(event) => {
                setMaxRaw(event.target.value);
              }}
              onBlur={() => {
                applyAmounts(minRaw, maxRaw, currency);
              }}
            />
          </div>
        </fieldset>
      </div>

      {chips.length > 0 ? (
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <ul className="flex flex-wrap gap-2" aria-label={t('transactions.filters.applied')}>
            {chips.map((chip) => (
              <Chip
                key={chip.key}
                label={chip.label}
                onRemove={chip.remove}
                removeLabel={t('transactions.filters.remove', { filter: chip.label })}
              />
            ))}
          </ul>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setMinRaw('');
              setMaxRaw('');
              setAmountErrors({});
              onAmountsChange({ ...emptyPrivateFilters });
              onUrlChange({
                ...emptyUrlFilters,
                range: url.range,
                from: url.from,
                to: url.to,
                sort: url.sort,
              });
            }}
          >
            {t('transactions.filters.clear')}
          </Button>
        </div>
      ) : null}
    </section>
  );
}
