import type { components, operations } from '@/shared/api/schema';

/** Finance types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Account = Schemas['AccountDTO'];
export type AccountInput = Schemas['AccountInput'];
export type AccountPatch = Schemas['AccountPatch'];
export type AccountType = AccountInput['account_type'];
export type AdjustmentInput = Schemas['AdjustmentInput'];
export type BalanceReport = Schemas['BalanceReport'];
export type BalancePoint = Schemas['BalancePoint'];
export type BalanceTotals = Schemas['BalanceTotals'];

export type Transaction = Schemas['TransactionDTO'];
export type TransactionType = Transaction['type'];
export type TransactionStatus = Transaction['status'];
export type TransactionInput = Schemas['TransactionInput'];
export type TransactionPatch = Schemas['TransactionPatch'];
export type CreateResult = Schemas['CreateResult'];
export type DuplicateHint = Schemas['DuplicateHint'];
export type RefundInput = Schemas['RefundInput'];
export type BulkUpdateInput = Schemas['BulkUpdateInput'];
export type AuditEvent = Schemas['AuditEventDTO'];
export type Attachment = Schemas['AttachmentDTO'];
export type Transfer = Schemas['TransferDTO'];
export type TransferInput = Schemas['TransferInput'];
export type TransactionListQuery = NonNullable<
  operations['transactions-list']['parameters']['query']
>;
export type TransactionSource = NonNullable<TransactionListQuery['source']>;
export type TransactionStatusFilter = NonNullable<TransactionListQuery['status']>;
export type TransactionSort = NonNullable<TransactionListQuery['sort']>;
export type DateRangePreset = Exclude<NonNullable<TransactionListQuery['range']>, ''>;

export type Category = Schemas['CategoryDTO'];
export type CategoryRef = Schemas['CategoryRef'];
export type Tag = Schemas['TagDTO'];
export type Merchant = Schemas['MerchantDTO'];
export type PaymentMethod = Schemas['PaymentMethodDTO'];
export type PaymentMethodInput = Schemas['PaymentMethodInput'];
export type PaymentMethodKind = PaymentMethodInput['kind'];
export type PaymentNetwork = NonNullable<PaymentMethodInput['network']>;

export type DashboardSummary = Schemas['DashboardSummary'];
export type CashFlowTotals = Schemas['CashFlowTotals'];
export type SeriesPoint = Schemas['SeriesPoint'];
export type CategorySlice = Schemas['CategorySlice'];
export type MerchantSlice = Schemas['MerchantSlice'];
export type Coverage = Schemas['Coverage'];
export type ReportWindow = Schemas['Window'];
/**
 * A dashboard widget's layout. `key` is a plain string: the contract's
 * WidgetDTO enum predates budgets, upcoming, goals and group_balances,
 * and the API may add widgets this client does not know yet.
 */
export type Widget = Omit<Schemas['WidgetDTO'], 'key'> & { key: string };
export type WidgetsPatch = Schemas['WidgetsPatch'];
export type DashboardPlanning = Schemas['DashboardPlanning'];
export type PlanningGroupBalance = Schemas['GroupBalance'];
export type AccountsReport = Schemas['AccountsReport'];

export type Preferences = Schemas['PreferencesDTO'];
export type PreferencesPatch = Schemas['PreferencesPatch'];
export type IncomeRange = NonNullable<PreferencesPatch['income_range']>;
export type EmailDigest = Preferences['email_digest'];
export type OnboardingInput = Schemas['OnboardingInput'];

// Round 2: organizing (categories, rules, tags, merchants).
export type CategoryKind = Category['kind'];
export type CategoryInput = Schemas['CategoryInput'];
export type CategoryPatch = Schemas['CategoryPatch'];
export type CategoryMergeInput = Schemas['MergeInput'];
export type CategoryMergeResult = Schemas['MergeResult'];
export type CategoryRule = Schemas['RuleDTO'];
export type CategoryRuleInput = Schemas['RuleInput'];
export type CategoryRulePreviewRequest = Schemas['Category-rules-previewRequest'];
export type CategoryRulePreview = Schemas['RulePreview'];
export type MerchantDetail = Schemas['MerchantDetail'];
export type MerchantPatch = Schemas['MerchantPatch'];
export type MerchantSpend = Schemas['MerchantSpend'];
export type MerchantAliasInput = Schemas['Merchants-aliasesRequest'];
export type MerchantMergeInput = Schemas['Merchants-mergeRequest'];
export type TagBody = Schemas['TagBody'];

// Round 2: budgets.
export type Budget = Schemas['BudgetDTO'];
export type BudgetInput = Schemas['BudgetInput'];
export type BudgetType = Budget['budget_type'];
export type BudgetPeriod = Budget['period'];
export type BudgetAccess = Budget['access'];
export type BudgetAllocation = Schemas['AllocationDTO'];
export type BudgetAllocationInput = Schemas['AllocInput'];
export type BudgetMember = Schemas['MemberDTO'];
export type BudgetMemberInput = Schemas['MemberInput'];
export type BudgetMemberUpdate = Schemas['Budgets-members-updateRequest'];
export type BudgetProgress = Schemas['ProgressDTO'];
export type BudgetPace = BudgetProgress['pace'];
export type BudgetAlert = Schemas['AlertDTO'];
export type BudgetAlertUpdate = Schemas['Budget-alerts-updateRequest'];
export type BudgetPerformance = Schemas['BudgetPerformance'];

