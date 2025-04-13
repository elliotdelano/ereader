import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import '../services/storage_service.dart';
import '../models/custom_theme.dart';

// Define predefined theme identifiers (can match enum names if needed)
const String lightThemeId = 'light';
const String darkThemeId = 'dark';
const String sepiaThemeId = 'sepia';

// Enum for predefined themes (can still be useful for UI selection)
enum AppTheme { light, dark, sepia }

class ThemeProvider with ChangeNotifier {
  // Service for loading/saving themes
  final StorageService _storageService = StorageService();

  // State
  ThemeData _currentThemeData =
      ThemeData.light(); // Start with basic light theme
  String _selectedThemeId = lightThemeId; // Default to light theme ID
  List<CustomTheme> _customThemes = [];

  // Persistence Key
  static const String _selectedThemeIdKey = 'selectedThemeId';

  // Getters
  ThemeData get themeData => _currentThemeData;
  String get selectedThemeId => _selectedThemeId;
  List<CustomTheme> get customThemes => List.unmodifiable(_customThemes);

  // --- Predefined Theme Data Generation (Using FlexColorScheme) ---
  static final ThemeData lightTheme = FlexThemeData.light(
    scheme: FlexScheme.material,
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 7,
    appBarStyle: FlexAppBarStyle.scaffoldBackground,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  );

  static final ThemeData darkTheme = FlexThemeData.dark(
    scheme: FlexScheme.material,
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 13,
    appBarStyle: FlexAppBarStyle.scaffoldBackground,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  );

