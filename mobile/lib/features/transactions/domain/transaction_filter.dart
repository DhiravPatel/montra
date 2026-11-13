import 'package:flutter/foundation.dart';
import 'package:montra_mobile/app/router/app_routes.dart';

/// Named date ranges the API understands (`range=`), in the user's time
/// zone and week/month settings.
const List<String> namedRanges = <String>[
  'today',
  'yesterday',
  'this_week',
  'last_week',
  'this_month',
  'last_month',
  'this_year',
  'last_year',
  'last_7_days',
  'last_30_days',
  'last_90_days',
];

/// Sort orders of `GET /transactions`.
const List<String> transactionSorts = <String>[
  'date_desc',
  'date_asc',
  'amount_desc',
  'amount_asc',
];

/// Filters for `GET /transactions` (the same query the server's dashboard
/// drill-down links use). Immutable with value equality so it can key a
/// provider family.
@immutable
class TransactionFilter {
  /// Creates a filter. Empty values mean "any".
  const TransactionFilter({
    this.range,
    this.from,
    this.to,
    this.types = const <String>{},
    this.accountIds = const <String>{},
    this.categoryIds = const <String>{},
    this.uncategorized = false,
    this.tagIds = const <String>{},
    this.merchantId,
    this.paymentMethodId,
    this.currency,
    this.minAmount,
    this.maxAmount,
    this.query,
    this.source,
    this.status,
    this.direction,
    this.reconciliationState,
    this.hasAttachment,
    this.recurring,
    this.sort = 'date_desc',
  });

