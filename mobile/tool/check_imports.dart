// Mobile module boundaries (ARCH-004, docs/ARCHITECTURE.md).
//
// Run from mobile/: `dart run tool/check_imports.dart` (also `make
// mobile-imports`, `make check` and CI). It reads every import, export and
// part directive under lib/ (package and relative URIs, all branches of
// conditional imports) and fails when:
//
// - lib/core/** imports lib/app/** other than the shared app modules, or
//   lib/features/** other than [coreFeatureImports];
// - lib/features/<f>/** imports lib/app/** other than the shared app modules
//   (the router, shell and bootstrap are wired in lib/app and lib/main.dart
//   only), or another feature's file not listed for <f> in [featureImports].
//
// The allowlists are the deliberate cross-feature imports on 2026-11-13.
// Adding an entry is a design decision made in review: prefer moving code
// that several features share to lib/core. `--stale` also lists allowlist
// entries that no longer match an import (informational, exit code 0).
import 'dart:io';

const String packageName = 'montra_mobile';

/// Modules under lib/app that core and features may import: localization,
/// the theme and the route names.
const Set<String> sharedAppModules = {
  'app/l10n/l10n.dart',
  'app/router/app_routes.dart',
  'app/theme/app_theme.dart',
  'app/theme/theme_mode_controller.dart',
};

/// Feature files lib/core may import (paths under lib/features): the error
/// code and display tables that core's error and label mapping uses.
const Set<String> coreFeatureImports = {
  'challenges/domain/challenge_codes.dart',
  'communities/domain/community_codes.dart',
  'group_money/domain/group_money_codes.dart',
  'groups/domain/group_codes.dart',
  'groups/domain/group_display.dart',
  'integrations/domain/integration_codes.dart',
  'moderation/domain/moderation_codes.dart',
  'notifications/domain/notification_codes.dart',
  'privacy/domain/privacy_display.dart',
  'social/domain/social_codes.dart',
  'support/domain/support_display.dart',
};

