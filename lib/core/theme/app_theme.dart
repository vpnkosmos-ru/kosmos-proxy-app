import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// The visual foundation for every Kosmos Proxy surface.
///
/// Dynamic system colours are deliberately not used here: the application is a
/// branded product and must look consistent on Android, iOS and desktop.
class AppTheme {
  AppTheme(this.mode, this.fontFamily);

  final AppThemeMode mode;
  final String fontFamily;

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6C56F5),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE7E1FF),
    onPrimaryContainer: Color(0xFF251A62),
    secondary: Color(0xFF4D6BFF),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE4EAFF),
    onSecondaryContainer: Color(0xFF10225E),
    tertiary: Color(0xFFFF934D),
    onTertiary: Color(0xFF3B1600),
    tertiaryContainer: Color(0xFFFFE3D2),
    onTertiaryContainer: Color(0xFF4A1B00),
    error: Color(0xFFE45B6B),
    onError: Colors.white,
    errorContainer: Color(0xFFFFE8EA),
    onErrorContainer: Color(0xFF5D1020),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF171525),
    surfaceContainerHighest: Color(0xFFF1EEFF),
    onSurfaceVariant: Color(0xFF77738A),
    outline: Color(0xFFE3DFFA),
    outlineVariant: Color(0xFFEDEAFF),
    shadow: Color(0xFF171525),
    scrim: Color(0xFF171525),
    inverseSurface: Color(0xFF29263B),
    onInverseSurface: Color(0xFFF6F3FF),
    inversePrimary: Color(0xFFC8BFFF),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB8A8FF),
    onPrimary: Color(0xFF251A62),
    primaryContainer: Color(0xFF4E3FD6),
    onPrimaryContainer: Color(0xFFF1EEFF),
    secondary: Color(0xFFB9C5FF),
    onSecondary: Color(0xFF10225E),
    secondaryContainer: Color(0xFF2948CC),
    onSecondaryContainer: Color(0xFFE4EAFF),
    tertiary: Color(0xFFFFB68B),
    onTertiary: Color(0xFF4A1B00),
    tertiaryContainer: Color(0xFF923E09),
    onTertiaryContainer: Color(0xFFFFE3D2),
    error: Color(0xFFFFB3BC),
    onError: Color(0xFF68001A),
    errorContainer: Color(0xFF8E2639),
    onErrorContainer: Color(0xFFFFE8EA),
    surface: Color(0xFF151325),
    onSurface: Color(0xFFE9E5F6),
    surfaceContainerHighest: Color(0xFF2A273D),
    onSurfaceVariant: Color(0xFFC9C4D7),
    outline: Color(0xFF938EA5),
    outlineVariant: Color(0xFF454257),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE9E5F6),
    onInverseSurface: Color(0xFF29263B),
    inversePrimary: Color(0xFF5F4BE8),
  );

  ThemeData lightTheme(ColorScheme? _) => _theme(_lightScheme, isDark: false);

  ThemeData darkTheme(ColorScheme? _) => _theme(_darkScheme, isDark: true);

  ThemeData _theme(ColorScheme scheme, {required bool isDark}) {
    final surface = scheme.surface;
    final cardRadius = BorderRadius.circular(24);
    final textTheme = Typography.material2021().black.apply(
      fontFamily: fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final shadow = isDark ? Colors.black.withValues(alpha: .22) : const Color(0xFF6C56F5).withValues(alpha: .09);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: isDark && mode.trueBlack ? Colors.black : (isDark ? const Color(0xFF151325) : const Color(0xFFF8F7FF)),
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.6),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.35),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: cardRadius, side: BorderSide(color: scheme.outlineVariant)),
        shadowColor: shadow,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: surface.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          foregroundColor: Colors.white,
          backgroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: const Color(0xFF171525).withValues(alpha: .32),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.primaryContainer),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      extensions: <ThemeExtension<dynamic>>{ConnectionButtonTheme.kosmos(isDark: isDark)},
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark || AppThemeMode.black => true,
    };
    final material = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    final base = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    return MaterialBasedCupertinoThemeData(
      materialTheme: material.copyWith(
        cupertinoOverrideTheme: base.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: base.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: base.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: base.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: base.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: base.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: base.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: base.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: base.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ),
        ),
      ),
    );
  }
}
