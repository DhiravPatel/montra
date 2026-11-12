import type { components, operations } from '@/shared/api/schema';

/** Exchange-rate types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

/** A stored rate observation (provider or your manual override). */
export type StoredRate = Schemas['RateDTO'];
export type RateSource = StoredRate['source'];
export type ManualRateInput = Schemas['ManualRateInput'];
/** The rate a conversion used, disclosed with its source and timestamp. */
export type DisclosedRate = Schemas['Rate'];
export type Conversion = Schemas['ConversionDTO'];
export type ConversionPolicy = Conversion['policy'];
export type ConvertQuery = operations['fx-convert']['parameters']['query'];
export type RatesQuery = NonNullable<operations['fx-rates-list']['parameters']['query']>;
