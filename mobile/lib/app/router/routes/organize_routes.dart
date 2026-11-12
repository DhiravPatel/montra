import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/labels/presentation/categories_screen.dart';
import 'package:montra_mobile/features/labels/presentation/category_form_screen.dart';
import 'package:montra_mobile/features/labels/presentation/category_rule_form_screen.dart';
import 'package:montra_mobile/features/labels/presentation/category_rules_screen.dart';
import 'package:montra_mobile/features/labels/presentation/merchant_detail_screen.dart';
import 'package:montra_mobile/features/labels/presentation/merchant_form_screen.dart';
import 'package:montra_mobile/features/labels/presentation/merchants_screen.dart';
import 'package:montra_mobile/features/labels/presentation/tags_screen.dart';

/// Top-level routes (pushed over the tabs) for: Categories, category rules,
/// tags and merchants.
List<RouteBase> organizeRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.categories,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const CategoriesScreen()),
  ),
  GoRoute(
    path: AppRoutes.newCategory,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CategoryFormScreen(parentId: state.uri.queryParameters['parent']),
    ),
  ),
  GoRoute(
    path: '/categories/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CategoryFormScreen(categoryId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: AppRoutes.categoryRules,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const CategoryRulesScreen()),
  ),
  GoRoute(
    path: AppRoutes.newCategoryRule,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const CategoryRuleFormScreen()),
  ),
  GoRoute(
    path: '/category-rules/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CategoryRuleFormScreen(ruleId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: AppRoutes.tags,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const TagsScreen()),
  ),
  GoRoute(
    path: AppRoutes.merchants,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const MerchantsScreen()),
  ),
  GoRoute(
    path: '/merchants/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      MerchantDetailScreen(merchantId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/merchants/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      MerchantFormScreen(merchantId: state.pathParameters['id']!),
    ),
  ),
];
