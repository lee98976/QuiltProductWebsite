import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared full-screen gradient used on auth, shell, and feature screens.
abstract final class AppDecorations {
  AppDecorations._();

  static final defaultScreenGradient = AppTheme.forOption(
    QuiltThemeOption.options.first,
  ).extension<QuiltThemeTokens>()!.screenGradient;

  static BoxDecoration screenBackground(BuildContext context) {
    final tokens = Theme.of(context).extension<QuiltThemeTokens>();
    return BoxDecoration(
      gradient: tokens?.screenGradient ?? defaultScreenGradient,
    );
  }

  static Color shadow(BuildContext context) {
    return shadowFromTheme(Theme.of(context));
  }

  static Color shadowFromTheme(ThemeData theme) {
    return theme.extension<QuiltThemeTokens>()?.shadow ??
        QuiltThemeOption.options.first.palette.shadow;
  }
}