  /// Reads a filter from a location such as
  /// `/transactions?from=2026-11-01&to=2026-11-30&category_id=…`.
  /// Unknown or malformed values are ignored.
  factory TransactionFilter.fromQuery(Map<String, String> q) {
    Set<String> ids(String key) => <String>{
      for (final String part in (q[key] ?? '').split(','))
        if (part.trim().isNotEmpty) part.trim(),
    };
    String? text(String key) {
      final String? v = q[key]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    String? oneOf(String key, Set<String> allowed) {
      final String? v = text(key);
      return v != null && allowed.contains(v) ? v : null;
    }

    final RegExp date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    String? day(String key) {
      final String? v = text(key);
      return v != null && date.hasMatch(v) ? v : null;
    }

    // "Without a category" never combines with categories.
    final bool uncategorized = q['uncategorized'] == 'true';
    return TransactionFilter(
      range: oneOf('range', namedRanges.toSet()),
      from: day('from'),
      to: day('to'),
      types: ids('type'),
      accountIds: ids('account_id'),
      categoryIds: uncategorized ? const <String>{} : ids('category_id'),
      uncategorized: uncategorized,
      tagIds: ids('tag_id'),
      merchantId: text('merchant_id'),
      paymentMethodId: text('payment_method_id'),
      currency: text('currency'),
      minAmount: text('min_amount'),
      maxAmount: text('max_amount'),
      query: text('q'),
      source: oneOf('source', _sources),
      status: oneOf('status', _statuses),
      direction: oneOf('direction', const <String>{'inflow', 'outflow'}),
      reconciliationState: oneOf('reconciliation_state', _reconciliation),
      hasAttachment: oneOf('has_attachment', const <String>{'true', 'false'}),
      recurring: oneOf('recurring', const <String>{'true', 'false'}),
      sort: oneOf('sort', transactionSorts.toSet()) ?? 'date_desc',
    );
  }

  /// Reads a saved filter (`POST /saved-filters` with scope
  /// `transactions`): the `GET /transactions` query as a JSON object, with
  /// lists for multi-value parameters and booleans for flags, as the web
  /// saves it too. Unknown keys and invalid values are ignored; IDs must be
  /// UUIDs. Returns null when nothing in [json] is understood (a non-empty
  /// filter this app cannot apply).
  static TransactionFilter? fromSavedJson(Map<String, Object?> json) {
    final RegExp uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    const Set<String> idKeys = <String>{
      'account_id',
      'category_id',
      'tag_id',
      'merchant_id',
      'payment_method_id',
    };
    final Map<String, String> query = <String, String>{};
    for (final MapEntry<String, Object?> e in json.entries) {
      final Object? v = e.value;
      List<String> parts;
      if (v is String) {
        parts = v.split(',');
      } else if (v is List) {
        parts = <String>[
          for (final Object? item in v)
            if (item is String) item,
        ];
      } else if (v is bool) {
        parts = <String>[if (v) 'true'];
      } else if (v is num && e.key.endsWith('_amount')) {
        parts = <String>[v.toString()];
      } else {
        continue;
      }
      parts = <String>[
        for (final String p in parts)
          if (p.trim().isNotEmpty &&
              (!idKeys.contains(e.key) ||
                  uuid.hasMatch(p.trim()) ||
                  (e.key == 'payment_method_id' &&
                      p.trim() == noPaymentMethod)))
            p.trim(),
      ];
      if (parts.isNotEmpty) {
        query[e.key] = parts.join(',');
      }
    }
    final String? q = query['q'];
    if (q != null && q.length > 100) {
      query['q'] = q.substring(0, 100);
    }
    for (final String key in <String>['min_amount', 'max_amount']) {
      final String? amount = query[key];
      if (amount != null && !RegExp(r'^\d+(\.\d+)?$').hasMatch(amount)) {
        query.remove(key);
      }
    }
    final TransactionFilter filter = TransactionFilter.fromQuery(query);
    final bool understood =
        filter != const TransactionFilter() ||
        json.isEmpty ||
        (json.length == 1 && json['sort'] == 'date_desc');
    return understood ? filter : null;
  }

  /// This filter as a saved filter: the `GET /transactions` query without
  /// empty values (and without `cursor`/`limit`), lists as JSON arrays.
  Map<String, Object?> toSavedJson() => <String, Object?>{
    for (final MapEntry<String, Object?> e in toQuery().entries)
      if (e.value is String && (e.value! as String).isNotEmpty)
        e.key: e.value
      else if (e.value is bool && (e.value! as bool))
        e.key: true
      else if (e.value is List && (e.value! as List<Object?>).isNotEmpty)
        e.key: e.value,
  };

  static const Set<String> _sources = <String>{
    'manual',
    'import',
    'receipt',
    'recurring',
    'integration',
    'correction',
    'group',
    'system',
  };

  static const Set<String> _statuses = <String>{
    'active',
    'posted',
    'pending',
    'draft',
    'voided',
    'all',
  };

  static const Set<String> _reconciliation = <String>{
    'unreconciled',
    'matched',
    'reconciled',
    'excluded',
  };

  /// Named range (takes precedence over [from]/[to] on the server).
  final String? range;

  /// Custom start date (`YYYY-MM-DD`).
  final String? from;

  /// Custom end date (`YYYY-MM-DD`).
  final String? to;

  /// Transaction types (wire values).
  final Set<String> types;

  /// Accounts.
  final Set<String> accountIds;

  /// Categories (subcategories included by the server).
  final Set<String> categoryIds;

  /// Only transactions without a category (never with [categoryIds]).
  final bool uncategorized;

  /// Tags (any of).
  final Set<String> tagIds;

  /// Merchant.
  final String? merchantId;

  /// Payment method, or [noPaymentMethod] for transactions without one.
  final String? paymentMethodId;

  /// `payment_method_id` value for "no payment method" (the analytics
  /// drill-down for spending without one).
  static const String noPaymentMethod = 'none';

  /// Whether the filter asks for transactions without a payment method.
  bool get withoutPaymentMethod => paymentMethodId == noPaymentMethod;

  /// Currency for the amount range (the server defaults to the base
  /// currency).
  final String? currency;

  /// Minimum amount (exact decimal string).
  final String? minAmount;

  /// Maximum amount (exact decimal string).
  final String? maxAmount;

  /// Text search over description, notes and merchant.
  final String? query;

  /// Provenance.
  final String? source;

  /// Status (`active` excludes deleted; `voided` shows deleted only).
  final String? status;

  /// `inflow` or `outflow`.
  final String? direction;

  /// Reconciliation state.
  final String? reconciliationState;

  /// `true`/`false`.
  final String? hasAttachment;

  /// `true`/`false`.
  final String? recurring;

  /// Sort order.
  final String sort;

  /// Whether a text search is active.
  bool get hasQuery => query != null && query!.trim().isNotEmpty;

  /// How many filters (other than search and sort) are active.
  int get activeCount => <bool>[
    range != null || from != null || to != null,
    types.isNotEmpty,
    accountIds.isNotEmpty,
    categoryIds.isNotEmpty || uncategorized,
    tagIds.isNotEmpty,
    merchantId != null,
    paymentMethodId != null,
    minAmount != null || maxAmount != null,
    source != null,
    status != null,
    direction != null,
    reconciliationState != null,
    hasAttachment != null,
    recurring != null,
  ].where((bool on) => on).length;

  /// Whether nothing narrows the list.
  bool get isEmpty => activeCount == 0 && !hasQuery;

  /// Query parameters for the API (lists are joined by `ApiClient`).
  Map<String, Object?> toQuery() => <String, Object?>{
    'range': range,
    if (range == null) 'from': from,
    if (range == null) 'to': to,
    'type': types.toList()..sort(),
    'account_id': accountIds.toList()..sort(),
    if (!uncategorized) 'category_id': categoryIds.toList()..sort(),
    if (uncategorized) 'uncategorized': true,
    'tag_id': tagIds.toList()..sort(),
    'merchant_id': merchantId,
    'payment_method_id': paymentMethodId,
    if (minAmount != null || maxAmount != null) 'currency': currency,
    'min_amount': minAmount,
    'max_amount': maxAmount,
    'q': query?.trim(),
    'source': source,
    'status': status,
    'direction': direction,
    'reconciliation_state': reconciliationState,
    'has_attachment': hasAttachment,
    'recurring': recurring,
    if (sort != 'date_desc') 'sort': sort,
  };

  /// The Transactions tab location showing this filter.
  String toLocation() {
    final Map<String, String> params = <String, String>{};
    for (final MapEntry<String, Object?> e in toQuery().entries) {
      final Object? v = e.value;
      if (v is String && v.isNotEmpty) {
        params[e.key] = v;
      } else if (v is bool && v) {
        params[e.key] = 'true';
      } else if (v is List<String> && v.isNotEmpty) {
        params[e.key] = v.join(',');
      }
    }
    if (currency != null && !params.containsKey('currency')) {
      params['currency'] = currency!;
    }
    return Uri(
      path: AppRoutes.transactions,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  /// A copy with some values replaced. Use the `clear*` flags to remove
  /// nullable values.
  TransactionFilter copyWith({
    String? range,
    String? from,
    String? to,
    bool clearDates = false,
    Set<String>? types,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    bool? uncategorized,
    Set<String>? tagIds,
    String? merchantId,
    bool clearMerchant = false,
    String? paymentMethodId,
    bool clearPaymentMethod = false,
    String? currency,
    String? minAmount,
    String? maxAmount,
    bool clearAmounts = false,
    String? query,
    bool clearQuery = false,
    String? source,
    bool clearSource = false,
    String? status,
    bool clearStatus = false,
    String? direction,
    bool clearDirection = false,
    String? reconciliationState,
    bool clearReconciliation = false,
    String? hasAttachment,
    bool clearHasAttachment = false,
    String? recurring,
    bool clearRecurring = false,
    String? sort,
  }) => TransactionFilter(
    range: clearDates ? range : (range ?? this.range),
    from: clearDates ? from : (from ?? this.from),
    to: clearDates ? to : (to ?? this.to),
    types: types ?? this.types,
    accountIds: accountIds ?? this.accountIds,
    categoryIds: (uncategorized ?? this.uncategorized)
        ? const <String>{}
        : (categoryIds ?? this.categoryIds),
    uncategorized: (categoryIds?.isNotEmpty ?? false)
        ? false
        : (uncategorized ?? this.uncategorized),
    tagIds: tagIds ?? this.tagIds,
    merchantId: clearMerchant ? null : (merchantId ?? this.merchantId),
    paymentMethodId: clearPaymentMethod
        ? null
        : (paymentMethodId ?? this.paymentMethodId),
    currency: clearAmounts ? currency : (currency ?? this.currency),
    minAmount: clearAmounts ? minAmount : (minAmount ?? this.minAmount),
    maxAmount: clearAmounts ? maxAmount : (maxAmount ?? this.maxAmount),
    query: clearQuery ? null : (query ?? this.query),
    source: clearSource ? null : (source ?? this.source),
    status: clearStatus ? null : (status ?? this.status),
    direction: clearDirection ? null : (direction ?? this.direction),
    reconciliationState: clearReconciliation
        ? null
        : (reconciliationState ?? this.reconciliationState),
    hasAttachment: clearHasAttachment
        ? null
        : (hasAttachment ?? this.hasAttachment),
    recurring: clearRecurring ? null : (recurring ?? this.recurring),
    sort: sort ?? this.sort,
  );

  /// The same filter without search and filters (sort kept).
  TransactionFilter cleared() => TransactionFilter(sort: sort);

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.range == range &&
      other.from == from &&
      other.to == to &&
      setEquals(other.types, types) &&
      setEquals(other.accountIds, accountIds) &&
      setEquals(other.categoryIds, categoryIds) &&
      other.uncategorized == uncategorized &&
      setEquals(other.tagIds, tagIds) &&
      other.merchantId == merchantId &&
      other.paymentMethodId == paymentMethodId &&
      other.currency == currency &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.query == query &&
      other.source == source &&
      other.status == status &&
      other.direction == direction &&
      other.reconciliationState == reconciliationState &&
      other.hasAttachment == hasAttachment &&
      other.recurring == recurring &&
      other.sort == sort;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    range,
    from,
    to,
    Object.hashAllUnordered(types),
    Object.hashAllUnordered(accountIds),
    Object.hashAllUnordered(categoryIds),
    uncategorized,
    Object.hashAllUnordered(tagIds),
    merchantId,
    paymentMethodId,
    currency,
    minAmount,
    maxAmount,
    query,
    source,
    status,
    direction,
    reconciliationState,
    hasAttachment,
    recurring,
    sort,
  ]);

  // Filters may contain search text; never print it.
  @override
  String toString() => 'TransactionFilter($activeCount active)';
}
