import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, sepia }

class ThemeProvider with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.light;
  static const String _themePrefKey = 'appTheme';

  ThemeProvider() {
    _loadTheme();
  }

  AppTheme get currentTheme => _currentTheme;

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.light:
        return ThemeData.light(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: Colors.white,
          // Add other light theme customizations
        );
      case AppTheme.dark:
        return ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: Colors.grey[900],
          // Add other dark theme customizations
        );
      case AppTheme.sepia:
        // Define Sepia colors
        const sepiaBackgroundColor = Color(0xFFFBF0D9);
        const sepiaForegroundColor = Color(
          0xFF5B4636,
        ); // Dark brown for text/icons
        const sepiaAppBarColor = Color(
          0xFFEFE0C9,
        ); // Slightly darker/desaturated for app bar

        return ThemeData.light(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: sepiaBackgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: sepiaAppBarColor,
            foregroundColor: sepiaForegroundColor, // Color for title and icons
            elevation: 0.5, // Subtle elevation
          ),
          textTheme: ThemeData.light().textTheme.apply(
            // Apply color to default light text theme
            bodyColor: sepiaForegroundColor,
            displayColor: sepiaForegroundColor,
          ),
          iconTheme: const IconThemeData(
            color: sepiaForegroundColor,
          ), // Default icon color
          // Optionally define a more complete color scheme:
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.brown, // Or generate from a seed color
            accentColor: Colors.brown[700],
            backgroundColor: sepiaBackgroundColor,
            brightness: Brightness.light,
          ).copyWith(
            surface: sepiaBackgroundColor,
            onSurface: sepiaForegroundColor,
            // Adjust other colors as needed
          ),
          // Customize other elements like buttons, sliders etc. if needed
        );
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, theme.index);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themePrefKey) ?? AppTheme.light.index;
    _currentTheme = AppTheme.values[themeIndex];
    notifyListeners();
  }
}
