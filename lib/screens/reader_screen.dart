import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/book.dart';
import '../models/bookmark.dart';
import '../providers/theme_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../services/storage_service.dart';
// Import the new provider and widget
import '../providers/reader_state_provider.dart';
import '../widgets/custom_epub_viewer.dart';
// Keep the old viewer import for commenting out
// import '../widgets/html_epub_reader_view.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({required this.book, super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final StorageService _storageService = StorageService();
  List<Bookmark> _bookmarks = [];
  PdfViewerController? _pdfController;
  String? _initialCfi;
  bool _isLoadingProgress = true;

  // Comment out the key for the old viewer
  // final GlobalKey<CustomEpubViewerState> _epubViewerKey =
  //     GlobalKey<CustomEpubViewerState>();

  // Placeholder for current location (page number for PDF, locator for EPUB)
  final String _currentLocation = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.book.format == BookFormat.pdf) {
      _pdfController = PdfViewerController();
    }
    // For EPUB, we now use a custom EPUB viewer widget. No controller needed.
  }

  @override
  void dispose() {
    _pdfController?.dispose(); // Dispose if it was created
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    _bookmarks = await _storageService.loadBookmarks(widget.book.path);
    setState(() {}); // Update UI if needed
  }

  Future<void> _addBookmark() async {
    String locationToAdd = _currentLocation; // Default to EPUB locator

    if (widget.book.format == BookFormat.pdf && _pdfController != null) {
      // Get current page for PDF
      locationToAdd = _pdfController!.pageNumber.toString();
    }

    if (locationToAdd.isNotEmpty) {
      final newBookmark = Bookmark(
        bookPath: widget.book.path,
        location: locationToAdd,
        timestamp: DateTime.now(),
      );
      await _storageService.addBookmark(newBookmark);
      _loadBookmarks(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bookmark added at $locationToAdd')),
      );
    }
  }

  // Placeholder for showing bookmarks
  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: _bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = _bookmarks[index];
            return ListTile(
              title: Text('Location: ${bookmark.location}'),
              subtitle: Text(bookmark.timestamp.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await _storageService.removeBookmark(bookmark);
                  _loadBookmarks(); // Refresh list
                  Navigator.pop(context); // Close bottom sheet
                },
              ),
              onTap: () {
                // Navigate to bookmark location
                _gotoBookmark(bookmark);
                Navigator.pop(context); // Close bottom sheet
              },
            );
          },
        );
      },
    );
  }

  // Placeholder for navigating to a bookmark
  void _gotoBookmark(Bookmark bookmark) {
    if (widget.book.format == BookFormat.pdf && _pdfController != null) {
      // syncfusion_flutter_pdfviewer uses page number
      final page = int.tryParse(bookmark.location);
      if (page != null) {
        _pdfController!.jumpToPage(page);
        print("Go to PDF page: $page");
      }
    }
  }

  // Placeholder for showing settings (theme, font)
  Future<void> _showSettings() async {
    // Get current settings to compare later
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );

    final initialTheme = themeProvider.currentTheme;
    final initialFontSize = settingsProvider.fontSize;
    final initialFontFamily = settingsProvider.fontFamily;

    // Use a StatefulWidget for the modal content to manage temporary state
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return _SettingsModal(
          initialTheme: initialTheme,
          initialFontSize: initialFontSize,
          initialFontFamily: initialFontFamily,
        );
      },
    );

    // ---- Code below executes after modal is closed ----

    // Get the potentially updated provider values
    final newTheme = themeProvider.currentTheme;
    final newFontSize = settingsProvider.fontSize;
    final newFontFamily = settingsProvider.fontFamily;

    // Check if settings actually changed
    final bool settingsChanged =
        initialTheme != newTheme ||
        initialFontSize != newFontSize ||
        initialFontFamily != newFontFamily;

    if (settingsChanged && widget.book.format == BookFormat.epub) {
      print("Settings changed, applying to EPUB...");

      // *** NEW APPROACH: No explicit reload needed ***
      // HtmlEpubReaderView consumes the providers and will rebuild automatically
      // triggering flutter_html to re-render with the new Style object.
      // The pagination calculation should also re-run on layout changes.
    }
  }

  Future<void> _loadInitialData() async {
    await _loadBookmarks();
    if (widget.book.format == BookFormat.epub) {
      // Load the progress map
      final progressData = await _storageService.loadReadingProgress(
        widget.book.path,
      );
      // Extract the CFI if the map and key exist
      if (progressData != null && progressData['cfi'] is String) {
        _initialCfi = progressData['cfi'] as String;
      } else {
        _initialCfi = null; // Ensure it's null if not found
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingProgress = false; // Mark loading as complete
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access providers
    final settingsProvider = Provider.of<ReaderSettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Add Bookmark',
            onPressed: _addBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'View Bookmarks',
            onPressed: _showBookmarks,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _showSettings,
          ),
        ],
      ),
      body: _buildReaderView(settingsProvider),
    );
  }

  Widget _buildReaderView(ReaderSettingsProvider settingsProvider) {
    if (widget.book.format == BookFormat.epub) {
      if (_isLoadingProgress) {
        return const Center(child: CircularProgressIndicator());
      }
      return CustomEpubViewer(
        filePath: widget.book.path,
        initialCfi: _initialCfi,
      );
    } else if (widget.book.format == BookFormat.pdf && _pdfController != null) {
      return SfPdfViewer.asset(widget.book.path, controller: _pdfController);
    } else {
      return const Center(
        child: Text('Unsupported file format or error loading viewer.'),
      );
    }
  }
}

