import 'package:flutter/material.dart';

/// 应用主题：克制扁平、灰底白卡、0.5px 细线条、Material 3
const _primary = Color(0xFF1E88E5);

const _lightSurface = Color(0xFFFFFFFF);
const _lightBackground = Color(0xFFF7F8FA);
const _lightSurfaceVariant = Color(0xFFEEF0F3);
const _lightOnSurface = Color(0xFF222222);
const _lightOnSurfaceVariant = Color(0xFF6B7280);
const _lightOutline = Color(0xFFE5E7EB);

const _darkSurface = Color(0xFF202225);
const _darkBackground = Color(0xFF17181B);
const _darkSurfaceVariant = Color(0xFF2A2C30);
const _darkOnSurface = Color(0xFFE6E8EB);
const _darkOnSurfaceVariant = Color(0xFFA1A6AD);
const _darkOutline = Color(0xFF34383E);

ThemeData buildLightTheme({String? fontFamily}) {
  const colorScheme = ColorScheme.light(
    primary: _primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFBBDEFB),
    onPrimaryContainer: Color(0xFF0D47A1),
    secondary: Color(0xFF26A69A),
    onSecondary: Colors.white,
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    surfaceContainerHighest: _lightSurfaceVariant,
    onSurfaceVariant: _lightOnSurfaceVariant,
    error: Color(0xFFE53935),
    onError: Colors.white,
    outline: _lightOutline,
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: colorScheme,
    scaffoldColor: _lightBackground,
    surface: _lightSurface,
    surfaceVariant: _lightSurfaceVariant,
    outline: _lightOutline,
    onSurface: _lightOnSurface,
    onSurfaceVariant: _lightOnSurfaceVariant,
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const colorScheme = ColorScheme.dark(
    primary: Color(0xFF64B5F6),
    onPrimary: Color(0xFF0D47A1),
    primaryContainer: Color(0xFF1565C0),
    onPrimaryContainer: Color(0xFFE3F2FD),
    secondary: Color(0xFF4DB6AC),
    onSecondary: Color(0xFF003B36),
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    surfaceContainerHighest: _darkSurfaceVariant,
    onSurfaceVariant: _darkOnSurfaceVariant,
    error: Color(0xFFEF5350),
    onError: Color(0xFF1A1A1A),
    outline: _darkOutline,
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: colorScheme,
    scaffoldColor: _darkBackground,
    surface: _darkSurface,
    surfaceVariant: _darkSurfaceVariant,
    outline: _darkOutline,
    onSurface: _darkOnSurface,
    onSurfaceVariant: _darkOnSurfaceVariant,
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  required Color surface,
  required Color surfaceVariant,
  required Color outline,
  required Color onSurface,
  required Color onSurfaceVariant,
  String? fontFamily,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 48,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
        fontFamily: fontFamily,
      ),
      shape: Border(bottom: BorderSide(color: outline, width: 0.5)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 22),
      unselectedIconTheme: IconThemeData(color: onSurfaceVariant, size: 22),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: onSurfaceVariant, fontSize: 12),
      indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 0.5, space: 0.5),
    listTileTheme: ListTileThemeData(
      iconColor: onSurfaceVariant,
      textColor: onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 1),
      ),
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface, fontFamily: fontFamily),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface, fontFamily: fontFamily),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, fontFamily: fontFamily),
      bodyLarge: TextStyle(fontSize: 15, color: onSurface, fontFamily: fontFamily),
      bodyMedium: TextStyle(fontSize: 14, color: onSurface, fontFamily: fontFamily),
      bodySmall: TextStyle(fontSize: 12, color: onSurfaceVariant, fontFamily: fontFamily),
    ),
  );
}
