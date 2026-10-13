import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/colors.dart';

/// One app theme, loaded from assets/app_themes.json. Add a theme by adding an entry there.
class AppThemeSpec {
  const AppThemeSpec({required this.id, required this.name, required this.colors});
  final String id;
  final String name;
  final AppColors colors;
}

/// Named colour roles. Screens read colours only through these (context.colors).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.text,
    required this.secondaryText,
    required this.accent,
    required this.onAccent,
  });

  final Color background;
  final Color surface;
  final Color raised;
  final Color text;
  final Color secondaryText;
  final Color accent;
  final Color onAccent;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? text,
    Color? secondaryText,
    Color? accent,
    Color? onAccent,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    text: text ?? this.text,
    secondaryText: secondaryText ?? this.secondaryText,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppThemes {
  AppThemes._(this.all);
  final List<AppThemeSpec> all;

  AppThemeSpec byId(String? id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static Future<AppThemes> load() async {
    final json = jsonDecode(await rootBundle.loadString('assets/app_themes.json')) as Map<String, dynamic>;
    final base = json['base'] as Map<String, dynamic>;
    Color c(Map<String, dynamic> t, String k) => hexToColor((t[k] ?? base[k]) as String);
    return AppThemes._([
      for (final t in (json['themes'] as List).cast<Map<String, dynamic>>())
        AppThemeSpec(
          id: t['id'] as String,
          name: t['name'] as String,
          colors: AppColors(
            background: c(t, 'background'),
            surface: c(t, 'surface'),
            raised: c(t, 'raised'),
            text: c(t, 'text'),
            secondaryText: c(t, 'secondaryText'),
            accent: c(t, 'accent'),
            onAccent: c(t, 'onAccent'),
          ),
        ),
    ]);
  }
}

/// Builds Material's ThemeData from the colour roles so stock widgets follow the theme too.
ThemeData buildTheme(AppColors c) {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: const Color(0xFFFF6B6B),
    onError: c.background,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.secondaryText,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.raised,
    outline: c.secondaryText,
    outlineVariant: c.raised,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c.raised),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.surface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.onAccent : c.secondaryText),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? c.text : c.secondaryText,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: TextStyle(color: c.secondaryText),
      labelStyle: TextStyle(color: c.secondaryText),
      floatingLabelStyle: TextStyle(color: c.accent),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: c.accent, width: 1.5)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.35),
      selectionHandleColor: c.accent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.raised, width: 1.5),
        minimumSize: const Size(48, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.accent)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: c.accent, foregroundColor: c.onAccent),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onAccent : c.secondaryText,
      ),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.raised),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.secondaryText),
    ),
    dividerTheme: DividerThemeData(color: c.raised, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      dragHandleColor: c.secondaryText,
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.surface),
    popupMenuTheme: PopupMenuThemeData(color: c.raised),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.raised,
      contentTextStyle: TextStyle(color: c.text),
      actionTextColor: c.accent,
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    listTileTheme: ListTileThemeData(iconColor: c.secondaryText, textColor: c.text),
    chipTheme: ChipThemeData(
      backgroundColor: c.raised,
      selectedColor: c.accent,
      labelStyle: TextStyle(color: c.text),
      side: BorderSide.none,
    ),
  );
}