// Round 2: recurring rules, bills and the planning calendar.
export type RecurringRule = Schemas['RecurringRuleDTO'];
export type RecurringRuleDetail = Schemas['RecurringRuleDetail'];
export type RecurringRuleInput = Schemas['RecurringRuleInput'];
export type RecurringFrequency = RecurringRuleInput['frequency'];
export type RecurringIntervalUnit = NonNullable<RecurringRuleInput['interval_unit']>;
export type RecurringKind = RecurringRule['kind'];
export type RecurringStatus = RecurringRule['status'];
export type RecurringDeleteResult = Schemas['RecurringDeleteResult'];
export type RecurringReport = Schemas['RecurringReport'];
export type Occurrence = Schemas['OccurrenceDTO'];
export type OccurrenceStatus = Occurrence['status'];
export type OccurrenceAction = Schemas['OccurrenceAction'];
export type Bill = Schemas['BillDTO'];
export type BillDetail = Schemas['BillDetail'];
export type BillInput = Schemas['BillInput'];
export type BillState = Bill['state'];
export type BillStatus = Bill['status'];
export type BillMarkPaidInput = Schemas['MarkPaidInput'];
export type BillPaymentCandidate = Schemas['BillPaymentCandidate'];
export type BillSkipInput = Schemas['Bills-skipRequest'];
export type CalendarItem = Schemas['CalendarItem'];

// Round 2: subscriptions.
export type Subscription = Schemas['SubscriptionDTO'];
export type SubscriptionDetail = Schemas['SubscriptionDetail'];
export type SubscriptionInput = Schemas['SubscriptionInput'];
export type SubscriptionStatus = Subscription['status'];
export type SubscriptionFrequency = SubscriptionInput['billing_frequency'];
export type SubscriptionSummary = Schemas['SubscriptionSummary'];
export type SubscriptionCostTotal = Schemas['SubscriptionCostTotal'];
export type SubscriptionEvent = Schemas['SubscriptionEvent'];
export type SubscriptionActionInput = Schemas['SubscriptionActionInput'];
export type SubscriptionPaymentInput = Schemas['SubscriptionPaymentInput'];
export type SubscriptionPayment = Schemas['SubscriptionPayment'];
/** A payment linked to a subscription now (`SubscriptionDetail.payments`). */
export type LinkedPayment = Schemas['LinkedPayment'];
export type CancellationChecklistItem = Schemas['CancellationChecklistItem'];
export type SubscriptionDuplicateWarning = Schemas['DuplicateWarning'];
export type DetectionCandidate = Schemas['DetectionCandidateDTO'];
export type DetectionConfirmInput = Schemas['DetectionConfirmInput'];
export type DetectionEvidence = Schemas['DetectionEvidence'];

// Round 2: goals.
export type Goal = Schemas['GoalDTO'];
export type GoalInput = Schemas['GoalInput'];
export type GoalType = GoalInput['goal_type'];
export type GoalStatus = Goal['status'];
export type GoalAccess = Goal['access'];
export type GoalMember = Schemas['GoalMember'];
export type GoalMemberInput = Schemas['GoalMemberInput'];
export type GoalMemberUpdate = Schemas['GoalMemberUpdate'];
export type GoalMilestone = Schemas['GoalMilestone'];
export type GoalMilestoneInput = Schemas['GoalMilestoneInput'];
export type GoalProgress = Schemas['GoalProgress'];
export type GoalContribution = Schemas['GoalContributionDTO'];
export type GoalContributionInput = Schemas['GoalContributionInput'];
export type GoalForecast = Schemas['GoalForecast'];
export type GoalReport = Schemas['GoalReport'];

// Round 2: people to share budgets and goals with.
export type PublicProfile = Schemas['PublicProfile'];
export type Group = Schemas['GroupDTO'];
export type GroupDetail = Schemas['GroupDetail'];
export type GroupMember = Schemas['GroupMemberDTO'];

/*
 * Round 2 adoption: partial PATCH bodies (only the fields sent change; a
 * previously set optional field is removed by naming it in `clear`, text is
 * cleared with ""), typed merge counts and the newer endpoints.
 */
export type BillPatch = Schemas['BillPatch'];
export type BillClearable = NonNullable<BillPatch['clear']>[number];
export type RecurringRulePatch = Schemas['RecurringRulePatch'];
export type RecurringRuleClearable = NonNullable<RecurringRulePatch['clear']>[number];
export type RecurringCommitment = Schemas['RecurringCommitment'];
export type BudgetPatch = Schemas['BudgetPatch'];
export type BudgetAlertThreshold = Budget['alert_thresholds'][number];
export type BudgetExplainItem = Schemas['ExplainItem'];
export type SubscriptionPatch = Schemas['SubscriptionPatch'];
export type SubscriptionClearable = NonNullable<SubscriptionPatch['clear']>[number];
export type SubscriptionPaymentCandidate = Schemas['SubscriptionPaymentCandidate'];
export type ChecklistItemPatch = Schemas['ChecklistItemPatch'];
export type GoalPatch = Schemas['GoalPatch'];
export type GoalClearable = NonNullable<GoalPatch['clear']>[number];
export type GoalOwner = Schemas['GoalOwner'];
export type GoalContributionRecordInput = Schemas['GoalContributionRecordInput'];
export type TagPatch = Schemas['TagPatch'];
export type CategoryRuleUpdate = Schemas['RuleUpdate'];
export type CategoryRuleApplyInput = Schemas['RuleApplyInput'];
export type MergeAffected = Schemas['MergeAffected'];
export type MerchantMergeResult = Schemas['MerchantMergeResult'];
export type MerchantMergeAffected = Schemas['MerchantMergeAffected'];
export type MerchantMergePreviewInput = Schemas['Merchants-merge-previewRequest'];
export type MerchantAliasRemoveInput = Schemas['Merchants-aliases-removeRequest'];
export type MerchantListQuery = NonNullable<operations['merchants-list']['parameters']['query']>;
export type MerchantStatusFilter = NonNullable<MerchantListQuery['status']>;
export type Limits = Schemas['Limits'];
