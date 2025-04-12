import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:ereader/providers/reader_settings_provider.dart';
import 'package:ereader/providers/theme_provider.dart';
import 'package:ereader/services/epub_server_service.dart';
import 'dart:convert';
import 'package:ereader/services/storage_service.dart';

import 'webview/platform_webview_interface.dart';
import 'webview/mobile_webview_adapter.dart';
import 'webview/desktop_webview_adapter.dart';

// Add a callback type for navigation methods if needed by parent
// typedef ChapterNavigationCallback = void Function(String href);

typedef EpubLocationChangedCallback =
    void Function(double percentage, String? cfi);

class CustomEpubViewer extends StatefulWidget {
  final String filePath;
  final String? initialCfi;
  final EpubLocationChangedCallback? onLocationChanged; // NEW: Callback

  // Add callbacks if ReaderScreen needs to trigger navigation
  // final ChapterNavigationCallback? onNextChapter;
  // final ChapterNavigationCallback? onPreviousChapter;

  const CustomEpubViewer({
    super.key,
    required this.filePath,
    this.initialCfi,
    this.onLocationChanged, // NEW: Add to constructor
  });

  @override
  State<CustomEpubViewer> createState() => CustomEpubViewerState();
}

class CustomEpubViewerState extends State<CustomEpubViewer>
    with WidgetsBindingObserver {
  final EpubServerService epubServerService = EpubServerService();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  String? _error;

  // --- UPDATED: Use Interface for Controller ---
  PlatformWebViewInterface? _platformWebViewController;
  bool get _isDesktop => Platform.isWindows || Platform.isLinux;
  // --- End UPDATED ---

  String? _baseUrl;
  String? _opfRelativePath; // Store the relative path to the OPF file
  String? _currentCfi; // Store the current CFI location
  double _bookPercentage = 0.0; // Store the overall book progress
  int _currentPage = 0; // Keep for UI display, might be updated by Epub.js
  int _totalPages = 1; // Keep for UI display, might be updated by Epub.js
  final String _jsChannelName = 'FlutterChannel';
  Timer? _saveProgressTimer; // ADDED: Timer for periodic saves

  // --- NEW: Resize Handling State ---
  Size? _previousSize;
  Timer? _resizeDebounceTimer;
  final Duration _resizeDebounceDuration = const Duration(milliseconds: 500);
  // --- END NEW ---

  // Store previous settings to detect changes
  double? _previousFontSize;
  String? _previousFontFamily;
  String? _previousSelectedThemeId; // Added to track theme ID changes
  EpubFlow? _previousEpubFlow;
  EpubSpread? _previousEpubSpread;
  // --- NEW: Previous Line Spacing / Margin State ---
  double? _previousLineSpacing;
  MarginSize? _previousMarginSize;
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    _initializeAndLoadEpub();
    // --- NEW: Register observer and start timer ---
    WidgetsBinding.instance.addObserver(this);
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveCurrentProgress();
    });
    // --- End NEW ---
  }

  // Use didChangeDependencies to get initial provider values and listen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Call initial settings application AFTER the JS is initialized
    // _updateSettingsIfNeeded(); // REMOVE: Moved to build method after watch
  }

  Future<void> _initializeAndLoadEpub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Start the server and get the base URL and content base path
      final serverResponse = await epubServerService.start(widget.filePath);

      if (serverResponse == null) {
        throw Exception('Failed to start EPUB server.');
      }

      _baseUrl = serverResponse['baseUrl'];
      _opfRelativePath = serverResponse['opfRelativePath'];

      if (_baseUrl == null || _opfRelativePath == null) {
        throw Exception('Failed to get base URL or OPF path from server.');
      }

      // Create and configure the WebView controller
      await _createAndLoadPlatformWebView();

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
        await epubServerService.stop();
      }
    }
  }

  Future<void> _createAndLoadPlatformWebView() async {
    if (_baseUrl == null) return;
    final initialUrlToLoad = '$_baseUrl/viewer.html';

    // 1. Instantiate the correct adapter
    if (_isDesktop) {
      print("Creating DesktopWebViewAdapter...");
      _platformWebViewController = DesktopWebViewAdapter();
    } else {
      print("Creating MobileWebViewAdapter...");
      _platformWebViewController = MobileWebViewAdapter();
    }

    // 2. Set up callbacks on the adapter
    _platformWebViewController?.onPageFinished = (String url) {
      print('Platform Page finished loading: $url');
      if (url.endsWith('viewer.html')) {
        _initializeEpubJs(); // Initialize JS after the viewer page loads
      }
    };

    _platformWebViewController?.onLoadEnd = (String url) {
      print('Platform LoadEnd: $url');
      // Potentially redundant if onPageFinished covers it, but good for specific platform logic
      if (url.endsWith('viewer.html') &&
          !_platformWebViewController!.isInitialized) {
        // Some platforms might signal readiness here instead of onPageFinished
        print("LoadEnd triggered, attempting JS init...");
        _initializeEpubJs();
      }
    };

    _platformWebViewController?.onWebResourceError = (Object error) {
      // Handle common error format if possible, otherwise just log
      print("Platform Web resource error: $error");
      // Maybe set an error state for the UI
      if (mounted) {
        setState(() => _error = "WebView Resource Error: $error");
      }
    };

    _platformWebViewController?.onLoadError = (url, errorCode, errorMsg) {
      print("Platform Load error: URL=$url, Code=$errorCode, Msg=$errorMsg");
      if (mounted) {
        setState(() => _error = "WebView Load Error ($errorCode): $errorMsg");
      }
    };

    _platformWebViewController?.onWebViewCreated = () {
      print("Platform WebView Created Callback Fired.");
      // For CEF, this might be a good place to initially load the URL
      // but we'll stick to calling loadUrl after initialize for consistency.
    };

    try {
      // 3. Initialize the adapter
      print("Initializing platform WebView adapter...");
      await _platformWebViewController?.initialize();
      print("Platform WebView adapter initialized.");

      // 4. Set background color (might be no-op on desktop)
      await _platformWebViewController?.setBackgroundColor(Colors.transparent);

      // 5. Add JS Channel
      print(
        "[CustomEpubViewer] Attempting to add JavaScript channel '$_jsChannelName'...",
      );
      await _platformWebViewController?.addJavaScriptChannel(
        _jsChannelName,
        onMessageReceived: (message) {
          _handleJsMessage(message);
        },
      );
      print("JavaScript channel added.");

      // 6. Load the initial URL
      print("Loading initial URL: $initialUrlToLoad");
      await _platformWebViewController?.loadUrl(initialUrlToLoad);
      print("Initial URL load request sent.");
    } catch (e) {
      print("Error during platform WebView setup: $e");
      if (mounted) {
        setState(() {
          _error = "Error setting up WebView: $e";
        });
      }
    }
  }

  void _handleJsMessage(String messageJsonString) {
    // --- ADDED LOGGING ---
    // print(
    //   "[JS -> Dart] Received object type: ${messageJsonString.runtimeType}",
    // );
    // --- END ADDED LOGGING ---
    // print("[JS -> Dart] Raw message: $messageJsonString");
    // --- END ADDED LOGGING ---
    try {
      // --- MODIFIED: Handle potential double-escaping from CEF ---
      dynamic jsonData;
      if (messageJsonString.startsWith('"') &&
          messageJsonString.endsWith('"')) {
        // Likely double-escaped (CEF)
        // print("[JS -> Dart] Detected double-escaped string, decoding twice...");
        try {
          String singleEscapedJson = jsonDecode(messageJsonString);
          jsonData = jsonDecode(singleEscapedJson);
        } catch (e) {
          print(
            "Error during double decode: $e. Raw string: $messageJsonString",
          );
          return; // Exit if double decode fails
        }
      } else {
        // Likely single-escaped (Mobile or standard)
        // print("[JS -> Dart] Assuming standard JSON string, decoding once...");
        jsonData = jsonDecode(messageJsonString);
      }

      // Ensure jsonData is a Map before proceeding
      if (jsonData is! Map<String, dynamic>) {
        print(
          "Error: Decoded JSON is not a Map. Type: ${jsonData.runtimeType}",
        );
        return;
      }
      final Map<String, dynamic> data = jsonData;
      // --- END MODIFIED ---

      final String action = data['action'] ?? 'unknown';
      // print("Received action from JS: $action"); // Log action type

      if (action == 'locationUpdate') {
        final receivedCfi = data['cfi'];
        // print("[JS -> Dart] Received locationUpdate: CFI = $receivedCfi");
        if (mounted) {
          setState(() {
            _currentCfi = receivedCfi;
            // Ensure percentage is treated as double
            final newPercentage = (data['percentage'] ?? 0.0).toDouble();
            _bookPercentage = newPercentage;
            _currentPage = data['displayedPage'] ?? 0;
            // _totalPages is set by paginationInfo
          });
          // --- NEW: Trigger Callback ---
          widget.onLocationChanged?.call(_bookPercentage, _currentCfi);
          // --- End NEW ---
        }
      } else if (action == 'paginationInfo') {
        if (mounted) {
          setState(() {
            // Ensure total pages is treated as int
            _totalPages = (data['totalPagesInBook'] ?? 1).toInt();
          });
        }
      } else if (action == 'error') {
        print("Error from Epub.js: ${data['message']}");
      }
    } catch (e) {
      print("Error decoding JS message: $e");
    }
  }

  Future<void> _initializeEpubJs() async {
    // Use the interface, check for null
    if (_platformWebViewController == null ||
        !_platformWebViewController!.isInitialized ||
        _opfRelativePath == null) {
      print(
        'Cannot initialize Epub.js: WebView controller not ready or OPF path is null.',
      );
      return;
    }
    // Ensure the path is properly escaped for JavaScript
    final escapedOpfPath = _opfRelativePath!
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'");

    // Escape the initial CFI for JS string, handle null
    String jsInitialCfiArg;
    if (widget.initialCfi == null || widget.initialCfi!.isEmpty) {
      jsInitialCfiArg = 'null';
    } else {
      // Basic escaping for JS string literal (ensure quotes are handled)
      final escapedCfi = widget.initialCfi!
          .replaceAll('\\', '\\\\') // Escape backslashes
          .replaceAll("'", "\\'"); // Escape single quotes
      jsInitialCfiArg = "'$escapedCfi'"; // Wrap in single quotes
    }

    // --- MODIFIED: Get Flow/Spread Settings ---
    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final epubFlowSetting = settingsProvider.epubFlow;
    final epubSpreadSetting = settingsProvider.epubSpread;

    // Convert enums to JS strings
    final jsFlow =
        epubFlowSetting == EpubFlow.scrolled ? "scrolled-doc" : "paginated";
    final jsSpread = epubSpreadSetting == EpubSpread.auto ? "auto" : "none";
    // --- END MODIFIED ---

    // Calculate adjusted width (multiple of 12 physical pixels) - REVERTING TO ROUND LOGICAL WIDTH
    // Use context safely, ensure it's available
    if (!mounted) return; // Check if widget is still mounted
    final queryData = MediaQuery.of(context);
    final screenWidthLogical = queryData.size.width;
    final screenHeightLogical =
        queryData.size.height -
        queryData.padding.top -
        queryData.padding.bottom; // Usable height

    // Calculate nearest multiple of 12 for the LOGICAL width
    final roundedLogicalWidth = (screenWidthLogical / 12).round() * 12;
    // Pass the channel object directly by its name
    // Pass the escaped initial CFI
    // Pass the ROUNDED LOGICAL width and calculated height
    // --- MODIFIED: Pass flow and spread strings to JS ---
    final jsCode = '''
       initializeEpubReader(
         '$escapedOpfPath',
         $jsInitialCfiArg,
         $roundedLogicalWidth,
         $screenHeightLogical,
         '$jsFlow', // Pass flow
         '$jsSpread' // Pass spread
       );
    ''';
    // --- END MODIFIED ---
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript(jsCode);
      print('Epub.js initialization called with OPF path: $_opfRelativePath');
      // Apply initial settings right after JS initialization completes
      await _applyThemeAndFontFamilyToWebView();
      await _applyFontSizeToWebView();
    } catch (e) {
      print(
        "Error calling initializeEpubReader or applying initial styles/size in JS: $e",
      );
    }
  }

  void _updateSettingsIfNeeded() {
    // Use the interface, check for null and initialized status
    if (!mounted ||
        _platformWebViewController == null ||
        !_platformWebViewController!.isInitialized ||
        _isLoading)
      return;

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final currentFontSize = settingsProvider.fontSize;
    final currentFontFamily = settingsProvider.fontFamily;
    final currentSelectedThemeId =
        themeProvider.selectedThemeId; // Get current theme ID
    final currentEpubFlow = settingsProvider.epubFlow;
    final currentEpubSpread = settingsProvider.epubSpread;
    // --- NEW: Get current spacing/margins ---
    final currentLineSpacing = settingsProvider.lineSpacing;
    final currentMarginSize = settingsProvider.marginSize;
    // --- END NEW ---

    bool changed = false;
    bool flowOrSpreadChanged = false; // Flag for flow/spread changes
    // --- NEW: Flags for other reload-triggering settings ---
    bool lineSpacingChanged = false;
    bool marginSizeChanged = false;
    // --- END NEW ---

    // Check if it's the first run (any previous value is null)
    if (_previousFontSize == null ||
        _previousFontFamily == null ||
        _previousSelectedThemeId == null || // Check previous theme ID
        _previousEpubFlow == null ||
        _previousEpubSpread == null ||
        // --- NEW: Check previous spacing/margins ---
        _previousLineSpacing == null ||
        _previousMarginSize == null
    // --- END NEW ---
    ) {
      changed = true; // Treat first run as changed
    } else {
      // Compare current values with previous ones
      if (_previousFontSize != currentFontSize) changed = true;
      if (_previousFontFamily != currentFontFamily) changed = true;
      if (_previousSelectedThemeId != currentSelectedThemeId) {
        changed = true; // Check theme ID change
      }
      if (_previousEpubFlow != currentEpubFlow) {
        changed = true;
        flowOrSpreadChanged = true;
      }
      if (_previousEpubSpread != currentEpubSpread) {
        changed = true;
        flowOrSpreadChanged = true;
      }
      // --- NEW: Check spacing/margin changes ---
      if (_previousLineSpacing != currentLineSpacing) {
        changed = true;
        lineSpacingChanged = true;
      }
      if (_previousMarginSize != currentMarginSize) {
        changed = true;
        marginSizeChanged = true;
      }
      // --- END NEW ---
    }

    if (changed) {
      // --- MODIFIED: Trigger reload if flow, spread, spacing, OR margins changed ---
      if (flowOrSpreadChanged || lineSpacingChanged || marginSizeChanged) {
        print(
          "(Build) Flow, Spread, Line Spacing, or Margin changed, re-initializing EPUB...",
        );
        // Store ALL new settings BEFORE reloading
        _previousFontSize = currentFontSize;
        _previousFontFamily = currentFontFamily;
        _previousSelectedThemeId = currentSelectedThemeId; // Store theme ID
        _previousEpubFlow = currentEpubFlow;
        _previousEpubSpread = currentEpubSpread;
        _previousLineSpacing = currentLineSpacing;
        _previousMarginSize = currentMarginSize;

        _initializeAndLoadEpub(); // Trigger full reload
        return; // Exit early, reload will handle applying styles
      }
      // --- END MODIFIED ---

      // If only theme, font size, or font family changed, apply dynamically
      print("(Build) Settings changed (Theme/Font), applying dynamically...");
      _applyThemeAndFontFamilyToWebView(); // Applies margins/line height too
      _applyFontSizeToWebView();

      // Store ALL current settings for next check
      _previousFontSize = currentFontSize;
      _previousFontFamily = currentFontFamily;
      _previousSelectedThemeId = currentSelectedThemeId; // Store theme ID
      _previousEpubFlow = currentEpubFlow;
      _previousEpubSpread = currentEpubSpread;
      // --- NEW: Store current spacing/margins ---
      _previousLineSpacing = currentLineSpacing;
      _previousMarginSize = currentMarginSize;
      // --- END NEW ---
    }
  }

  Future<void> _applyThemeAndFontFamilyToWebView() async {
    // Use the interface, check for null
    if (_platformWebViewController == null) return;

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    // Removed themeProvider fetch here, done in _getThemeBaseStyles

    // Removed final currentTheme = themeProvider.currentTheme;
    final currentFontFamily = settingsProvider.fontFamily;
    // --- NEW: Get Line Spacing & Margins --- (Still needed here for passing)
    final currentLineSpacing = settingsProvider.lineSpacing;
    final currentMarginSize = settingsProvider.marginSize;
    // --- END NEW ---

    // 1. Build the base theme styles (pass necessary non-theme settings)
    Map<String, dynamic> styles = _getThemeBaseStyles(
      currentLineSpacing,
      currentMarginSize,
    );

    // 2. Add font *family* to the body style within the rules
    if (styles['body'] is! Map) {
      styles['body'] = <String, dynamic>{};
    }
    Map<String, dynamic> bodyStyles = styles['body'] as Map<String, dynamic>;
    bodyStyles['font-family'] = "'$currentFontFamily'";

    // 3. Encode and call the applyStyles JavaScript function (which uses register+select)
    final stylesJson = jsonEncode(styles);
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript(
        'applyStyles($stylesJson);',
      );
      print(
        "Applied base styles: Family=$currentFontFamily (Theme applied based on ThemeProvider)",
      );
    } catch (e) {
      print("Error applying base styles/family: $e");
    }
  }

  Future<void> _applyFontSizeToWebView() async {
    // Use the interface, check for null
    if (_platformWebViewController == null) return;

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final currentFontSize = settingsProvider.fontSize;

    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript(
        'changeFontSize($currentFontSize);',
      );
      print("Applied font size: $currentFontSize");
    } catch (e) {
      print("Error applying font size: $e");
    }
  }

  Map<String, dynamic> _getThemeBaseStyles(
    double lineSpacing,
    MarginSize marginSize,
  ) {
    // Get the current theme data directly
    final themeData =
        Provider.of<ThemeProvider>(context, listen: false).themeData;
    final colorScheme = themeData.colorScheme;

    // Define common rules using theme colors where appropriate
    Map<String, dynamic> commonRules = {
      'a': {
        'color': _colorToCss(
          colorScheme.primary,
        ), // Use primary color for links
        'text-decoration': 'none',
      },
      'a:hover': {'text-decoration': 'underline'},
      'p': {'line-height': lineSpacing.toString(), 'margin-bottom': '0.8em'},
      // Add more common rules if needed
    };

    // --- NEW: Determine Padding based on MarginSize ---
    String paddingValue;
    switch (marginSize) {
      case MarginSize.none:
        paddingValue = '0';
        break;
      case MarginSize.small:
        paddingValue = '2%'; // Example value
        break;
      case MarginSize.large:
        paddingValue = '8%'; // Example value
        break;
      default:
        paddingValue = '5%'; // Default to medium
    }
    // --- END NEW ---

    // Define theme-specific overrides based on ThemeData
    Map<String, dynamic> bodyStyles = {
      'background-color': _colorToCss(themeData.scaffoldBackgroundColor),
      'color': _colorToCss(
        colorScheme.onSurface,
      ), // Use onSurface for main text
      'padding': paddingValue,
    };

    // Combine common rules and body styles
    // Specific rules in commonRules will override general body styles if keys match (like 'a')
    return {'body': bodyStyles, ...commonRules};
  }

  // Helper function to convert Flutter Color to CSS hex string
  String _colorToCss(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }

  Future<void> nextPage() async {
    // Use the interface, check for null
    if (_platformWebViewController == null) return;
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript('window.nextPage();');
    } catch (e) {
      print("Error navigating to next page: $e");
    }
  }

  Future<void> previousPage() async {
    // Use the interface, check for null
    if (_platformWebViewController == null) return;
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript('window.previousPage();');
    } catch (e) {
      print("Error navigating to previous page: $e");
    }
  }

  @override
  void dispose() {
    print("CustomEpubViewer disposing, stopping server...");
    epubServerService.stop();

    // --- NEW: Unregister observer, cancel timer, and save final progress ---
    WidgetsBinding.instance.removeObserver(this);
    _saveProgressTimer?.cancel();
    _resizeDebounceTimer?.cancel(); // ADDED: Cancel resize timer
    _saveCurrentProgress(isClosing: true); // Ensure final save on dispose
    // --- End NEW ---

    // --- UPDATED: Dispose via interface ---
    print("Disposing platform WebView controller...");
    _platformWebViewController?.dispose();
    _platformWebViewController = null;
    // --- End UPDATED ---

    print("CustomEpubViewer disposed.");

    super.dispose();
  }

  // --- NEW: Lifecycle Handling ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      print("App lifecycle state changed to $state, saving progress...");
      _saveCurrentProgress(); // Save progress when app is paused or detached
    }
  }
  // --- End Lifecycle Handling ---

  Widget _buildPlatformWebView() {
    if (_platformWebViewController == null) {
      // This might happen briefly before initialization or if creation failed
      return const Center(child: Text("WebView Controller not available."));
    }
    // Use the buildView method from the interface
    return _platformWebViewController!.buildView();
  }

  @override
  Widget build(BuildContext context) {
    // WATCH providers here to trigger rebuilds when settings change
    context.watch<ReaderSettingsProvider>();
    context.watch<ThemeProvider>();

    // --- NEW: Resize Detection (only for desktop) ---
    if (_isDesktop) {
      final Size currentSize = MediaQuery.sizeOf(context);
      if (_previousSize != null && currentSize != _previousSize) {
        _handleResizeDebounced(currentSize);
      }
      _previousSize = currentSize; // Store current size for next build
    }
    // --- END NEW ---

    // Call the update check on every build AFTER watching providers
    // Use a post-frame callback to ensure it runs after the build completes
    // and webviewcontroller is likely available if not loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check mount status again inside the callback
      if (mounted && _platformWebViewController != null && !_isLoading) {
        _updateSettingsIfNeeded();
      }
    });

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

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text("Error", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeAndLoadEpub,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(children: [_buildPlatformWebView()]);
  }

  // --- NEW: Debounced Resize Handler ---
  void _handleResizeDebounced(Size newSize) {
    if (_resizeDebounceTimer?.isActive ?? false) {
      _resizeDebounceTimer!.cancel();
    }
    _resizeDebounceTimer = Timer(_resizeDebounceDuration, () {
      _callJsResize(newSize);
    });
  }

  // --- NEW: Function to call JS resize ---
  Future<void> _callJsResize(Size newSize) async {
    // Don't resize if controller isn't ready, not on desktop, or still loading initial epub
    if (_platformWebViewController == null ||
        !_isDesktop ||
        _isLoading ||
        !_platformWebViewController!.isInitialized)
      return;

    // Get padding info, ensuring context is still valid
    if (!mounted) return;
    final queryData = MediaQuery.of(context);
    final screenWidthLogical = newSize.width;
    final screenHeightLogical =
        newSize.height -
        queryData.padding.top -
        queryData.padding.bottom; // Usable height

    // Calculate nearest multiple of 12 for the LOGICAL width
    final roundedLogicalWidth = (screenWidthLogical / 12).round() * 12;

    // Ensure non-zero dimensions before sending
    if (roundedLogicalWidth <= 0 || screenHeightLogical <= 0) {
      print(
        "[Resize] Calculated zero or negative dimension, skipping JS call.",
      );
      return;
    }

    final jsCode = 'handleResize($roundedLogicalWidth, $screenHeightLogical);';
    print("[Resize] Calling JS: $jsCode");
    try {
      await _platformWebViewController!.runJavaScript(jsCode);
    } catch (e) {
      print("[Resize] Error calling handleResize in JS: $e");
    }
  }
  // --- END NEW ---

  /// Fetches the Table of Contents as a JSON string from the underlying EPUB.
  /// Returns null if the ToC cannot be fetched.
  Future<String?> getTocJson() async {
    // Use the interface, check for null and initialized status
    if (_platformWebViewController == null ||
        !_platformWebViewController!.isInitialized ||
        _isLoading) {
      print("getTocJson: WebView not ready or still loading.");
      return null;
    }
    try {
      // Use interface method
      final result = await _platformWebViewController!
          .runJavaScriptReturningResult('getToc();');
      // result might be wrapped in quotes, check and handle
      if (result is String && result.isNotEmpty) {
        // Basic check if it looks like JSON (starts/ends with [] or {})
        if ((result.startsWith('[') && result.endsWith(']')) ||
            (result.startsWith('{') && result.endsWith('}'))) {
          return result;
        } else {
          // Attempt to decode if it seems like a quoted string containing JSON
          try {
            return jsonDecode(result)
                as String; // If JS returns a string that *is* JSON
          } catch (_) {
            // If decoding fails, return the raw string if it seems plausible, otherwise null
            return result; // Or consider returning null if it's definitely not JSON
          }
        }
      } else if (result != null) {
        print(
          "getTocJson: Received non-string or empty result: ${result.runtimeType}",
        );
        return result.toString(); // Or null? Handle unexpected types
      }
      return null;
    } catch (e) {
      print("Error calling getToc() in JS: $e");
      return null;
    }
  }

  /// Navigates the EPUB view to the specified href.
  Future<void> navigateToHref(String href) async {
    // Use the interface, check for null
    if (_platformWebViewController == null) {
      print("navigateToHref: WebView not ready or still loading.");
      return;
    }
    // Escape href for JS string literal
    final escapedHref = href.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final jsCode = "navigateToHref('$escapedHref');";
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript(jsCode);
      print("Called navigateToHref('$href')");
    } catch (e) {
      print("Error calling navigateToHref in JS: $e");
    }
  }

  // --- NEW: Navigation Methods ---
  /// Navigates the EPUB view to the specified percentage.
  Future<void> navigateToPercentage(double percentage) async {
    // Use the interface, check for null
    if (_platformWebViewController == null) {
      print("navigateToPercentage: WebView not ready or still loading.");
      return;
    }
    // Ensure percentage is within valid range
    final clampedPercentage = percentage.clamp(0.0, 1.0);
    final jsCode = "navigateToPercentage($clampedPercentage);";
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript(jsCode);
      print("Called navigateToPercentage($clampedPercentage)");
    } catch (e) {
      print("Error calling navigateToPercentage in JS: $e");
    }
  }

  /// Navigates the EPUB view to the specified CFI.
  Future<void> navigateToCfi(String cfi) async {
    // Use the interface, check for null
    if (_platformWebViewController == null) {
      print("navigateToCfi: WebView not ready or still loading.");
      return;
    }
    // Escape CFI for JS string literal
    final escapedCfi = cfi.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final jsCode = "navigateToCfi('$escapedCfi');";
    try {
      // Use interface method
      await _platformWebViewController!.runJavaScript(jsCode);
      print("Called navigateToCfi('$cfi')");
    } catch (e) {
      print("Error calling navigateToCfi in JS: $e");
    }
  }
  // --- End Navigation Methods ---

  // --- NEW: Progress Saving Logic ---
  Future<void> _saveCurrentProgress({bool isClosing = false}) async {
    final logPrefix = isClosing ? "(Dispose)" : "(Auto-save)";
    if (_currentCfi != null && _currentCfi!.isNotEmpty) {
      // print(
      //   "$logPrefix Saving progress: Attempting with CFI='$_currentCfi', Percentage=${_bookPercentage.toStringAsFixed(4)} for path=${widget.filePath}",
      // );
      try {
        await _storageService.saveReadingProgress(
          widget.filePath,
          _currentCfi!, // Assert non-null as checked above
          _bookPercentage,
        );
      } catch (e) {
        print("$logPrefix Error saving progress: $e");
      }
    } else {
      print(
        "$logPrefix Skipping save: No valid CFI available (_currentCfi = '$_currentCfi').",
      );
    }
  }

  // --- End Progress Saving Logic ---
}
