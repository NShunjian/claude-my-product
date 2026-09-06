import 'package:flutter/material.dart';

/// 对齐 theme/tokens.ts — Light + Dark 两套色板 + 间距 + 圆角。
class AppColors {
  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.bg,
    required this.bgCard,
    required this.text,
    required this.textVariant,
    required this.error,
    required this.divider,
    required this.surface,
  });

  final Color primary;
  final Color primaryLight;
  final Color bg;
  final Color bgCard;
  final Color text;
  final Color textVariant;
  final Color error;
  final Color divider;
  final Color surface;

  static const light = AppColors(
    primary: Color(0xFF2E7DE6),
    primaryLight: Color(0xFFD9E8FA),
    bg: Color(0xFFFFFFFF),
    bgCard: Color(0xFFFAFAFA),
    text: Color(0xFF1A1A1A),
    textVariant: Color(0xFF5F6368),
    error: Color(0xFFBA1A1A),
    divider: Color(0xFFE0E0E0),
    surface: Color(0xFFF5F5F5),
  );

  static const dark = AppColors(
    primary: Color(0xFF5BA3FF),
    primaryLight: Color(0xFF1F3A60),
    bg: Color(0xFF0F1115),
    bgCard: Color(0xFF181B22),
    text: Color(0xFFE6E8EC),
    textVariant: Color(0xFFA0A6B2),
    error: Color(0xFFFF6B6B),
    divider: Color(0xFF2A2F38),
    surface: Color(0xFF1F242C),
  );
}

class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class AppRadius {
  const AppRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
}

@immutable
class AppThemeExt extends ThemeExtension<AppThemeExt> {
  const AppThemeExt({
    required this.colors,
    required this.tabBarHeight,
  });

  final AppColors colors;
  final double tabBarHeight;

  static const tabBarHeightDefault = 56.0;

  @override
  AppThemeExt copyWith({AppColors? colors, double? tabBarHeight}) => AppThemeExt(
        colors: colors ?? this.colors,
        tabBarHeight: tabBarHeight ?? this.tabBarHeight,
      );

  @override
  AppThemeExt lerp(ThemeExtension<AppThemeExt>? other, double t) {
    if (other is! AppThemeExt) return this;
    return AppThemeExt(
      colors: t < 0.5 ? colors : other.colors,
      tabBarHeight: tabBarHeight + (other.tabBarHeight - tabBarHeight) * t,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppThemeExt>()?.colors ?? AppColors.light;
  double get tabBarHeight =>
      Theme.of(this).extension<AppThemeExt>()?.tabBarHeight ?? AppThemeExt.tabBarHeightDefault;
}
