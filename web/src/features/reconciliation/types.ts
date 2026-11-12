import type { components, operations } from '@/shared/api/schema';

/** Reconciliation types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Reconciliation = Schemas['ReconBalanceDTO'];
export type ReconciliationInput = Schemas['ReconBalanceInput'];
export type BalanceKind = NonNullable<ReconciliationInput['balance_kind']>;
export type Candidate = Schemas['ReconCandidate'];
export type CandidateItem = Schemas['ReconCandidateItem'];
export type MatchKind = Candidate['kind'];
export type Match = Schemas['ReconMatchDTO'];
export type MatchItem = Schemas['ReconMatchItemDTO'];
export type MatchInput = Schemas['ReconMatchInput'];
/** A line of a statement import that can be matched by hand (or was). */
export type StatementLine = Schemas['StatementLineDTO'];
export type StatementLineStatus = NonNullable<
  NonNullable<operations['accounts-statement-lines']['parameters']['query']>['status']
>;
