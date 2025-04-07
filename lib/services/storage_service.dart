import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/library_screen.dart';

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
}
