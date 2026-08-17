import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic design tokens extension attached to [ThemeData].
class EHThemeTokens extends ThemeExtension<EHThemeTokens> {
  const EHThemeTokens({
    required this.isDark,
    required this.bgApp,
    required this.bgSecondary,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceNav,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.sectionHeading,
    required this.borderSubtle,
    required this.borderControl,
    required this.bluePrimary,
    required this.blueDarker,
    required this.blueSelectedBg,
    required this.blueSelectedText,
    required this.gold,
    required this.goldBright,
    required this.goldContainer,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.errorText,
    required this.navInactiveIcon,
    required this.navInactiveLabel,
    required this.navSelectedIcon,
    required this.navSelectedLabel,
    required this.switchTrackOff,
    required this.switchThumbOff,
    required this.switchTrackOn,
    required this.switchThumbOn,
    required this.chevron,
    required this.headerAction,
    required this.iconBgBlue,
    required this.iconFgBlue,
    required this.iconBgGreen,
    required this.iconFgGreen,
    required this.iconBgPlant,
    required this.iconFgPlant,
    required this.iconBgWater,
    required this.iconFgWater,
    required this.iconBgOrange,
    required this.iconFgOrange,
    required this.iconBgKitchen,
    required this.iconFgKitchen,
    required this.iconBgPurple,
    required this.iconFgPurple,
  });

  final bool isDark;
  final Color bgApp;
  final Color bgSecondary;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceNav;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color sectionHeading;

  final Color borderSubtle;
  final Color borderControl;

  final Color bluePrimary;
  final Color blueDarker;
  final Color blueSelectedBg;
  final Color blueSelectedText;

  final Color gold;
  final Color goldBright;
  final Color goldContainer;

  final Color success;
  final Color successContainer;

  final Color warning;
  final Color warningContainer;

  final Color error;
  final Color errorContainer;
  final Color errorText;

  final Color navInactiveIcon;
  final Color navInactiveLabel;
  final Color navSelectedIcon;
  final Color navSelectedLabel;

  final Color switchTrackOff;
  final Color switchThumbOff;
  final Color switchTrackOn;
  final Color switchThumbOn;

  final Color chevron;
  final Color headerAction;

  // Contextual icon badges
  final Color iconBgBlue;
  final Color iconFgBlue;
  final Color iconBgGreen;
  final Color iconFgGreen;
  final Color iconBgPlant;
  final Color iconFgPlant;
  final Color iconBgWater;
  final Color iconFgWater;
  final Color iconBgOrange;
  final Color iconFgOrange;
  final Color iconBgKitchen;
  final Color iconFgKitchen;
  final Color iconBgPurple;
  final Color iconFgPurple;

  static const dark = EHThemeTokens(
    isDark: true,
    bgApp: EHColors.darkBgApp,
    bgSecondary: EHColors.darkBgSecondary,
    surfaceCard: EHColors.darkSurfaceCard,
    surfaceElevated: EHColors.darkSurfaceElevated,
    surfaceNav: EHColors.darkSurfaceNav,
    textPrimary: EHColors.darkTextPrimary,
    textSecondary: EHColors.darkTextSecondary,
    textTertiary: EHColors.darkTextTertiary,
    sectionHeading: EHColors.darkSectionHeading,
    borderSubtle: EHColors.darkBorderSubtle,
    borderControl: EHColors.darkBorderControl,
    bluePrimary: EHColors.darkBluePrimary,
    blueDarker: EHColors.darkBlueDarker,
    blueSelectedBg: EHColors.darkBlueSelectedBg,
    blueSelectedText: EHColors.darkBlueSelectedText,
    gold: EHColors.darkGold,
    goldBright: EHColors.darkGoldBright,
    goldContainer: EHColors.darkGoldContainer,
    success: EHColors.darkSuccess,
    successContainer: EHColors.darkSuccessContainer,
    warning: EHColors.darkWarning,
    warningContainer: EHColors.darkWarningContainer,
    error: EHColors.darkError,
    errorContainer: EHColors.darkErrorContainer,
    errorText: EHColors.darkErrorText,
    navInactiveIcon: EHColors.darkNavInactiveIcon,
    navInactiveLabel: EHColors.darkNavInactiveLabel,
    navSelectedIcon: EHColors.darkNavSelectedIcon,
    navSelectedLabel: EHColors.darkNavSelectedLabel,
    switchTrackOff: EHColors.darkSwitchTrackOff,
    switchThumbOff: EHColors.darkSwitchThumbOff,
    switchTrackOn: EHColors.darkSwitchTrackOn,
    switchThumbOn: EHColors.darkSwitchThumbOn,
    chevron: EHColors.darkChevron,
    headerAction: EHColors.darkHeaderAction,
    iconBgBlue: EHColors.darkIconBgBlue,
    iconFgBlue: EHColors.darkIconFgBlue,
    iconBgGreen: EHColors.darkIconBgGreen,
    iconFgGreen: EHColors.darkIconFgGreen,
    iconBgPlant: EHColors.darkIconBgPlant,
    iconFgPlant: EHColors.darkIconFgPlant,
    iconBgWater: EHColors.darkIconBgWater,
    iconFgWater: EHColors.darkIconFgWater,
    iconBgOrange: EHColors.darkIconBgOrange,
    iconFgOrange: EHColors.darkIconFgOrange,
    iconBgKitchen: EHColors.darkIconBgKitchen,
    iconFgKitchen: EHColors.darkIconFgKitchen,
    iconBgPurple: EHColors.darkIconBgPurple,
    iconFgPurple: EHColors.darkIconFgPurple,
  );

