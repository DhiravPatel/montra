import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/imports/presentation/import_detail_screen.dart';
import 'package:montra_mobile/features/imports/presentation/import_mapping_screen.dart';
import 'package:montra_mobile/features/imports/presentation/import_rows_screen.dart';
import 'package:montra_mobile/features/imports/presentation/import_wizard_screen.dart';
import 'package:montra_mobile/features/imports/presentation/imports_screen.dart';
import 'package:montra_mobile/features/reconciliation/presentation/reconcile_balance_screen.dart';
import 'package:montra_mobile/features/reconciliation/presentation/reconciliation_screen.dart';
import 'package:montra_mobile/features/reconciliation/presentation/statement_lines_screen.dart';

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Top-level routes for statement imports and account reconciliation.
/// Literal segments (`new`) come before `:id`.
List<RouteBase> importRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.imports,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ImportsScreen(
        accountId: _nonEmpty(state.uri.queryParameters['account_id']),
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.newImport,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ImportWizardScreen(
        accountId: _nonEmpty(state.uri.queryParameters['account_id']),
      ),
    ),
  ),
  GoRoute(
    path: '/imports/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ImportDetailScreen(importId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/imports/:id/mapping',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ImportMappingScreen(importId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/imports/:id/rows',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ImportRowsScreen(
        importId: state.pathParameters['id']!,
        status: _nonEmpty(state.uri.queryParameters['status']),
      ),
    ),
  ),
  GoRoute(
    path: '/accounts/:accountId/reconcile',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReconciliationScreen(accountId: state.pathParameters['accountId']!),
    ),
  ),
  GoRoute(
    path: '/accounts/:accountId/reconcile/lines',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      StatementLinesScreen(
        accountId: state.pathParameters['accountId']!,
        matched: state.uri.queryParameters['status'] == 'matched',
      ),
    ),
  ),
  GoRoute(
    path: '/accounts/:accountId/reconcile/new',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReconcileBalanceScreen(
        accountId: state.pathParameters['accountId']!,
        importBatchId: _nonEmpty(state.uri.queryParameters['import_batch_id']),
      ),
    ),
  ),
];
