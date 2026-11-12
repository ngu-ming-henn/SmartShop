import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UTS colours (navy and gold from uts.edu.my). Green stays for the
/// sustainability features: green points, no plastic bag, receipts saved.
class AppColors {
  AppColors._();
  static const primary = Color(0xFF262476); // UTS navy: app bar, main buttons
  static const primaryBright = Color(0xFF3A57E8); // gradients, focus
  static const primaryLight = Color(0xFFDCDDF7); // chips, highlights
  static const accent = Color(0xFFD4AF37); // UTS gold: badges, "Ready"
  static const eco = Color(0xFF2E7D32); // green: points and sustainability
  static const background = Color(0xFFF4F6FB);
  static const error = Color(0xFFD32F2F); // out of stock, errors
  static const warning = Color(
    0xFFE65100,
  ); // low stock (dark orange, AA contrast)
  static const textOnAccent = Color(0xFF3E2723);

  // Dark mode
  static const backgroundDark = Color(0xFF0E1022);
  static const surfaceDark = Color(0xFF191B33);
  static const appBarDark = Color(0xFF1A1950);
  static const primaryOnDark = Color(0xFFA3AEFF); // navy is too dark here
  static const ecoOnDark = Color(0xFF7BC47F);

  /// Navy to blue: splash, login and register headers, main buttons.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryBright],
  );
}

/// Colours that change between light and dark mode.
extension ThemeColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Navy text and icons in light mode, light indigo in dark mode.
  Color get brand => colors.primary;

  /// Green for points and sustainability, lighter in dark mode.
  Color get eco => isDark ? AppColors.ecoOnDark : AppColors.eco;
}

ThemeData buildAppTheme({
  bool useGoogleFonts = true,
  Brightness brightness = Brightness.light,
}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primary: dark ? AppColors.primaryOnDark : AppColors.primary,
    onPrimary: dark ? const Color(0xFF10123A) : Colors.white,
    secondary: AppColors.primaryBright,
    secondaryContainer: dark ? const Color(0xFF2E3170) : AppColors.primaryLight,
    onSecondaryContainer: dark ? Colors.white : AppColors.primary,
    tertiary: AppColors.accent,
    onTertiary: AppColors.textOnAccent,
    error: dark ? const Color(0xFFFF6B6B) : AppColors.error,
    surface: dark ? AppColors.surfaceDark : Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? AppColors.backgroundDark
        : AppColors.background,
  );

  final line = dark ? const Color(0xFF34375A) : const Color(0xFFD5D8E5);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: useGoogleFonts
        ? GoogleFonts.poppinsTextTheme(base.textTheme)
        : base.textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.appBarDark : AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? AppColors.primaryBright : null,
        foregroundColor: dark ? Colors.white : null,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1F2240) : Colors.white,
      border: border(line),
      enabledBorder: border(line),
      focusedBorder: border(AppColors.primaryBright, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.07),
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
