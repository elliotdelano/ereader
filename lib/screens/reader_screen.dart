import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../models/book.dart';
import '../providers/theme_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/custom_epub_viewer.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({required this.book, super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final StorageService _storageService = StorageService();
  PdfViewerController? _pdfController;
  String? _initialCfi;
  bool _isLoadingProgress = true;
  bool _isAppBarVisible = false;
  final GlobalKey<CustomEpubViewerState> _epubViewerKey = GlobalKey();

  // --- NEW: Slider and Progress State ---
  double _currentBookPercentage = 0.0; // Latest actual book progress
  double _sliderValue = 0.0; // Visual position of slider thumb
  String? _preScrubCfi; // CFI before user starts scrubbing
  String? _currentCfiFromViewer; // Latest CFI received from viewer
  bool _isScrubbing = false; // Is the user currently dragging the slider?
  // --- End NEW ---

  // Placeholder for current location (page number for PDF, locator for EPUB)
  final String _currentLocation = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
    _loadInitialData();
    if (widget.book.format == BookFormat.pdf) {
      _pdfController = PdfViewerController();
    }
    _markAsCurrentlyReading();
    // For EPUB, we now use a custom EPUB viewer widget. No controller needed.
  }

  @override
  void dispose() {
    _pdfController?.dispose(); // Dispose if it was created
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
    if (widget.book.format == BookFormat.epub) {
      // Load the progress map
      final progressData = await _storageService.loadReadingProgress(
        widget.book.path,
      );

      // Extract the CFI and Percentage if the map and keys exist
      double initialPercentage = 0.0;
      if (progressData != null) {
        if (progressData['cfi'] is String) {
          _initialCfi = progressData['cfi'] as String;
          _currentCfiFromViewer = _initialCfi; // Initialize with loaded CFI
        } else {
          _initialCfi = null;
          _currentCfiFromViewer = null;
        }
        // Also load percentage
        if (progressData['percentage'] is double) {
          initialPercentage = progressData['percentage'] as double;
        } else if (progressData['percentage'] is int) {
          // Handle cases where it might have been saved as int (though unlikely now)
          initialPercentage = (progressData['percentage'] as int).toDouble();
        }
      } else {
        _initialCfi = null;
        _currentCfiFromViewer = null;
      }

      // Initialize slider and book percentage state
      _currentBookPercentage = initialPercentage;
      _sliderValue = initialPercentage;
    }
    if (mounted) {
      setState(() {
        _isLoadingProgress = false; // Mark loading as complete
      });
    }
  }

  Future<void> _showTableOfContents() async {
    // Ensure it's an EPUB and the key is valid
    if (widget.book.format != BookFormat.epub ||
        _epubViewerKey.currentState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Table of Contents not available for this format or viewer not ready.',
          ),
        ),
      );
      return;
    }

    // Show loading indicator while fetching
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final tocJson = await _epubViewerKey.currentState!.getTocJson();

    Navigator.pop(context); // Dismiss loading indicator

    if (tocJson == null || tocJson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load Table of Contents.')),
      );
      return;
    }

    try {
      final List<dynamic> tocRaw = jsonDecode(tocJson);
      final List<Map<String, dynamic>> tocList =
          List<Map<String, dynamic>>.from(tocRaw);

      if (tocList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table of Contents is empty.')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6, // Start at 60% height
            minChildSize: 0.3, // Min 30% height
            maxChildSize: 0.9, // Max 90% height
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle for dragging
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8.0,
                      left: 16.0,
                      right: 16.0,
                    ),
                    child: Text(
                      "Table of Contents",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: tocList.length,
                      itemBuilder: (context, index) {
                        final item = tocList[index];
                        final String label = item['label'] ?? 'Untitled';
                        final String? href = item['href'];
                        final int depth = item['depth'] ?? 0;

                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: 16.0 + (depth * 16.0),
                            right: 16.0,
                          ), // Indentation
                          title: Text(
                            label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          dense: true,
                          onTap:
                              href == null
                                  ? null
                                  : () {
                                    print("Navigating to: $href");
                                    _epubViewerKey.currentState?.navigateToHref(
                                      href,
                                    );
                                    Navigator.pop(
                                      context,
                                    ); // Close the bottom sheet
                                  },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print("Error decoding or displaying ToC: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error displaying Table of Contents.')),
      );
    }
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    // Define tap zones (adjust percentages as needed)
    final leftZoneEnd = screenWidth * 0.35;
    final rightZoneStart = screenWidth * 0.65;

    if (tapX < leftZoneEnd) {
      // Tap on left: Previous page
      _epubViewerKey.currentState?.previousPage();
    } else if (tapX > rightZoneStart) {
      // Tap on right: Next page
      _epubViewerKey.currentState?.nextPage();
    } else {
      // Tap in center: Toggle AppBar and System UI
      setState(() {
        _isAppBarVisible = !_isAppBarVisible;
      });

      // Update System UI based on AppBar visibility
      if (_isAppBarVisible) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top],
        );
      }
    }
  }

  // NEW: Handle horizontal swipes for page turning
  void _handleHorizontalSwipe(DragEndDetails details) {
    if (widget.book.format != BookFormat.epub) return; // Only for EPUBs

    // Velocity check to determine direction and intent
    // Adjust the threshold (e.g., 500) as needed for sensitivity
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! < -500) {
        // Swiped Left (->): Next Page
        _epubViewerKey.currentState?.nextPage();
      } else if (details.primaryVelocity! > 500) {
        // Swiped Right (<-): Previous Page
        _epubViewerKey.currentState?.previousPage();
      }
    }
  }

  // --- NEW: Handle Location Update from Viewer ---
  void _handleLocationUpdate(double percentage, String? cfi) {
    if (mounted) {
      setState(() {
        _currentBookPercentage = percentage;
        _currentCfiFromViewer = cfi;
        // Only update slider's visual value if user isn't actively dragging it
        if (!_isScrubbing) {
          _sliderValue = percentage;
        }
      });
    }
  }
  // --- End NEW ---

  @override
  Widget build(BuildContext context) {
    // Access providers
    final settingsProvider = Provider.of<ReaderSettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final topPadding = MediaQuery.of(context).padding.top;

    // Determine Status Bar Style based on Theme
    final bool isDarkMode = themeProvider.currentTheme == AppTheme.dark;
    final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
      statusBarColor:
          Theme.of(context)
              .colorScheme
              .surface, // Black background for dark mode, transparent otherwise
      statusBarIconBrightness:
          isDarkMode
              ? Brightness.light
              : Brightness.dark, // Light icons for dark mode, dark otherwise
      systemStatusBarContrastEnforced: false,
    );

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Main content with padding
          Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: _buildReaderView(settingsProvider),
          ),
          // Invisible gesture detector covering only the main content area
          // Placed *before* the AppBar in the Stack order
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTapUp: _handleTap,
              onHorizontalDragEnd:
                  _handleHorizontalSwipe, // ADDED: Handle swipes
              behavior:
                  HitTestBehavior
                      .translucent, // Allows taps to pass through if needed, but primarily for AppBar toggle
            ),
          ),
          // Floating AppBar with fade animation
          // Placed *after* the GestureDetector, so it's on top when visible
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isAppBarVisible ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring:
                    !_isAppBarVisible, // Allows interaction ONLY when visible
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.only(left: 8, right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withAlpha(230),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      // NEW: Wrap AppBar and Slider
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          title: Text(widget.book.title),
                          actions: [
                            if (widget.book.format == BookFormat.epub)
                              IconButton(
                                icon: const Icon(Icons.list),
                                tooltip: 'Table of Contents',
                                onPressed: _showTableOfContents,
                              ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              tooltip: 'Settings',
                              onPressed: _showSettings,
                            ),
                          ],
                        ),
                        // --- NEW: Slider Added Here ---
                        if (widget.book.format == BookFormat.epub)
                          SizedBox(
                            height: 20, // Height for the slider area
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12.0,
                                ),
                                activeTrackColor:
                                    Theme.of(context).colorScheme.primary,
                                inactiveTrackColor: (isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300)
                                    .withAlpha(150),
                                thumbColor:
                                    Theme.of(context).colorScheme.primary,
                                overlayColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(60),
                              ),
                              child: Slider(
                                value: _sliderValue.clamp(
                                  0.0,
                                  1.0,
                                ), // Use _sliderValue
                                min: 0.0,
                                max: 1.0,
                                onChangeStart: (value) {
                                  setState(() {
                                    _isScrubbing = true;
                                    _preScrubCfi = _currentCfiFromViewer;
                                    print(
                                      "Slider scrub start, saved CFI: $_preScrubCfi",
                                    );
                                  });
                                },
                                onChanged: (value) {
                                  setState(() {
                                    // Only update visual slider value
                                    _sliderValue = value;
                                  });
                                },
                                onChangeEnd: (value) {
                                  print(
                                    "Slider scrub end at: ${value.toStringAsFixed(4)}",
                                  );
                                  // Use GlobalKey to call viewer's method
                                  _epubViewerKey.currentState
                                      ?.navigateToPercentage(value);

                                  // Show Undo SnackBar
                                  if (mounted && _preScrubCfi != null) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).removeCurrentSnackBar(); // Remove previous if any
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Jumped to location',
                                        ),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          onPressed: () {
                                            print(
                                              "Undo pressed, navigating back to: $_preScrubCfi",
                                            );
                                            if (_preScrubCfi != null) {
                                              _epubViewerKey.currentState
                                                  ?.navigateToCfi(
                                                    _preScrubCfi!,
                                                  );
                                            }
                                          },
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                  // Important: Reset scrubbing flag and preScrubCfi after nav
                                  setState(() {
                                    _isScrubbing = false;
                                    _preScrubCfi = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        // --- End Slider ---
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderView(ReaderSettingsProvider settingsProvider) {
    if (widget.book.format == BookFormat.epub) {
      if (_isLoadingProgress) {
        return const Center(child: CircularProgressIndicator());
      }
      return CustomEpubViewer(
        key: _epubViewerKey,
        filePath: widget.book.path,
        initialCfi: _initialCfi,
        onLocationChanged: _handleLocationUpdate,
      );
    } else if (widget.book.format == BookFormat.pdf && _pdfController != null) {
      return SfPdfViewer.asset(widget.book.path, controller: _pdfController);
    } else {
      return const Center(
        child: Text('Unsupported file format or error loading viewer.'),
      );
    }
  }

  // NEW Method to mark book as currently reading
  Future<void> _markAsCurrentlyReading() async {
    try {
      final currentSet = await _storageService.loadCurrentlyReading();
      if (!currentSet.contains(widget.book.path)) {
        currentSet.add(widget.book.path);
        await _storageService.saveCurrentlyReading(currentSet);
        print("Marked ${widget.book.path} as currently reading.");
      }
    } catch (e) {
      print("Error marking book as currently reading: $e");
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