/// Importing feature -> files of other features it may import (paths under
/// lib/features).
const Map<String, Set<String>> featureImports = {
  'accounts': {
    'auth/presentation/currency_picker.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_tile.dart',
  },
  'analytics': {
    'dashboard/presentation/dashboard_widgets.dart',
    'labels/domain/label_display.dart',
    'recurring/domain/recurring_display.dart',
    'transactions/domain/transaction_filter.dart',
  },
  'bills': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'recurring/domain/lifecycle.dart',
    'recurring/domain/recurring_display.dart',
    'recurring/domain/schedule.dart',
    'recurring/presentation/recurring_detail_screen.dart',
    'recurring/presentation/schedule_editor.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_picker.dart',
  },
  'budgets': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/application/paged_list.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'labels/presentation/load_more_footer.dart',
    'people/application/people_providers.dart',
    'people/presentation/people_pickers.dart',
    'transactions/presentation/transaction_tile.dart',
  },
  'calendar': {'recurring/domain/recurring_display.dart'},
  'challenges': {
    'communities/application/communities_providers.dart',
    'communities/presentation/community_form_errors.dart',
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
    'people/presentation/people_pickers.dart',
  },
  'communities': {
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
    'moderation/data/moderation_api.dart',
    'moderation/domain/moderation_display.dart',
    'people/presentation/people_pickers.dart',
  },
  'dashboard': {
    'analytics/domain/analytics_query.dart',
    'budgets/application/budgets_providers.dart',
    'budgets/domain/budget_display.dart',
    'budgets/presentation/budget_alert_actions.dart',
    'budgets/presentation/budget_alerts_banner.dart',
    'budgets/presentation/budget_widgets.dart',
    'calendar/presentation/calendar_screen.dart',
    'goals/application/goals_providers.dart',
    'goals/domain/goal_display.dart',
    'goals/presentation/goal_widgets.dart',
    'groups/domain/group_display.dart',
    'labels/domain/label_display.dart',
    'notifications/presentation/notification_bell.dart',
    'recurring/domain/recurring_display.dart',
    'settings/application/preferences_providers.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_tile.dart',
    'transactions/presentation/transactions_screen.dart',
  },
  'fx': {'auth/presentation/currency_picker.dart'},
  'goals': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
    'people/application/people_providers.dart',
    'people/presentation/people_pickers.dart',
    'transactions/domain/transaction_display.dart',
    'transactions/presentation/transaction_picker.dart',
  },
  'group_money': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'goals/domain/goal_export.dart',
    'labels/application/paged_list.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/load_more_footer.dart',
    'people/application/people_providers.dart',
    'people/presentation/people_pickers.dart',
    'receipts/presentation/file_actions.dart',
    'recurring/domain/lifecycle.dart',
    'recurring/domain/recurring_display.dart',
    'recurring/domain/schedule.dart',
    'recurring/presentation/schedule_editor.dart',
  },
  'groups': {
    'auth/presentation/currency_picker.dart',
    'people/application/people_providers.dart',
    'people/presentation/people_pickers.dart',
    'social/data/social_api.dart',
    'social/domain/social_display.dart',
    'social/presentation/person_widgets.dart',
  },
  'imports': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/application/paged_list.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'labels/presentation/load_more_footer.dart',
    'receipts/presentation/file_actions.dart',
    'reconciliation/domain/reconciliation_display.dart',
  },
  'insights': {
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
  },
  'integrations': {'accounts/presentation/account_picker.dart'},
  'labels': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'people/presentation/people_pickers.dart',
    'settings/application/preferences_providers.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_tile.dart',
  },
  'moderation': {'communities/domain/community_display.dart'},
  'notifications': {
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
    'people/application/people_providers.dart',
    'settings/application/preferences_providers.dart',
    'settings/data/preferences_api.dart',
  },
  'onboarding': {
    'accounts/presentation/account_widgets.dart',
    'auth/domain/device_profile.dart',
    'auth/presentation/currency_picker.dart',
    'goals/application/goals_providers.dart',
    'goals/data/goals_api.dart',
    'goals/domain/goal_display.dart',
    'labels/application/labels_providers.dart',
    'labels/domain/label_display.dart',
    'recurring/domain/schedule.dart',
    'settings/application/preferences_providers.dart',
    'settings/data/preferences_api.dart',
  },
  'payment_methods': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
  },
  'privacy': {
    'settings/data/limits_api.dart',
    'settings/presentation/reauth_sheet.dart',
  },
  'receipts': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_picker.dart',
  },
  'reconciliation': {
    'accounts/application/accounts_providers.dart',
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
    'transactions/data/transactions_api.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_tile.dart',
  },
  'recurring': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_picker.dart',
  },
  'search': {
    'accounts/domain/account_types.dart',
    'budgets/domain/budget_display.dart',
    'goals/domain/goal_display.dart',
    'labels/domain/organize_display.dart',
    'people/presentation/people_pickers.dart',
  },
  'settings': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/domain/device_profile.dart',
    'auth/domain/password_policy.dart',
    'auth/presentation/currency_picker.dart',
    'auth/presentation/widgets/password_requirements.dart',
    'receipts/application/receipts_providers.dart',
    'receipts/presentation/file_actions.dart',
    'social/application/social_providers.dart',
    'social/data/social_api.dart',
    'social/domain/social_display.dart',
  },
  'social': {
    'groups/application/groups_providers.dart',
    'labels/application/paged_list.dart',
    'labels/presentation/load_more_footer.dart',
    'people/application/people_providers.dart',
    'people/presentation/people_pickers.dart',
  },
  'subscriptions': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'people/application/people_providers.dart',
    'people/presentation/people_pickers.dart',
    'recurring/domain/lifecycle.dart',
    'transactions/domain/transaction_display.dart',
    'transactions/domain/transaction_filter.dart',
    'transactions/presentation/transaction_picker.dart',
  },
  'transactions': {
    'accounts/application/accounts_providers.dart',
    'accounts/presentation/account_picker.dart',
    'auth/presentation/currency_picker.dart',
    'labels/application/labels_providers.dart',
    'labels/domain/label_display.dart',
    'labels/presentation/label_pickers.dart',
    'payment_methods/application/payment_methods_providers.dart',
    'payment_methods/presentation/payment_method_picker.dart',
    'receipts/presentation/file_actions.dart',
  },
};

