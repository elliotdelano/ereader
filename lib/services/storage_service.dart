import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/library_screen.dart';
import '../models/book.dart';
import '../models/custom_theme.dart';

class StorageService {
  static const String _folderPathKey = 'selectedFolderPath';
  static const String _bookmarksKeyPrefix =
      'bookmarks_'; // Prefix for book-specific bookmarks

  // --- Folder Path ---

  Future<void> setSelectedFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderPathKey, path);
  }

  Future<String?> getSelectedFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderPathKey);
  }

  // --- Reading Progress ---
  static const String _progressKeyPrefix = 'progress_';

  // Saves both CFI and percentage progress (0.0 to 1.0)
  Future<void> saveReadingProgress(
    String bookPath,
    String cfi,
    double percentage,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _progressKeyPrefix + bookPath;
      // Store as a JSON map
      final progressData = {'cfi': cfi, 'percentage': percentage};
      final jsonString = jsonEncode(progressData);
      // print("Saving progress for $bookPath: Data=$jsonString"); // Log saving
      await prefs.setString(key, jsonString);
    } catch (e) {
      print("Error saving reading progress for $bookPath: $e");
    }
  }

  // Loads the progress data map containing 'cfi' and 'percentage'
  Future<Map<String, dynamic>?> loadReadingProgress(String bookPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _progressKeyPrefix + bookPath;
      final jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) {
        // print("No saved progress found for $bookPath");
        return null;
      }
      final progressData = jsonDecode(jsonString) as Map<String, dynamic>;
      // print("Loaded progress for $bookPath: Data=$progressData"); // Log loading
      return progressData;
    } catch (e) {
      print("Error loading reading progress for $bookPath: $e");
      return null;
    }
  }

  // --- Sort Settings ---
  static const String _sortOptionKey = 'librarySortOption';
  static const String _sortDirectionKey = 'librarySortAscending';

  // --- Currently Reading --- NEW SECTION
  static const String _currentlyReadingKey = 'currentlyReading';

  // Save the set of currently reading book paths
  Future<void> saveCurrentlyReading(Set<String> paths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert set to list for JSON encoding
      final pathList = paths.toList();
      await prefs.setStringList(_currentlyReadingKey, pathList);
      // print("Saved currently reading paths: $pathList");
    } catch (e) {
      print("Error saving currently reading paths: $e");
    }
  }

  // Load the set of currently reading book paths
  Future<Set<String>> loadCurrentlyReading() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pathList = prefs.getStringList(_currentlyReadingKey);
      if (pathList == null) {
        return <String>{}; // Return empty set if not found
      }
      // Convert list back to set
      final pathSet = pathList.toSet();
      // print("Loaded currently reading paths: $pathSet");
      return pathSet;
    } catch (e) {
      print("Error loading currently reading paths: $e");
      return <String>{}; // Return empty set on error
    }
  }

  // Save sort preferences
  Future<void> saveSortSettings(SortOption option, bool ascending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortOptionKey, option.name); // Store enum by name
      await prefs.setBool(_sortDirectionKey, ascending);
      print("Saved sort settings: Option=${option.name}, Ascending=$ascending");
    } catch (e) {
      print("Error saving sort settings: $e");
    }
  }

  // Load sort preferences
  Future<(SortOption, bool)> loadSortSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final optionName = prefs.getString(_sortOptionKey);
      final ascending = prefs.getBool(_sortDirectionKey);

      // Default to title ascending if nothing is saved
      final SortOption loadedOption = SortOption.values.firstWhere(
        (e) => e.name == optionName,
        orElse: () => SortOption.title, // Default option
      );
      final bool loadedAscending = ascending ?? true; // Default direction

      print(
        "Loaded sort settings: Option=${loadedOption.name}, Ascending=$loadedAscending",
      );
      return (loadedOption, loadedAscending);
    } catch (e) {
      print("Error loading sort settings: $e");
      // Return defaults on error
      return (SortOption.title, true);
    }
  }

  // --- NEW: Custom Theme Storage ---

  /// Saves the list of custom themes to SharedPreferences.
  Future<void> saveCustomThemes(List<CustomTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert each theme to its JSON representation
    final List<Map<String, dynamic>> themesJsonList =
        themes.map((theme) => theme.toJson()).toList();
    // Encode the entire list of maps into a single JSON string
    final String themesJsonString = jsonEncode(themesJsonList);
    await prefs.setString(_customThemesKey, themesJsonString);
    print("Saved ${themes.length} custom themes.");
  }

  /// Loads the list of custom themes from SharedPreferences.
  Future<List<CustomTheme>> loadCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themesJsonString = prefs.getString(_customThemesKey);

    if (themesJsonString == null || themesJsonString.isEmpty) {
      print("No custom themes found in storage.");
      return []; // Return empty list if no themes are saved
    }

    try {
      // Decode the JSON string into a List<dynamic> (which should be List<Map<String, dynamic>>)
      final List<dynamic> themesJsonList = jsonDecode(themesJsonString);
      // Convert each map back into a CustomTheme object
      final List<CustomTheme> themes =
          themesJsonList
              .map((json) => CustomTheme.fromJson(json as Map<String, dynamic>))
              .toList();
      print("Loaded ${themes.length} custom themes.");
      return themes;
    } catch (e) {
      print("Error loading/decoding custom themes: $e");
      // Optionally clear the invalid data
      // await prefs.remove(_customThemesKey);
      return []; // Return empty list on error
    }
  }

  // --- END NEW ---

  // --- NEW: Key for Custom Themes ---
  static const String _customThemesKey = 'customThemes';
  // --- END NEW ---

  // Load the list of books
}
