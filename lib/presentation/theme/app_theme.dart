import 'package:flutter/cupertino.dart';

/// Presentation-layer theme skeleton for Wood CFT (task 1.2).
///
/// A restrained, neutral Cupertino theme with a single accent color, provided
/// in light and dark variants (Requirement 17.1, 17.7). There is deliberately
/// no wood photography, no secondary brand colors, and no business logic here;
/// screens and tabs arrive in later tasks.
///
/// The theme is intentionally conservative: it leans on Cupertino's system
/// neutrals for backgrounds and labels so controls stay faithful to the Apple
/// Human Interface Guidelines, and overrides only the primary accent so action
/// affordances read consistently in both appearances.
abstract final class AppTheme {
  /// The single accent color used across the app in light appearance.
  ///
  /// A muted slate blue — enough contrast to signal an action without the
  /// saturation of the default iOS system blue, keeping the palette restrained.
  static const Color accentLight = Color(0xFF3A5A78);

  /// The single accent color used across the app in dark appearance.
  ///
  /// A slightly lighter tint of [accentLight] so the accent keeps adequate
  /// contrast against dark neutral backgrounds.
  static const Color accentDark = Color(0xFF7FA8C9);

  /// The light-appearance Cupertino theme.
  static const CupertinoThemeData light = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: accentLight,
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    applyThemeToAll: true,
  );

  /// The dark-appearance Cupertino theme.
  static const CupertinoThemeData dark = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: accentDark,
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    applyThemeToAll: true,
  );

  /// Resolves the theme for the given [brightness].
  ///
  /// Defaults to [light] when the platform brightness is unknown (`null`).
  static CupertinoThemeData forBrightness(Brightness? brightness) =>
      brightness == Brightness.dark ? dark : light;
}
