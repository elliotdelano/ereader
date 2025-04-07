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
      print("Message from WebView: $messageJsonString");
      try {
        final data = jsonDecode(messageJsonString);
        if (data['action'] == 'locationUpdate') {
          if (mounted) {
            setState(() {
              _currentCfi = data['cfi'];
              _bookPercentage = data['percentage'] ?? 0.0;
              _currentPage = data['displayedPage'] ?? 0;
              _totalPages = data['totalPagesInChapter'] ?? 1;
            });
          }
        } else if (data['action'] == 'paginationInfo') {
          if (mounted) {
            setState(() {
              _totalPages = (data['totalPagesInBook'] ?? 1).toInt();
            });
          }
        } else if (data['action'] == 'error') {
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
    final jsCode = '''
      initializeEpubReader('$escapedOpfPath', window.$_jsChannelName);
    ''';
    try {
      await _webViewController!.runJavaScript(jsCode);
      print('Epub.js initialization called with OPF path: $_opfRelativePath');
      // Apply initial settings after JS is initialized
      if (mounted && !_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Check mount again in callback
            setState(
              () {},
            ); // Trigger rebuild to apply initial styles via build()
          }
        });
      }
    } catch (e) {
      print("Error calling initializeEpubReader in JS: $e");
    }
  }

  void _updateSettingsIfNeeded() {
    // This function now just contains the logic, called from build()
    if (!mounted || _webViewController == null || _isLoading)
      return; // Don't run if loading or not ready

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
      print("(Build) Settings changed, applying to WebView..."); // Added tag
      _applyCurrentStylesToWebView(); // Apply the styles
      // Store current settings for next check
      _previousFontSize = currentFontSize;
      _previousFontFamily = currentFontFamily;
      _previousAppTheme = currentTheme;
    }
  }

  Future<void> _applyCurrentStylesToWebView() async {
    if (_webViewController == null) return;

    final settingsProvider = Provider.of<ReaderSettingsProvider>(
      context,
      listen: false,
    );
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final currentTheme = themeProvider.currentTheme;
    final currentFontSize = settingsProvider.fontSize;
    final currentFontFamily = settingsProvider.fontFamily;

    // 1. Build the base theme styles
    Map<String, dynamic> styles = _getThemeBaseStyles(currentTheme);

    // 2. Add font size and family to the body style within the rules
    // Ensure 'body' key exists, initialize if not (though _getThemeBaseStyles should handle it)
    if (styles['body'] is! Map) {
      styles['body'] = <String, dynamic>{};
    }
    // Merge font styles into the existing body map
    Map<String, dynamic> bodyStyles =
        styles['body'] as Map<String, dynamic>; // Get the body map
    bodyStyles['font-size'] = '${currentFontSize}px';
    bodyStyles['font-family'] =
        "'$currentFontFamily'"; // Ensure font family is quoted

    // 3. Encode and call the JavaScript function
    final stylesJson = jsonEncode(styles);
    try {
      await _webViewController!.runJavaScript('applyStyles($stylesJson);');
      print(
        "Applied styles: Theme=${currentTheme.name}, Size=$currentFontSize, Family=$currentFontFamily",
      );
    } catch (e) {
      print("Error applying styles: $e");
    }
  }

  Map<String, dynamic> _getThemeBaseStyles(AppTheme theme) {
    // Define common rules if any (e.g., link styling independent of theme)
    Map<String, dynamic> commonRules = {
      'a': {'text-decoration': 'none'}, // Example: Remove underline from links
      'a:hover': {'text-decoration': 'underline'},
      'p': {'line-height': '1.5', 'margin-bottom': '0.8em'}, // Adjust spacing
    };

    switch (theme) {
      case AppTheme.dark:
        return {
          'body': {'background-color': '#121212', 'color': '#E0E0E0'},
          'a': {
            'color': '#BB86FC',
            ...commonRules['a'],
          }, // Merge common link style
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
}
