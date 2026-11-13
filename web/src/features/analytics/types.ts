import type { components, operations } from '@/shared/api/schema';

/** Analytics types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type CashFlowReport = Schemas['CashFlowReport'];
export type CashFlowTotals = Schemas['CashFlowTotals'];
export type ConvertedTotals = Schemas['ConvertedTotals'];
export type DisclosedRate = Schemas['Rate'];
export type SeriesPoint = Schemas['SeriesPoint'];
export type Granularity = CashFlowReport['series_granularity'];
export type Coverage = Schemas['Coverage'];
export type AnalyticsWindow = Schemas['Window'];

export type CategoryReport = Schemas['CategoryReport'];
export type CategorySlice = Schemas['CategorySlice'];
export type MerchantReport = Schemas['MerchantReport'];
export type MerchantSlice = Schemas['MerchantSlice'];
export type PaymentMethodReport = Schemas['PaymentMethodReport'];
export type PaymentMethodSlice = Schemas['PaymentMethodSlice'];
export type AccountsReport = Schemas['AccountsReport'];
export type BalanceTotals = Schemas['BalanceTotals'];

export type Comparison = Schemas['Comparison'];
export type CurrencyComparison = Schemas['CurrencyComparison'];
export type CategoryDelta = Schemas['CategoryDelta'];
/** The change of every total between the periods, computed by the API. */
export type TotalsChange = Schemas['TotalsChange'];
export type MetricChange = Schemas['MetricChange'];
export type CategoryKind = CategoryReport['kind'];

export type BudgetPerformance = Schemas['BudgetPerformance'];
export type BudgetSummaryItem = Schemas['BudgetDTO'];
export type BudgetPace = Schemas['ProgressDTO']['pace'];
export type GoalReport = Schemas['GoalReport'];
export type GoalTotal = Schemas['GoalTotal'];
export type GoalSummaryItem = Schemas['GoalDTO'];
export type SubscriptionSummary = Schemas['SubscriptionSummary'];
export type SubscriptionSummaryItem = Schemas['SubscriptionDTO'];
export type RecurringReport = Schemas['RecurringReport'];
export type RecurringCommitment = Schemas['RecurringCommitment'];

/** Shared filters of the period-based analytics endpoints (same model everywhere). */
export type AnalyticsQuery = NonNullable<operations['analytics-cash-flow']['parameters']['query']>;
export type CompareQuery = NonNullable<operations['analytics-compare']['parameters']['query']>;
export type DateRangeName = Exclude<NonNullable<AnalyticsQuery['range']>, ''>;