final RegExp _directive = RegExp(
  r'^\s*(?:import|export|part)\s+([^;]+);',
  multiLine: true,
);
final RegExp _uri = RegExp(r"""['"]([^'"]+)['"]""");

/// Resolves a directive URI in [fromLib] (a path under lib/) to a path under
/// lib/, or null for SDK and other packages.
String? resolve(String uri, String fromLib) {
  const prefix = 'package:$packageName/';
  if (uri.startsWith(prefix)) return uri.substring(prefix.length);
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
  final parts = fromLib.split('/')..removeLast();
  for (final seg in uri.split('/')) {
    if (seg == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else if (seg != '.') {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

/// The boundary violation for an import of [target] from [from] (both paths
/// under lib/), or null when it is allowed. [used] collects allowlist hits.
String? violation(String from, String target, Set<String> used) {
  final src = from.split('/');
  final dst = target.split('/');
  if (src.first == 'core') {
    if (dst.first == 'app' && !sharedAppModules.contains(target)) {
      return 'core must not import $target (only ${sharedAppModules.join(', ')})';
    }
    if (dst.first == 'features') {
      final rel = target.substring('features/'.length);
      if (!coreFeatureImports.contains(rel)) {
        return 'core must not import $target; move shared code to lib/core '
            'or list it in coreFeatureImports';
      }
      used.add('core>$rel');
    }
    return null;
  }
  if (src.first == 'features' && src.length > 2) {
    final feature = src[1];
    if (dst.first == 'app' && !sharedAppModules.contains(target)) {
      return "feature '$feature' must not import $target (the app shell is wired in lib/app)";
    }
    if (dst.first == 'features' && dst.length > 2 && dst[1] != feature) {
      final rel = target.substring('features/'.length);
      if (!(featureImports[feature]?.contains(rel) ?? false)) {
        return "feature '$feature' must not import $target; move shared code to "
            'lib/core or list it under $feature in featureImports';
      }
      used.add('$feature>$rel');
    }
  }
  return null;
}

void main(List<String> args) {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('run from mobile/ (lib/ not found)');
    exit(2);
  }
  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final problems = <String>[];
  final used = <String>{};
  var directives = 0;
  for (final file in files) {
    final from = file.path.substring(lib.path.length + 1).replaceAll(r'\', '/');
    final text = file.readAsStringSync();
    for (final d in _directive.allMatches(text)) {
      final line = '\n'.allMatches(text.substring(0, d.start)).length + 1;
      for (final u in _uri.allMatches(d.group(1)!)) {
        final target = resolve(u.group(1)!, from);
        if (target == null) continue;
        directives++;
        final v = violation(from, target, used);
        if (v != null) problems.add('lib/$from:$line: $v');
      }
    }
  }
  if (args.contains('--stale')) {
    final listed = <String>{
      for (final c in coreFeatureImports) 'core>$c',
      for (final e in featureImports.entries)
        for (final t in e.value) '${e.key}>$t',
    };
    for (final s in listed.difference(used).toList()..sort()) {
      stdout.writeln('stale allowlist entry: ${s.replaceFirst('>', ' -> ')}');
    }
  }
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln(
      '${problems.length} import boundary violation(s) (ARCH-004); see tool/check_imports.dart',
    );
    exit(1);
  }
  stdout.writeln(
    'import boundaries OK: ${files.length} files, $directives internal imports',
  );
}
