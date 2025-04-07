import 'package:shared_preferences/shared_preferences.dart';
import '../models/bookmark.dart';
import 'dart:convert';

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

  // --- Bookmarks ---

  // Save bookmarks for a specific book path
  Future<void> saveBookmarks(String bookPath, List<Bookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bookmarksKeyPrefix + bookPath; // Unique key per book
    final bookmarkStrings = bookmarks.map((b) => b.toString()).toList();
    await prefs.setStringList(key, bookmarkStrings);
  }

  // Load bookmarks for a specific book path
  Future<List<Bookmark>> loadBookmarks(String bookPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bookmarksKeyPrefix + bookPath;
    final bookmarkStrings = prefs.getStringList(key) ?? [];

    final List<Bookmark> bookmarks = [];
    for (final str in bookmarkStrings) {
      final bookmark = Bookmark.fromString(str);
      if (bookmark != null) {
        bookmarks.add(bookmark);
      }
    }
    // Optional: Sort bookmarks by timestamp or location
    bookmarks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return bookmarks;
  }

  // Add a single bookmark
  Future<void> addBookmark(Bookmark bookmark) async {
    final currentBookmarks = await loadBookmarks(bookmark.bookPath);
    // Avoid duplicates (optional, based on location)
    if (!currentBookmarks.any((b) => b.location == bookmark.location)) {
      currentBookmarks.add(bookmark);
      await saveBookmarks(bookmark.bookPath, currentBookmarks);
    }
  }

  // Remove a single bookmark
  Future<void> removeBookmark(Bookmark bookmarkToRemove) async {
    final currentBookmarks = await loadBookmarks(bookmarkToRemove.bookPath);
    currentBookmarks.removeWhere(
      (b) =>
          b.location == bookmarkToRemove.location &&
          b.timestamp == bookmarkToRemove.timestamp,
    );
    await saveBookmarks(bookmarkToRemove.bookPath, currentBookmarks);
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
      print("Saving progress for $bookPath: Data=$jsonString"); // Log saving
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
        print("No saved progress found for $bookPath");
        return null;
      }
      final progressData = jsonDecode(jsonString) as Map<String, dynamic>;
      print("Loaded progress for $bookPath: Data=$progressData"); // Log loading
      return progressData;
    } catch (e) {
      print("Error loading reading progress for $bookPath: $e");
      return null;
    }
  }
}
