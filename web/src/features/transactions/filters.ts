import { parseRangeChoice, type RangeChoice } from '@/shared/finance/dateRange';
import { TRANSACTION_TYPES, transactionSourceLabel } from '@/shared/finance/labels';
import type {
  TransactionListQuery,
  TransactionSort,
  TransactionSource,
  TransactionStatusFilter,
  TransactionType,
} from '@/shared/finance/types';
import { isLocalDate } from '@/shared/formatting/dates';

/**
 * Transaction list filters.
 *
 * Only non-sensitive filters live in the URL (dates, IDs, enum values) so
 * lists can be bookmarked and dashboards can drill down
 * (`/transactions?from=…&to=…&category_id=…`). Search text and amount
 * bounds are personal details and stay in memory only (spec §20B.23).
 */
export interface UrlFilters {
  range: RangeChoice;
  from: string;
  to: string;
  types: TransactionType[];
  accountIds: string[];
  categoryIds: string[];
  /** Only transactions without a category (never combined with categoryIds). */
  uncategorized: boolean;
  tagIds: string[];
  merchantId: string;
  /** A payment method ID, or `none` for transactions without one (the API's drill-down value). */
  paymentMethodId: string;
  source: Exclude<TransactionSource, ''> | '';
  status: Exclude<TransactionStatusFilter, ''> | '';
  direction: 'inflow' | 'outflow' | '';
  sort: Exclude<TransactionSort, ''>;
}

export interface PrivateFilters {
  q: string;
  /** Canonical decimal strings (already validated), or ''. */
  minAmount: string;
  maxAmount: string;
  currency: string;
}

export const emptyUrlFilters: UrlFilters = {
  range: 'all',
  from: '',
  to: '',
  types: [],
  accountIds: [],
  categoryIds: [],
  uncategorized: false,
  tagIds: [],
  merchantId: '',
  paymentMethodId: '',
  source: '',
  status: '',
  direction: '',
  sort: 'date_desc',
};

