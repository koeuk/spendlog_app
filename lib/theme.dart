import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/branding.dart';

/// SpendLog's look: glass. Every surface is a translucent pane over a soft
/// gradient ground ([GlassBackdrop]), with a light hairline where it catches
/// the edge, one confident green for anything you can act on, and pill-shaped
/// controls. Both palettes come off one builder, so light and dark can only
/// drift where they mean to.
abstract final class AppTheme {
  static const green = Color(0xFF2F6B3D);
  static const greenBright = Color(0xFF4B9D5F);
  static const cream = Color(0xFFF7F6F2);
  static const ink = Color(0xFF171717);

  // The dark palette: near-black ground (see GlassBackdrop), one step
  // lighter for cards.
  static const darkGround = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const paper = Color(0xFFECECEA);

  static const cardRadius = 24.0;
  static const pillRadius = 28.0;

  /// Rows in a list — expenses, categories, users — are short and
  /// stack tightly, so the panel radius reads as lumpy on them. They round a
  /// step less than the big cards.
  static const rowRadius = 18.0;

  /// Horizontal breathing room between a tab's content and the window edge.
  /// Matches the floating nav bar's inset so cards and bar share an edge.
  static const pageInset = 16.0;

  /// Room a scrollable must leave at its bottom so its last row clears the
  /// floating nav bar, which the tabs' content now runs underneath. Also where
  /// the tabs' add button comes to rest: a clear gap above the bar.
  static const navBarClearance = 84.0;

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

  /// The translucent pane colour. `strong` is more opaque, for panels that
  /// carry forms (sheets, dialogs) and must stay legible over busy content.
  static Color glassFill(BuildContext context, {bool strong = false}) =>
      _fill(Theme.of(context).brightness == Brightness.dark, strong: strong);

  /// The light edge a pane catches — bright in light mode, barely there in
  /// dark, where a bright rim would read as a hard outline.
  static Color glassBorder(BuildContext context) =>
      _edge(Theme.of(context).brightness == Brightness.dark);

  /// Cards, inputs and chips are solid — white by day, the dark surface at
  /// night — over the flat ground. Only the `strong` panes that carry a
  /// backdrop blur (nav bar, sheets) keep a hint of translucency, so what
  /// scrolls beneath them still shows through the frost.
  static Color _fill(bool isDark, {bool strong = false}) {
    final base = isDark ? darkSurface : Colors.white;
    if (!strong) return base;
    return base.withValues(alpha: isDark ? 0.94 : 0.92);
  }

  static Color _edge(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE3E7EC);

  /// The card theme's shape at the tighter [rowRadius], hairline border kept.
  static ShapeBorder rowShape(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(rowRadius),
      side: shape is RoundedRectangleBorder ? shape.side : BorderSide.none,
    );
  }

  /// The soft red wash behind an inline error, and the ink on it — pink on
  /// white by day, a dim red tint with a lighter red by night.
  static Color errorFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFDC2626).withValues(alpha: 0.18)
          : const Color(0xFFFDECEC);

  static Color errorInk(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF87171)
          : const Color(0xFFB3261E);

  /// The card/sheet background for the active palette.
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  /// The accent for anything you can act on — the admin's button colour when
  /// one is chosen, the house green otherwise. Read from the theme so every
  /// widget follows a change without a restart.
  static Color accent(BuildContext context) => Theme.of(context).colorScheme.primary;

  /// Text and icons laid on [accent]: white on a deep colour, ink on a pale one.
  static Color onAccent(BuildContext context) => Theme.of(context).colorScheme.onPrimary;

  static ThemeData light([Branding branding = Branding.stock, String locale = 'en']) =>
      _build(Brightness.light, branding, locale);

  static ThemeData dark([Branding branding = Branding.stock, String locale = 'en']) =>
      _build(Brightness.dark, branding, locale);

  static ThemeData _build(Brightness brightness, Branding branding, String locale) {
    final isDark = brightness == Brightness.dark;

    final chosen = branding.branded ? Branding.parseHex(branding.buttonColor) : null;
    final accent = chosen ?? green;
    // A chosen colour is lifted for dark mode the way the house green is:
    // the deep one reads on cream, the bright one on near-black.
    final accentBright = chosen == null ? greenBright : Color.lerp(chosen, Colors.white, 0.22)!;
    final primary = isDark ? accentBright : accent;
    // Computed, never chosen: the label has to survive whichever fill is
    // picked, and only the fill knows which end reads on it.
    final onPrimary = primary.computeLuminance() > 0.45 ? ink : Colors.white;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      surface: isDark ? darkSurface : Colors.white,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = isDark ? paper : ink;
    final hairline = scheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.06);
    final inputBorder = scheme.onSurface.withValues(
      alpha: isDark ? 0.14 : 0.10,
    );
    // On a chosen background the cards go solid white, as on the web: glass
    // over a tinted ground would frost the tint into every card.
    final fill = !isDark && branding.plainBackground ? Colors.white : _fill(isDark);
    final opaque = isDark ? darkSurface : Colors.white;

    return base.copyWith(
      // Transparent on purpose: the gradient ground is painted once, beneath
      // the navigator, by GlassBackdrop.
      scaffoldBackgroundColor: Colors.transparent,
      // Inter has no Khmer glyphs; Noto Sans Khmer is the face built for them.
      textTheme: (locale == 'km'
              ? GoogleFonts.notoSansKhmerTextTheme(base.textTheme)
              : GoogleFonts.interTextTheme(base.textTheme))
          .apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: text,
        // Every screen's title, set once: a step under titleLarge so the bar
        // reads as a label over the content rather than a headline of its own.
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: text),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: fill,
        // No outline: a white card on the grey ground is its own edge.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        side: BorderSide(color: inputBorder),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: text),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : fill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? onPrimary : text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: inputBorder)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: opaque,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: opaque,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 16,
        ),
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
          borderSide: BorderSide(color: primary, width: 1.6),
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
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
