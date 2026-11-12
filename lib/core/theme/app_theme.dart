import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';

/// Urbanist is a variable font: the weight must be applied through the `wght` axis.
extension WeightedTextStyle on TextStyle {
  TextStyle w(int weight) => copyWith(
        fontWeight: FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)],
        fontVariations: [FontVariation('wght', weight.toDouble())],
      );
}

abstract final class AppRadius {
  static const control = 12.0;
  static const tile = 16.0;
  static const card = 22.0;
  static const sheet = 28.0;
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0D101A38), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x47101A38),
      blurRadius: 36,
      spreadRadius: -26,
      offset: Offset(0, 16),
    ),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x12101A38), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(
      color: Color(0x5C101A38),
      blurRadius: 48,
      spreadRadius: -22,
      offset: Offset(0, 22),
    ),
  ];
}

abstract final class AppTheme {
  static const _family = 'Urbanist';

  static TextTheme _textTheme() {
    TextStyle s(double size, int weight, {double? height, double spacing = 0}) =>
        TextStyle(
          fontFamily: _family,
          fontSize: size,
          height: height,
          letterSpacing: spacing,
          color: AppColors.slate900,
        ).w(weight);

    return TextTheme(
      displaySmall: s(32, 600, height: 1.06, spacing: -0.8),
      headlineMedium: s(28, 600, height: 1.1, spacing: -0.7),
      headlineSmall: s(24, 600, height: 1.15, spacing: -0.5),
      titleLarge: s(20, 600, height: 1.2, spacing: -0.3),
      titleMedium: s(16, 600, height: 1.25, spacing: -0.2),
      titleSmall: s(14.5, 600, height: 1.25),
      bodyLarge: s(16, 500, height: 1.35),
      bodyMedium: s(14, 500, height: 1.35),
      bodySmall: s(12.5, 500, height: 1.3),
      labelLarge: s(14, 600),
      labelMedium: s(12.5, 600),
      labelSmall: s(11, 700, spacing: 0.8),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand600,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand600,
      onPrimary: Colors.white,
      secondary: AppColors.accent500,
      surface: AppColors.surface,
      onSurface: AppColors.slate900,
      error: AppColors.rose600,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
    );

    final textTheme = _textTheme();
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: const BorderSide(color: AppColors.lineStrong),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _family,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.page,
      canvasColor: AppColors.page,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        foregroundColor: AppColors.slate900,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate50,
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: textTheme.bodyMedium!.copyWith(color: AppColors.slate400),
        labelStyle: textTheme.bodyMedium!.copyWith(color: AppColors.slate500),
        floatingLabelStyle:
            textTheme.labelMedium!.copyWith(color: AppColors.brand600),
        errorStyle: textTheme.labelMedium!.copyWith(color: AppColors.rose600),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: AppColors.brand500, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.rose400),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.rose500, width: 1.6),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brand600,
        selectionColor: AppColors.accent500.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.brand600,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.slate400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand600
              : AppColors.slate200,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.slate300, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand600
              : Colors.transparent,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brand600,
        linearTrackColor: AppColors.slate100,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brand900,
        contentTextStyle:
            textTheme.bodyMedium!.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.brand900,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.labelMedium!.copyWith(color: Colors.white),
        waitDuration: AppMotion.normal,
      ),
    );
  }
}
