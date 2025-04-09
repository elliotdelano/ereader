import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- NEW: Enums for Settings ---
enum MarginSize { none, small, medium, large }

enum EpubFlow { paginated, scrolled }

enum EpubSpread { none, auto }
// --- END NEW ---

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
  // --- NEW: State Variables ---
  double _lineSpacing = 1.5; // Default line spacing
  MarginSize _marginSize = MarginSize.medium; // Default margin
  EpubFlow _epubFlow = EpubFlow.paginated; // Default flow
  EpubSpread _epubSpread = EpubSpread.none; // Default spread
  // --- END NEW ---

  static const String _fontSizePrefKey = 'readerFontSize';
  static const String _fontFamilyPrefKey = 'readerFontFamily';
  // --- NEW: Persistence Keys ---
  static const String _lineSpacingPrefKey = 'readerLineSpacing';
  static const String _marginSizePrefKey = 'readerMarginSize'; // Store as index
  static const String _epubFlowPrefKey = 'readerEpubFlow'; // Store as index
  static const String _epubSpreadPrefKey = 'readerEpubSpread'; // Store as index
  // --- END NEW ---

  List<String> get availableFontFamilies => fontFamilies;

  ReaderSettingsProvider() {
    _loadSettings();
  }

  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  // --- NEW: Getters ---
  double get lineSpacing => _lineSpacing;
  MarginSize get marginSize => _marginSize;
  EpubFlow get epubFlow => _epubFlow;
  EpubSpread get epubSpread => _epubSpread;
  // --- END NEW ---

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

  // --- NEW: Setters ---
  Future<void> setLineSpacing(double value) async {
    _lineSpacing = value.clamp(1.0, 2.5); // Limit line spacing
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lineSpacingPrefKey, _lineSpacing);
  }

  Future<void> setMarginSize(MarginSize value) async {
    _marginSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_marginSizePrefKey, _marginSize.index); // Save index
  }

  Future<void> setEpubFlow(EpubFlow value) async {
    _epubFlow = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_epubFlowPrefKey, _epubFlow.index); // Save index
  }

  Future<void> setEpubSpread(EpubSpread value) async {
    _epubSpread = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_epubSpreadPrefKey, _epubSpread.index); // Save index
  }
  // --- END NEW ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontSizePrefKey) ?? 16.0;
    _fontFamily =
        prefs.getString(_fontFamilyPrefKey) ?? availableFontFamilies[0];
    // Ensure loaded font is valid
    if (!availableFontFamilies.contains(_fontFamily)) {
      _fontFamily = availableFontFamilies[0];
    }

    // --- NEW: Load New Settings ---
    _lineSpacing = prefs.getDouble(_lineSpacingPrefKey) ?? 1.5;
    _lineSpacing = _lineSpacing.clamp(
      1.0,
      2.5,
    ); // Ensure loaded value is clamped

    int marginIndex =
        prefs.getInt(_marginSizePrefKey) ?? MarginSize.medium.index;
    _marginSize =
        MarginSize.values.elementAtOrNull(marginIndex) ?? MarginSize.medium;

    int flowIndex = prefs.getInt(_epubFlowPrefKey) ?? EpubFlow.paginated.index;
    _epubFlow =
        EpubFlow.values.elementAtOrNull(flowIndex) ?? EpubFlow.paginated;

    int spreadIndex = prefs.getInt(_epubSpreadPrefKey) ?? EpubSpread.none.index;
    _epubSpread =
        EpubSpread.values.elementAtOrNull(spreadIndex) ?? EpubSpread.none;
    // --- END NEW ---

    notifyListeners();
  }
}

// Helper extension for safe enum lookup by index
extension SafeElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }
}
