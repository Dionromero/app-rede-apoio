import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Famílias tipográficas (embutidas em assets/fonts, licença OFL).
///
/// - Fraunces: serifada com calor humano, para títulos.
/// - Atkinson Hyperlegible: criada pelo Braille Institute para máxima
///   legibilidade; ideal para ler sob estresse ou com baixa visão.
abstract final class AppFonts {
  static const display = 'Fraunces';
  static const body = 'Atkinson';

  /// Estilo de título serifado. [peso] vai de 300 a 900.
  static TextStyle serif({
    double size = 28,
    double peso = 560,
    Color color = AppColors.textPrimary,
    double height = 1.15,
    double letterSpacing = -0.4,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontVariations: [
        FontVariation('wght', peso),
        FontVariation('opsz', size.clamp(9, 144)),
        const FontVariation('SOFT', 60),
      ],
    );
  }
}

/// Raios e durações usados em todo o app.
abstract final class AppShape {
  static const double radiusSm = 10;
  static const double radius = 16;
  static const double radiusLg = 24;

  static const Duration rapido = Duration(milliseconds: 160);
  static const Duration medio = Duration(milliseconds: 280);
  static const Duration lento = Duration(milliseconds: 420);
  static const Curve curva = Curves.easeOutCubic;
}

abstract final class AppTheme {
  static ThemeData get light {
    const body = AppFonts.body;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.wine,
      brightness: Brightness.light,
      primary: AppColors.wine,
      secondary: AppColors.ink,
      tertiary: AppColors.moss,
      surface: AppColors.surface,
      error: AppColors.emergency,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: body,
      scaffoldBackgroundColor: AppColors.background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppFonts.serif(size: 22, peso: 600),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // Botão principal (CTA)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.wine,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radius)),
          textStyle: const TextStyle(
            fontFamily: body,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Botão de texto (secundário)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShape.radiusSm),
          ),
          textStyle: const TextStyle(
            fontFamily: body,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),

      // Botão outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.wine,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radius)),
          textStyle: const TextStyle(fontFamily: body, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppShape.radius)),
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(fontFamily: body, color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radiusSm)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.border,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppFonts.serif(size: 22, peso: 600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radiusLg)),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        hintStyle: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(color: AppColors.wine, fontWeight: FontWeight.w700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusSm),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusSm),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusSm),
          borderSide: const BorderSide(color: AppColors.wine, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusSm),
          borderSide: const BorderSide(color: AppColors.emergency, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusSm),
          borderSide: const BorderSide(color: AppColors.emergency, width: 1.8),
        ),
        prefixIconColor: AppColors.textSecondary,
      ),

      // ChoiceChip (filtros)
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.wineSoft,
        labelStyle: const TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.textPrimary, // sem cor, o texto sumia no Android
        ),
        side: const BorderSide(color: AppColors.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShape.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: AppSpacing.xxs),
      ),

      // Textos: títulos serifados, corpo em Atkinson Hyperlegible.
      textTheme: TextTheme(
        displayLarge: AppFonts.serif(size: 44, peso: 520),
        headlineLarge: AppFonts.serif(size: 34, peso: 540),
        headlineMedium: AppFonts.serif(size: 30, peso: 540),
        headlineSmall: AppFonts.serif(size: 25, peso: 560, height: 1.2),
        titleLarge: AppFonts.serif(size: 21, peso: 600, letterSpacing: -0.2),
        titleMedium: const TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        titleSmall: const TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontFamily: body,
          fontSize: 16,
          height: 1.55,
          color: AppColors.textSecondary,
        ),
        bodyMedium: const TextStyle(
          fontFamily: body,
          fontSize: 14.5,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
        bodySmall: const TextStyle(
          fontFamily: body,
          fontSize: 12.5,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        labelSmall: const TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
