class Bookmark {
  final String bookPath; // To associate the bookmark with a specific book
  final String location; // Could be page number (PDF) or locator string (EPUB)
  final String? textSnippet; // Optional text context for the bookmark
  final DateTime timestamp;

  Bookmark({
    required this.bookPath,
    required this.location,
    this.textSnippet,
    required this.timestamp,
  });

  // Methods for serialization/deserialization if storing complex data
  // For simple storage with shared_preferences, we might store a list of strings
  // representing bookmarks, e.g., "bookPath|location|timestamp|textSnippet"
  // Or use JSON encoding if storing in a database or more complex pref structure.

  // Example simple serialization to string
  @override
  String toString() {
    // Use a delimiter that's unlikely to appear in paths or snippets
    const delimiter = '|||';
    return '$bookPath$delimiter$location$delimiter${timestamp.toIso8601String()}${textSnippet != null ? '$delimiter$textSnippet' : ''}';
  }

  // Example simple deserialization from string
  static Bookmark? fromString(String data) {
    try {
      const delimiter = '|||';
      final parts = data.split(delimiter);
      if (parts.length < 3) return null; // Basic validation

      return Bookmark(
        bookPath: parts[0],
        location: parts[1],
        timestamp: DateTime.parse(parts[2]),
        textSnippet: parts.length > 3 ? parts[3] : null,
      );
    } catch (e) {
      print("Error parsing bookmark string: $e");
      return null;
    }
  }
}
