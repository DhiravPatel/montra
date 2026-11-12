import 'package:flutter/material.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';

/// Centers [child] at a readable width with standard padding.
class ContentFrame extends StatelessWidget {
  /// Creates the frame.
  const ContentFrame({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    super.key,
  });

  /// Content.
  final Widget child;

  /// Padding around [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Insets.maxContentWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// A scrollable, safe-area aware page body. Content grows with the system
/// text size instead of overflowing.
class ScrollableContent extends StatelessWidget {
  /// Creates the body.
  const ScrollableContent({required this.children, super.key});

  /// Vertical content.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

/// A heading announced as a header by screen readers.
class SectionHeading extends StatelessWidget {
  /// Creates the heading.
  const SectionHeading(this.text, {this.large = false, super.key});

  /// Heading text.
  final String text;

  /// Use the larger headline style.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Text(
        text,
        style: large ? textTheme.headlineSmall : textTheme.titleMedium,
      ),
    );
  }
}
