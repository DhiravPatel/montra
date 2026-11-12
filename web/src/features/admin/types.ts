import type { components } from '@/shared/api/schema';

/** Admin dashboard types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

/** Aggregate platform usage for a window: counts only, never people or records. */
export type Usage = Schemas['Usage'];
export type DailyUsage = Schemas['DailyUsage'];
