import 'package:flutter/material.dart';

const _seed = Color(0xFF5B4CFF);

abstract final class SoundPadTheme {
  static ThemeData light({String fontFamily = 'Nunito'}) =>
      _theme(Brightness.light, fontFamily: fontFamily);

  static ThemeData dark({String fontFamily = 'Nunito'}) =>
      _theme(Brightness.dark, fontFamily: fontFamily);

  static ThemeData _theme(
    Brightness brightness, {
    required String fontFamily,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );

    const radius = BorderRadius.all(Radius.circular(28));
    const shape = RoundedSuperellipseBorder(borderRadius: radius);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 1,
        highlightElevation: 2,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest),
        shape: const WidgetStatePropertyAll(
          RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      sliderTheme: SliderThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        showValueIndicator: ShowValueIndicator.onDrag,
        thumbSize: WidgetStateProperty.all(const Size(4, 28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }
}
