import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  const family = 'HindSiliguri';
  const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(controlRadius)));
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: family,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryInk,
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      tertiary: AppColors.accent,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.field,
      outlineVariant: AppColors.line,
      surfaceContainerHighest: AppColors.neutralSoft,
      error: AppColors.danger,
    ),
  );
  TextStyle type(double size, FontWeight weight,
          {Color color = AppColors.ink, double height = 1.4}) =>
      TextStyle(
          fontFamily: family,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color);
  final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      borderSide: const BorderSide(color: AppColors.field, width: 1.5));
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: type(32, FontWeight.w700, height: 1.2),
      headlineMedium: type(28, FontWeight.w700, height: 1.25),
      headlineSmall: type(23, FontWeight.w700, height: 1.3),
      titleLarge: type(20, FontWeight.w700),
      titleMedium: type(16, FontWeight.w600),
      titleSmall: type(14, FontWeight.w600),
      bodyLarge: type(15, FontWeight.w400, height: 1.5),
      bodyMedium: type(14, FontWeight.w400, height: 1.5),
      bodySmall: type(12, FontWeight.w400, color: AppColors.muted),
      labelLarge: type(14, FontWeight.w600),
      labelMedium: type(12, FontWeight.w600),
      labelSmall: type(11, FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      titleTextStyle: type(18, FontWeight.w700),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.card,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      labelStyle: type(14, FontWeight.w500, color: AppColors.muted),
      floatingLabelStyle: type(14, FontWeight.w600, color: AppColors.primary),
      hintStyle: type(15, FontWeight.w400, color: AppColors.faint),
      helperStyle: type(12, FontWeight.w400, color: AppColors.muted),
      helperMaxLines: 3,
      errorMaxLines: 3,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 2)),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: shape,
            elevation: 0,
            textStyle: type(15, FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: shape,
            side: const BorderSide(color: AppColors.field),
            foregroundColor: AppColors.ink,
            textStyle: type(15, FontWeight.w600))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.primary,
            shape: shape,
            textStyle: type(14, FontWeight.w600))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primarySoft,
      side: const BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
      labelStyle: type(13, FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(cardRadius)))),
    dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(heroRadius)))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: type(14, FontWeight.w500, color: Colors.white),
        shape: shape),
    switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.primary : null)),
    dividerTheme: const DividerThemeData(
        color: AppColors.lineSoft, thickness: 1, space: 28),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary, linearTrackColor: AppColors.primarySoft),
    listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        iconColor: AppColors.muted),
    dividerColor: AppColors.lineSoft,
  );
}
