import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:ereader/providers/reader_settings_provider.dart';
import 'package:ereader/providers/theme_provider.dart';
import 'package:ereader/services/epub_server_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';

// Add a callback type for navigation methods if needed by parent
// typedef ChapterNavigationCallback = void Function(String href);

class CustomEpubViewer extends StatefulWidget {
  final String filePath;
  // Add callbacks if ReaderScreen needs to trigger navigation
  // final ChapterNavigationCallback? onNextChapter;
  // final ChapterNavigationCallback? onPreviousChapter;

  const CustomEpubViewer({
    super.key,
    required this.filePath,
    // this.onNextChapter,
    // this.onPreviousChapter,
  });

  @override
  State<CustomEpubViewer> createState() => CustomEpubViewerState();
}

class CustomEpubViewerState extends State<CustomEpubViewer> {
  final EpubServerService epubServerService = EpubServerService();
  bool _isLoading = true;
  String? _error;
  WebViewController? _webViewController;
  List<String>? _spineHrefs; // Store the spine hrefs
  String? _currentHref; // Store the current relative path
  int _currentIndex = -1; // Store the index in the spine
  String? _baseUrl;

  // Pagination State
  int _currentPage = 0;
  int _totalPages = 1;
  final String _jsChannelName = 'FlutterChannel';

  @override
  void initState() {
    super.initState();
    _initializeAndLoadEpub();
  }

  // Combined initialization and loading logic
  Future<void> _initializeAndLoadEpub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Get settings and theme for initial CSS
      final settings = Provider.of<ReaderSettingsProvider>(
        context,
        listen: false,
      );
      final appTheme =
          Provider.of<ThemeProvider>(context, listen: false).currentTheme;
      final css = _generateCss(settings, appTheme);

      // Start the server and get the initial URL and spine
      final startUrl = await epubServerService.start(
        widget.filePath,
        customCss: css,
      );
      _spineHrefs = epubServerService.spineHrefs;

      if (startUrl == null || _spineHrefs == null || _spineHrefs!.isEmpty) {
        throw Exception('Failed to load EPUB content or spine.');
      }

      // Extract base URL and starting href
      final uri = Uri.parse(startUrl);
      _baseUrl =
          '${uri.scheme}://${uri.authority}'; // e.g., http://localhost:8080
      final startHref =
          uri.path.startsWith('/')
              ? uri.path.substring(1)
              : uri.path; // Remove leading '/' if present

      // Find the index of the starting href
      _currentIndex = _spineHrefs!.indexOf(startHref);
      if (_currentIndex == -1) {
        // Fallback if startHref not in spine? Use the first item.
        _currentHref = _spineHrefs!.first;
        _currentIndex = 0;
        print(
          "Warning: Start Href '$startHref' not found in spine. Using first item '$_currentHref'.",
        );
      } else {
        _currentHref = startHref;
      }

