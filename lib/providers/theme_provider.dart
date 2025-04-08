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
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
            primary: const Color(0xFF0000EE),
            onSurface: const Color(0xFF000000),
          ),
        );
      case AppTheme.dark:
        return ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF121212),
            brightness: Brightness.dark,
            primary: const Color(0xFFBB86FC),
            onSurface: const Color(0xFFE0E0E0),
          ),
        );
      case AppTheme.sepia:
        const sepiaBackgroundColor = Color(0xFFFBF0D9);
        const sepiaTextColor = Color(0xFF5B4636);
        const sepiaLinkColor = Color(0xFF704214);
        return ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: sepiaBackgroundColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: sepiaBackgroundColor,
            brightness: Brightness.light,
            primary: sepiaLinkColor,
            onSurface: sepiaTextColor,
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
