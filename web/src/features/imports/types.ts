import type { components, operations } from '@/shared/api/schema';

/** Statement import types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type ImportBatch = Schemas['ImportBatchDTO'];
export type ImportStatus = ImportBatch['status'];
export type ImportRow = Schemas['ImportRowDTO'];
export type ImportRowStatus = ImportRow['status'];
export type ImportRowPage = Schemas['ImportRowPage'];
export type ImportRowUpdate = Schemas['ImportRowUpdate'];
export type ImportCreateInput = Schemas['ImportCreateInput'];
export type ColumnMapping = Schemas['ColumnMapping'];
export type SignConvention = NonNullable<ColumnMapping['sign_convention']>;
export type RowTotals = Schemas['RowTotals'];
export type RowsQuery = NonNullable<operations['imports-rows']['parameters']['query']>;
/** A row filter: one status, or '' for every row. */
export type RowFilter = NonNullable<RowsQuery['status']>;
export type Direction = NonNullable<ImportRow['direction']>;
