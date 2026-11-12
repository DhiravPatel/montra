import 'package:flutter/material.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/widgets/layout.dart';

/// Layout for signed-out screens: app bar with a title (and a back button
/// when there is somewhere to go back to) above scrollable, width-limited
/// content.
class AuthScaffold extends StatelessWidget {
  /// Creates the scaffold.
  const AuthScaffold({
    required this.title,
    required this.children,
    this.intro,
    super.key,
  });

  /// Screen title (also the app bar title).
  final String title;

  /// Optional explanatory paragraph under the heading.
  final String? intro;

  /// Body content.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ScrollableContent(
      children: <Widget>[
        if (intro != null) ...<Widget>[
          Text(intro!, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Insets.lg),
        ],
        ...children,
      ],
    ),
  );
}
