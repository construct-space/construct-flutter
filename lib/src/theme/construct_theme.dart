// Construct design tokens — mirrors the desktop's "Light" theme so
// every Construct surface (web, desktop, mobile) reads as one product.
//
// Tokens are imported from
// construct-app/frontend/composables/useAppTheme.ts (the "vs" entry).
// When the desktop theme palette evolves, update here too — there's
// no shared cross-language constants module yet.

import 'package:flutter/material.dart';

class ConstructColors {
  // Slate-100 — soft light gray that the desktop uses as the canvas.
  static const background = Color(0xFFF1F5F9);
  // Slate-900 — near-black ink for body text.
  static const foreground = Color(0xFF0F172A);
  // Slate-500 — secondary text, captions, hints.
  static const muted = Color(0xFF64748B);
  // Coral red — Construct's signature accent. Used for primary
  // actions (Ask button, user message bubble, active sidebar icons).
  static const accent = Color(0xFFE63946);
  static const accentForeground = Color(0xFFFFFFFF);
  // Tinted surface for cards / inputs (5% accent on background).
  static const surfaceTint = Color(0xFFFAEAEB);
  // Hairline divider — slate-200.
  static const divider = Color(0xFFE2E8F0);
}

const _emojiFallbacks = <String>[
  'Apple Color Emoji',
  'Noto Color Emoji',
  'Segoe UI Emoji',
];

ThemeData buildConstructTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ConstructColors.accent,
    brightness: Brightness.light,
    surface: ConstructColors.background,
    onSurface: ConstructColors.foreground,
    primary: ConstructColors.accent,
    onPrimary: ConstructColors.accentForeground,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ConstructColors.background,
    dividerColor: ConstructColors.divider,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: ConstructColors.foreground,
          displayColor: ConstructColors.foreground,
          fontFamilyFallback: _emojiFallbacks,
        )
        .copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: ConstructColors.foreground,
            height: 1.45,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            color: ConstructColors.muted,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            color: ConstructColors.muted,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            color: ConstructColors.foreground,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            color: ConstructColors.foreground,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
    primaryTextTheme:
        base.primaryTextTheme.apply(fontFamilyFallback: _emojiFallbacks),
    appBarTheme: const AppBarTheme(
      backgroundColor: ConstructColors.background,
      foregroundColor: ConstructColors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ConstructColors.foreground,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: ConstructColors.surfaceTint,
      labelStyle: const TextStyle(color: ConstructColors.foreground),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(
      color: ConstructColors.divider,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ConstructColors.accent,
        foregroundColor: ConstructColors.accentForeground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        iconColor: WidgetStatePropertyAll(ConstructColors.foreground),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: ConstructColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ConstructColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ConstructColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ConstructColors.accent, width: 1.5),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ConstructColors.accent,
    ),
  );
}
