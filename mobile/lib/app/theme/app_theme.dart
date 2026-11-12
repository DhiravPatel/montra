import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Spacing scale (logical pixels).
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Readable width for forms and text on large screens.
  static const double maxContentWidth = 560;
}

/// Calm, trustworthy Material 3 theme for Montra.
///
/// * Colors derive from a deep teal seed (the brand color used in Montra's
///   emails); Material 3 tonal palettes keep text/background pairs at
///   accessible contrast in light and dark mode.
/// * Every interactive control keeps a 48dp minimum touch target.
/// * Text scales with the system setting (no clamping); layouts scroll.
/// * Page transitions honor "reduce motion" (the system setting or the
///   account's `reduced_motion`, applied through `MediaQuery`).
/// * [highContrast] themes (the system setting or the account's
///   `high_contrast`) use Material's highest contrast level, stronger
///   borders and darker status colors.
abstract final class AppTheme {
  /// Brand seed color.
  static const Color seed = Color(0xFF1F6F5C);

  /// Minimum interactive size.
  static const Size minTouchTarget = Size(48, 48);

  /// Light theme.
  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast: highContrast);

  /// Dark theme.
  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast: highContrast);

  static ThemeData _build(Brightness brightness, {required bool highContrast}) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
    );
    // Borders that separate controls and cards: stronger in high contrast.
    final Color border = highContrast ? scheme.outline : scheme.outlineVariant;
    final BorderRadius radius = BorderRadius.circular(12);
    final ButtonStyle buttonShape = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 48)),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: radius),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[
        StatusColors.forScheme(scheme, highContrast: highContrast),
      ],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ReducedMotionPageTransitionsBuilder(
            PredictiveBackPageTransitionsBuilder(),
          ),
          // The Cupertino builder also drives the swipe-back gesture, which
          // stays available with reduced motion because the user controls it.
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
        helperMaxLines: 4,
        errorMaxLines: 6,
        hintMaxLines: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonShape),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonShape),
      textButtonTheme: TextButtonThemeData(
        style: buttonShape.copyWith(
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: highContrast ? 2 : 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        minTileHeight: 56,
        contentPadding: EdgeInsets.symmetric(horizontal: Insets.md),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
    );
  }
}

/// Semantic status colors that Material's [ColorScheme] does not provide.
///
/// Status is never conveyed by color alone: widgets pair these colors with
/// an icon and text (see `StatusLabel`).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  /// Creates the palette.
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  /// Palette tuned for [scheme]'s brightness; [highContrast] uses darker
  /// (light theme) or lighter (dark theme) text and stronger containers.
  factory StatusColors.forScheme(
    ColorScheme scheme, {
    bool highContrast = false,
  }) {
    final bool dark = scheme.brightness == Brightness.dark;
    if (highContrast) {
      return dark
          ? const StatusColors(
              success: Color(0xFFB4F5D6),
              onSuccess: Color(0xFF001A11),
              successContainer: Color(0xFF9BF5CF),
              onSuccessContainer: Color(0xFF001A11),
              warning: Color(0xFFFFE0A8),
              warningContainer: Color(0xFFFFDEA6),
              onWarningContainer: Color(0xFF1C1200),
            )
          : const StatusColors(
              success: Color(0xFF00402F),
              onSuccess: Color(0xFFFFFFFF),
              successContainer: Color(0xFF00402F),
              onSuccessContainer: Color(0xFFFFFFFF),
              warning: Color(0xFF4A3600),
              warningContainer: Color(0xFF4A3600),
              onWarningContainer: Color(0xFFFFFFFF),
            );
    }
    return dark
        ? const StatusColors(
            success: Color(0xFF7FD8B4),
            onSuccess: Color(0xFF00382A),
            successContainer: Color(0xFF00513D),
            onSuccessContainer: Color(0xFF9BF5CF),
            warning: Color(0xFFF2C161),
            warningContainer: Color(0xFF5B4300),
            onWarningContainer: Color(0xFFFFDEA6),
          )
        : const StatusColors(
            success: Color(0xFF006C51),
            onSuccess: Color(0xFFFFFFFF),
            successContainer: Color(0xFF9BF5CF),
            onSuccessContainer: Color(0xFF002117),
            warning: Color(0xFF785900),
            warningContainer: Color(0xFFFFDEA6),
            onWarningContainer: Color(0xFF261A00),
          );
  }

  /// Text/icon color for positive states on surfaces.
  final Color success;

  /// Content color on [success].
  final Color onSuccess;

  /// Container for positive states.
  final Color successContainer;

  /// Content color on [successContainer].
  final Color onSuccessContainer;

  /// Text/icon color for caution states on surfaces.
  final Color warning;

  /// Container for caution states.
  final Color warningContainer;

  /// Content color on [warningContainer].
  final Color onWarningContainer;

  /// Reads the palette from [context]'s theme.
  static StatusColors of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.extension<StatusColors>() ??
        StatusColors.forScheme(theme.colorScheme);
  }

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) => StatusColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) {
      return this;
    }
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}

/// Wraps a platform page transition and removes it when the user asked the
/// system to reduce motion (`MediaQuery.disableAnimations`).
class ReducedMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Wraps [delegate].
  const ReducedMotionPageTransitionsBuilder(this.delegate);

  /// The transition used when motion is allowed.
  final PageTransitionsBuilder delegate;

  static bool _reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  Duration get transitionDuration => delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final DelegatedTransitionBuilder? inner = delegate.delegatedTransition;
    if (inner == null) {
      return null;
    }
    return (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      bool allowSnapshotting,
      Widget? child,
    ) => _reduceMotion(context)
        ? child
        : inner(
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reduceMotion(context)) {
      return child;
    }
    return delegate.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Returns [duration], or zero when the user asked to reduce motion.
Duration motionAware(BuildContext context, Duration duration) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    ? Duration.zero
    : duration;
