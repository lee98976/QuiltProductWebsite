import 'package:flutter/material.dart';

import 'AppColors.dart';

class QuiltThemeOption {
  const QuiltThemeOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.palette,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final QuiltThemePalette palette;

  static const defaultId = 'quilt';

  static const options = [
    QuiltThemeOption(
      id: defaultId,
      label: 'Quilt',
      description: 'Clean indigo and soft slate.',
      icon: Icons.auto_awesome_outlined,
      palette: QuiltThemePalette(
        title: AppColors.title,
        subtitle: AppColors.subtitle,
        hint: AppColors.hint,
        inputFill: AppColors.inputFill,
        inputBorder: AppColors.inputBorder,
        accent: AppColors.accent,
        surface: AppColors.surface,
        shadow: AppColors.shadow,
        gradientStart: AppColors.gradientStart,
        gradientMid: AppColors.gradientMid,
        gradientEnd: AppColors.gradientEnd,
      ),
    ),
    QuiltThemeOption(
      id: 'ocean',
      label: 'Ocean',
      description: 'Teal, blue, and airy mist.',
      icon: Icons.water_drop_outlined,
      palette: QuiltThemePalette(
        title: Color(0xFF0B2239),
        subtitle: Color(0xFF3F5E73),
        hint: Color(0xFF83A4B8),
        inputFill: Color(0xFFEAF6F7),
        inputBorder: Color(0xFFC8E4E8),
        accent: Color(0xFF0891B2),
        surface: Color(0xFFFFFFFF),
        shadow: Color(0xFF0B2239),
        gradientStart: Color(0xFFE6FFFB),
        gradientMid: Color(0xFFF7FBFF),
        gradientEnd: Color(0xFFD9ECFF),
      ),
    ),
    QuiltThemeOption(
      id: 'forest',
      label: 'Forest',
      description: 'Green, sage, and warm paper.',
      icon: Icons.park_outlined,
      palette: QuiltThemePalette(
        title: Color(0xFF182617),
        subtitle: Color(0xFF52654C),
        hint: Color(0xFF8CA083),
        inputFill: Color(0xFFF0F6EA),
        inputBorder: Color(0xFFD7E5CC),
        accent: Color(0xFF4D7C0F),
        surface: Color(0xFFFFFEFB),
        shadow: Color(0xFF182617),
        gradientStart: Color(0xFFF0FDF4),
        gradientMid: Color(0xFFFFFEFB),
        gradientEnd: Color(0xFFE8F5D5),
      ),
    ),
    QuiltThemeOption(
      id: 'sunrise',
      label: 'Sunrise',
      description: 'Coral, gold, and pale sky.',
      icon: Icons.wb_sunny_outlined,
      palette: QuiltThemePalette(
        title: Color(0xFF2B1D17),
        subtitle: Color(0xFF6B5548),
        hint: Color(0xFFA89383),
        inputFill: Color(0xFFFFF3EA),
        inputBorder: Color(0xFFF4D3C2),
        accent: Color(0xFFEA580C),
        surface: Color(0xFFFFFFFF),
        shadow: Color(0xFF2B1D17),
        gradientStart: Color(0xFFFFF7ED),
        gradientMid: Color(0xFFFFFBF7),
        gradientEnd: Color(0xFFE0F2FE),
      ),
    ),
    QuiltThemeOption(
      id: 'berry',
      label: 'Berry',
      description: 'Magenta, rose, and cool lavender.',
      icon: Icons.local_florist_outlined,
      palette: QuiltThemePalette(
        title: Color(0xFF281525),
        subtitle: Color(0xFF6A4A61),
        hint: Color(0xFFA4819A),
        inputFill: Color(0xFFFDF2F8),
        inputBorder: Color(0xFFF5CDE1),
        accent: Color(0xFFBE185D),
        surface: Color(0xFFFFFFFF),
        shadow: Color(0xFF281525),
        gradientStart: Color(0xFFFCE7F3),
        gradientMid: Color(0xFFFBFAFF),
        gradientEnd: Color(0xFFEDE9FE),
      ),
    ),
  ];

  static QuiltThemeOption byId(String? id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return options.first;
  }
}

class QuiltThemePalette {
  const QuiltThemePalette({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.inputFill,
    required this.inputBorder,
    required this.accent,
    required this.surface,
    required this.shadow,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
  });

  final Color title;
  final Color subtitle;
  final Color hint;
  final Color inputFill;
  final Color inputBorder;
  final Color accent;
  final Color surface;
  final Color shadow;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
}

@immutable
class QuiltThemeTokens extends ThemeExtension<QuiltThemeTokens> {
  const QuiltThemeTokens({required this.screenGradient, required this.shadow});

  final LinearGradient screenGradient;
  final Color shadow;

  @override
  QuiltThemeTokens copyWith({LinearGradient? screenGradient, Color? shadow}) {
    return QuiltThemeTokens(
      screenGradient: screenGradient ?? this.screenGradient,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  QuiltThemeTokens lerp(ThemeExtension<QuiltThemeTokens>? other, double t) {
    if (other is! QuiltThemeTokens) return this;
    return QuiltThemeTokens(
      screenGradient:
          LinearGradient.lerp(screenGradient, other.screenGradient, t) ??
          screenGradient,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
    );
  }
}

abstract final class AppTheme {
  AppTheme._();

  static ThemeData forOption(QuiltThemeOption option) {
    final palette = option.palette;
    final systemTextTheme = Typography.material2021().black;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: palette.accent,
        onPrimary: palette.surface,
        primaryContainer: palette.accent.withValues(alpha: 0.14),
        onPrimaryContainer: palette.accent,
        surface: palette.surface,
        onSurface: palette.title,
        onSurfaceVariant: palette.subtitle,
        outline: palette.inputBorder,
        surfaceContainerHighest: palette.inputFill,
      ),
      extensions: [
        QuiltThemeTokens(
          screenGradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              palette.gradientStart,
              palette.gradientMid,
              palette.gradientEnd,
            ],
          ),
          shadow: palette.shadow,
        ),
      ],
      textTheme: systemTextTheme.copyWith(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: palette.title,
          letterSpacing: -0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: palette.subtitle,
        ),
        bodySmall: TextStyle(fontSize: 14, color: palette.subtitle),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        prefixIconColor: palette.hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        elevation: 14,
        shadowColor: palette.shadow.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
          elevation: const WidgetStatePropertyAll(14),
          shadowColor: WidgetStatePropertyAll(
            palette.shadow.withValues(alpha: 0.18),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.surface,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        splashBorderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
