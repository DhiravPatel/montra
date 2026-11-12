import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/receipts/presentation/receipt_detail_screen.dart';
import 'package:montra_mobile/features/receipts/presentation/receipt_match_screen.dart';
import 'package:montra_mobile/features/receipts/presentation/receipt_record_screen.dart';
import 'package:montra_mobile/features/receipts/presentation/receipt_review_screen.dart';
import 'package:montra_mobile/features/receipts/presentation/receipts_screen.dart';

/// Top-level routes (pushed over the tabs) for receipts.
List<RouteBase> receiptRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.receipts,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ReceiptsScreen()),
  ),
  GoRoute(
    path: '/receipts/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReceiptDetailScreen(receiptId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/receipts/:id/review',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReceiptReviewScreen(receiptId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/receipts/:id/match',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReceiptMatchScreen(receiptId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/receipts/:id/record',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReceiptRecordScreen(receiptId: state.pathParameters['id']!),
    ),
  ),
];
