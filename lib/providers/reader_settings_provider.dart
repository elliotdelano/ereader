import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define available font families (add more as needed)
const List<String> fontFamilies = [
  'Arial',
  'Verdana',
  'Times New Roman',
  'Georgia',
  'Courier New',
  'Comic Sans MS',
  'Trebuchet MS',
  'Garamond',
];

class ReaderSettingsProvider with ChangeNotifier {
  double _fontSize = 16.0;
  String _fontFamily = fontFamilies[0]; // Default font

  static const String _fontSizePrefKey = 'readerFontSize';
  static const String _fontFamilyPrefKey = 'readerFontFamily';

  List<String> get availableFontFamilies => fontFamilies;

  ReaderSettingsProvider() {
    _loadSettings();
  }

  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(10.0, 30.0); // Limit font size to a reasonable range
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizePrefKey, _fontSize);
  }

  Future<void> setFontFamily(String family) async {
    if (availableFontFamilies.contains(family)) {
      _fontFamily = family;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontFamilyPrefKey, _fontFamily);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontSizePrefKey) ?? 16.0;
    _fontFamily =
        prefs.getString(_fontFamilyPrefKey) ?? availableFontFamilies[0];
    // Ensure loaded font is valid
    if (!availableFontFamilies.contains(_fontFamily)) {
      _fontFamily = availableFontFamilies[0];
    }
    notifyListeners();
  }
}