  static const light = EHThemeTokens(
    isDark: false,
    bgApp: EHColors.lightBgApp,
    bgSecondary: EHColors.lightBgSecondary,
    surfaceCard: EHColors.lightSurfaceCard,
    surfaceElevated: EHColors.lightSurfaceElevated,
    surfaceNav: EHColors.lightSurfaceNav,
    textPrimary: EHColors.lightTextPrimary,
    textSecondary: EHColors.lightTextSecondary,
    textTertiary: EHColors.lightTextTertiary,
    sectionHeading: EHColors.lightSectionHeading,
    borderSubtle: EHColors.lightBorderSubtle,
    borderControl: EHColors.lightBorderControl,
    bluePrimary: EHColors.lightBluePrimary,
    blueDarker: EHColors.lightBlueDarker,
    blueSelectedBg: EHColors.lightBlueSelectedBg,
    blueSelectedText: EHColors.lightBlueSelectedText,
    gold: EHColors.lightGold,
    goldBright: EHColors.lightGoldBright,
    goldContainer: EHColors.lightGoldContainer,
    success: EHColors.lightSuccess,
    successContainer: EHColors.lightSuccessContainer,
    warning: EHColors.lightWarning,
    warningContainer: EHColors.lightWarningContainer,
    error: EHColors.lightError,
    errorContainer: EHColors.lightErrorContainer,
    errorText: EHColors.lightErrorText,
    navInactiveIcon: EHColors.lightNavInactiveIcon,
    navInactiveLabel: EHColors.lightNavInactiveLabel,
    navSelectedIcon: EHColors.lightNavSelectedIcon,
    navSelectedLabel: EHColors.lightNavSelectedLabel,
    switchTrackOff: EHColors.lightSwitchTrackOff,
    switchThumbOff: EHColors.lightSwitchThumbOff,
    switchTrackOn: EHColors.lightSwitchTrackOn,
    switchThumbOn: EHColors.lightSwitchThumbOn,
    chevron: EHColors.lightChevron,
    headerAction: EHColors.lightHeaderAction,
    iconBgBlue: EHColors.lightIconBgBlue,
    iconFgBlue: EHColors.lightIconFgBlue,
    iconBgGreen: EHColors.lightIconBgGreen,
    iconFgGreen: EHColors.lightIconFgGreen,
    iconBgPlant: EHColors.lightIconBgPlant,
    iconFgPlant: EHColors.lightIconFgPlant,
    iconBgWater: EHColors.lightIconBgWater,
    iconFgWater: EHColors.lightIconFgWater,
    iconBgOrange: EHColors.lightIconBgOrange,
    iconFgOrange: EHColors.lightIconFgOrange,
    iconBgKitchen: EHColors.lightIconBgKitchen,
    iconFgKitchen: EHColors.lightIconFgKitchen,
    iconBgPurple: EHColors.lightIconBgPurple,
    iconFgPurple: EHColors.lightIconFgPurple,
  );

