import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/connectivity.dart';

/// Shows an app-wide banner above every screen while the device is offline.
///
/// Used from `MaterialApp.builder`. The banner absorbs the top safe-area
/// inset so screens below it do not pad twice.
class ConnectivityBannerHost extends ConsumerWidget {
  /// Wraps [child] (the router's navigator).
  const ConnectivityBannerHost({required this.child, super.key});

  /// App content.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool online = ref.watch(isOnlineProvider).value ?? true;
    if (online) {
      return child;
    }
    final double topInset = MediaQuery.paddingOf(context).top;
    return Column(
      children: <Widget>[
        OfflineBanner(topInset: topInset),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The offline strip itself.
class OfflineBanner extends StatelessWidget {
  /// Creates the banner; [topInset] is the status-bar height to pad.
  const OfflineBanner({this.topInset = 0, super.key});

  /// Extra top padding (status bar).
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: scheme.inverseSurface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Insets.md,
            topInset + Insets.sm,
            Insets.md,
            Insets.sm,
          ),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: scheme.onInverseSurface,
                  size: 20,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  context.l10n.offlineBanner,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onInverseSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
