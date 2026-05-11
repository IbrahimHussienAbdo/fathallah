import 'package:flutter/material.dart';

/// Central theme configuration for the app.
/// Uses a professional navy/petroleum-inspired color palette.
class AppTheme {
  AppTheme._();

  // ── Brand Colors ─────────────────────────────────────
  static const Color primary     = Color(0xFF0D2E4E); // deep navy
  static const Color primaryLight= Color(0xFF1A5276); // medium navy
  static const Color accent      = Color(0xFF2E86C1); // steel blue
  static const Color gold        = Color(0xFFF0A500); // petroleum gold
  static const Color success     = Color(0xFF1E8449); // green
  static const Color danger      = Color(0xFFC0392B); // red
  static const Color warning     = Color(0xFFD68910); // amber
  static const Color surface     = Color(0xFFF4F6F8); // light bg
  static const Color cardBg      = Colors.white;

  // ── Gradients ─────────────────────────────────────────

  /// Primary gradient used in headers and hero areas.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle background gradient for screens.
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF0F4F8), Color(0xFFE8EDF3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── ThemeData ─────────────────────────────────────────

  /// Returns the configured [ThemeData] for the app.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: accent,
          surface: surface,
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: EdgeInsets.zero,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: gold,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: primary.withOpacity(0.12),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
