import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';

/// Centered progress indicator with an accessible label.
class LoadingStateView extends StatelessWidget {
  /// Creates the view.
  const LoadingStateView({this.label, super.key});

  /// Text announced to screen readers and shown under the spinner.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final String text = label ?? context.l10n.loadingLabel;
    return Center(
      child: Semantics(
        label: text,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              if (label != null) ...<Widget>[
                const SizedBox(height: Insets.md),
                ExcludeSemantics(
                  child: Text(label!, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-area message: icon, title, optional body, reference and action.
class MessageStateView extends StatelessWidget {
  /// Creates the view.
  const MessageStateView({
    required this.icon,
    required this.title,
    this.body,
    this.requestId,
    this.action,
    super.key,
  });

  /// Decorative icon (hidden from screen readers; the title carries meaning).
  final IconData icon;

  /// Headline.
  final String title;

  /// Explanation.
  final String? body;

  /// Support reference.
  final String? requestId;

  /// Primary action (e.g. retry).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Insets.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.md),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              if (body != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Text(
                  body!,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (requestId != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                RequestReference(requestId!),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: Insets.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The right error state for [error]: offline, permission denied, or a
/// generic failure with the request reference. Always offers [onRetry].
class ErrorStateView extends StatelessWidget {
  /// Creates the view.
  const ErrorStateView({required this.error, required this.onRetry, super.key});

  /// The failure.
  final Object error;

  /// Retries the failed operation.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Widget retry = OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: Text(l10n.actionRetry),
    );
    final Object e = error;
    if (e is ApiException && e.isConnectivityProblem) {
      return MessageStateView(
        icon: Icons.cloud_off_outlined,
        title: l10n.errorOfflineTitle,
        body: describeError(l10n, e),
        action: retry,
      );
    }
    if (e is ApiException && e.isPermissionDenied) {
      return MessageStateView(
        icon: Icons.lock_outline,
        title: l10n.errorPermissionTitle,
        body: l10n.errorPermissionBody,
        requestId: requestIdOf(e),
        action: retry,
      );
    }
    return MessageStateView(
      icon: Icons.error_outline,
      title: l10n.errorGenericTitle,
      body: describeError(l10n, e),
      requestId: requestIdOf(e),
      action: retry,
    );
  }
}

/// Renders an [AsyncValue] with consistent loading, error, empty and data
/// states. Previous data stays visible while refreshing.
class AsyncValueView<T> extends StatelessWidget {
  /// Creates the view.
  const AsyncValueView({
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.empty,
    this.loadingLabel,
    super.key,
  });

  /// The value to render.
  final AsyncValue<T> value;

  /// Builds the data state.
  final Widget Function(T data) data;

  /// Retries after an error.
  final VoidCallback onRetry;

  /// Whether [data] counts as empty.
  final bool Function(T data)? isEmpty;

  /// The empty state.
  final Widget? empty;

  /// Loading label.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<T> v = value;
    // The latest attempt failed (and no retry is running): show the error.
    if (v is AsyncError<T> && !v.isLoading) {
      return ErrorStateView(error: v.error, onRetry: onRetry);
    }
    // Data, or a reload that still has the previous data.
    if (v is AsyncData<T> || (v.hasValue && v is! AsyncError<T>)) {
      return _dataOrEmpty(v.requireValue);
    }
    return LoadingStateView(label: loadingLabel);
  }

  Widget _dataOrEmpty(T current) {
    if (empty != null && (isEmpty?.call(current) ?? false)) {
      return empty!;
    }
    return data(current);
  }
}
