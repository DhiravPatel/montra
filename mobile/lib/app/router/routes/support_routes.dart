import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/privacy/presentation/account_closure_screens.dart';
import 'package:montra_mobile/features/privacy/presentation/limits_screen.dart';
import 'package:montra_mobile/features/privacy/presentation/privacy_screen.dart';
import 'package:montra_mobile/features/support/domain/help_guide_content.dart';
import 'package:montra_mobile/features/support/presentation/contact_screen.dart';
import 'package:montra_mobile/features/support/presentation/help_guide_screen.dart';
import 'package:montra_mobile/features/support/presentation/help_guides_screen.dart';
import 'package:montra_mobile/features/support/presentation/help_screen.dart';
import 'package:montra_mobile/features/support/presentation/support_form_screen.dart';
import 'package:montra_mobile/features/support/presentation/support_request_screen.dart';

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Top-level routes for help and support, the public contact form,
/// privacy and data, and the fair-use limits. Literal segments come before
/// parameters. Staff tools (support queue, platform moderation, usage) are
/// web-only.
List<RouteBase> supportRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.help,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const HelpScreen()),
  ),
  GoRoute(
    path: AppRoutes.newSupportRequest,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const SupportFormScreen()),
  ),
  GoRoute(
    path: AppRoutes.helpGuides,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      HelpGuidesScreen(
        topic: HelpGuideTopic.values
            .where(
              (HelpGuideTopic t) =>
                  t.name == state.uri.queryParameters['topic'],
            )
            .firstOrNull,
      ),
    ),
  ),
  GoRoute(
    path: '/help/guides/:slug',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, HelpGuideScreen(slug: state.pathParameters['slug']!)),
  ),
  GoRoute(
    path: '/help/requests/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      SupportRequestScreen(requestId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: AppRoutes.contact,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ContactScreen()),
  ),
  GoRoute(
    path: AppRoutes.privacy,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      PrivacyScreen(exportId: _nonEmpty(state.uri.queryParameters['export'])),
    ),
  ),
  GoRoute(
    path: AppRoutes.deactivateAccount,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const DeactivateScreen()),
  ),
  GoRoute(
    path: AppRoutes.deleteAccount,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const DeleteAccountScreen()),
  ),
  GoRoute(
    path: AppRoutes.limits,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const LimitsScreen()),
  ),
];
