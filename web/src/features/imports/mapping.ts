import { z } from 'zod';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { ColumnMapping, SignConvention } from './types';

/** Date layouts the server accepts (ColumnMapping.date_format in the contract). */
export const DATE_FORMATS = [
  'YYYY-MM-DD',
  'DD/MM/YYYY',
  'MM/DD/YYYY',
  'DD-MM-YYYY',
  'MM-DD-YYYY',
  'DD.MM.YYYY',
  'YYYY/MM/DD',
  'DD/MM/YY',
  'MM/DD/YY',
  'DD-MM-YY',
  'DD-MMM-YYYY',
  'DD MMM YYYY',
  'DD-MMM-YY',
  'DD MMM YY',
  'MMM DD, YYYY',
  'YYYYMMDD',
] as const;

type AmountMode = 'single' | 'split';

export interface MappingValues {
  headerRow: string;
  dateColumn: string;
  dateFormat: string;
  amountMode: AmountMode;
  amountColumn: string;
  signConvention: SignConvention;
  debitColumn: string;
  creditColumn: string;
  indicatorColumn: string;
  decimalSeparator: '.' | ',';
  descriptionColumns: string[];
  referenceColumn: string;
  balanceColumn: string;
  currencyColumn: string;
  externalIdColumn: string;
}

function column(value: number | undefined): string {
  return value !== undefined && value >= 0 ? String(value) : '';
}

/** Form values from the server's mapping (detected, or chosen earlier). */
export function mappingToValues(mapping: ColumnMapping | undefined): MappingValues {
  const split =
    mapping?.amount_column === undefined &&
    mapping?.debit_column !== undefined &&
    mapping.credit_column !== undefined;
  return {
    headerRow: String(mapping?.header_row ?? -1),
    dateColumn: column(mapping?.date_column),
    dateFormat: mapping?.date_format ?? '',
    amountMode: split ? 'split' : 'single',
    amountColumn: column(mapping?.amount_column),
    signConvention: mapping?.sign_convention ?? 'negative_is_outflow',
    debitColumn: column(mapping?.debit_column),
    creditColumn: column(mapping?.credit_column),
    indicatorColumn: column(mapping?.indicator_column),
    decimalSeparator: mapping?.decimal_separator === ',' ? ',' : '.',
    descriptionColumns: (mapping?.description_columns ?? []).map(String),
    referenceColumn: column(mapping?.reference_column),
    balanceColumn: column(mapping?.balance_column),
    currencyColumn: column(mapping?.currency_column),
    externalIdColumn: column(mapping?.external_id_column),
  };
}

/** The mapping to send (column indexes are 0-based; optional columns are left out when unused). */
export function valuesToMapping(values: MappingValues): ColumnMapping {
  const mapping: ColumnMapping = {
    header_row: Number(values.headerRow),
    date_column: Number(values.dateColumn),
    date_format: values.dateFormat,
    decimal_separator: values.decimalSeparator,
    description_columns: values.descriptionColumns.map(Number).sort((a, b) => a - b),
  };
  if (values.amountMode === 'single') {
    mapping.amount_column = Number(values.amountColumn);
    mapping.sign_convention = values.signConvention;
  } else {
    mapping.debit_column = Number(values.debitColumn);
    mapping.credit_column = Number(values.creditColumn);
  }
  if (values.indicatorColumn !== '') mapping.indicator_column = Number(values.indicatorColumn);
  if (values.referenceColumn !== '') mapping.reference_column = Number(values.referenceColumn);
  if (values.balanceColumn !== '') mapping.balance_column = Number(values.balanceColumn);
  if (values.currencyColumn !== '') mapping.currency_column = Number(values.currencyColumn);
  if (values.externalIdColumn !== '') mapping.external_id_column = Number(values.externalIdColumn);
  return mapping;
}

/** Client-side checks mirroring the server's mapping validation (so most mistakes never leave the form). */
export function mappingSchema(t: Translate) {
  return z
    .object({
      headerRow: z.string(),
      dateColumn: z.string(),
      dateFormat: z.string(),
      amountMode: z.enum(['single', 'split']),
      amountColumn: z.string(),
      signConvention: z.enum(['negative_is_outflow', 'positive_is_outflow']),
      debitColumn: z.string(),
      creditColumn: z.string(),
      indicatorColumn: z.string(),
      decimalSeparator: z.enum(['.', ',']),
      descriptionColumns: z.array(z.string()),
      referenceColumn: z.string(),
      balanceColumn: z.string(),
      currencyColumn: z.string(),
      externalIdColumn: z.string(),
    })
    .superRefine((values, ctx) => {
      const require = (path: keyof MappingValues, message: MessageKey) => {
        ctx.addIssue({ code: 'custom', path: [path], message: t(message) });
      };
      if (values.dateColumn === '') require('dateColumn', 'imports.mapping.errors.dateColumn');
      if (values.dateFormat === '') require('dateFormat', 'imports.mapping.errors.dateFormat');
      if (values.amountMode === 'single') {
        if (values.amountColumn === '')
          require('amountColumn', 'imports.mapping.errors.amountColumn');
      } else {
        if (values.debitColumn === '') require('debitColumn', 'imports.mapping.errors.debitColumn');
        if (values.creditColumn === '')
          require('creditColumn', 'imports.mapping.errors.creditColumn');
        if (values.debitColumn !== '' && values.debitColumn === values.creditColumn)
          require('creditColumn', 'imports.mapping.errors.sameColumn');
      }
    });
}