  @override
  EHThemeTokens copyWith({
    bool? isDark,
    Color? bgApp,
    Color? bgSecondary,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceNav,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? sectionHeading,
    Color? borderSubtle,
    Color? borderControl,
    Color? bluePrimary,
    Color? blueDarker,
    Color? blueSelectedBg,
    Color? blueSelectedText,
    Color? gold,
    Color? goldBright,
    Color? goldContainer,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? errorText,
    Color? navInactiveIcon,
    Color? navInactiveLabel,
    Color? navSelectedIcon,
    Color? navSelectedLabel,
    Color? switchTrackOff,
    Color? switchThumbOff,
    Color? switchTrackOn,
    Color? switchThumbOn,
    Color? chevron,
    Color? headerAction,
    Color? iconBgBlue,
    Color? iconFgBlue,
    Color? iconBgGreen,
    Color? iconFgGreen,
    Color? iconBgPlant,
    Color? iconFgPlant,
    Color? iconBgWater,
    Color? iconFgWater,
    Color? iconBgOrange,
    Color? iconFgOrange,
    Color? iconBgKitchen,
    Color? iconFgKitchen,
    Color? iconBgPurple,
    Color? iconFgPurple,
  }) =>
      EHThemeTokens(
        isDark: isDark ?? this.isDark,
        bgApp: bgApp ?? this.bgApp,
        bgSecondary: bgSecondary ?? this.bgSecondary,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        surfaceNav: surfaceNav ?? this.surfaceNav,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        sectionHeading: sectionHeading ?? this.sectionHeading,
        borderSubtle: borderSubtle ?? this.borderSubtle,
        borderControl: borderControl ?? this.borderControl,
        bluePrimary: bluePrimary ?? this.bluePrimary,
        blueDarker: blueDarker ?? this.blueDarker,
        blueSelectedBg: blueSelectedBg ?? this.blueSelectedBg,
        blueSelectedText: blueSelectedText ?? this.blueSelectedText,
        gold: gold ?? this.gold,
        goldBright: goldBright ?? this.goldBright,
        goldContainer: goldContainer ?? this.goldContainer,
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        error: error ?? this.error,
        errorContainer: errorContainer ?? this.errorContainer,
        errorText: errorText ?? this.errorText,
        navInactiveIcon: navInactiveIcon ?? this.navInactiveIcon,
        navInactiveLabel: navInactiveLabel ?? this.navInactiveLabel,
        navSelectedIcon: navSelectedIcon ?? this.navSelectedIcon,
        navSelectedLabel: navSelectedLabel ?? this.navSelectedLabel,
        switchTrackOff: switchTrackOff ?? this.switchTrackOff,
        switchThumbOff: switchThumbOff ?? this.switchThumbOff,
        switchTrackOn: switchTrackOn ?? this.switchTrackOn,
        switchThumbOn: switchThumbOn ?? this.switchThumbOn,
        chevron: chevron ?? this.chevron,
        headerAction: headerAction ?? this.headerAction,
        iconBgBlue: iconBgBlue ?? this.iconBgBlue,
        iconFgBlue: iconFgBlue ?? this.iconFgBlue,
        iconBgGreen: iconBgGreen ?? this.iconBgGreen,
        iconFgGreen: iconFgGreen ?? this.iconFgGreen,
        iconBgPlant: iconBgPlant ?? this.iconBgPlant,
        iconFgPlant: iconFgPlant ?? this.iconFgPlant,
        iconBgWater: iconBgWater ?? this.iconBgWater,
        iconFgWater: iconFgWater ?? this.iconFgWater,
        iconBgOrange: iconBgOrange ?? this.iconBgOrange,
        iconFgOrange: iconFgOrange ?? this.iconFgOrange,
        iconBgKitchen: iconBgKitchen ?? this.iconBgKitchen,
        iconFgKitchen: iconFgKitchen ?? this.iconFgKitchen,
        iconBgPurple: iconBgPurple ?? this.iconBgPurple,
        iconFgPurple: iconFgPurple ?? this.iconFgPurple,
      );

