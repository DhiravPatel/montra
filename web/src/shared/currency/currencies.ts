/**
 * Locale helpers for currencies. The list of supported currencies, their
 * exponents and retirement status come from `GET /currencies` (see api.ts);
 * nothing here is a copy of that reference data.
 */

const eurozone = [
  'AT',
  'BE',
  'BG',
  'CY',
  'DE',
  'EE',
  'ES',
  'FI',
  'FR',
  'GR',
  'HR',
  'IE',
  'IT',
  'LT',
  'LU',
  'LV',
  'MT',
  'NL',
  'PT',
  'SI',
  'SK',
];

/** Common region -> currency suggestions for preselecting a picker. Only a hint; the user chooses. */
const regionCurrency: Readonly<Record<string, string>> = {
  ...Object.fromEntries(eurozone.map((region) => [region, 'EUR'])),
  AE: 'AED',
  AR: 'ARS',
  AU: 'AUD',
  BD: 'BDT',
  BH: 'BHD',
  BR: 'BRL',
  CA: 'CAD',
  CH: 'CHF',
  CL: 'CLP',
  CN: 'CNY',
  CO: 'COP',
  CZ: 'CZK',
  DK: 'DKK',
  EG: 'EGP',
  GB: 'GBP',
  HK: 'HKD',
  HU: 'HUF',
  ID: 'IDR',
  IL: 'ILS',
  IN: 'INR',
  JP: 'JPY',
  KE: 'KES',
  KR: 'KRW',
  KW: 'KWD',
  LK: 'LKR',
  MX: 'MXN',
  MY: 'MYR',
  NG: 'NGN',
  NO: 'NOK',
  NP: 'NPR',
  NZ: 'NZD',
  OM: 'OMR',
  PE: 'PEN',
  PH: 'PHP',
  PK: 'PKR',
  PL: 'PLN',
  QA: 'QAR',
  RO: 'RON',
  SA: 'SAR',
  SE: 'SEK',
  SG: 'SGD',
  TH: 'THB',
  TR: 'TRY',
  TW: 'TWD',
  UA: 'UAH',
  US: 'USD',
  VN: 'VND',
  ZA: 'ZAR',
};

/**
 * Suggests a currency from a locale's explicit region (e.g. en-IN -> INR);
 * null when the locale has no region or the region is not mapped. Callers
 * must still check the suggestion is selectable in `GET /currencies`.
 */
export function defaultCurrencyForLocale(locale: string): string | null {
  let region: string | undefined;
  try {
    region = new Intl.Locale(locale).region;
  } catch {
    return null;
  }
  if (!region) return null;
  return regionCurrency[region] ?? null;
}

/** Localized currency name, e.g. "Indian Rupee"; falls back to the API name, then the code. */
export function currencyName(code: string, locale: string, fallback?: string): string {
  try {
    return new Intl.DisplayNames([locale], { type: 'currency' }).of(code) ?? fallback ?? code;
  } catch {
    return fallback ?? code;
  }
}
