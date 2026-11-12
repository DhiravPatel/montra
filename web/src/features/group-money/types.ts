import type { components, operations } from '@/shared/api/schema';

/** Group money types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Money = Schemas['Money'];

export type GroupDetail = Schemas['GroupDetail'];
export type GroupMember = Schemas['GroupMemberDTO'];

export type GroupExpense = Schemas['GroupExpenseDTO'];
export type GroupExpenseDetail = Schemas['GroupExpenseDetail'];
export type GroupExpenseInput = Schemas['GroupExpenseInput'];
export type ExpenseParticipantInput = Schemas['ExpenseParticipantInput'];
export type ExpensePayerInput = Schemas['ExpensePayerInput'];
export type ExpenseItemInput = Schemas['ExpenseItemInput'];
export type ExpenseShare = Schemas['ExpenseShareDTO'];
export type ExpensePayer = Schemas['ExpensePayerDTO'];
export type ExpenseItem = Schemas['ExpenseItemDTO'];
export type ExpenseStatus = GroupExpense['status'];
export type SplitMethod = NonNullable<GroupExpenseInput['split_method']>;
/** Where a saved expense's rate came from (`manual`: typed by a member or their saved rate). */
export type FxRateSource = NonNullable<GroupExpense['fx_rate_source']>;
/** What the request says about the rate (`lookup`: Montra's rate for the expense date). */
export type FxRateSourceInput = NonNullable<GroupExpenseInput['fx_rate_source']>;

/** Server-side filters of GET /groups/{id}/expenses (empty strings mean "any"). */
type ExpenseListQuery = NonNullable<operations['groups-expenses-list']['parameters']['query']>;
export interface ExpenseFilters {
  status: NonNullable<ExpenseListQuery['status']>;
  /** YYYY-MM-DD, inclusive. */
  from: string;
  to: string;
  payerUserId: string;
  /** A starter category key, or `uncategorized`. */
  categoryKey: string;
  /** Also list deleted expenses (ignored when a status is chosen). */
  includeDeleted: boolean;
}

/** One cursor page of expenses, newest first. */
export interface ExpensePage {
  items: GroupExpense[];
  nextCursor: string | null;
}

export type GroupComment = Schemas['GroupCommentDTO'];
export type GroupDispute = Schemas['GroupDisputeDTO'];
export type DisputeStatus = GroupDispute['status'];
export type ResolveDisputeInput = Schemas['ResolveDisputeInput'];
export type ExpenseRecordInput = Schemas['ExpenseRecordInput'];

export type GroupBalances = Schemas['GroupBalancesDTO'];
export type MemberBalance = Schemas['GroupMemberBalance'];
export type GroupTransfer = Schemas['GroupTransferDTO'];
export type GroupSuggestions = Schemas['GroupSuggestionsDTO'];

export type Settlement = Schemas['SettlementDTO'];
export type SettlementInput = Schemas['SettlementInput'];
export type SettlementActionBody = Schemas['SettlementActionBody'];
export type SettlementStatus = Settlement['status'];
export type SettlementMethod = Settlement['method'];
/** Lifecycle actions of POST /groups/{id}/settlements/{settlementId}/{action}. */
export type SettlementAction = 'confirm' | 'dispute' | 'mark-paid' | 'record' | 'unlink' | 'void';

export type GroupRecurring = Schemas['GroupRecurringDTO'];
export type GroupRecurringInput = Schemas['GroupRecurringInput'];
export type GroupRecurringUpdate = Schemas['GroupRecurringUpdate'];
export type RecurringSplitMethod = NonNullable<GroupRecurringInput['split_method']>;
export type RecurringStatusAction = 'pause' | 'resume' | 'stop';
export type Occurrence = Schemas['OccurrenceDTO'];

export type GroupReport = Schemas['GroupReportDTO'];
export type Conversion = Schemas['ConversionDTO'];

/** CSV text from GET /groups/{id}/export with the file name the server suggested (if safe). */
export interface CsvDownload {
  csv: string;
  fileName: string | null;
}

/** Router state after saving an expense: its page then points at the server's shares. */
export interface SavedState {
  saved: true;
}
