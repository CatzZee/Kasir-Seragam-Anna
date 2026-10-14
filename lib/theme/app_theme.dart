import 'package:flutter/material.dart';

/// Palet diambil dari dunia produknya sendiri: navy seragam sekolah Indonesia,
/// dipasangkan kuning emas sebagai warna aksi utama. Kontras navy/putih ~11:1
/// dan kuning/navy ~8:1 -> aman dibaca mata usia 45+ di bawah lampu neon toko.
class AppColors {
  static const primary = Color(0xFF0B3C7D);
  static const primaryDark = Color(0xFF072A57);
  static const accent = Color(0xFFF5A302);
  static const success = Color(0xFF15803D);
  static const danger = Color(0xFFB91C1C);
  static const bg = Color(0xFFEEF2F7);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF475569);
  static const border = Color(0xFFCBD5E1);
}

class AppSize {
  static const tap = 56.0; // tinggi minimum semua elemen yang bisa ditekan
  static const gap = 12.0;
  static const radius = 12.0;
}

class AppTheme {
  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      // Skala tipe dinaikkan satu tingkat dari default Flutter.
      // Body default 14sp terlalu kecil untuk pengguna presbiopi.
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.text),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
        bodyLarge: TextStyle(fontSize: 18, color: AppColors.text),
        bodyMedium: TextStyle(fontSize: 16, color: AppColors.text),
        bodySmall: TextStyle(fontSize: 14, color: AppColors.textMuted),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white, size: 28),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSize.tap),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSize.tap),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(fontSize: 17, color: AppColors.textMuted),
        hintStyle: const TextStyle(fontSize: 17, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.radius),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.radius),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSize.radius),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(fontSize: 16, color: Colors.white),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
        subtitleTextStyle: TextStyle(fontSize: 15, color: AppColors.textMuted),
      ),
    );
  }
}