// StatefulWidget for the Modal Bottom Sheet Content
class _SettingsModal extends StatefulWidget {
  final AppTheme initialTheme;
  final double initialFontSize;
  final String initialFontFamily;

  const _SettingsModal({
    required this.initialTheme,
    required this.initialFontSize,
    required this.initialFontFamily,
  });

  @override
  State<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<_SettingsModal> {
  late AppTheme _currentTheme;
  late double _currentFontSize;
  late String _currentFontFamily;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initialTheme;
    _currentFontSize = widget.initialFontSize;
    _currentFontFamily = widget.initialFontFamily;
  }

  @override
  Widget build(BuildContext context) {
    // Access providers for available options and *setting* the values
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: Theme.of(context).textTheme.titleLarge),
          DropdownButton<AppTheme>(
            value: _currentTheme,
            items: const [
              DropdownMenuItem(value: AppTheme.light, child: Text('Light')),
              DropdownMenuItem(value: AppTheme.dark, child: Text('Dark')),
              DropdownMenuItem(value: AppTheme.sepia, child: Text('Sepia')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _currentTheme = value;
                });
                // Update provider immediately only when modal closes
                themeProvider.setTheme(value); // Actually update provider here
              }
            },
          ),
          const Divider(),
          Text('Font', style: Theme.of(context).textTheme.titleLarge),
          DropdownButton<String>(
            value: _currentFontFamily,
            items:
                settingsProvider.availableFontFamilies.map((font) {
                  return DropdownMenuItem(value: font, child: Text(font));
                }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _currentFontFamily = value;
                });
                settingsProvider.setFontFamily(value); // Update provider here
              }
            },
          ),
          const Divider(),
          Text(
            'Font Size (${_currentFontSize.round()})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Slider(
            value: _currentFontSize,
            min: 10.0,
            max: 30.0,
            divisions: 20,
            label: _currentFontSize.round().toString(),
            onChanged: (value) {
              setState(() {
                _currentFontSize = value;
              });
            },
            // Update provider only when interaction ends
            onChangeEnd: (value) {
              settingsProvider.setFontSize(value);
            },
          ),
        ],
      ),
    );
  }
}
