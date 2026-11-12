import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';

/// Visual tone of a [NoticeBanner]. Each tone has its own icon, so meaning
/// never depends on color alone.
enum NoticeTone {
  /// Neutral information.
  info,

  /// Something succeeded.
  success,

  /// Something needs attention.
  warning,

  /// Something failed.
  error,
}

/// An inline message with an icon, announced to screen readers when shown.
class NoticeBanner extends StatelessWidget {
  /// Creates the banner.
  const NoticeBanner({
    required this.message,
    this.tone = NoticeTone.info,
    this.title,
    this.requestId,
    this.action,
    super.key,
  });

  /// Main text.
  final String message;

  /// Optional bold first line.
  final String? title;

  /// Tone (icon and colors).
  final NoticeTone tone;

  /// Support reference shown under the message.
  final String? requestId;

  /// Optional action below the text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StatusColors status = StatusColors.of(context);
    final (Color background, Color foreground, IconData icon) = switch (tone) {
      NoticeTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
      NoticeTone.success => (
        status.successContainer,
        status.onSuccessContainer,
        Icons.check_circle_outline,
      ),
      NoticeTone.warning => (
        status.warningContainer,
        status.onWarningContainer,
        Icons.warning_amber_outlined,
      ),
      NoticeTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
    };
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(child: Icon(icon, color: foreground)),
              const SizedBox(width: Insets.sm + Insets.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null) ...<Widget>[
                      Text(
                        title!,
                        style: text.titleSmall?.copyWith(color: foreground),
                      ),
                      const SizedBox(height: Insets.xs),
                    ],
                    Text(
                      message,
                      style: text.bodyMedium?.copyWith(color: foreground),
                    ),
                    if (requestId != null)
                      RequestReference(requestId!, color: foreground),
                    if (action != null) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      action!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A selectable support reference (`Reference: <request id>`) with a copy
/// button. Request IDs are random correlation IDs, not personal data.
class RequestReference extends StatelessWidget {
  /// Creates the reference.
  const RequestReference(this.requestId, {this.color, super.key});

  /// The request ID.
  final String requestId;

  /// Text color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextStyle? style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: color);
    return Row(
      children: <Widget>[
        Expanded(
          child: SelectableText(l10n.requestReference(requestId), style: style),
        ),
        IconButton(
          tooltip: l10n.copyReference,
          color: color,
          icon: const Icon(Icons.copy_outlined, size: 20),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: requestId));
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
            }
          },
        ),
      ],
    );
  }
}