  // Sepia Theme (Example using themed constructor)
  static final ThemeData sepiaTheme = FlexThemeData.light(
    // Use colors approximating sepia
    colors: const FlexSchemeColor(
      primary: Color(0xff8D6E63), // Brownish primary
      primaryContainer: Color(0xffA1887F),
      secondary: Color(0xffA1887F), // Similar secondary
      secondaryContainer: Color(0xffBCAAA4),
      tertiary: Color(0xff795548),
      tertiaryContainer: Color(0xffA1887F),
      appBarColor: Color(0xffA1887F),
      error: Color(0xffcf6679),
    ),
    surface: const Color(0xFFF5F0E8), // Sepia background
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 40,
    scaffoldBackground: const Color(0xFFFAF5ED), // Slightly lighter scaffold
    appBarStyle: FlexAppBarStyle.scaffoldBackground,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnLevel: 30,
      useM2StyleDividerInM3: true,
      adaptiveElevationShadowsBack: FlexAdaptive.excludeWebAndroidFuchsia(),
      adaptiveAppBarScrollUnderOff: FlexAdaptive.excludeWebAndroidFuchsia(),
      adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
      defaultRadiusAdaptive: 10.0,
      elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
      elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      toggleButtonsBorderSchemeColor: SchemeColor.primary,
      segmentedButtonSchemeColor: SchemeColor.primary,
      segmentedButtonBorderSchemeColor: SchemeColor.primary,
      unselectedToggleIsColored: true,
      sliderValueTinted: true,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 19,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedBorderWidth: 1.0,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.tertiary,
      cardRadius: 14.0,
      popupMenuRadius: 6.0,
      popupMenuElevation: 3.0,
      alignedDropdown: true,
      dialogRadius: 18.0,
      appBarScrolledUnderElevation: 1.0,
      drawerElevation: 1.0,
      drawerIndicatorSchemeColor: SchemeColor.primary,
      bottomSheetRadius: 18.0,
      bottomSheetElevation: 2.0,
      bottomSheetModalElevation: 4.0,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      menuRadius: 6.0,
      menuElevation: 3.0,
      menuBarRadius: 0.0,
      menuBarElevation: 1.0,
      menuBarShadowColor: Color(0x00000000),
      searchBarElevation: 4.0,
      searchViewElevation: 4.0,
      searchUseGlobalShape: true,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarElevation: 1.0,
      navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
      navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationRailUseIndicator: true,
      navigationRailIndicatorSchemeColor: SchemeColor.primary,
      navigationRailIndicatorOpacity: 1.00,
      navigationRailBackgroundSchemeColor: SchemeColor.surface,
    ),
    keyColors: const FlexKeyColors(),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    // Modify text theme for better contrast on sepia if needed
    // textTheme: ...,
    // primaryTextTheme: ...,
  ).copyWith(
    // Ensure text selection handles, etc., have reasonable contrast
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: const Color(0xff8D6E63),
      selectionColor: const Color(0xff8D6E63).withAlpha(30),
      selectionHandleColor: const Color(0xff8D6E63),
    ),
  );

  ThemeProvider() {
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _customThemes = await _storageService.loadCustomThemes();

    // Load selected ID, default to lightThemeId
    String savedId = prefs.getString(_selectedThemeIdKey) ?? lightThemeId;

    // Validate saved ID
    bool isValid = false;
    if (savedId == lightThemeId ||
        savedId == darkThemeId ||
        savedId == sepiaThemeId) {
      isValid = true;
    } else if (_customThemes.any((theme) => theme.id == savedId)) {
      isValid = true;
    }

    _selectedThemeId = isValid ? savedId : lightThemeId;
    _applyThemeById(
      _selectedThemeId,
      notify: false,
    ); // Apply without notifying yet

    notifyListeners(); // Notify once after loading everything
    print("Theme settings loaded. Selected ID: $_selectedThemeId");
  }

  // Select a theme by its ID (predefined or custom)
  Future<void> selectTheme(String themeId) async {
    await _applyThemeById(themeId);
  }

  Future<void> _applyThemeById(String themeId, {bool notify = true}) async {
    ThemeData newThemeData;
    String newSelectedId = lightThemeId; // Default

    if (themeId == lightThemeId) {
      newThemeData = lightTheme;
      newSelectedId = lightThemeId;
    } else if (themeId == darkThemeId) {
      newThemeData = darkTheme;
      newSelectedId = darkThemeId;
    } else if (themeId == sepiaThemeId) {
      newThemeData = sepiaTheme;
      newSelectedId = sepiaThemeId;
    } else {
      // Try to find custom theme
      final customTheme = _customThemes.firstWhere(
        (theme) => theme.id == themeId,
        orElse: () => _customThemes.first, // Fallback logic needed
      );
      // If not found, could default to light, or handle error
      // For now, let's assume it's found if ID matches one in the list
      newThemeData = _generateThemeDataFromCustom(customTheme);
      newSelectedId = customTheme.id;
    }

    _currentThemeData = newThemeData;
    _selectedThemeId = newSelectedId;

    // Persist selected theme ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedThemeIdKey, _selectedThemeId);

    if (notify) {
      notifyListeners();
    }
    print("Applied theme: $_selectedThemeId");
  }

  // Generate ThemeData from a CustomTheme object using FlexColorScheme
  ThemeData _generateThemeDataFromCustom(CustomTheme theme) {
    print(
      "Generating theme data for custom theme: ${theme.name} (${theme.id})",
    );
    // Use brightness directly from theme object
    final bool isDark = theme.brightness == Brightness.dark;

    // Use seeds for theme generation
    final FlexColorScheme flexScheme =
        isDark
            ? FlexColorScheme.dark(
              primary: theme.primaryColor,
              secondary: theme.secondaryColor, // Use optional seed
              tertiary: theme.tertiaryColor, // Use optional seed
              // Keep other settings consistent with predefined dark theme
              surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
              appBarStyle: FlexAppBarStyle.scaffoldBackground,
              blendLevel: 40,
              subThemesData: const FlexSubThemesData(
                interactionEffects: true,
                tintedDisabledControls: true,
                blendOnLevel: 30,
                useM2StyleDividerInM3: true,
                adaptiveElevationShadowsBack:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveAppBarScrollUnderOff:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
                defaultRadiusAdaptive: 10.0,
                elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
                elevatedButtonSecondarySchemeColor:
                    SchemeColor.primaryContainer,
                outlinedButtonOutlineSchemeColor: SchemeColor.primary,
                toggleButtonsBorderSchemeColor: SchemeColor.primary,
                segmentedButtonSchemeColor: SchemeColor.primary,
                segmentedButtonBorderSchemeColor: SchemeColor.primary,
                unselectedToggleIsColored: true,
                sliderValueTinted: true,
                inputDecoratorSchemeColor: SchemeColor.primary,
                inputDecoratorIsFilled: true,
                inputDecoratorBackgroundAlpha: 19,
                inputDecoratorBorderType: FlexInputBorderType.outline,
                inputDecoratorUnfocusedHasBorder: false,
                inputDecoratorFocusedBorderWidth: 1.0,
                inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
                fabUseShape: true,
                fabAlwaysCircular: true,
                fabSchemeColor: SchemeColor.tertiary,
                cardRadius: 14.0,
                popupMenuRadius: 6.0,
                popupMenuElevation: 3.0,
                alignedDropdown: true,
                dialogRadius: 18.0,
                appBarScrolledUnderElevation: 1.0,
                drawerElevation: 1.0,
                drawerIndicatorSchemeColor: SchemeColor.primary,
                bottomSheetRadius: 18.0,
                bottomSheetElevation: 2.0,
                bottomSheetModalElevation: 4.0,
                bottomNavigationBarMutedUnselectedLabel: false,
                bottomNavigationBarMutedUnselectedIcon: false,
                menuRadius: 6.0,
                menuElevation: 3.0,
                menuBarRadius: 0.0,
                menuBarElevation: 1.0,
                menuBarShadowColor: Color(0x00000000),
                searchBarElevation: 4.0,
                searchViewElevation: 4.0,
                searchUseGlobalShape: true,
                navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
                navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationBarIndicatorSchemeColor: SchemeColor.primary,
                navigationBarElevation: 1.0,
                navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
                navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationRailUseIndicator: true,
                navigationRailIndicatorSchemeColor: SchemeColor.primary,
                navigationRailIndicatorOpacity: 1.00,
                navigationRailBackgroundSchemeColor: SchemeColor.surface,
              ),
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
            )
            : FlexColorScheme.light(
              primary: theme.primaryColor,
              secondary: theme.secondaryColor, // Use optional seed
              tertiary: theme.tertiaryColor, // Use optional seed
              // Keep other settings consistent with predefined light theme
              surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
              appBarStyle: FlexAppBarStyle.scaffoldBackground,
              blendLevel: 40,
              subThemesData: const FlexSubThemesData(
                interactionEffects: true,
                tintedDisabledControls: true,
                blendOnLevel: 30,
                useM2StyleDividerInM3: true,
                adaptiveElevationShadowsBack:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveAppBarScrollUnderOff:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
                defaultRadiusAdaptive: 10.0,
                elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
                elevatedButtonSecondarySchemeColor:
                    SchemeColor.primaryContainer,
                outlinedButtonOutlineSchemeColor: SchemeColor.primary,
                toggleButtonsBorderSchemeColor: SchemeColor.primary,
                segmentedButtonSchemeColor: SchemeColor.primary,
                segmentedButtonBorderSchemeColor: SchemeColor.primary,
                unselectedToggleIsColored: true,
                sliderValueTinted: true,
                inputDecoratorSchemeColor: SchemeColor.primary,
                inputDecoratorIsFilled: true,
                inputDecoratorBackgroundAlpha: 19,
                inputDecoratorBorderType: FlexInputBorderType.outline,
                inputDecoratorUnfocusedHasBorder: false,
                inputDecoratorFocusedBorderWidth: 1.0,
                inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
                fabUseShape: true,
                fabAlwaysCircular: true,
                fabSchemeColor: SchemeColor.tertiary,
                cardRadius: 14.0,
                popupMenuRadius: 6.0,
                popupMenuElevation: 3.0,
                alignedDropdown: true,
                dialogRadius: 18.0,
                appBarScrolledUnderElevation: 1.0,
                drawerElevation: 1.0,
                drawerIndicatorSchemeColor: SchemeColor.primary,
                bottomSheetRadius: 18.0,
                bottomSheetElevation: 2.0,
                bottomSheetModalElevation: 4.0,
                bottomNavigationBarMutedUnselectedLabel: false,
                bottomNavigationBarMutedUnselectedIcon: false,
                menuRadius: 6.0,
                menuElevation: 3.0,
                menuBarRadius: 0.0,
                menuBarElevation: 1.0,
                menuBarShadowColor: Color(0x00000000),
                searchBarElevation: 4.0,
                searchViewElevation: 4.0,
                searchUseGlobalShape: true,
                navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
                navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationBarIndicatorSchemeColor: SchemeColor.primary,
                navigationBarElevation: 1.0,
                navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
                navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationRailUseIndicator: true,
                navigationRailIndicatorSchemeColor: SchemeColor.primary,
                navigationRailIndicatorOpacity: 1.00,
                navigationRailBackgroundSchemeColor: SchemeColor.surface,
              ),
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
            );

    // Generate the ThemeData from the FlexColorScheme object
    ThemeData generatedTheme = flexScheme.toTheme;

    // Apply further specific overrides ONLY if necessary
    // In a seed-based approach, try to rely on FlexColorScheme first.
    // We still need the custom text color override if that was a specific requirement
    // you wanted to keep, otherwise REMOVE this textTheme override.
    // If you removed textColor from CustomTheme, you MUST remove this.
    // generatedTheme = generatedTheme.copyWith(
    //   textTheme: generatedTheme.textTheme.apply(
    //     bodyColor: theme.textColor, // Apply the specific text color chosen
    //     displayColor: theme.textColor,
    //   ),
    //   iconTheme: generatedTheme.iconTheme.copyWith(color: theme.textColor),
    //   primaryIconTheme: generatedTheme.primaryIconTheme.copyWith(color: theme.textColor),
    // );

    // Return the generated (and potentially slightly adjusted) theme
    return generatedTheme;

    // ----- OLD CODE REMOVED -----
    // final baseFlexTheme =
    //     isDark
    //         ? FlexThemeData.dark(...)
    //         : FlexThemeData.light(...);
    // return baseFlexTheme.copyWith(...);
    // ----- END OLD CODE REMOVED -----
  }

  // --- Custom Theme Management ---

  Future<void> addOrUpdateCustomTheme(CustomTheme theme) async {
    final index = _customThemes.indexWhere((t) => t.id == theme.id);
    if (index >= 0) {
      // Update existing
      _customThemes[index] = theme;
      print("Updated custom theme: ${theme.name}");
    } else {
      // Add new
      _customThemes.add(theme);
      print("Added custom theme: ${theme.name}");
    }
    await _storageService.saveCustomThemes(_customThemes);
    notifyListeners();

    // If the updated theme is the currently selected one, re-apply it
    if (_selectedThemeId == theme.id) {
      await _applyThemeById(theme.id, notify: false); // Re-generate ThemeData
      notifyListeners(); // Notify after re-applying
    }
  }

  Future<void> deleteCustomTheme(String themeId) async {
    // Prevent deleting predefined themes (though UI should prevent this)
    if (themeId == lightThemeId ||
        themeId == darkThemeId ||
        themeId == sepiaThemeId) {
      print("Cannot delete predefined themes.");
      return;
    }

    final initialLength = _customThemes.length;
    _customThemes.removeWhere((theme) => theme.id == themeId);

    if (_customThemes.length < initialLength) {
      print("Deleted custom theme with ID: $themeId");
      await _storageService.saveCustomThemes(_customThemes);

      // If the deleted theme was the selected one, revert to default
      if (_selectedThemeId == themeId) {
        print(
          "Deleted theme was selected. Reverting to default: $lightThemeId",
        );
        await selectTheme(lightThemeId); // This already applies and notifies
      } else {
        notifyListeners(); // Notify if a different theme was deleted
      }
    } else {
      print("Theme with ID $themeId not found for deletion.");
    }
  }

  // --- Helper to get theme name by ID (for display purposes maybe) ---
}
