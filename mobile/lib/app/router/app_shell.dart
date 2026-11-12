import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';

/// A top-level destination of the signed-in app (spec §2.1): Home,
/// Transactions, Insights, Together (friends, groups, communities and
/// challenges) and Profile, each with a matching `StatefulShellBranch` in
/// `app_router.dart`.
@immutable
class AppDestination {
  /// Creates a destination.
  const AppDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showsUnreadBadge = false,
  });

  /// Root path of the branch.
  final String path;

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected.
  final IconData selectedIcon;

  /// Localized label.
  final String Function(AppLocalizations l10n) label;

  /// Whether unread notifications show as a badge on this destination
  /// (the notification center is opened from Profile).
  final bool showsUnreadBadge;
}

/// Destinations in navigation-bar order (one per shell branch).
final List<AppDestination> appDestinations = <AppDestination>[
  AppDestination(
    path: AppRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: (AppLocalizations l10n) => l10n.navHome,
  ),
  AppDestination(
    path: AppRoutes.transactions,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: (AppLocalizations l10n) => l10n.navTransactions,
  ),
  AppDestination(
    path: AppRoutes.insights,
    icon: Icons.lightbulb_outline,
    selectedIcon: Icons.lightbulb,
    label: (AppLocalizations l10n) => l10n.navInsights,
  ),
  AppDestination(
    path: AppRoutes.together,
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: (AppLocalizations l10n) => l10n.navTogether,
  ),
  AppDestination(
    path: AppRoutes.profile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: (AppLocalizations l10n) => l10n.navProfile,
    showsUnreadBadge: true,
  ),
];

/// Frame around the signed-in branches. A bottom [NavigationBar] appears
/// once there are at least two destinations (Material requires two).
class AppShell extends ConsumerWidget {
  /// Creates the shell.
  const AppShell({
    required this.navigationShell,
    required this.destinations,
    super.key,
  });

  /// go_router's branch container.
  final StatefulNavigationShell navigationShell;

  /// Destinations matching the shell's branches.
  final List<AppDestination> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (destinations.length < 2) {
      return navigationShell;
    }
    final AppLocalizations l10n = context.l10n;
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        // At large text sizes five labels do not fit and would break inside
        // words; then only the selected tab shows its label (every tab keeps
        // its tooltip and screen-reader label).
        labelBehavior: MediaQuery.textScalerOf(context).scale(14) > 14 * 1.2
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : null,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: <NavigationDestination>[
          for (final AppDestination d in destinations)
            NavigationDestination(
              icon: _badged(l10n, Icon(d.icon), d, unread),
              selectedIcon: _badged(l10n, Icon(d.selectedIcon), d, unread),
              label: d.label(l10n),
            ),
        ],
      ),
    );
  }

  /// [icon] with the unread-notification badge when [d] carries it.
  Widget _badged(
    AppLocalizations l10n,
    Widget icon,
    AppDestination d,
    int unread,
  ) {
    if (!d.showsUnreadBadge || unread <= 0) {
      return icon;
    }
    return Semantics(
      label: l10n.notificationsUnreadBadge(unread),
      child: Badge.count(count: unread, child: icon),
    );
  }
}