  @override
  EHThemeTokens lerp(ThemeExtension<EHThemeTokens>? other, double t) {
    if (other is! EHThemeTokens) return this;
    return EHThemeTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      bgApp: Color.lerp(bgApp, other.bgApp, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceNav: Color.lerp(surfaceNav, other.surfaceNav, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      sectionHeading: Color.lerp(sectionHeading, other.sectionHeading, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderControl: Color.lerp(borderControl, other.borderControl, t)!,
      bluePrimary: Color.lerp(bluePrimary, other.bluePrimary, t)!,
      blueDarker: Color.lerp(blueDarker, other.blueDarker, t)!,
      blueSelectedBg: Color.lerp(blueSelectedBg, other.blueSelectedBg, t)!,
      blueSelectedText: Color.lerp(blueSelectedText, other.blueSelectedText, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldBright: Color.lerp(goldBright, other.goldBright, t)!,
      goldContainer: Color.lerp(goldContainer, other.goldContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      navInactiveIcon: Color.lerp(navInactiveIcon, other.navInactiveIcon, t)!,
      navInactiveLabel: Color.lerp(navInactiveLabel, other.navInactiveLabel, t)!,
      navSelectedIcon: Color.lerp(navSelectedIcon, other.navSelectedIcon, t)!,
      navSelectedLabel: Color.lerp(navSelectedLabel, other.navSelectedLabel, t)!,
      switchTrackOff: Color.lerp(switchTrackOff, other.switchTrackOff, t)!,
      switchThumbOff: Color.lerp(switchThumbOff, other.switchThumbOff, t)!,
      switchTrackOn: Color.lerp(switchTrackOn, other.switchTrackOn, t)!,
      switchThumbOn: Color.lerp(switchThumbOn, other.switchThumbOn, t)!,
      chevron: Color.lerp(chevron, other.chevron, t)!,
      headerAction: Color.lerp(headerAction, other.headerAction, t)!,
      iconBgBlue: Color.lerp(iconBgBlue, other.iconBgBlue, t)!,
      iconFgBlue: Color.lerp(iconFgBlue, other.iconFgBlue, t)!,
      iconBgGreen: Color.lerp(iconBgGreen, other.iconBgGreen, t)!,
      iconFgGreen: Color.lerp(iconFgGreen, other.iconFgGreen, t)!,
      iconBgPlant: Color.lerp(iconBgPlant, other.iconBgPlant, t)!,
      iconFgPlant: Color.lerp(iconFgPlant, other.iconFgPlant, t)!,
      iconBgWater: Color.lerp(iconBgWater, other.iconBgWater, t)!,
      iconFgWater: Color.lerp(iconFgWater, other.iconFgWater, t)!,
      iconBgOrange: Color.lerp(iconBgOrange, other.iconBgOrange, t)!,
      iconFgOrange: Color.lerp(iconFgOrange, other.iconFgOrange, t)!,
      iconBgKitchen: Color.lerp(iconBgKitchen, other.iconBgKitchen, t)!,
      iconFgKitchen: Color.lerp(iconFgKitchen, other.iconFgKitchen, t)!,
      iconBgPurple: Color.lerp(iconBgPurple, other.iconBgPurple, t)!,
      iconFgPurple: Color.lerp(iconFgPurple, other.iconFgPurple, t)!,
    );
  }
}

/// Extension on BuildContext for quick access to EHThemeTokens.
extension EHThemeContextExtension on BuildContext {
  EHThemeTokens get ehColors =>
      Theme.of(this).extension<EHThemeTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? EHThemeTokens.dark
          : EHThemeTokens.light);
}

/// Application theme definitions.
class EHAppTheme {
  const EHAppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: EHColors.lightBluePrimary,
      brightness: Brightness.light,
      surface: EHColors.lightSurfaceCard,
      primary: EHColors.lightBluePrimary,
      onPrimary: Colors.white,
      secondary: EHColors.lightBlueSelectedBg,
      onSecondary: EHColors.lightBlueSelectedText,
      error: EHColors.lightError,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: EHColors.lightBgApp,
      dividerColor: EHColors.lightBorderSubtle,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: EHColors.lightTextPrimary,
        displayColor: EHColors.lightTextPrimary,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EHColors.lightBgApp,
        foregroundColor: EHColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: EHColors.lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: EHColors.lightSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EHColors.lightSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.lightBorderControl),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.lightBorderControl),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.lightBluePrimary, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return EHColors.lightSwitchTrackOn;
          }
          return EHColors.lightSwitchTrackOff;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return EHColors.lightSwitchThumbOn;
          }
          return EHColors.lightSwitchThumbOff;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: EHColors.lightSurfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: EHColors.lightSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      extensions: const [EHThemeTokens.light],
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: EHColors.darkBluePrimary,
      brightness: Brightness.dark,
      surface: EHColors.darkSurfaceCard,
      primary: EHColors.darkBluePrimary,
      onPrimary: EHColors.darkTextPrimary,
      secondary: EHColors.darkBlueSelectedBg,
      onSecondary: EHColors.darkBlueSelectedText,
      error: EHColors.darkError,
      onError: EHColors.darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: EHColors.darkBgApp,
      dividerColor: EHColors.darkBorderControl,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: EHColors.darkTextPrimary,
        displayColor: EHColors.darkTextPrimary,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EHColors.darkBgApp,
        foregroundColor: EHColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: EHColors.darkHeaderAction),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: EHColors.darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: EHColors.darkBorderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EHColors.darkSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: EHColors.darkTextTertiary),
        labelStyle: const TextStyle(color: EHColors.darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.darkBorderControl),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.darkBorderControl),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.darkBluePrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EHColors.darkError),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return EHColors.darkSwitchTrackOn;
          }
          return EHColors.darkSwitchTrackOff;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return EHColors.darkSwitchThumbOn;
          }
          return EHColors.darkSwitchThumbOff;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: EHColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: EHColors.darkBorderSubtle),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: EHColors.darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      extensions: const [EHThemeTokens.dark],
    );
  }
}
