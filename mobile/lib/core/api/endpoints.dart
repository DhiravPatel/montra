import 'package:flutter/foundation.dart';

/// One operation of the Montra API (`/api/v1` is added by the client).
///
/// `test/core/api/endpoints_contract_test.dart` checks every endpoint here
/// against the OpenAPI contract (method, path and whether it is protected).
@immutable
class ApiEndpoint {
  /// Creates an endpoint.
  const ApiEndpoint(
    this.method,
    this.path, {
    required this.requiresAuth,
    this.idempotent = false,
  });

  /// HTTP method.
  final String method;

  /// Path template relative to `/api/v1`, e.g. `/me/sessions/{sessionId}`.
  final String path;

  /// Whether the operation requires a bearer token (contract `security`).
  final bool requiresAuth;

  /// Whether the operation requires an `Idempotency-Key` header (financial
  /// creates; see `core/api/idempotency.dart`).
  final bool idempotent;

  /// Fills `{name}` placeholders with URL-encoded [parameters].
  String resolve([Map<String, String> parameters = const <String, String>{}]) {
    return path.replaceAllMapped(RegExp(r'\{([A-Za-z0-9_]+)\}'), (Match m) {
      final String name = m.group(1)!;
      final String? value = parameters[name];
      if (value == null || value.isEmpty) {
        throw ArgumentError.value(name, 'parameters', 'missing path parameter');
      }
      return Uri.encodeComponent(value);
    });
  }

  @override
  bool operator ==(Object other) =>
      other is ApiEndpoint &&
      other.method == method &&
      other.path == path &&
      other.requiresAuth == requiresAuth &&
      other.idempotent == idempotent;

  @override
  int get hashCode => Object.hash(method, path, requiresAuth, idempotent);

  @override
  String toString() => '$method $path';
}

/// Every endpoint the app calls.
abstract final class ApiEndpoints {
  // Auth (public).
  static const ApiEndpoint register = ApiEndpoint(
    'POST',
    '/auth/register',
    requiresAuth: false,
  );
  static const ApiEndpoint login = ApiEndpoint(
    'POST',
    '/auth/login',
    requiresAuth: false,
  );
  static const ApiEndpoint verifyMfa = ApiEndpoint(
    'POST',
    '/auth/mfa/verify',
    requiresAuth: false,
  );
  static const ApiEndpoint refresh = ApiEndpoint(
    'POST',
    '/auth/refresh',
    requiresAuth: false,
  );
  static const ApiEndpoint forgotPassword = ApiEndpoint(
    'POST',
    '/auth/password/forgot',
    requiresAuth: false,
  );
  static const ApiEndpoint resetPassword = ApiEndpoint(
    'POST',
    '/auth/password/reset',
    requiresAuth: false,
  );
  static const ApiEndpoint verifyEmail = ApiEndpoint(
    'POST',
    '/auth/email/verify',
    requiresAuth: false,
  );
  static const ApiEndpoint resendVerification = ApiEndpoint(
    'POST',
    '/auth/email/resend',
    requiresAuth: false,
  );

  // Reference data (public).
  static const ApiEndpoint listCurrencies = ApiEndpoint(
    'GET',
    '/currencies',
    requiresAuth: false,
  );

  // Auth (session required).
  static const ApiEndpoint logout = ApiEndpoint(
    'POST',
    '/auth/logout',
    requiresAuth: true,
  );
  static const ApiEndpoint logoutAll = ApiEndpoint(
    'POST',
    '/auth/logout-all',
    requiresAuth: true,
  );
  static const ApiEndpoint reauthenticate = ApiEndpoint(
    'POST',
    '/auth/reauthenticate',
    requiresAuth: true,
  );
  static const ApiEndpoint currentSession = ApiEndpoint(
    'GET',
    '/auth/session',
    requiresAuth: true,
  );

  // Account security.
  static const ApiEndpoint changePassword = ApiEndpoint(
    'POST',
    '/me/password',
    requiresAuth: true,
  );
  static const ApiEndpoint listSessions = ApiEndpoint(
    'GET',
    '/me/sessions',
    requiresAuth: true,
  );
  static const ApiEndpoint revokeSession = ApiEndpoint(
    'DELETE',
    '/me/sessions/{sessionId}',
    requiresAuth: true,
  );
  static const ApiEndpoint totpSetup = ApiEndpoint(
    'POST',
    '/me/mfa/totp/setup',
    requiresAuth: true,
  );
  static const ApiEndpoint totpActivate = ApiEndpoint(
    'POST',
    '/me/mfa/totp/activate',
    requiresAuth: true,
  );
  static const ApiEndpoint totpDisable = ApiEndpoint(
    'POST',
    '/me/mfa/totp/disable',
    requiresAuth: true,
  );
  static const ApiEndpoint regenerateRecoveryCodes = ApiEndpoint(
    'POST',
    '/me/mfa/recovery-codes',
    requiresAuth: true,
  );

  // Profile, preferences and onboarding.
  static const ApiEndpoint getMe = ApiEndpoint(
    'GET',
    '/me',
    requiresAuth: true,
  );
  static const ApiEndpoint getPreferences = ApiEndpoint(
    'GET',
    '/me/preferences',
    requiresAuth: true,
  );
  static const ApiEndpoint updatePreferences = ApiEndpoint(
    'PATCH',
    '/me/preferences',
    requiresAuth: true,
  );
  static const ApiEndpoint recordOnboarding = ApiEndpoint(
    'POST',
    '/me/onboarding',
    requiresAuth: true,
  );

