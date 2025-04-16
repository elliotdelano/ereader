import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import '../models/book.dart';
import '../providers/theme_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/epub_viewer.dart';
import '../widgets/reader/settings_panel.dart';
import '../widgets/reader/toc_panel.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({required this.book, super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final StorageService _storageService = StorageService();
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

  // --- NEW: State for Sliding Panels ---
  bool _isSettingsPanelVisible = false;
  bool _isTocPanelVisible = false;
  List<Map<String, dynamic>>? _currentTocList; // To hold loaded ToC data
  // --- END NEW ---

  // --- NEW: Focus Node for Keyboard Events ---
  final FocusNode _focusNode = FocusNode();
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
    _loadInitialData();
    _markAsCurrentlyReading();
    // For EPUB, we now use a custom EPUB viewer widget. No controller needed.
    // --- NEW: Request Focus ---
    // Request focus after the first frame to ensure the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
    // --- END NEW ---
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // --- NEW: Dispose FocusNode ---
    _focusNode.dispose();
    // --- END NEW ---
    super.dispose();
  }

  // --- NEW: Method to dismiss panels ---
  void _dismissPanels() {
    if (!mounted) return;
    setState(() {
      _isSettingsPanelVisible = false;
      _isTocPanelVisible = false;
    });
  }
  // --- END NEW ---

  Future<void> _showSettings() async {
    // Toggle panel visibility
    setState(() {
      _isTocPanelVisible = false; // Close ToC if open
      _isSettingsPanelVisible = !_isSettingsPanelVisible;
    });
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

      // --- NEW: Pre-fetch ToC silently ---
      // We need the key available which means the viewer must have been built at least once.
      // Let's try fetching after a short delay post-build.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && _epubViewerKey.currentState != null) {
          try {
            final tocJson = await _epubViewerKey.currentState!.getTocJson();
            if (tocJson != null && tocJson.isNotEmpty) {
              final List<dynamic> tocRaw = jsonDecode(tocJson);
              _currentTocList = List<Map<String, dynamic>>.from(tocRaw);
              print("Pre-fetched ToC successfully.");
            } else {
              print("Pre-fetched ToC was null or empty.");
            }
          } catch (e) {
            print("Error pre-fetching ToC: $e");
          }
        }
      });
      // --- END NEW ---
    }
    if (mounted) {
      setState(() {
        _isLoadingProgress = false; // Mark loading as complete
      });
    }
  }

  Future<void> _showTableOfContents() async {
    if (widget.book.format != BookFormat.epub) return;

    // --- MODIFIED: Use pre-fetched ToC or fetch now ---
    if (_currentTocList == null) {
      // Attempt to fetch if not pre-fetched
      if (_epubViewerKey.currentState == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Viewer not ready.')));
        return;
      }
      showDialog(
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      try {
        final tocJson = await _epubViewerKey.currentState!.getTocJson();
        Navigator.pop(context); // Dismiss loading
        if (tocJson != null && tocJson.isNotEmpty) {
          final List<dynamic> tocRaw = jsonDecode(tocJson);
          _currentTocList = List<Map<String, dynamic>>.from(tocRaw);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load Table of Contents.')),
          );
          return;
        }
      } catch (e) {
        Navigator.pop(context); // Dismiss loading on error
        print("Error fetching ToC: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading Table of Contents.')),
        );
        return;
      }
    }

    if (_currentTocList == null || _currentTocList!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Table of Contents is empty.')),
      );
      return;
    }

    // Toggle panel visibility
    setState(() {
      _isSettingsPanelVisible = false; // Close settings if open
      _isTocPanelVisible = !_isTocPanelVisible;
    });
    // --- END MODIFIED ---
  }

  @override
  Widget build(BuildContext context) {
    // Access providers
    final settingsProvider = Provider.of<ReaderSettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final topPadding = MediaQuery.of(context).padding.top;

    final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
      // statusBarColor:
      //     Theme.of(context)
      //         .colorScheme
      //         .surface, // Black background for dark mode, transparent otherwise
      statusBarIconBrightness: themeProvider.themeData.brightness,
      systemStatusBarContrastEnforced: false,
    );

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    // --- MODIFIED: Calculate panel dimensions ---
    const double panelMaxHeight = 450.0;
    const double panelMaxWidth = 500.0; // Define max width
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;

    // Calculate actual width, respecting max width and side padding (20px each side)
    final double actualPanelWidth = math.min(screenWidth - 40.0, panelMaxWidth);
    // Calculate horizontal offset to center the panel
    final double panelLeftOffset = (screenWidth - actualPanelWidth) / 2.0;

    // Calculate vertical offset to center the panel (approximated)
    // Note: This centers the *top* of the panel. We might need adjustment
    // if the panel height varies significantly or if exact vertical centering is crucial.
    final double panelTopOffset = (screenHeight - panelMaxHeight) / 2.0;

    // Positions for animation
    final double offScreenTop = -screenHeight; // Animate from top
    final double onScreenTop = math.max(
      panelTopOffset,
      topPadding + 10,
    ); // Ensure below status bar

    // --- END MODIFIED ---

    // --- MODIFIED: Wrap Scaffold with Focus and KeyboardListener ---
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        // backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            // Layer 1: Main reader content
            Padding(
              // TODO: Add Container to handle background color
              padding: EdgeInsets.only(top: topPadding),
              child: _buildReaderView(settingsProvider),
            ),

            // --- REVERTED: Use Three Gesture Detectors ---
            // Define zones for clarity
            if (settingsProvider.epubFlow == EpubFlow.paginated)
              Positioned.fill(
                top: topPadding, // Start below status bar area
                child: Row(
                  children: [
                    // Left Zone (Tap/Swipe)
                    Expanded(
                      flex: 35, // Corresponds to 35%
                      child: GestureDetector(
                        onTap: _handleLeftTap,
                        onHorizontalDragEnd: _handleHorizontalSwipe,
                        behavior: HitTestBehavior.translucent,
                        child: Container(
                          color: Colors.transparent,
                        ), // Fill area
                      ),
                    ),
                    // Center Zone (Tap for AppBar only)
                    Expanded(
                      flex: 30, // Corresponds to 30%
                      child: GestureDetector(
                        onTap: _handleCenterTap,
                        onHorizontalDragEnd: _handleHorizontalSwipe,
                        behavior: HitTestBehavior.translucent,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    // Right Zone (Tap/Swipe)
                    Expanded(
                      flex: 35, // Corresponds to 35%
                      child: GestureDetector(
                        onTap: _handleRightTap,
                        onHorizontalDragEnd: _handleHorizontalSwipe,
                        behavior: HitTestBehavior.translucent,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),

            if (settingsProvider.epubFlow == EpubFlow.scrolled)
              Positioned.fill(
                top: topPadding, // Start below status bar area
                child: Column(
                  children: [
                    Expanded(
                      flex: 30, // Corresponds to 30%
                      child: GestureDetector(
                        onTap: _handleCenterTap,
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                  ],
                ),
              ),

            // Layer 4: Dimming background for panels
            Visibility(
              visible: _isSettingsPanelVisible || _isTocPanelVisible,
              child: GestureDetector(
                onTap: _dismissPanels,
                child: Container(color: Colors.black.withAlpha(100)),
              ),
            ),

            // Layer 5: Settings Panel - Animate from Top Center
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _isSettingsPanelVisible ? onScreenTop : offScreenTop,
              left: panelLeftOffset,
              width: actualPanelWidth,
              child: Container(
                constraints: BoxConstraints(maxHeight: panelMaxHeight),
                child: Material(
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(16.0),
                  child: SettingsPanelContent(),
                ),
              ),
            ),

            // Layer 6: ToC Panel - Animate from Top Center
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _isTocPanelVisible ? onScreenTop : offScreenTop,
              left: panelLeftOffset,
              width: actualPanelWidth,
              child: Container(
                constraints: BoxConstraints(maxHeight: panelMaxHeight),
                child: Material(
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(16.0),
                  child: TocPanelContent(
                    tocList: _currentTocList ?? [],
                    onItemTap: (href) {
                      _epubViewerKey.currentState?.navigateToHref(href);
                      _dismissPanels();
                    },
                  ),
                ),
              ),
            ),

            // Layer 7: Floating AppBar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isAppBarVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isAppBarVisible,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8, right: 8, top: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBar(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                          if (widget.book.format == BookFormat.epub)
                            SizedBox(
                              height: 20,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12.0,
                                  ),
                                ),
                                child: Slider(
                                  value: _sliderValue.clamp(0.0, 1.0),
                                  min: 0.0,
                                  max: 1.0,
                                  onChangeStart: (value) {
                                    setState(() {
                                      _isScrubbing = true;
                                      _preScrubCfi = _currentCfiFromViewer;
                                    });
                                  },
                                  onChanged: (value) {
                                    setState(() {
                                      _sliderValue = value;
                                    });
                                  },
                                  onChangeEnd: (value) {
                                    _epubViewerKey.currentState
                                        ?.navigateToPercentage(value);
                                    if (mounted && _preScrubCfi != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).removeCurrentSnackBar();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Jumped to location',
                                          ),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () {
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
                                    setState(() {
                                      _isScrubbing = false;
                                      _preScrubCfi = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  // --- NEW: Dedicated Tap Handlers ---
  void _handleLeftTap() {
    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    if (settingsProvider.epubFlow != EpubFlow.scrolled) {
      _epubViewerKey.currentState?.previousPage();
    }
  }

  void _handleCenterTap() {
    setState(() {
      _isAppBarVisible = !_isAppBarVisible;
    });
    if (_isAppBarVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
    }
  }

  void _handleRightTap() {
    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    if (settingsProvider.epubFlow != EpubFlow.scrolled) {
      _epubViewerKey.currentState?.nextPage();
    }
  }
  // --- END NEW ---

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

  // NEW: Handle horizontal swipes for page turning
  void _handleHorizontalSwipe(DragEndDetails details) {
    if (widget.book.format != BookFormat.epub) return; // Only for EPUBs

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    if (settingsProvider.epubFlow == EpubFlow.scrolled) {
      return; // Do nothing in scroll mode
    }

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

  // --- NEW: Keyboard Event Handler ---
  void _handleKeyEvent(KeyEvent event) {
    // --- MODIFIED: Check platform directly ---
    if (event is KeyDownEvent && // Process key down events
        (Platform.isWindows || Platform.isLinux) && // Only on desktop
        widget.book.format == BookFormat.epub) {
      // Only for EPUBs
      // --- END MODIFIED ---

      final settingsProvider = Provider.of<ReaderSettingsProvider>(
        context,
        listen: false,
      );

      // Only handle arrows if in paginated mode
      if (settingsProvider.epubFlow == EpubFlow.paginated) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          // print("[Keyboard] Left Arrow Pressed");
          _epubViewerKey.currentState?.previousPage();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          // print("[Keyboard] Right Arrow Pressed");
          _epubViewerKey.currentState?.nextPage();
        }
      }
    }
  }

  // --- END NEW ---
}
