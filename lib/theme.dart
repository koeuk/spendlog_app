import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SpendLog's look, matching the web app: calm surfaces, one confident green,
/// generously rounded cards (28) and pill-shaped controls. Both palettes come
/// off one builder, so light and dark can only drift where they mean to.
abstract final class AppTheme {
  static const green = Color(0xFF2F6B3D);
  static const greenBright = Color(0xFF4B9D5F);
  static const cream = Color(0xFFF7F6F2);
  static const ink = Color(0xFF171717);

  // The dark palette: near-black ground, one step lighter for cards.
  static const darkGround = Color(0xFF121412);
  static const darkSurface = Color(0xFF1D201D);
  static const paper = Color(0xFFECECEA);

  static const cardRadius = 28.0;
  static const pillRadius = 28.0;

  /// Room a scrollable must leave at its bottom so its last row clears the
  /// floating nav bar, which the tabs' content now runs underneath.
  static const navBarClearance = 104.0;

  /// A tab's Scaffold is nested inside the shell's, whose body extends under
  /// the nav bar — so its FAB would otherwise come to rest behind the glass.
  /// Padding the button by the clearance it is missing lifts it clear; the
  /// Scaffold's own 16 is already part of that clearance.
  static const fabNavBarOffset = navBarClearance - kFloatingActionButtonMargin;

  /// Text at a reduced emphasis, in whichever palette is active. Screens use
  /// this instead of Colors.black.withValues so dark mode gets light text for
  /// free.
  static Color faint(BuildContext context, double alpha) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha);

  /// The card/sheet background for the active palette.
  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: brightness,
      // The bright variant reads better on near-black; the deep one on cream.
      primary: isDark ? greenBright : green,
      surface: isDark ? darkSurface : Colors.white,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = isDark ? paper : ink;
    final hairline = scheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.06);
    final inputBorder = scheme.onSurface.withValues(alpha: 0.12);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? darkGround : cream,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: text,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.35)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: const BorderSide(color: greenBright, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: isDark ? greenBright : green),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