  // Dashboard and analytics.
  static const ApiEndpoint dashboardSummary = ApiEndpoint(
    'GET',
    '/dashboard/summary',
    requiresAuth: true,
  );
  static const ApiEndpoint dashboardWidgets = ApiEndpoint(
    'GET',
    '/dashboard/widgets',
    requiresAuth: true,
  );
  static const ApiEndpoint updateDashboardWidgets = ApiEndpoint(
    'PATCH',
    '/dashboard/widgets',
    requiresAuth: true,
  );
  static const ApiEndpoint dashboardPlanning = ApiEndpoint(
    'GET',
    '/dashboard/planning',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsAccounts = ApiEndpoint(
    'GET',
    '/analytics/accounts',
    requiresAuth: true,
  );

  // Accounts.
  static const ApiEndpoint listAccounts = ApiEndpoint(
    'GET',
    '/accounts',
    requiresAuth: true,
  );
  static const ApiEndpoint createAccount = ApiEndpoint(
    'POST',
    '/accounts',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getAccount = ApiEndpoint(
    'GET',
    '/accounts/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateAccount = ApiEndpoint(
    'PATCH',
    '/accounts/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint adjustAccount = ApiEndpoint(
    'POST',
    '/accounts/{id}/adjustments',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint archiveAccount = ApiEndpoint(
    'POST',
    '/accounts/{id}/archive',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreAccount = ApiEndpoint(
    'POST',
    '/accounts/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint closeAccount = ApiEndpoint(
    'POST',
    '/accounts/{id}/close',
    requiresAuth: true,
  );
  static const ApiEndpoint accountBalance = ApiEndpoint(
    'GET',
    '/accounts/{id}/balance',
    requiresAuth: true,
  );
  static const ApiEndpoint accountTransactions = ApiEndpoint(
    'GET',
    '/accounts/{id}/transactions',
    requiresAuth: true,
  );

  // Payment methods.
  static const ApiEndpoint listPaymentMethods = ApiEndpoint(
    'GET',
    '/payment-methods',
    requiresAuth: true,
  );
  static const ApiEndpoint createPaymentMethod = ApiEndpoint(
    'POST',
    '/payment-methods',
    requiresAuth: true,
  );
  static const ApiEndpoint updatePaymentMethod = ApiEndpoint(
    'PATCH',
    '/payment-methods/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint deletePaymentMethod = ApiEndpoint(
    'DELETE',
    '/payment-methods/{id}',
    requiresAuth: true,
  );

  // Categories, tags and merchants (pickers).
  static const ApiEndpoint listCategories = ApiEndpoint(
    'GET',
    '/categories',
    requiresAuth: true,
  );
  static const ApiEndpoint listTags = ApiEndpoint(
    'GET',
    '/tags',
    requiresAuth: true,
  );
  static const ApiEndpoint listMerchants = ApiEndpoint(
    'GET',
    '/merchants',
    requiresAuth: true,
  );

  // Transactions and transfers.
  static const ApiEndpoint listTransactions = ApiEndpoint(
    'GET',
    '/transactions',
    requiresAuth: true,
  );
  static const ApiEndpoint searchTransactions = ApiEndpoint(
    'GET',
    '/transactions/search',
    requiresAuth: true,
  );
  static const ApiEndpoint createTransaction = ApiEndpoint(
    'POST',
    '/transactions',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getTransaction = ApiEndpoint(
    'GET',
    '/transactions/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateTransaction = ApiEndpoint(
    'PATCH',
    '/transactions/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteTransaction = ApiEndpoint(
    'DELETE',
    '/transactions/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreTransaction = ApiEndpoint(
    'POST',
    '/transactions/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint duplicateTransaction = ApiEndpoint(
    'POST',
    '/transactions/{id}/duplicate',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint refundTransaction = ApiEndpoint(
    'POST',
    '/transactions/{id}/refunds',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint transactionAudit = ApiEndpoint(
    'GET',
    '/transactions/{id}/audit',
    requiresAuth: true,
  );
  static const ApiEndpoint transactionAttachments = ApiEndpoint(
    'GET',
    '/transactions/{id}/attachments',
    requiresAuth: true,
  );
  static const ApiEndpoint detachAttachment = ApiEndpoint(
    'DELETE',
    '/transactions/{id}/attachments/{fileId}',
    requiresAuth: true,
  );
  static const ApiEndpoint bulkUpdateTransactions = ApiEndpoint(
    'POST',
    '/transactions/bulk-update',
    requiresAuth: true,
  );
  static const ApiEndpoint bulkDeleteTransactions = ApiEndpoint(
    'POST',
    '/transactions/bulk-delete',
    requiresAuth: true,
  );
  static const ApiEndpoint createTransfer = ApiEndpoint(
    'POST',
    '/transactions/transfers',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getTransfer = ApiEndpoint(
    'GET',
    '/transactions/transfers/{id}',
    requiresAuth: true,
  );

  static const ApiEndpoint getPaymentMethod = ApiEndpoint(
    'GET',
    '/payment-methods/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint restorePaymentMethod = ApiEndpoint(
    'POST',
    '/payment-methods/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint getOnboarding = ApiEndpoint(
    'GET',
    '/me/onboarding',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteTransfer = ApiEndpoint(
    'DELETE',
    '/transactions/transfers/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreTransfer = ApiEndpoint(
    'POST',
    '/transactions/transfers/{id}/restore',
    requiresAuth: true,
  );

  // Round 2: Category management.
  static const ApiEndpoint createCategory = ApiEndpoint(
    'POST',
    '/categories',
    requiresAuth: true,
  );
  static const ApiEndpoint mergeCategories = ApiEndpoint(
    'POST',
    '/categories/merge',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteCategory = ApiEndpoint(
    'DELETE',
    '/categories/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateCategory = ApiEndpoint(
    'PATCH',
    '/categories/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint archiveCategory = ApiEndpoint(
    'POST',
    '/categories/{id}/archive',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreCategory = ApiEndpoint(
    'POST',
    '/categories/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint listCategoryRules = ApiEndpoint(
    'GET',
    '/category-rules',
    requiresAuth: true,
  );
  static const ApiEndpoint createCategoryRule = ApiEndpoint(
    'POST',
    '/category-rules',
    requiresAuth: true,
  );
  static const ApiEndpoint applyCategoryRules = ApiEndpoint(
    'POST',
    '/category-rules/apply',
    requiresAuth: true,
  );
  static const ApiEndpoint previewCategoryRule = ApiEndpoint(
    'POST',
    '/category-rules/preview',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteCategoryRule = ApiEndpoint(
    'DELETE',
    '/category-rules/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateCategoryRule = ApiEndpoint(
    'PUT',
    '/category-rules/{id}',
    requiresAuth: true,
  );

  // Round 2: Tags.
  static const ApiEndpoint createTag = ApiEndpoint(
    'POST',
    '/tags',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteTag = ApiEndpoint(
    'DELETE',
    '/tags/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateTag = ApiEndpoint(
    'PATCH',
    '/tags/{id}',
    requiresAuth: true,
  );

  // Round 2: Merchants.
  static const ApiEndpoint addMerchantAlias = ApiEndpoint(
    'POST',
    '/merchants/aliases',
    requiresAuth: true,
  );
  static const ApiEndpoint mergeMerchants = ApiEndpoint(
    'POST',
    '/merchants/merge',
    requiresAuth: true,
  );
  static const ApiEndpoint getMerchant = ApiEndpoint(
    'GET',
    '/merchants/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateMerchant = ApiEndpoint(
    'PATCH',
    '/merchants/{id}',
    requiresAuth: true,
  );

  // Round 2: Budgets and alerts.
  static const ApiEndpoint listBudgets = ApiEndpoint(
    'GET',
    '/budgets',
    requiresAuth: true,
  );
  static const ApiEndpoint createBudget = ApiEndpoint(
    'POST',
    '/budgets',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteBudget = ApiEndpoint(
    'DELETE',
    '/budgets/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint getBudget = ApiEndpoint(
    'GET',
    '/budgets/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateBudget = ApiEndpoint(
    'PATCH',
    '/budgets/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint addBudgetMember = ApiEndpoint(
    'POST',
    '/budgets/{id}/members',
    requiresAuth: true,
  );
  static const ApiEndpoint removeBudgetMember = ApiEndpoint(
    'DELETE',
    '/budgets/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateBudgetMember = ApiEndpoint(
    'PATCH',
    '/budgets/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint pauseBudget = ApiEndpoint(
    'POST',
    '/budgets/{id}/pause',
    requiresAuth: true,
  );
  static const ApiEndpoint budgetProgress = ApiEndpoint(
    'GET',
    '/budgets/{id}/progress',
    requiresAuth: true,
  );
  static const ApiEndpoint resumeBudget = ApiEndpoint(
    'POST',
    '/budgets/{id}/resume',
    requiresAuth: true,
  );
  static const ApiEndpoint budgetTransactions = ApiEndpoint(
    'GET',
    '/budgets/{id}/transactions',
    requiresAuth: true,
  );
  static const ApiEndpoint listBudgetAlerts = ApiEndpoint(
    'GET',
    '/budget-alerts',
    requiresAuth: true,
  );
  static const ApiEndpoint updateBudgetAlert = ApiEndpoint(
    'PATCH',
    '/budget-alerts/{id}',
    requiresAuth: true,
  );

  // Round 2: Recurring rules.
  static const ApiEndpoint listRecurringRules = ApiEndpoint(
    'GET',
    '/recurring-rules',
    requiresAuth: true,
  );
  static const ApiEndpoint createRecurringRule = ApiEndpoint(
    'POST',
    '/recurring-rules',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint deleteRecurringRule = ApiEndpoint(
    'DELETE',
    '/recurring-rules/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint getRecurringRule = ApiEndpoint(
    'GET',
    '/recurring-rules/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateRecurringRule = ApiEndpoint(
    'PATCH',
    '/recurring-rules/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint pauseRecurringRule = ApiEndpoint(
    'POST',
    '/recurring-rules/{id}/pause',
    requiresAuth: true,
  );
  static const ApiEndpoint resumeRecurringRule = ApiEndpoint(
    'POST',
    '/recurring-rules/{id}/resume',
    requiresAuth: true,
  );
  static const ApiEndpoint skipNextRecurring = ApiEndpoint(
    'POST',
    '/recurring-rules/{id}/skip-next',
    requiresAuth: true,
  );
  static const ApiEndpoint stopRecurringRule = ApiEndpoint(
    'POST',
    '/recurring-rules/{id}/stop',
    requiresAuth: true,
  );
  static const ApiEndpoint recurringOccurrenceAction = ApiEndpoint(
    'POST',
    '/recurring-occurrences/{id}/actions',
    requiresAuth: true,
    idempotent: true,
  );

  // Round 2: Bills.
  static const ApiEndpoint listBills = ApiEndpoint(
    'GET',
    '/bills',
    requiresAuth: true,
  );
  static const ApiEndpoint createBill = ApiEndpoint(
    'POST',
    '/bills',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getBill = ApiEndpoint(
    'GET',
    '/bills/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateBill = ApiEndpoint(
    'PATCH',
    '/bills/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint markBillPaid = ApiEndpoint(
    'POST',
    '/bills/{id}/mark-paid',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint billPaymentCandidates = ApiEndpoint(
    'GET',
    '/bills/{id}/payment-candidates',
    requiresAuth: true,
  );
  static const ApiEndpoint skipBill = ApiEndpoint(
    'POST',
    '/bills/{id}/skip',
    requiresAuth: true,
  );

  // Round 2: Planning calendar.
  static const ApiEndpoint planningCalendar = ApiEndpoint(
    'GET',
    '/calendar',
    requiresAuth: true,
  );

  // Round 2: Subscriptions.
  static const ApiEndpoint listSubscriptions = ApiEndpoint(
    'GET',
    '/subscriptions',
    requiresAuth: true,
  );
  static const ApiEndpoint createSubscription = ApiEndpoint(
    'POST',
    '/subscriptions',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint listSubscriptionDetections = ApiEndpoint(
    'GET',
    '/subscriptions/detections',
    requiresAuth: true,
  );
  static const ApiEndpoint refreshSubscriptionDetections = ApiEndpoint(
    'POST',
    '/subscriptions/detections/refresh',
    requiresAuth: true,
  );
  static const ApiEndpoint confirmSubscriptionDetection = ApiEndpoint(
    'POST',
    '/subscriptions/detections/{id}/confirm',
    requiresAuth: true,
  );
  static const ApiEndpoint dismissSubscriptionDetection = ApiEndpoint(
    'POST',
    '/subscriptions/detections/{id}/dismiss',
    requiresAuth: true,
  );
  static const ApiEndpoint subscriptionsSummary = ApiEndpoint(
    'GET',
    '/subscriptions/summary',
    requiresAuth: true,
  );
  static const ApiEndpoint getSubscription = ApiEndpoint(
    'GET',
    '/subscriptions/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateSubscription = ApiEndpoint(
    'PATCH',
    '/subscriptions/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint subscriptionCancellationStarted = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/cancellation-started',
    requiresAuth: true,
  );
  static const ApiEndpoint subscriptionCancelled = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/cancelled',
    requiresAuth: true,
  );
  static const ApiEndpoint pauseSubscription = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/pause',
    requiresAuth: true,
  );
  static const ApiEndpoint recordSubscriptionPayment = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/payments',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint reactivateSubscription = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/reactivate',
    requiresAuth: true,
  );
  static const ApiEndpoint resumeSubscription = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/resume',
    requiresAuth: true,
  );
  static const ApiEndpoint verifySubscription = ApiEndpoint(
    'POST',
    '/subscriptions/{id}/verify',
    requiresAuth: true,
  );

  // Round 2: Goals.
  static const ApiEndpoint listGoals = ApiEndpoint(
    'GET',
    '/goals',
    requiresAuth: true,
  );
  static const ApiEndpoint createGoal = ApiEndpoint(
    'POST',
    '/goals',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint deleteGoal = ApiEndpoint(
    'DELETE',
    '/goals/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint getGoal = ApiEndpoint(
    'GET',
    '/goals/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateGoal = ApiEndpoint(
    'PATCH',
    '/goals/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint achieveGoal = ApiEndpoint(
    'POST',
    '/goals/{id}/achieve',
    requiresAuth: true,
  );
  static const ApiEndpoint cancelGoal = ApiEndpoint(
    'POST',
    '/goals/{id}/cancel',
    requiresAuth: true,
  );
  static const ApiEndpoint listGoalContributions = ApiEndpoint(
    'GET',
    '/goals/{id}/contributions',
    requiresAuth: true,
  );
  static const ApiEndpoint addGoalContribution = ApiEndpoint(
    'POST',
    '/goals/{id}/contributions',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint voidGoalContribution = ApiEndpoint(
    'POST',
    '/goals/{id}/contributions/{contributionId}/void',
    requiresAuth: true,
  );
  static const ApiEndpoint exportGoal = ApiEndpoint(
    'GET',
    '/goals/{id}/export',
    requiresAuth: true,
  );
  static const ApiEndpoint goalForecast = ApiEndpoint(
    'GET',
    '/goals/{id}/forecast',
    requiresAuth: true,
  );
  static const ApiEndpoint addGoalMember = ApiEndpoint(
    'POST',
    '/goals/{id}/members',
    requiresAuth: true,
  );
  static const ApiEndpoint removeGoalMember = ApiEndpoint(
    'DELETE',
    '/goals/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateGoalMember = ApiEndpoint(
    'PATCH',
    '/goals/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint pauseGoal = ApiEndpoint(
    'POST',
    '/goals/{id}/pause',
    requiresAuth: true,
  );
  static const ApiEndpoint resumeGoal = ApiEndpoint(
    'POST',
    '/goals/{id}/resume',
    requiresAuth: true,
  );

  // Round 2: People: friends and groups (pickers).
  static const ApiEndpoint listFriends = ApiEndpoint(
    'GET',
    '/connections',
    requiresAuth: true,
  );
  static const ApiEndpoint listGroups = ApiEndpoint(
    'GET',
    '/groups',
    requiresAuth: true,
  );
  static const ApiEndpoint getGroup = ApiEndpoint(
    'GET',
    '/groups/{id}',
    requiresAuth: true,
  );

  // Round 3 (adoption): bill and budget lifecycle, labels, subscriptions, goals, limits.
  static const ApiEndpoint pauseBill = ApiEndpoint(
    'POST',
    '/bills/{id}/pause',
    requiresAuth: true,
  );
  static const ApiEndpoint resumeBill = ApiEndpoint(
    'POST',
    '/bills/{id}/resume',
    requiresAuth: true,
  );
  static const ApiEndpoint archiveBill = ApiEndpoint(
    'POST',
    '/bills/{id}/archive',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreBill = ApiEndpoint(
    'POST',
    '/bills/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreBudget = ApiEndpoint(
    'POST',
    '/budgets/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint getCategory = ApiEndpoint(
    'GET',
    '/categories/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint applySavedCategoryRule = ApiEndpoint(
    'POST',
    '/category-rules/{id}/apply',
    requiresAuth: true,
  );
  static const ApiEndpoint removeMerchantAlias = ApiEndpoint(
    'POST',
    '/merchants/aliases/remove',
    requiresAuth: true,
  );
  static const ApiEndpoint previewMerchantMerge = ApiEndpoint(
    'POST',
    '/merchants/merge/preview',
    requiresAuth: true,
  );
  static const ApiEndpoint subscriptionPaymentCandidates = ApiEndpoint(
    'GET',
    '/subscriptions/{id}/payment-candidates',
    requiresAuth: true,
  );
  static const ApiEndpoint unlinkSubscriptionPayment = ApiEndpoint(
    'DELETE',
    '/subscriptions/{id}/payments/{transactionId}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateSubscriptionChecklistItem = ApiEndpoint(
    'PATCH',
    '/subscriptions/{id}/cancellation-checklist/{index}',
    requiresAuth: true,
  );
  static const ApiEndpoint recordGoalContribution = ApiEndpoint(
    'POST',
    '/goals/{id}/contributions/{contributionId}/record',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getLimits = ApiEndpoint(
    'GET',
    '/limits',
    requiresAuth: true,
  );

  // Round 3: files (upload intent -> content -> complete; signed downloads).
  static const ApiEndpoint createUploadIntent = ApiEndpoint(
    'POST',
    '/files/upload-intent',
    requiresAuth: true,
  );
  static const ApiEndpoint uploadFileContent = ApiEndpoint(
    'PUT',
    '/files/{fileId}/content',
    requiresAuth: true,
  );
  static const ApiEndpoint completeFileUpload = ApiEndpoint(
    'POST',
    '/files/{fileId}/complete',
    requiresAuth: true,
  );
  static const ApiEndpoint getFile = ApiEndpoint(
    'GET',
    '/files/{fileId}',
    requiresAuth: true,
  );
  static const ApiEndpoint fileAccess = ApiEndpoint(
    'GET',
    '/files/{fileId}/access',
    requiresAuth: true,
  );
  static const ApiEndpoint downloadFile = ApiEndpoint(
    'GET',
    '/files/{fileId}/content',
    requiresAuth: false,
  );
  static const ApiEndpoint deleteFile = ApiEndpoint(
    'DELETE',
    '/files/{fileId}',
    requiresAuth: true,
  );
  static const ApiEndpoint addAttachment = ApiEndpoint(
    'POST',
    '/transactions/{id}/attachments',
    requiresAuth: true,
  );

  // Round 3: receipts (reviewed by hand; never POST /receipts/{id}/process).
  static const ApiEndpoint listReceipts = ApiEndpoint(
    'GET',
    '/receipts',
    requiresAuth: true,
  );
  static const ApiEndpoint createReceipt = ApiEndpoint(
    'POST',
    '/receipts',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getReceipt = ApiEndpoint(
    'GET',
    '/receipts/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint reviewReceipt = ApiEndpoint(
    'PATCH',
    '/receipts/{id}/review',
    requiresAuth: true,
  );
  static const ApiEndpoint receiptMatchCandidates = ApiEndpoint(
    'GET',
    '/receipts/{id}/match-candidates',
    requiresAuth: true,
  );
  static const ApiEndpoint matchReceipt = ApiEndpoint(
    'POST',
    '/receipts/{id}/match-transaction',
    requiresAuth: true,
  );
  static const ApiEndpoint receiptCreateTransaction = ApiEndpoint(
    'POST',
    '/receipts/{id}/create-transaction',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint unlinkReceipt = ApiEndpoint(
    'POST',
    '/receipts/{id}/unlink',
    requiresAuth: true,
  );
  static const ApiEndpoint discardReceipt = ApiEndpoint(
    'POST',
    '/receipts/{id}/discard',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreReceipt = ApiEndpoint(
    'POST',
    '/receipts/{id}/restore',
    requiresAuth: true,
  );

  // Round 3: statement imports (CSV, XLSX, OFX).
  static const ApiEndpoint listImports = ApiEndpoint(
    'GET',
    '/imports',
    requiresAuth: true,
  );
  static const ApiEndpoint createImport = ApiEndpoint(
    'POST',
    '/imports',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getImport = ApiEndpoint(
    'GET',
    '/imports/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateImportMapping = ApiEndpoint(
    'PATCH',
    '/imports/{id}/mapping',
    requiresAuth: true,
  );
  static const ApiEndpoint importRows = ApiEndpoint(
    'GET',
    '/imports/{id}/rows',
    requiresAuth: true,
  );
  static const ApiEndpoint updateImportRow = ApiEndpoint(
    'PATCH',
    '/imports/{id}/rows/{rowId}',
    requiresAuth: true,
  );
  static const ApiEndpoint confirmImport = ApiEndpoint(
    'POST',
    '/imports/{id}/confirm',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint cancelImport = ApiEndpoint(
    'POST',
    '/imports/{id}/cancel',
    requiresAuth: true,
  );
  static const ApiEndpoint retryFailedImport = ApiEndpoint(
    'POST',
    '/imports/{id}/retry-failed',
    requiresAuth: true,
  );
  static const ApiEndpoint rollbackImport = ApiEndpoint(
    'POST',
    '/imports/{id}/rollback',
    requiresAuth: true,
  );

  // Round 3: reconciliation.
  static const ApiEndpoint listReconciliations = ApiEndpoint(
    'GET',
    '/accounts/{id}/reconciliations',
    requiresAuth: true,
  );
  static const ApiEndpoint createReconciliation = ApiEndpoint(
    'POST',
    '/accounts/{id}/reconciliations',
    requiresAuth: true,
  );
  static const ApiEndpoint reconciliationCandidates = ApiEndpoint(
    'GET',
    '/reconciliation/candidates',
    requiresAuth: true,
  );
  static const ApiEndpoint listReconciliationMatches = ApiEndpoint(
    'GET',
    '/reconciliation/matches',
    requiresAuth: true,
  );
  static const ApiEndpoint createReconciliationMatch = ApiEndpoint(
    'POST',
    '/reconciliation/matches',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteReconciliationMatch = ApiEndpoint(
    'DELETE',
    '/reconciliation/matches/{id}',
    requiresAuth: true,
  );

  // Round 3: analytics (one currency at a time; never summed across currencies).
  static const ApiEndpoint analyticsCashFlow = ApiEndpoint(
    'GET',
    '/analytics/cash-flow',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsCategories = ApiEndpoint(
    'GET',
    '/analytics/categories',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsExpenses = ApiEndpoint(
    'GET',
    '/analytics/expenses',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsIncome = ApiEndpoint(
    'GET',
    '/analytics/income',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsMerchants = ApiEndpoint(
    'GET',
    '/analytics/merchants',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsBudgets = ApiEndpoint(
    'GET',
    '/analytics/budgets',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsGoals = ApiEndpoint(
    'GET',
    '/analytics/goals',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsSubscriptions = ApiEndpoint(
    'GET',
    '/analytics/subscriptions',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsRecurring = ApiEndpoint(
    'GET',
    '/analytics/recurring',
    requiresAuth: true,
  );
  static const ApiEndpoint analyticsCompare = ApiEndpoint(
    'GET',
    '/analytics/compare',
    requiresAuth: true,
  );

  // Round 3: reports and schedules.
  static const ApiEndpoint listReports = ApiEndpoint(
    'GET',
    '/reports',
    requiresAuth: true,
  );
  static const ApiEndpoint createReport = ApiEndpoint(
    'POST',
    '/reports',
    requiresAuth: true,
  );
  static const ApiEndpoint getReport = ApiEndpoint(
    'GET',
    '/reports/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint downloadReport = ApiEndpoint(
    'GET',
    '/reports/{id}/download',
    requiresAuth: true,
  );
  static const ApiEndpoint listReportSchedules = ApiEndpoint(
    'GET',
    '/reports/schedules',
    requiresAuth: true,
  );
  static const ApiEndpoint createReportSchedule = ApiEndpoint(
    'POST',
    '/reports/schedules',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteReportSchedule = ApiEndpoint(
    'DELETE',
    '/reports/schedules/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint getReportSchedule = ApiEndpoint(
    'GET',
    '/reports/schedules/{id}',
    requiresAuth: true,
  );

  // Round 3: exchange rates.
  static const ApiEndpoint listFxRates = ApiEndpoint(
    'GET',
    '/fx/rates',
    requiresAuth: true,
  );
  static const ApiEndpoint setFxRate = ApiEndpoint(
    'POST',
    '/fx/rates',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteFxRate = ApiEndpoint(
    'DELETE',
    '/fx/rates/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint convertFx = ApiEndpoint(
    'GET',
    '/fx/convert',
    requiresAuth: true,
  );

  // Round 4 (adoption): single records, statement lines, report delete and schedule edits.
  static const ApiEndpoint getCategoryRule = ApiEndpoint(
    'GET',
    '/category-rules/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint getTag = ApiEndpoint(
    'GET',
    '/tags/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint accountStatementLines = ApiEndpoint(
    'GET',
    '/accounts/{id}/statement-lines',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteReport = ApiEndpoint(
    'DELETE',
    '/reports/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateReportSchedule = ApiEndpoint(
    'PATCH',
    '/reports/schedules/{id}',
    requiresAuth: true,
  );

  // Round 4: friends (exact-username search, requests, blocks and mutes, profile).
  static const ApiEndpoint searchUsers = ApiEndpoint(
    'GET',
    '/users/search',
    requiresAuth: true,
  );
  static const ApiEndpoint listFriendRequests = ApiEndpoint(
    'GET',
    '/friend-requests',
    requiresAuth: true,
  );
  static const ApiEndpoint sendFriendRequest = ApiEndpoint(
    'POST',
    '/friend-requests',
    requiresAuth: true,
  );
  static const ApiEndpoint acceptFriendRequest = ApiEndpoint(
    'POST',
    '/friend-requests/{id}/accept',
    requiresAuth: true,
  );
  static const ApiEndpoint declineFriendRequest = ApiEndpoint(
    'POST',
    '/friend-requests/{id}/decline',
    requiresAuth: true,
  );
  static const ApiEndpoint cancelFriendRequest = ApiEndpoint(
    'POST',
    '/friend-requests/{id}/cancel',
    requiresAuth: true,
  );
  static const ApiEndpoint removeFriend = ApiEndpoint(
    'DELETE',
    '/connections/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint blockUser = ApiEndpoint(
    'POST',
    '/users/{userId}/block',
    requiresAuth: true,
  );
  static const ApiEndpoint unblockUser = ApiEndpoint(
    'DELETE',
    '/users/{userId}/block',
    requiresAuth: true,
  );
  static const ApiEndpoint muteUser = ApiEndpoint(
    'POST',
    '/users/{userId}/mute',
    requiresAuth: true,
  );
  static const ApiEndpoint listBlocks = ApiEndpoint(
    'GET',
    '/blocks',
    requiresAuth: true,
  );
  static const ApiEndpoint listMutes = ApiEndpoint(
    'GET',
    '/mutes',
    requiresAuth: true,
  );
  static const ApiEndpoint updateProfile = ApiEndpoint(
    'PATCH',
    '/me',
    requiresAuth: true,
  );

  // Round 4: groups (settings, members, invitations, join requests, activity).
  static const ApiEndpoint createGroup = ApiEndpoint(
    'POST',
    '/groups',
    requiresAuth: true,
  );
  static const ApiEndpoint updateGroup = ApiEndpoint(
    'PATCH',
    '/groups/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteGroup = ApiEndpoint(
    'DELETE',
    '/groups/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint archiveGroup = ApiEndpoint(
    'POST',
    '/groups/{id}/archive',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreGroup = ApiEndpoint(
    'POST',
    '/groups/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint transferGroupOwnership = ApiEndpoint(
    'POST',
    '/groups/{id}/transfer-ownership',
    requiresAuth: true,
  );
  static const ApiEndpoint groupActivity = ApiEndpoint(
    'GET',
    '/groups/{id}/activity',
    requiresAuth: true,
  );
  static const ApiEndpoint addGroupMember = ApiEndpoint(
    'POST',
    '/groups/{id}/members',
    requiresAuth: true,
  );
  static const ApiEndpoint updateGroupMember = ApiEndpoint(
    'PATCH',
    '/groups/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint removeGroupMember = ApiEndpoint(
    'DELETE',
    '/groups/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint listGroupInvitations = ApiEndpoint(
    'GET',
    '/groups/{id}/invitations',
    requiresAuth: true,
  );
  static const ApiEndpoint createGroupInvitation = ApiEndpoint(
    'POST',
    '/groups/{id}/invitations',
    requiresAuth: true,
  );
  static const ApiEndpoint revokeGroupInvitation = ApiEndpoint(
    'DELETE',
    '/groups/{id}/invitations/{invitationId}',
    requiresAuth: true,
  );
  static const ApiEndpoint myGroupInvitations = ApiEndpoint(
    'GET',
    '/group-invitations',
    requiresAuth: true,
  );
  static const ApiEndpoint previewGroupInvitation = ApiEndpoint(
    'POST',
    '/group-invitations/preview',
    requiresAuth: true,
  );
  static const ApiEndpoint acceptGroupInvitationLink = ApiEndpoint(
    'POST',
    '/group-invitations/accept',
    requiresAuth: true,
  );
  static const ApiEndpoint acceptGroupInvitation = ApiEndpoint(
    'POST',
    '/group-invitations/{invitationId}/accept',
    requiresAuth: true,
  );
  static const ApiEndpoint declineGroupInvitation = ApiEndpoint(
    'POST',
    '/group-invitations/{invitationId}/decline',
    requiresAuth: true,
  );
  static const ApiEndpoint listGroupJoinRequests = ApiEndpoint(
    'GET',
    '/groups/{id}/join-requests',
    requiresAuth: true,
  );
  static const ApiEndpoint createGroupJoinRequest = ApiEndpoint(
    'POST',
    '/groups/{id}/join-requests',
    requiresAuth: true,
  );
  static const ApiEndpoint approveGroupJoinRequest = ApiEndpoint(
    'POST',
    '/groups/{id}/join-requests/{requestId}/approve',
    requiresAuth: true,
  );
  static const ApiEndpoint declineGroupJoinRequest = ApiEndpoint(
    'POST',
    '/groups/{id}/join-requests/{requestId}/decline',
    requiresAuth: true,
  );

  // Round 4: group money (expenses, balances, settlements, recurring shared expenses, reports).
  static const ApiEndpoint listGroupExpenses = ApiEndpoint(
    'GET',
    '/groups/{id}/expenses',
    requiresAuth: true,
  );
  static const ApiEndpoint createGroupExpense = ApiEndpoint(
    'POST',
    '/groups/{id}/expenses',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getGroupExpense = ApiEndpoint(
    'GET',
    '/groups/{id}/expenses/{expenseId}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateGroupExpense = ApiEndpoint(
    'PATCH',
    '/groups/{id}/expenses/{expenseId}',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteGroupExpense = ApiEndpoint(
    'DELETE',
    '/groups/{id}/expenses/{expenseId}',
    requiresAuth: true,
  );
  static const ApiEndpoint commentGroupExpense = ApiEndpoint(
    'POST',
    '/groups/{id}/expenses/{expenseId}/comments',
    requiresAuth: true,
  );
  static const ApiEndpoint disputeGroupExpense = ApiEndpoint(
    'POST',
    '/groups/{id}/expenses/{expenseId}/disputes',
    requiresAuth: true,
  );
  static const ApiEndpoint resolveGroupDispute = ApiEndpoint(
    'POST',
    '/groups/{id}/disputes/{disputeId}/resolve',
    requiresAuth: true,
  );
  static const ApiEndpoint recordGroupExpense = ApiEndpoint(
    'POST',
    '/groups/{id}/expenses/{expenseId}/my-record',
    requiresAuth: true,
  );
  static const ApiEndpoint groupBalances = ApiEndpoint(
    'GET',
    '/groups/{id}/balances',
    requiresAuth: true,
  );
  static const ApiEndpoint groupSettlementSuggestions = ApiEndpoint(
    'GET',
    '/groups/{id}/settlement-suggestions',
    requiresAuth: true,
  );
  static const ApiEndpoint listGroupSettlements = ApiEndpoint(
    'GET',
    '/groups/{id}/settlements',
    requiresAuth: true,
  );
  static const ApiEndpoint createGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getGroupSettlement = ApiEndpoint(
    'GET',
    '/groups/{id}/settlements/{settlementId}',
    requiresAuth: true,
  );
  static const ApiEndpoint confirmGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/confirm',
    requiresAuth: true,
  );
  static const ApiEndpoint disputeGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/dispute',
    requiresAuth: true,
  );
  static const ApiEndpoint markGroupSettlementPaid = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/mark-paid',
    requiresAuth: true,
  );
  static const ApiEndpoint recordGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/record',
    requiresAuth: true,
  );
  static const ApiEndpoint unlinkGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/unlink',
    requiresAuth: true,
  );
  static const ApiEndpoint correctGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/correct',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint voidGroupSettlement = ApiEndpoint(
    'POST',
    '/groups/{id}/settlements/{settlementId}/void',
    requiresAuth: true,
  );
  static const ApiEndpoint listGroupRecurring = ApiEndpoint(
    'GET',
    '/groups/{id}/recurring-expenses',
    requiresAuth: true,
  );
  static const ApiEndpoint createGroupRecurring = ApiEndpoint(
    'POST',
    '/groups/{id}/recurring-expenses',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint getGroupRecurring = ApiEndpoint(
    'GET',
    '/groups/{id}/recurring-expenses/{ruleId}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateGroupRecurring = ApiEndpoint(
    'PATCH',
    '/groups/{id}/recurring-expenses/{ruleId}',
    requiresAuth: true,
  );
  static const ApiEndpoint pauseGroupRecurring = ApiEndpoint(
    'POST',
    '/groups/{id}/recurring-expenses/{ruleId}/pause',
    requiresAuth: true,
  );
  static const ApiEndpoint resumeGroupRecurring = ApiEndpoint(
    'POST',
    '/groups/{id}/recurring-expenses/{ruleId}/resume',
    requiresAuth: true,
  );
  static const ApiEndpoint stopGroupRecurring = ApiEndpoint(
    'POST',
    '/groups/{id}/recurring-expenses/{ruleId}/stop',
    requiresAuth: true,
  );
  static const ApiEndpoint addGroupRecurringOccurrence = ApiEndpoint(
    'POST',
    '/groups/{id}/recurring-expenses/{ruleId}/occurrences/{occurrenceId}/add',
    requiresAuth: true,
    idempotent: true,
  );
  static const ApiEndpoint skipGroupRecurringOccurrence = ApiEndpoint(
    'POST',
    '/groups/{id}/recurring-expenses/{ruleId}/occurrences/{occurrenceId}/skip',
    requiresAuth: true,
  );
  static const ApiEndpoint groupReports = ApiEndpoint(
    'GET',
    '/groups/{id}/reports',
    requiresAuth: true,
  );
  static const ApiEndpoint exportGroup = ApiEndpoint(
    'GET',
    '/groups/{id}/export',
    requiresAuth: true,
  );

  // Round 5: communities, posts, comments and content reports.
  static const ApiEndpoint listCommunities = ApiEndpoint(
    'GET',
    '/communities',
    requiresAuth: true,
  );
  static const ApiEndpoint createCommunity = ApiEndpoint(
    'POST',
    '/communities',
    requiresAuth: true,
  );
  static const ApiEndpoint getCommunity = ApiEndpoint(
    'GET',
    '/communities/{ref}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateCommunity = ApiEndpoint(
    'PATCH',
    '/communities/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint archiveCommunity = ApiEndpoint(
    'POST',
    '/communities/{id}/archive',
    requiresAuth: true,
  );
  static const ApiEndpoint restoreCommunity = ApiEndpoint(
    'POST',
    '/communities/{id}/restore',
    requiresAuth: true,
  );
  static const ApiEndpoint transferCommunityOwnership = ApiEndpoint(
    'POST',
    '/communities/{id}/transfer-ownership',
    requiresAuth: true,
  );
  static const ApiEndpoint joinCommunity = ApiEndpoint(
    'POST',
    '/communities/{id}/join',
    requiresAuth: true,
  );
  static const ApiEndpoint leaveCommunity = ApiEndpoint(
    'POST',
    '/communities/{id}/leave',
    requiresAuth: true,
  );
  static const ApiEndpoint listCommunityMembers = ApiEndpoint(
    'GET',
    '/communities/{id}/members',
    requiresAuth: true,
  );
  static const ApiEndpoint updateCommunityMemberRole = ApiEndpoint(
    'PATCH',
    '/communities/{id}/members/{userId}',
    requiresAuth: true,
  );
  static const ApiEndpoint approveCommunityMember = ApiEndpoint(
    'POST',
    '/communities/{id}/members/{userId}/approve',
    requiresAuth: true,
  );
  static const ApiEndpoint rejectCommunityMember = ApiEndpoint(
    'POST',
    '/communities/{id}/members/{userId}/reject',
    requiresAuth: true,
  );
  static const ApiEndpoint listCommunityInvitations = ApiEndpoint(
    'GET',
    '/communities/{id}/invitations',
    requiresAuth: true,
  );
  static const ApiEndpoint createCommunityInvitation = ApiEndpoint(
    'POST',
    '/communities/{id}/invitations',
    requiresAuth: true,
  );
  static const ApiEndpoint revokeCommunityInvitation = ApiEndpoint(
    'DELETE',
    '/communities/{id}/invitations/{invitationId}',
    requiresAuth: true,
  );
  static const ApiEndpoint myCommunityInvitations = ApiEndpoint(
    'GET',
    '/community-invitations',
    requiresAuth: true,
  );
  static const ApiEndpoint previewCommunityInvitation = ApiEndpoint(
    'POST',
    '/community-invitations/preview',
    requiresAuth: true,
  );
  static const ApiEndpoint acceptCommunityInvitationLink = ApiEndpoint(
    'POST',
    '/community-invitations/accept',
    requiresAuth: true,
  );
  static const ApiEndpoint acceptCommunityInvitation = ApiEndpoint(
    'POST',
    '/community-invitations/{id}/accept',
    requiresAuth: true,
  );
  static const ApiEndpoint declineCommunityInvitation = ApiEndpoint(
    'POST',
    '/community-invitations/{id}/decline',
    requiresAuth: true,
  );
  static const ApiEndpoint listCommunityPosts = ApiEndpoint(
    'GET',
    '/communities/{id}/posts',
    requiresAuth: true,
  );
  static const ApiEndpoint createCommunityPost = ApiEndpoint(
    'POST',
    '/communities/{id}/posts',
    requiresAuth: true,
  );
  static const ApiEndpoint getPost = ApiEndpoint(
    'GET',
    '/posts/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updatePost = ApiEndpoint(
    'PATCH',
    '/posts/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint deletePost = ApiEndpoint(
    'DELETE',
    '/posts/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint createComment = ApiEndpoint(
    'POST',
    '/posts/{id}/comments',
    requiresAuth: true,
  );
  static const ApiEndpoint updateComment = ApiEndpoint(
    'PATCH',
    '/comments/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint deleteComment = ApiEndpoint(
    'DELETE',
    '/comments/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint votePoll = ApiEndpoint(
    'POST',
    '/posts/{id}/poll/votes',
    requiresAuth: true,
  );
  static const ApiEndpoint addPostReaction = ApiEndpoint(
    'POST',
    '/posts/{id}/reactions',
    requiresAuth: true,
  );
  static const ApiEndpoint removePostReaction = ApiEndpoint(
    'DELETE',
    '/posts/{id}/reactions/{kind}',
    requiresAuth: true,
  );
  static const ApiEndpoint addCommentReaction = ApiEndpoint(
    'POST',
    '/comments/{id}/reactions',
    requiresAuth: true,
  );
  static const ApiEndpoint removeCommentReaction = ApiEndpoint(
    'DELETE',
    '/comments/{id}/reactions/{kind}',
    requiresAuth: true,
  );
  static const ApiEndpoint reportPost = ApiEndpoint(
    'POST',
    '/posts/{id}/reports',
    requiresAuth: true,
  );
  static const ApiEndpoint createContentReport = ApiEndpoint(
    'POST',
    '/content-reports',
    requiresAuth: true,
  );
  static const ApiEndpoint myContentReports = ApiEndpoint(
    'GET',
    '/content-reports',
    requiresAuth: true,
  );

  // Round 5: moderation (community moderators and what affected the user; staff tools are web-only).
  static const ApiEndpoint communityModerationReports = ApiEndpoint(
    'GET',
    '/communities/{id}/moderation/reports',
    requiresAuth: true,
  );
  static const ApiEndpoint communityModerationAct = ApiEndpoint(
    'POST',
    '/communities/{id}/moderation/actions',
    requiresAuth: true,
  );
  static const ApiEndpoint communityModerationAppeals = ApiEndpoint(
    'GET',
    '/communities/{id}/moderation/appeals',
    requiresAuth: true,
  );
  static const ApiEndpoint communityModerationLog = ApiEndpoint(
    'GET',
    '/communities/{id}/moderation/actions',
    requiresAuth: true,
  );
  static const ApiEndpoint reverseModerationAction = ApiEndpoint(
    'POST',
    '/moderation/actions/{id}/reverse',
    requiresAuth: true,
  );
  static const ApiEndpoint decideModerationAppeal = ApiEndpoint(
    'POST',
    '/moderation/appeals/{id}/decide',
    requiresAuth: true,
  );
  static const ApiEndpoint myModeration = ApiEndpoint(
    'GET',
    '/me/moderation',
    requiresAuth: true,
  );
  static const ApiEndpoint myModerationAppeals = ApiEndpoint(
    'GET',
    '/me/moderation/appeals',
    requiresAuth: true,
  );
  static const ApiEndpoint appealModerationAction = ApiEndpoint(
    'POST',
    '/moderation/actions/{id}/appeals',
    requiresAuth: true,
  );

  // Round 5: challenges.
  static const ApiEndpoint listChallenges = ApiEndpoint(
    'GET',
    '/challenges',
    requiresAuth: true,
  );
  static const ApiEndpoint createChallenge = ApiEndpoint(
    'POST',
    '/challenges',
    requiresAuth: true,
  );
  static const ApiEndpoint getChallenge = ApiEndpoint(
    'GET',
    '/challenges/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint updateChallenge = ApiEndpoint(
    'PATCH',
    '/challenges/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint cancelChallenge = ApiEndpoint(
    'POST',
    '/challenges/{id}/cancel',
    requiresAuth: true,
  );
  static const ApiEndpoint joinChallenge = ApiEndpoint(
    'POST',
    '/challenges/{id}/join',
    requiresAuth: true,
  );
  static const ApiEndpoint leaveChallenge = ApiEndpoint(
    'POST',
    '/challenges/{id}/leave',
    requiresAuth: true,
  );
  static const ApiEndpoint updateChallengeParticipation = ApiEndpoint(
    'PATCH',
    '/challenges/{id}/participation',
    requiresAuth: true,
  );
  static const ApiEndpoint recordChallengeProgress = ApiEndpoint(
    'POST',
    '/challenges/{id}/progress',
    requiresAuth: true,
  );
  static const ApiEndpoint challengeLeaderboard = ApiEndpoint(
    'GET',
    '/challenges/{id}/leaderboard',
    requiresAuth: true,
  );

  // Round 5: notifications (in-app center and preferences; no push SDK).
  static const ApiEndpoint listNotifications = ApiEndpoint(
    'GET',
    '/notifications',
    requiresAuth: true,
  );
  static const ApiEndpoint updateNotification = ApiEndpoint(
    'PATCH',
    '/notifications/{notificationId}',
    requiresAuth: true,
  );
  static const ApiEndpoint readAllNotifications = ApiEndpoint(
    'POST',
    '/notifications/read-all',
    requiresAuth: true,
  );
  static const ApiEndpoint unreadNotificationCount = ApiEndpoint(
    'GET',
    '/notifications/unread-count',
    requiresAuth: true,
  );
  static const ApiEndpoint notificationPreferences = ApiEndpoint(
    'GET',
    '/notifications/preferences',
    requiresAuth: true,
  );
  static const ApiEndpoint updateNotificationPreferences = ApiEndpoint(
    'PATCH',
    '/notifications/preferences',
    requiresAuth: true,
  );

  // Round 5: integrations (the OAuth callback is handled by the web app).
  static const ApiEndpoint listIntegrations = ApiEndpoint(
    'GET',
    '/integrations',
    requiresAuth: true,
  );
  static const ApiEndpoint connectIntegration = ApiEndpoint(
    'POST',
    '/integrations/{ref}/connect',
    requiresAuth: true,
  );
  static const ApiEndpoint integrationStatus = ApiEndpoint(
    'GET',
    '/integrations/{ref}/status',
    requiresAuth: true,
  );
  static const ApiEndpoint syncIntegration = ApiEndpoint(
    'POST',
    '/integrations/{ref}/sync',
    requiresAuth: true,
  );
  static const ApiEndpoint disconnectIntegration = ApiEndpoint(
    'DELETE',
    '/integrations/{ref}',
    requiresAuth: true,
  );

  // Round 5: search and insights (deterministic insights only; no AI generation).
  static const ApiEndpoint search = ApiEndpoint(
    'GET',
    '/search',
    requiresAuth: true,
  );
  static const ApiEndpoint recentSearches = ApiEndpoint(
    'GET',
    '/search/recent',
    requiresAuth: true,
  );
  static const ApiEndpoint clearRecentSearches = ApiEndpoint(
    'DELETE',
    '/search/recent',
    requiresAuth: true,
  );
  static const ApiEndpoint listInsights = ApiEndpoint(
    'GET',
    '/insights',
    requiresAuth: true,
  );
  static const ApiEndpoint getInsight = ApiEndpoint(
    'GET',
    '/insights/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint actOnInsight = ApiEndpoint(
    'POST',
    '/insights/{id}/actions',
    requiresAuth: true,
  );
  static const ApiEndpoint insightFeedback = ApiEndpoint(
    'POST',
    '/insights/{id}/feedback',
    requiresAuth: true,
  );
  static const ApiEndpoint listInsightMutes = ApiEndpoint(
    'GET',
    '/insights/mutes',
    requiresAuth: true,
  );
  static const ApiEndpoint unmuteInsights = ApiEndpoint(
    'DELETE',
    '/insights/mutes',
    requiresAuth: true,
  );

  // Round 5: help and support.
  static const ApiEndpoint listSupportRequests = ApiEndpoint(
    'GET',
    '/support/requests',
    requiresAuth: true,
  );
  static const ApiEndpoint createSupportRequest = ApiEndpoint(
    'POST',
    '/support/requests',
    requiresAuth: true,
  );
  static const ApiEndpoint getSupportRequest = ApiEndpoint(
    'GET',
    '/support/requests/{id}',
    requiresAuth: true,
  );
  static const ApiEndpoint supportRequestMessages = ApiEndpoint(
    'GET',
    '/support/requests/{id}/messages',
    requiresAuth: true,
  );
  static const ApiEndpoint createSupportRequestMessage = ApiEndpoint(
    'POST',
    '/support/requests/{id}/messages',
    requiresAuth: true,
  );
  static const ApiEndpoint contactSupport = ApiEndpoint(
    'POST',
    '/support/contact',
    requiresAuth: false,
  );

  // Round 5: privacy, legal and data.
  static const ApiEndpoint legal = ApiEndpoint(
    'GET',
    '/legal',
    requiresAuth: false,
  );
  static const ApiEndpoint listConsents = ApiEndpoint(
    'GET',
    '/me/consents',
    requiresAuth: true,
  );
  static const ApiEndpoint grantConsent = ApiEndpoint(
    'POST',
    '/me/consents',
    requiresAuth: true,
  );
  static const ApiEndpoint revokeConsent = ApiEndpoint(
    'DELETE',
    '/me/consents/{consentType}',
    requiresAuth: true,
  );
  static const ApiEndpoint requestExport = ApiEndpoint(
    'POST',
    '/me/export',
    requiresAuth: true,
  );
  static const ApiEndpoint getExport = ApiEndpoint(
    'GET',
    '/me/export/{exportId}',
    requiresAuth: true,
  );
  static const ApiEndpoint listExports = ApiEndpoint(
    'GET',
    '/me/exports',
    requiresAuth: true,
  );
  static const ApiEndpoint deactivateAccount = ApiEndpoint(
    'POST',
    '/me/deactivate',
    requiresAuth: true,
  );
  static const ApiEndpoint requestDeletion = ApiEndpoint(
    'POST',
    '/me/deletion-request',
    requiresAuth: true,
  );
  static const ApiEndpoint deletionStatus = ApiEndpoint(
    'GET',
    '/me/deletion-request',
    requiresAuth: true,
  );
  static const ApiEndpoint cancelDeletion = ApiEndpoint(
    'DELETE',
    '/me/deletion-request',
    requiresAuth: true,
  );

  /// All endpoints, for contract tests.
  static const List<ApiEndpoint> all = <ApiEndpoint>[
    register,
    login,
    verifyMfa,
    refresh,
    forgotPassword,
    resetPassword,
    verifyEmail,
    resendVerification,
    listCurrencies,
    logout,
    logoutAll,
    reauthenticate,
    currentSession,
    changePassword,
    listSessions,
    revokeSession,
    totpSetup,
    totpActivate,
    totpDisable,
    regenerateRecoveryCodes,
    getMe,
    getPreferences,
    updatePreferences,
    recordOnboarding,
    dashboardSummary,
    dashboardWidgets,
    updateDashboardWidgets,
    dashboardPlanning,
    analyticsAccounts,
    listAccounts,
    createAccount,
    getAccount,
    updateAccount,
    adjustAccount,
    archiveAccount,
    restoreAccount,
    closeAccount,
    accountBalance,
    accountTransactions,
    listPaymentMethods,
    createPaymentMethod,
    updatePaymentMethod,
    deletePaymentMethod,
    listCategories,
    listTags,
    listMerchants,
    listTransactions,
    searchTransactions,
    createTransaction,
    getTransaction,
    updateTransaction,
    deleteTransaction,
    restoreTransaction,
    duplicateTransaction,
    refundTransaction,
    transactionAudit,
    transactionAttachments,
    detachAttachment,
    bulkUpdateTransactions,
    bulkDeleteTransactions,
    createTransfer,
    getTransfer,
    getPaymentMethod,
    restorePaymentMethod,
    getOnboarding,
    deleteTransfer,
    restoreTransfer,
    createCategory,
    mergeCategories,
    deleteCategory,
    updateCategory,
    archiveCategory,
    restoreCategory,
    listCategoryRules,
    createCategoryRule,
    applyCategoryRules,
    previewCategoryRule,
    deleteCategoryRule,
    updateCategoryRule,
    createTag,
    deleteTag,
    updateTag,
    addMerchantAlias,
    mergeMerchants,
    getMerchant,
    updateMerchant,
    listBudgets,
    createBudget,
    deleteBudget,
    getBudget,
    updateBudget,
    addBudgetMember,
    removeBudgetMember,
    updateBudgetMember,
    pauseBudget,
    budgetProgress,
    resumeBudget,
    budgetTransactions,
    listBudgetAlerts,
    updateBudgetAlert,
    listRecurringRules,
    createRecurringRule,
    deleteRecurringRule,
    getRecurringRule,
    updateRecurringRule,
    pauseRecurringRule,
    resumeRecurringRule,
    skipNextRecurring,
    stopRecurringRule,
    recurringOccurrenceAction,
    listBills,
    createBill,
    getBill,
    updateBill,
    markBillPaid,
    billPaymentCandidates,
    skipBill,
    planningCalendar,
    listSubscriptions,
    createSubscription,
    listSubscriptionDetections,
    refreshSubscriptionDetections,
    confirmSubscriptionDetection,
    dismissSubscriptionDetection,
    subscriptionsSummary,
    getSubscription,
    updateSubscription,
    subscriptionCancellationStarted,
    subscriptionCancelled,
    pauseSubscription,
    recordSubscriptionPayment,
    reactivateSubscription,
    resumeSubscription,
    verifySubscription,
    listGoals,
    createGoal,
    deleteGoal,
    getGoal,
    updateGoal,
    achieveGoal,
    cancelGoal,
    listGoalContributions,
    addGoalContribution,
    voidGoalContribution,
    exportGoal,
    goalForecast,
    addGoalMember,
    removeGoalMember,
    updateGoalMember,
    pauseGoal,
    resumeGoal,
    listFriends,
    listGroups,
    getGroup,
    pauseBill,
    resumeBill,
    archiveBill,
    restoreBill,
    restoreBudget,
    getCategory,
    applySavedCategoryRule,
    removeMerchantAlias,
    previewMerchantMerge,
    subscriptionPaymentCandidates,
    unlinkSubscriptionPayment,
    updateSubscriptionChecklistItem,
    recordGoalContribution,
    getLimits,
    createUploadIntent,
    uploadFileContent,
    completeFileUpload,
    getFile,
    fileAccess,
    downloadFile,
    deleteFile,
    addAttachment,
    listReceipts,
    createReceipt,
    getReceipt,
    reviewReceipt,
    receiptMatchCandidates,
    matchReceipt,
    receiptCreateTransaction,
    unlinkReceipt,
    discardReceipt,
    listImports,
    createImport,
    getImport,
    updateImportMapping,
    importRows,
    updateImportRow,
    confirmImport,
    cancelImport,
    retryFailedImport,
    rollbackImport,
    listReconciliations,
    createReconciliation,
    reconciliationCandidates,
    listReconciliationMatches,
    createReconciliationMatch,
    deleteReconciliationMatch,
    analyticsCashFlow,
    analyticsCategories,
    analyticsExpenses,
    analyticsIncome,
    analyticsMerchants,
    analyticsBudgets,
    analyticsGoals,
    analyticsSubscriptions,
    analyticsRecurring,
    analyticsCompare,
    listReports,
    createReport,
    getReport,
    downloadReport,
    listReportSchedules,
    createReportSchedule,
    deleteReportSchedule,
    getReportSchedule,
    listFxRates,
    setFxRate,
    deleteFxRate,
    convertFx,
    restoreReceipt,
    getCategoryRule,
    getTag,
    accountStatementLines,
    deleteReport,
    updateReportSchedule,
    searchUsers,
    listFriendRequests,
    sendFriendRequest,
    acceptFriendRequest,
    declineFriendRequest,
    cancelFriendRequest,
    removeFriend,
    blockUser,
    unblockUser,
    muteUser,
    listBlocks,
    listMutes,
    updateProfile,
    createGroup,
    updateGroup,
    deleteGroup,
    archiveGroup,
    restoreGroup,
    transferGroupOwnership,
    groupActivity,
    addGroupMember,
    updateGroupMember,
    removeGroupMember,
    listGroupInvitations,
    createGroupInvitation,
    revokeGroupInvitation,
    myGroupInvitations,
    previewGroupInvitation,
    acceptGroupInvitationLink,
    acceptGroupInvitation,
    declineGroupInvitation,
    listGroupJoinRequests,
    createGroupJoinRequest,
    approveGroupJoinRequest,
    declineGroupJoinRequest,
    listGroupExpenses,
    createGroupExpense,
    getGroupExpense,
    updateGroupExpense,
    deleteGroupExpense,
    commentGroupExpense,
    disputeGroupExpense,
    resolveGroupDispute,
    recordGroupExpense,
    groupBalances,
    groupSettlementSuggestions,
    listGroupSettlements,
    createGroupSettlement,
    getGroupSettlement,
    confirmGroupSettlement,
    disputeGroupSettlement,
    markGroupSettlementPaid,
    recordGroupSettlement,
    unlinkGroupSettlement,
    correctGroupSettlement,
    voidGroupSettlement,
    listGroupRecurring,
    createGroupRecurring,
    getGroupRecurring,
    updateGroupRecurring,
    pauseGroupRecurring,
    resumeGroupRecurring,
    stopGroupRecurring,
    addGroupRecurringOccurrence,
    skipGroupRecurringOccurrence,
    groupReports,
    exportGroup,
    listCommunities,
    createCommunity,
    getCommunity,
    updateCommunity,
    archiveCommunity,
    restoreCommunity,
    transferCommunityOwnership,
    joinCommunity,
    leaveCommunity,
    listCommunityMembers,
    updateCommunityMemberRole,
    approveCommunityMember,
    rejectCommunityMember,
    listCommunityInvitations,
    createCommunityInvitation,
    revokeCommunityInvitation,
    myCommunityInvitations,
    previewCommunityInvitation,
    acceptCommunityInvitationLink,
    acceptCommunityInvitation,
    declineCommunityInvitation,
    listCommunityPosts,
    createCommunityPost,
    getPost,
    updatePost,
    deletePost,
    createComment,
    updateComment,
    deleteComment,
    votePoll,
    addPostReaction,
    removePostReaction,
    addCommentReaction,
    removeCommentReaction,
    reportPost,
    createContentReport,
    myContentReports,
    communityModerationReports,
    communityModerationAct,
    communityModerationAppeals,
    communityModerationLog,
    reverseModerationAction,
    decideModerationAppeal,
    myModeration,
    myModerationAppeals,
    appealModerationAction,
    listChallenges,
    createChallenge,
    getChallenge,
    updateChallenge,
    cancelChallenge,
    joinChallenge,
    leaveChallenge,
    updateChallengeParticipation,
    recordChallengeProgress,
    challengeLeaderboard,
    listNotifications,
    updateNotification,
    readAllNotifications,
    unreadNotificationCount,
    notificationPreferences,
    updateNotificationPreferences,
    listIntegrations,
    connectIntegration,
    integrationStatus,
    syncIntegration,
    disconnectIntegration,
    search,
    recentSearches,
    clearRecentSearches,
    listInsights,
    getInsight,
    actOnInsight,
    insightFeedback,
    listInsightMutes,
    unmuteInsights,
    listSupportRequests,
    createSupportRequest,
    getSupportRequest,
    supportRequestMessages,
    createSupportRequestMessage,
    contactSupport,
    legal,
    listConsents,
    grantConsent,
    revokeConsent,
    requestExport,
    getExport,
    listExports,
    deactivateAccount,
    requestDeletion,
    deletionStatus,
    cancelDeletion,
  ];
}
