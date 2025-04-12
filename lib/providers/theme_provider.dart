import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'dart:convert';

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
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useTextTheme: true,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  );

  static final ThemeData darkTheme = FlexThemeData.dark(
    scheme: FlexScheme.material,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useTextTheme: true,
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
    scaffoldBackground: const Color(0xFFFAF5ED), // Slightly lighter scaffold
    subThemesData: const FlexSubThemesData(
      useTextTheme: true,
      blendOnLevel: 10,
      useM2StyleDividerInM3: true,
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
    final Brightness brightness =
        theme.backgroundColor.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark;
    final bool isDark = brightness == Brightness.dark;

    // Create FlexSchemeColor from the user's core choices
    final FlexSchemeColor schemeColors = FlexSchemeColor.from(
      primary: theme.primaryColor,
      // Let FlexSchemeColor compute secondary/tertiary unless user picks them
    );

    final baseFlexTheme =
        isDark
            ? FlexThemeData.dark(
              colors: schemeColors,
              surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
              blendLevel: 13, // Default dark blend level
              scaffoldBackground: theme.backgroundColor,
              appBarBackground: theme.surfaceColor,
              subThemesData: FlexSubThemesData(
                blendOnLevel: 20,
                useTextTheme: true,
                useM2StyleDividerInM3: true,
              ),
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
            )
            : FlexThemeData.light(
              colors: schemeColors,
              surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
              blendLevel: 7, // Default light blend level
              scaffoldBackground: theme.backgroundColor,
              appBarBackground: theme.surfaceColor,
              subThemesData: FlexSubThemesData(
                blendOnLevel: 10,
                useTextTheme: true,
                useM2StyleDividerInM3: true,
              ),
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
            );

    // Apply further specific overrides
    return baseFlexTheme.copyWith(
      cardTheme: baseFlexTheme.cardTheme.copyWith(
        color: theme.surfaceColor, // Explicitly set card color
      ),
      // Ensure text selection uses primary color for contrast
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: theme.primaryColor,
        selectionColor: theme.primaryColor.withAlpha(30),
        selectionHandleColor: theme.primaryColor,
      ),
      // Apply the custom text color
      textTheme: baseFlexTheme.textTheme.apply(
        bodyColor:
            theme
                .textColor, // Color for body text (bodyLarge, bodyMedium, bodySmall)
        displayColor:
            theme.textColor, // Color for display text (displayLarge, etc.)
        // You might want to explicitly set headlineColor, titleColor etc. if needed
      ),
      // Apply custom text color to icon themes as well for consistency
      iconTheme: baseFlexTheme.iconTheme.copyWith(color: theme.textColor),
      primaryIconTheme: baseFlexTheme.primaryIconTheme.copyWith(
        color: theme.textColor,
      ),
    );
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
