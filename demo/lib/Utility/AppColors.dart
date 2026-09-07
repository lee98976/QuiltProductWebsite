import 'package:flutter/material.dart';

/// Single source of color values for the app. Used to build [ThemeData] in
/// main.dart so Material widgets (AppBar, TextField, FilledButton, etc.) get
/// consistent colors. Also use for one-off decorations (e.g. auth gradient,
/// card shadow) that don't have a ThemeData slot.
///
/// **Text hierarchy:** title → subtitle → hint (darkest to lightest).
class AppColors {
  AppColors._();

  // ----- Text (use for hierarchy: title > subtitle > hint) -----
  /// Primary headings (e.g. "Welcome back", screen titles).
  static const Color title = Color(0xFF0F172A); // slate 900

  /// Secondary text (e.g. "Login to your account", descriptions).
  static const Color subtitle = Color(0xFF475569); // slate 600

  /// Tertiary text, labels, and icon tint (e.g. "Don't have an account?", input labels).
  static const Color hint = Color(0xFF94A3B8); // slate 400

  // ----- Surfaces & inputs -----
  /// Input field background (subtle fill).
  static const Color inputFill = Color(0xFFF1F5F9); // slate 100

  /// Input border when idle.
  static const Color inputBorder = Color(0xFFE2E8F0); // slate 200

  /// Input border and focus ring (accent).
  static const Color inputBorderFocused = Color(0xFF6366F1); // indigo 500

  /// Card/sheet background (e.g. login card).
  static const Color surface = Color(0xFFFFFFFF); // white

  /// Soft shadow for cards (use with BoxShadow and low opacity).
  static const Color shadow = Color(0xFF0F172A); // slate 900

  // ----- Brand / actions -----
  /// Primary actions (buttons, links, focus).
  static const Color accent = Color(0xFF6366F1); // indigo 500

  // ----- Auth screen background gradient -----
  static const Color gradientStart = Color(0xFFEEF2FF); // indigo 50
  static const Color gradientMid = Color(0xFFF8FAFC); // slate 50
  static const Color gradientEnd = Color(0xFFE0E7FF); // indigo 100
}
