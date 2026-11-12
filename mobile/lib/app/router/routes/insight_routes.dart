import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_compare_screen.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_report_screen.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_screen.dart';
import 'package:montra_mobile/features/fx/presentation/currency_converter_screen.dart';
import 'package:montra_mobile/features/fx/presentation/exchange_rates_screen.dart';
import 'package:montra_mobile/features/fx/presentation/manual_rate_form_screen.dart';
import 'package:montra_mobile/features/reports/presentation/report_detail_screen.dart';
import 'package:montra_mobile/features/reports/presentation/report_form_screen.dart';
import 'package:montra_mobile/features/reports/presentation/report_schedules_screen.dart';
import 'package:montra_mobile/features/reports/presentation/reports_screen.dart';
import 'package:montra_mobile/features/reports/presentation/schedule_form_screen.dart';

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Top-level routes for analytics, reports and exchange rates. Literal
/// segments come before parameters.
List<RouteBase> insightRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.analytics,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const AnalyticsScreen()),
  ),
  GoRoute(
    path: AppRoutes.analyticsCompare,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      AnalyticsCompareScreen(query: state.uri.queryParameters),
    ),
  ),
  GoRoute(
    path: '/analytics/:report',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      AnalyticsReportScreen(
        report: state.pathParameters['report']!,
        query: state.uri.queryParameters,
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.reports,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ReportsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newReport,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ReportFormScreen()),
  ),
  GoRoute(
    path: AppRoutes.reportSchedules,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ReportSchedulesScreen()),
  ),
  GoRoute(
    path: AppRoutes.newReportSchedule,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ScheduleFormScreen()),
  ),
  GoRoute(
    path: '/reports/schedules/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ScheduleFormScreen(scheduleId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: '/reports/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ReportDetailScreen(reportId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: AppRoutes.exchangeRates,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ExchangeRatesScreen()),
  ),
  GoRoute(
    path: AppRoutes.newExchangeRate,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ManualRateFormScreen(
        base: _nonEmpty(state.uri.queryParameters['base']),
        quote: _nonEmpty(state.uri.queryParameters['quote']),
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.currencyConverter,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const CurrencyConverterScreen()),
  ),
];
