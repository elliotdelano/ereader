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
import 'package:ereader/services/storage_service.dart';

// Add a callback type for navigation methods if needed by parent
// typedef ChapterNavigationCallback = void Function(String href);

class CustomEpubViewer extends StatefulWidget {
  final String filePath;
  final String? initialCfi;
  // Add callbacks if ReaderScreen needs to trigger navigation
  // final ChapterNavigationCallback? onNextChapter;
  // final ChapterNavigationCallback? onPreviousChapter;

  const CustomEpubViewer({super.key, required this.filePath, this.initialCfi});

  @override
  State<CustomEpubViewer> createState() => CustomEpubViewerState();
}

class CustomEpubViewerState extends State<CustomEpubViewer> {
  final EpubServerService epubServerService = EpubServerService();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  String? _error;
  WebViewController? _webViewController;
  String? _baseUrl;
  String? _opfRelativePath; // Store the relative path to the OPF file
  String? _currentCfi; // Store the current CFI location
  double _bookPercentage = 0.0; // Store the overall book progress
  int _currentPage = 0; // Keep for UI display, might be updated by Epub.js
  int _totalPages = 1; // Keep for UI display, might be updated by Epub.js
  final String _jsChannelName = 'FlutterChannel';

  // Store previous settings to detect changes
  double? _previousFontSize;
  String? _previousFontFamily;
  AppTheme? _previousAppTheme;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadEpub();
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
        await epubServerService.stop();
      }
    }
  }

  void _createAndLoadWebViewController() {
    if (_baseUrl == null) return;
    final initialUrlToLoad = '$_baseUrl/viewer.html';

    void _handleJsMessage(String messageJsonString) {
      // print("Message from WebView: $messageJsonString"); // Keep commented unless debugging all messages
      try {
        final data = jsonDecode(messageJsonString);
        final String action = data['action'] ?? 'unknown';
        // print("Received action from JS: $action"); // Log action type

        if (action == 'locationUpdate') {
          if (mounted) {
            setState(() {
              _currentCfi = data['cfi'];
              // Ensure percentage is treated as double
              _bookPercentage = (data['percentage'] ?? 0.0).toDouble();
              _currentPage = data['displayedPage'] ?? 0;
              // _totalPages is set by paginationInfo
            });
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

    final controller = WebViewController();
    _webViewController = controller;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        _jsChannelName,
        onMessageReceived: (message) {
          _handleJsMessage(message.message);
        },
      )
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            if (url.endsWith('viewer.html')) {
              _initializeEpubJs();
            }
          },
          onWebResourceError: (WebResourceError error) {
            print(
              "Web resource error: ${error.description}, URL: ${error.url}",
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(_baseUrl!)) {
              return NavigationDecision.navigate;
            }
            print("Blocked navigation to: ${request.url}");
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrlToLoad));
  }

  Future<void> _initializeEpubJs() async {
    if (_webViewController == null || _opfRelativePath == null) {
      print(
        'Cannot initialize Epub.js: WebView controller or OPF path is null.',
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

    // Pass the channel object directly by its name
    // Pass the escaped initial CFI
    final jsCode = '''
       initializeEpubReader('$escapedOpfPath', $jsInitialCfiArg);
    ''';
    try {
      await _webViewController!.runJavaScript(jsCode);
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
    // This function now just contains the logic, called from build()
    if (!mounted || _webViewController == null || _isLoading)
      return; // ADD _isLoading CHECK

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final currentFontSize = settingsProvider.fontSize;
    final currentFontFamily = settingsProvider.fontFamily;
    final currentTheme = themeProvider.currentTheme;

    bool changed = false;
    if (_previousFontSize == null ||
        _previousFontFamily == null ||
        _previousAppTheme == null) {
      changed = true;
    } else {
      if (_previousFontSize != currentFontSize) changed = true;
      if (_previousFontFamily != currentFontFamily) changed = true;
      if (_previousAppTheme != currentTheme) changed = true;
    }

    if (changed) {
      print("(Build) Settings changed, applying to WebView...");
      _applyThemeAndFontFamilyToWebView();
      _applyFontSizeToWebView();

      // Store current settings for next check
      _previousFontSize = currentFontSize;
      _previousFontFamily = currentFontFamily;
      _previousAppTheme = currentTheme;
    }
  }

  Future<void> _applyThemeAndFontFamilyToWebView() async {
    if (_webViewController == null) return;

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final currentTheme = themeProvider.currentTheme;
    final currentFontFamily = settingsProvider.fontFamily;

    // 1. Build the base theme styles
    Map<String, dynamic> styles = _getThemeBaseStyles(currentTheme);

    // 2. Add font *family* to the body style within the rules
    if (styles['body'] is! Map) {
      styles['body'] = <String, dynamic>{};
    }
    Map<String, dynamic> bodyStyles = styles['body'] as Map<String, dynamic>;
    bodyStyles['font-family'] = "'$currentFontFamily'";

    // 3. Encode and call the applyStyles JavaScript function (which uses register+select)
    final stylesJson = jsonEncode(styles);
    try {
      await _webViewController!.runJavaScript('applyStyles($stylesJson);');
      print(
        "Applied base styles: Theme=${currentTheme.name}, Family=$currentFontFamily",
      );
    } catch (e) {
      print("Error applying base styles/family: $e");
    }
  }

  Future<void> _applyFontSizeToWebView() async {
    if (_webViewController == null) return;

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final currentFontSize = settingsProvider.fontSize;

    try {
      // Call the dedicated JS function for font size
      await _webViewController!.runJavaScript(
        'changeFontSize($currentFontSize);',
      );
      print("Applied font size: $currentFontSize");
    } catch (e) {
      print("Error applying font size: $e");
    }
  }

  Map<String, dynamic> _getThemeBaseStyles(AppTheme theme) {
    // Define common rules if any (e.g., link styling independent of theme)
    Map<String, dynamic> commonRules = {
      'a': {'text-decoration': 'none'},
      'a:hover': {'text-decoration': 'underline'},
      'p': {'line-height': '1.5', 'margin-bottom': '0.8em'},
    };

    switch (theme) {
      case AppTheme.dark:
        return {
          'body': {'background-color': '#121212', 'color': '#E0E0E0'},
          'a': {'color': '#BB86FC', ...commonRules['a']},
          'p': commonRules['p'],
          // Add other dark-specific overrides here if needed
        };
      case AppTheme.sepia:
        return {
          'body': {'background-color': '#FBF0D9', 'color': '#5B4636'},
          'a': {'color': '#704214', ...commonRules['a']},
          'p': commonRules['p'],
        };
      case AppTheme.light:
      default:
        return {
          'body': {'background-color': '#FFFFFF', 'color': '#000000'},
          'a': {'color': '#0000EE', ...commonRules['a']},
          'p': commonRules['p'],
        };
    }
  }

  Future<void> nextPage() async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.runJavaScript('window.nextPage();');
    } catch (e) {
      print("Error navigating to next page: $e");
    }
  }

  Future<void> previousPage() async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.runJavaScript('window.previousPage();');
    } catch (e) {
      print("Error navigating to previous page: $e");
    }
  }

  @override
  void dispose() {
    print("CustomEpubViewer disposing, stopping server...");
    epubServerService.stop();

    // Save current reading progress
    if (_currentCfi != null && _currentCfi!.isNotEmpty) {
      print("Saving progress: CFI=$_currentCfi for path=${widget.filePath}");
      // Use _storageService instance
      _storageService.saveReadingProgress(
        widget.filePath,
        _currentCfi!,
        _bookPercentage,
      );
    } else {
      print("No valid CFI to save for ${widget.filePath}");
    }

    super.dispose();
  }

  Widget _buildPlatformWebView() {
    if (_webViewController == null) {
      return const Center(child: Text("WebView Controller not initialized."));
    }

    Widget webViewWidget = WebViewWidget(controller: _webViewController!);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == 0) return;
        const double minSwipeVelocity = 100.0;
        if (details.primaryVelocity!.abs() < minSwipeVelocity) return;

        if (details.primaryVelocity! < 0) {
          nextPage();
        } else {
          previousPage();
        }
      },
      dragStartBehavior: DragStartBehavior.down,
      child: webViewWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // WATCH providers here to trigger rebuilds when settings change
    context.watch<ReaderSettingsProvider>();
    context.watch<ThemeProvider>();

    // Call the update check on every build AFTER watching providers
    // Use a post-frame callback to ensure it runs after the build completes
    // and webviewcontroller is likely available if not loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check mount status again inside the callback
      if (mounted && _webViewController != null && !_isLoading) {
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

    final themeProviderRead =
        context
            .read<
              ThemeProvider
            >(); // Use read here if only needed for color value
    final bool isDark = themeProviderRead.currentTheme == AppTheme.dark;
    final Color textColor = isDark ? Colors.white70 : Colors.black54;
    final Color backgroundColor =
        isDark ? Colors.black.withAlpha(100) : Colors.white.withAlpha(150);

    return Stack(
      children: [
        _buildPlatformWebView(),
        Positioned(
          bottom: 5,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(_bookPercentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Fetches the Table of Contents as a JSON string from the underlying EPUB.
  /// Returns null if the ToC cannot be fetched.
  Future<String?> getTocJson() async {
    if (_webViewController == null || _isLoading) {
      print("getTocJson: WebView not ready or still loading.");
      return null;
    }
    try {
      final result = await _webViewController!.runJavaScriptReturningResult(
        'getToc();',
      );
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
    if (_webViewController == null || _isLoading) {
      print("navigateToHref: WebView not ready or still loading.");
      return;
    }
    // Escape href for JS string literal
    final escapedHref = href.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final jsCode = "navigateToHref('$escapedHref');";
    try {
      await _webViewController!.runJavaScript(jsCode);
      print("Called navigateToHref('$href')");
    } catch (e) {
      print("Error calling navigateToHref in JS: $e");
    }
  }
}
