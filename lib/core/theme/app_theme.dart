import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppText {
  /// Titres condensés (Oswald)
  static TextStyle title(double size, {Color color = AppColors.text}) =>
      GoogleFonts.oswald(
          fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.1);

  /// Texte courant (Manrope)
  static TextStyle body(double size,
          {Color color = AppColors.text, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

  /// Petit titre vert en majuscules (ex: "BON RETOUR,")
  static TextStyle eyebrow({Color color = AppColors.lime}) => GoogleFonts.manrope(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: color);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c));
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
          primary: AppColors.lime, surface: AppColors.surface),
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: AppText.body(13, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.lime),
        errorBorder: border(AppColors.red),
        focusedErrorBorder: border(AppColors.red),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface2,
        contentTextStyle: AppText.body(13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