export const emptyPrivateFilters: PrivateFilters = {
  q: '',
  minAmount: '',
  maxAmount: '',
  currency: '',
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** `payment_method_id=none`: transactions recorded without a payment method. */
export const NO_PAYMENT_METHOD = 'none';
const STATUSES = ['active', 'posted', 'pending', 'draft', 'voided', 'all'] as const;
const SORTS = ['date_desc', 'date_asc', 'amount_desc', 'amount_asc'] as const;

function ids(value: string | null): string[] {
  if (!value) return [];
  return [...new Set(value.split(',').filter((part) => UUID.test(part)))].slice(0, 20);
}

function oneOf<T extends string>(value: string | null, allowed: readonly T[]): T | '' {
  return value && (allowed as readonly string[]).includes(value) ? (value as T) : '';
}

const SOURCES = Object.keys(transactionSourceLabel).filter(
  (source): source is Exclude<TransactionSource, ''> => source !== '',
);

export function readUrlFilters(params: URLSearchParams): UrlFilters {
  const from = params.get('from') ?? '';
  const to = params.get('to') ?? '';
  const validFrom = isLocalDate(from) ? from : '';
  const validTo = isLocalDate(to) ? to : '';
  let range = parseRangeChoice(params.get('range') ?? '', true);
  if (!range) range = validFrom || validTo ? 'custom' : 'all';
  const types = (params.get('type') ?? '')
    .split(',')
    .filter((type): type is TransactionType => (TRANSACTION_TYPES as string[]).includes(type));
  const merchant = params.get('merchant_id') ?? '';
  const method = params.get('payment_method_id') ?? '';
  return {
    range,
    from: range === 'custom' ? validFrom : '',
    to: range === 'custom' ? validTo : '',
    types: [...new Set(types)],
    accountIds: ids(params.get('account_id')),
    categoryIds: params.get('uncategorized') === 'true' ? [] : ids(params.get('category_id')),
    uncategorized: params.get('uncategorized') === 'true',
    tagIds: ids(params.get('tag_id')),
    merchantId: UUID.test(merchant) ? merchant : '',
    paymentMethodId: UUID.test(method) || method === NO_PAYMENT_METHOD ? method : '',
    source: oneOf(params.get('source'), SOURCES),
    status: oneOf(params.get('status'), STATUSES),
    direction: oneOf(params.get('direction'), ['inflow', 'outflow'] as const),
    sort: oneOf(params.get('sort'), SORTS) || 'date_desc',
  };
}

export function writeUrlFilters(filters: UrlFilters): URLSearchParams {
  const params = new URLSearchParams();
  if (filters.range !== 'all') params.set('range', filters.range);
  if (filters.range === 'custom') {
    if (filters.from) params.set('from', filters.from);
    if (filters.to) params.set('to', filters.to);
  }
  if (filters.types.length > 0) params.set('type', filters.types.join(','));
  if (filters.accountIds.length > 0) params.set('account_id', filters.accountIds.join(','));
  if (filters.uncategorized) params.set('uncategorized', 'true');
  else if (filters.categoryIds.length > 0) params.set('category_id', filters.categoryIds.join(','));
  if (filters.tagIds.length > 0) params.set('tag_id', filters.tagIds.join(','));
  if (filters.merchantId) params.set('merchant_id', filters.merchantId);
  if (filters.paymentMethodId) params.set('payment_method_id', filters.paymentMethodId);
  if (filters.source) params.set('source', filters.source);
  if (filters.status) params.set('status', filters.status);
  if (filters.direction) params.set('direction', filters.direction);
  if (filters.sort !== 'date_desc') params.set('sort', filters.sort);
  return params;
}

/** The API query for the current filters (empty values are left out). */
export function toListQuery(url: UrlFilters, priv: PrivateFilters): TransactionListQuery {
  const query: TransactionListQuery = { sort: url.sort };
  if (url.range === 'custom') {
    if (url.from) query.from = url.from;
    if (url.to) query.to = url.to;
  } else if (url.range !== 'all') {
    query.range = url.range;
  }
  if (url.types.length > 0) query.type = url.types;
  if (url.accountIds.length > 0) query.account_id = url.accountIds;
  if (url.uncategorized) query.uncategorized = true;
  else if (url.categoryIds.length > 0) query.category_id = url.categoryIds;
  if (url.tagIds.length > 0) query.tag_id = url.tagIds;
  if (url.merchantId) query.merchant_id = url.merchantId;
  if (url.paymentMethodId) query.payment_method_id = url.paymentMethodId;
  if (url.source) query.source = url.source;
  if (url.status) query.status = url.status;
  if (url.direction) query.direction = url.direction;
  const q = priv.q.trim().slice(0, 100);
  if (q) query.q = q;
  if (priv.minAmount || priv.maxAmount) {
    if (priv.currency) query.currency = priv.currency;
    if (priv.minAmount) query.min_amount = priv.minAmount;
    if (priv.maxAmount) query.max_amount = priv.maxAmount;
  }
  return query;
}

/** How many filters (beyond the period and sort order) are active. */
export function countActiveFilters(url: UrlFilters, priv: PrivateFilters): number {
  return [
    url.types.length > 0,
    url.accountIds.length > 0,
    url.categoryIds.length > 0 || url.uncategorized,
    url.tagIds.length > 0,
    Boolean(url.merchantId),
    Boolean(url.paymentMethodId),
    Boolean(url.source),
    Boolean(url.status),
    Boolean(url.direction),
    Boolean(priv.minAmount || priv.maxAmount),
  ].filter(Boolean).length;
}

// --- Saved filters ----------------------------------------------------------

const DECIMAL = /^\d{1,15}(\.\d{1,4})?$/;
const CURRENCY = /^[A-Z]{3}$/;

/** Every key of the GET /transactions query a saved filter may hold (not cursor or limit). */
const QUERY_KEYS = new Set([
  'range',
  'from',
  'to',
  'type',
  'account_id',
  'category_id',
  'merchant_id',
  'payment_method_id',
  'tag_id',
  'currency',
  'min_amount',
  'max_amount',
  'q',
  'source',
  'status',
  'reconciliation_state',
  'direction',
  'has_attachment',
  'uncategorized',
  'recurring',
  'include_shared',
  'sort',
]);

/**
 * The filters to save: exactly the GET /transactions query this screen
 * sends (search text included), without paging. Null when nothing narrows
 * or reorders the list, so there is nothing worth saving.
 */
export function toSavedFilter(url: UrlFilters, priv: PrivateFilters): TransactionListQuery | null {
  const query = toListQuery(url, priv);
  const narrowed = Object.keys(query).some((key) => key !== 'sort');
  return narrowed || query.sort !== 'date_desc' ? query : null;
}

function asText(value: unknown): string | null {
  if (typeof value === 'string') return value;
  if (typeof value === 'boolean' || typeof value === 'number') return String(value);
  if (Array.isArray(value) && value.every((item) => typeof item === 'string')) {
    return value.join(',');
  }
  return null;
}

export interface AppliedFilters {
  url: UrlFilters;
  priv: PrivateFilters;
}

/**
 * Reads a saved filter (any client may have saved it, so nothing is
 * trusted): known keys are validated as the URL filters are, unknown keys
 * and invalid values are dropped and reported as `partial`. Filters this
 * screen does not offer (reconciliation state, attachments, recurring,
 * shared accounts) are left out the same way. Null when nothing is usable.
 */
export function fromSavedFilter(
  filter: Readonly<Record<string, unknown>>,
): { value: AppliedFilters; partial: boolean } | null {
  const params = new URLSearchParams();
  let partial = false;
  for (const [key, raw] of Object.entries(filter)) {
    const text = asText(raw);
    if (!QUERY_KEYS.has(key) || text === null) {
      partial = true;
      continue;
    }
    if (text !== '') params.set(key, text);
  }
  const url = readUrlFilters(params);
  // Whatever the URL reader could not keep was invalid or unsupported here.
  const kept = writeUrlFilters(url);
  for (const key of [
    'range',
    'type',
    'account_id',
    'category_id',
    'uncategorized',
    'tag_id',
    'merchant_id',
    'payment_method_id',
    'source',
    'status',
    'direction',
    'from',
    'to',
  ]) {
    const given = params.get(key);
    if (given !== null && given !== '' && kept.get(key) !== given) {
      // `uncategorized=false` and an explicit default are no loss.
      if (!(key === 'uncategorized' && given === 'false')) partial = true;
    }
  }
  for (const key of ['reconciliation_state', 'has_attachment', 'recurring', 'include_shared']) {
    const given = params.get(key);
    if (given !== null && given !== '' && given !== 'false') partial = true;
  }
  const sort = params.get('sort');
  if (sort !== null && sort !== url.sort) partial = true;

  const q = (params.get('q') ?? '').slice(0, 100);
  const min = params.get('min_amount') ?? '';
  const max = params.get('max_amount') ?? '';
  const currency = params.get('currency') ?? '';
  const validMin = DECIMAL.test(min) ? min : '';
  const validMax = DECIMAL.test(max) ? max : '';
  const validCurrency = CURRENCY.test(currency) ? currency : '';
  if ((min && !validMin) || (max && !validMax) || (currency && !validCurrency)) partial = true;
  if ((validMin || validMax) && !validCurrency) partial = true;
  const priv: PrivateFilters =
    validCurrency && (validMin || validMax)
      ? { q, minAmount: validMin, maxAmount: validMax, currency: validCurrency }
      : { ...emptyPrivateFilters, q };

  const usable = kept.toString() !== '' || Boolean(q) || Boolean(priv.minAmount || priv.maxAmount);
  if (!usable && Object.keys(filter).length > 0 && partial) return null;
  return { value: { url, priv }, partial };
}
