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
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: sepiaBackgroundColor,
            brightness: Brightness.light,
          ),
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
