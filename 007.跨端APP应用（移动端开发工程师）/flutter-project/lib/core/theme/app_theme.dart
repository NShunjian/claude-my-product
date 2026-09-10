import 'package:flutter/material.dart';

import 'tokens.dart';

/// 对齐 theme/global.scss — light / dark ThemeData。
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final c = AppColors.light;
    return _build(c, Brightness.light);
  }

  static ThemeData dark() {
    final c = AppColors.dark;
    return _build(c, Brightness.dark);
  }

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: b,
      surface: c.bg,
      error: c.error,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: c.bg,
      colorScheme: scheme.copyWith(
        primary: c.primary,
        surface: c.bg,
        onSurface: c.text,
        error: c.error,
      ),
      dividerColor: c.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        // ponytail: scrolledUnderElevation: 0 + surfaceTintColor: transparent
        //          → 滚动时 AppBar 底色不变深也不出阴影(uniapp app-header
        //          同样永远纯色不变)。只设 elevation: 0 不够,M3 AppBar 在
        //          ListView 滚动时仍会从 scrolledUnderElevation(默认 3)
        //          涨 elevation + 加 surfaceTint,表现为"变色"。
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: c.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.bg,
        selectedItemColor: c.primary,
        unselectedItemColor: c.textVariant,
        type: BottomNavigationBarType.fixed,
      ),
      extensions: [
        AppThemeExt(
          colors: c,
          tabBarHeight: AppThemeExt.tabBarHeightDefault,
        ),
      ],
    );
  }
}