      // Create and configure the WebView controller *after* server starts
      _createAndLoadWebViewController();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading EPUB: $e';
        });
        // Clean up server if initialization failed mid-way
        await epubServerService.stop();
      }
    }
  }

  // Create the correct controller and load the initial content
  void _createAndLoadWebViewController() {
    if (_currentHref == null || _baseUrl == null) return;
    final initialUrlToLoad = '$_baseUrl/$_currentHref';

    // --- JavaScript Channel / Message Setup ---
    // Define the message handling logic once
    void _handleJsMessage(String messageJsonString) {
      print("Message from WebView: $messageJsonString");
      try {
        final data = jsonDecode(messageJsonString);
        if (data['action'] == 'paginationInfo') {
          if (mounted) {
            setState(() {
              // Ensure types are integers
              _totalPages = (data['totalPages'] ?? 1).toInt();
              _currentPage = (data['currentPage'] ?? 0).toInt();
            });
          }
        }
        // Add other actions if needed
      } catch (e) {
        print("Error decoding JS message: $e");
      }
    }

    // Use webview_flutter controller setup directly
    final controller = WebViewController();
    _webViewController = controller;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Add JS channel
      ..addJavaScriptChannel(
        _jsChannelName,
        onMessageReceived: (message) {
          _handleJsMessage(message.message);
        },
      )
      // Set navigation delegate to run JS after page finishes
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            _runSetupPaginationJs();
          },
          onNavigationRequest: (NavigationRequest request) {
            // Prevent navigation for JS channel calls if needed (usually not necessary)
            // if (request.url.startsWith('js-bridge:')) return NavigationDecision.prevent;
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrlToLoad));
  }

  // --- JavaScript Functions ---

  String _getSetupPaginationJs() {
    // Injects and runs JS to calculate pagination using a wrapper div
    return '''
      function setupPagination() {
        try {
          // --- Create or get wrapper ---
          let wrapper = document.getElementById('pagination-wrapper');
          if (!wrapper) {
            console.log('Creating pagination wrapper...');
            wrapper = document.createElement('div');
            wrapper.id = 'pagination-wrapper';
            // Move all existing body children into the wrapper
            while (document.body.firstChild) {
              wrapper.appendChild(document.body.firstChild);
            }
            document.body.appendChild(wrapper);
          } else {
            console.log('Using existing pagination wrapper.');
          }

          const vw = window.innerWidth;
          if (!vw || !wrapper) return;

          // Ensure styles are applied (especially column-width)
          wrapper.style.height = '100%';
          wrapper.style.columnWidth = vw + 'px';

          // Allow time for column rendering
          setTimeout(() => {
            const totalWidth = wrapper.scrollWidth;
            // Calculate total pages carefully
            const totalPages = Math.max(1, Math.round(totalWidth / vw)); // Ensure at least 1 page
            const currentPage = Math.max(0, Math.round(wrapper.scrollLeft / vw)); // Ensure at least 0

            // Send info back to Flutter using standard webview_flutter mechanisms
            const messagePayload = JSON.stringify({ action: 'paginationInfo', totalPages: totalPages, currentPage: currentPage });
            // Use the channel name directly for Android/iOS
            if (window.$_jsChannelName && window.$_jsChannelName.postMessage) { // Android
              window.$_jsChannelName.postMessage(messagePayload);
            } else if (typeof webkit !== 'undefined' && webkit.messageHandlers && webkit.messageHandlers.$_jsChannelName) { // iOS/macOS
              webkit.messageHandlers.$_jsChannelName.postMessage(messagePayload);
            } else {
              console.error('Flutter JS communication channel not found.');
            }
            console.log('Pagination: ', currentPage + 1, '/', totalPages);
          }, 150); // Slightly longer delay maybe needed
        } catch (e) {
          console.error('Error in setupPagination:', e);
        }
      }
      // Ensure function exists before calling
      if (typeof setupPagination === 'function') {
         setupPagination(); // Run immediately
      }
    ''';
  }

  Future<void> _runSetupPaginationJs() async {
    if (_webViewController == null) return;
    try {
      final jsCode = _getSetupPaginationJs();
      await _webViewController!.runJavaScript(jsCode);
    } catch (e) {
      print("Error running setupPagination JS: $e");
    }
  }

  Future<void> _runGoToPageJs(int pageIndex) async {
    if (_webViewController == null) return;
    final jsCode = '''
      (() => {
        try {
          const wrapper = document.getElementById('pagination-wrapper');
          if (!wrapper) { console.error("Pagination wrapper not found!"); return; }

          console.log('[goToPage] Attempting page: ' + $pageIndex);
          const vw = window.innerWidth;
          console.log('[goToPage] Viewport Width (vw): ' + vw);
          const targetScrollX = $pageIndex * vw;
          console.log('[goToPage] Target ScrollX: ' + targetScrollX);
          console.log('[goToPage] Current wrapper scrollLeft before scroll: ' + wrapper.scrollLeft);
          // Try direct assignment instead of scrollTo method
          wrapper.scrollLeft = targetScrollX;
          console.log('[goToPage] Set wrapper.scrollLeft to: ' + targetScrollX);
          // Use requestAnimationFrame to check scroll position *after* browser potentially renders the scroll
          requestAnimationFrame(() => {
            console.log('[goToPage] Current wrapper scrollLeft after scroll: ' + wrapper.scrollLeft);
          });

          // Update Flutter with new page info immediately after scroll command
          // (This might be slightly inaccurate if scroll isn't instant, but good enough for UI)
          const totalWidth = wrapper.scrollWidth;
          const totalPages = Math.max(1, Math.round(totalWidth / vw));
          const messagePayload = JSON.stringify({ action: 'paginationInfo', totalPages: totalPages, currentPage: $pageIndex });
          // Use standard webview_flutter mechanisms
          if (window.$_jsChannelName && window.$_jsChannelName.postMessage) { // Android
            window.$_jsChannelName.postMessage(messagePayload);
          } else if (typeof webkit !== 'undefined' && webkit.messageHandlers && webkit.messageHandlers.$_jsChannelName) { // iOS/macOS
            webkit.messageHandlers.$_jsChannelName.postMessage(messagePayload);
          } else {
            console.error('Flutter JS communication channel not found.');
          }
        } catch (e) {
          console.error('Error in goToPage:', e);
        }
      })(); // Immediately invoke the function
    ''';
    try {
      await _webViewController!.runJavaScript(jsCode);
    } catch (e) {
      print("Error running goToPage JS: $e");
    }
  }

  // --- Navigation Logic ---

  // Public method to navigate to a specific href (relative path)
  Future<void> navigateToHref(
    String href, {
    bool isInitializing = false,
  }) async {
    if (_baseUrl == null || _webViewController == null || _spineHrefs == null)
      return;

    final targetIndex = _spineHrefs!.indexOf(href);
    if (targetIndex == -1) {
      print("Error: Href '$href' not found in spine.");
      return; // Href not found in spine
    }

    final url = '$_baseUrl/$href';
    print("Navigating to chapter: $url");

    // Reset pagination state before loading new chapter
    if (!isInitializing && mounted) {
      setState(() {
        _currentPage = 0;
        _totalPages = 1;
      });
    }

    try {
      // Use webview_flutter loadRequest
      await _webViewController!.loadRequest(Uri.parse(url));

      // Update state after successful load initiation
      if (mounted) {
        setState(() {
          _currentHref = href;
          _currentIndex = targetIndex;
          // Don't reset page numbers here, wait for onPageFinished
        });
      }
    } catch (e) {
      print("Error navigating to $href: $e");
      // Optionally show error to user
    }
  }

  // Renamed to be private
  Future<void> _nextChapter() async {
    if (_spineHrefs != null && _currentIndex < _spineHrefs!.length - 1) {
      await navigateToHref(_spineHrefs![_currentIndex + 1]);
    } else {
      print("Already on the last chapter.");
    }
  }

  // Renamed to be private
  Future<void> _previousChapter({bool goToLastPage = false}) async {
    if (_spineHrefs != null && _currentIndex > 0) {
      await navigateToHref(_spineHrefs![_currentIndex - 1]);
      // Navigation to last page will be handled by onPageFinished logic if goToLastPage is true
      // Currently not implemented due to complexity
    } else {
      print("Already on the first chapter.");
    }
  }

  // New page navigation methods
  Future<void> nextPage() async {
    if (_currentPage < _totalPages - 1) {
      // Go to next page within the chapter
      final nextPage = _currentPage + 1;
      await _runGoToPageJs(nextPage);
    } else {
      // Go to the first page of the next chapter
      print("End of chapter, moving to next chapter...");
      await _nextChapter();
    }
  }

  Future<void> previousPage() async {
    if (_currentPage > 0) {
      // Go to previous page within the chapter
      final prevPage = _currentPage - 1;
      await _runGoToPageJs(prevPage);
    } else {
      // Go to the first page of the previous chapter (simplified)
      print("Start of chapter, moving to previous chapter (start)...");
      await _previousChapter(); // Go to start of previous chapter
    }
  }

  // Re-add reloadWebView for webview_flutter
  Future<void> reloadWebView() async {
    if (_webViewController == null || _baseUrl == null || _currentHref == null)
      return;
    print("Reloading WebView with cache bust...");
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final urlToLoad = '$_baseUrl/$_currentHref?cb=$timestamp';
    try {
      await _webViewController!.loadRequest(Uri.parse(urlToLoad));
    } catch (e) {
      print("Error reloading WebView: $e");
    }
  }

  @override
  void dispose() {
    // No explicit dispose needed for webview_flutter controller typically
    epubServerService.stop(); // Stop the server
    super.dispose();
  }

  String _generateCss(ReaderSettingsProvider settings, AppTheme appTheme) {
    final bgColor =
        appTheme == AppTheme.dark
            ? '#121212'
            : appTheme == AppTheme.sepia
            ? '#f4ecd8'
            : '#ffffff';
    final textColor =
        appTheme == AppTheme.dark
            ? '#E0E0E0'
            : appTheme == AppTheme.sepia
            ? '#5b4636'
            : '#000000';

    // Added text-align: justify
    return '''
      html, body {
        margin: 0 !important;
        padding: 0 !important;
        height: 100% !important; /* Use 100% instead of vh for potentially better calculation */
        width: 100% !important;  /* Use 100% instead of vw */
        overflow: hidden !important; /* Prevent default scrollbars */
        box-sizing: border-box !important;
      }
      body {
        font-family: ${settings.fontFamily} !important;
        font-size: ${settings.fontSize}px !important;
        background-color: $bgColor !important;
        color: $textColor !important;
        margin: 0 !important; /* Remove body margin */
        padding: 1em !important; /* Add padding inside the body */
        word-wrap: break-word !important;
        line-height: 1.6 !important;
        /* Remove max-width and centering for pagination */
        text-align: justify !important;

        /* Pagination specific styles - column-width might be set by JS */
        height: 100% !important; /* Ensure body takes full height */
        /* width: 100%; Ensure body takes full width */ /* Width might not be needed if html sets it */
        overflow-x: scroll !important; /* Enable horizontal scrolling for columns */
        overflow-y: hidden !important; /* Disable vertical scrolling */
        column-width: 100%; /* Default, will be overridden by JS */
        column-gap: 0px !important; /* No space between pages */
        box-sizing: border-box !important;

        /* Prevent breaking elements across pages */
        break-inside: avoid;
        page-break-inside: avoid; /* Legacy */

        /* Enable smooth scrolling for JS scrollTo */
        scroll-behavior: smooth;
      }
      /* More specific rules to prevent breaks */
      p, div, img, figure, h1, h2, h3, h4, h5, h6, li, blockquote, pre {
        break-inside: avoid-page !important;
        page-break-inside: avoid !important; /* Legacy */
      }
      img {
        max-width: 100% !important;
        height: auto !important;
        display: block !important;
        margin-top: 0.5em !important;
        margin-bottom: 0.5em !important;
      }
      p {
         line-height: 1.6 !important;
         margin-top: 0 !important;
         margin-bottom: 1em !important;
      }
      h1, h2, h3, h4, h5, h6 {
         line-height: 1.3 !important;
         margin-top: 1.5em !important;
         margin-bottom: 0.5em !important;
         color: $textColor !important;
      }
      a {
        color: ${appTheme == AppTheme.dark ? '#4a9eff' : '#0066cc'} !important;
        text-decoration: none !important;
      }
      a:hover {
        text-decoration: underline !important;
      }
      ''';
  }

  // Build the appropriate WebView widget based on the platform
  Widget _buildPlatformWebView() {
    // Ensure controller is created before building the view
    if (_webViewController == null) {
      return const Center(child: Text("WebView Controller not initialized."));
    }

    // Use webview_flutter directly
    Widget webViewWidget = WebViewWidget(controller: _webViewController!);

    // Wrap the WebView in a GestureDetector for swipe navigation
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == 0) return; // No swipe
        // Set a threshold for swipe velocity
        const double minSwipeVelocity = 100.0;
        if (details.primaryVelocity!.abs() < minSwipeVelocity) return;

        if (details.primaryVelocity! < 0) {
          // Swiped Left (-> Next Page)
          nextPage();
        } else {
          // Swiped Right (<- Previous Page)
          previousPage();
        }
      },
      // Prevent vertical gestures from being captured by this detector
      // Allow vertical scrolling *if* we ever re-enable it in the webview
      dragStartBehavior: DragStartBehavior.down,
      child: webViewWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading EPUB...'),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _initializeAndLoadEpub, // Use the combined init/load method
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Success state - build the WebView
    return Stack(
      // Remove the outer Consumer2 as it's not driving rebuilds here
      children: [
        _buildPlatformWebView(), // Build the webview with gesture detector
        // Optional: Display Page Numbers
        Positioned(
          bottom: 5,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              // Ensure totalPages is at least 1 for display
              'Page ${_currentPage + 1} of ${_totalPages > 0 ? _totalPages : 1}',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.7),
                // Use a less opaque background
                backgroundColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withOpacity(0.6),
                fontSize: 12,
                // Add some padding for readability
                // Note: Text background doesn't support padding directly. Wrap in Container if needed.
              ),
            ),
          ),
        ),
        // Remove Floating Action Buttons if relying on gestures
      ],
    );
  }
}
