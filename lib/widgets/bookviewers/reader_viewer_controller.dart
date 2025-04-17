/// Interface for all format-specific readers (e.g., EPUB, PDF).
abstract class ReaderViewerController {
  /// Called to navigate to the next logical page/section.
  Future<void> nextPage();

  /// Called to navigate to the previous logical page/section.
  Future<void> previousPage();

  /// Called to navigate to a specific location by CFI or equivalent.
  Future<void> navigateToCfi(String cfi);

  /// Called to navigate to a specific location by percentage (0.0 - 1.0).
  Future<void> navigateToPercentage(double percentage);

  /// Called to navigate to a specific location by href or equivalent.
  Future<void> navigateToTocEntry(String loc);

  /// Returns the Table of Contents as a JSON string (or null if not supported).
  Future<List<Map<String, dynamic>>> getTocJson();

  /// Called to dispose any resources.
  void dispose();
}
