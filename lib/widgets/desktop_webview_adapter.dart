import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';
import './platform_webview_interface.dart';

/// Desktop implementation using webview_cef, adapted from the package example.
class DesktopWebViewAdapter implements PlatformWebViewInterface {
  final _webviewManager = WebviewManager();
  WebViewController? _controller;
  bool _cefManagerInitialized = false;
  bool _controllerInitialized =
      false; // Track if controller.initialize(url) was called
  bool _pageLoadFinished = false; // Track if onLoadEnd was called

  // Interface Callbacks
  @override
  ValueChanged<String>? onPageFinished;
  @override
  ValueChanged<Object>? onWebResourceError;
  @override
  VoidCallback? onWebViewCreated;
  @override
  ValueChanged<String>? onLoadEnd;
  @override
  Function(String url, int errorCode, String errorMsg)? onLoadError;

  // Internal JS Channel Management
  final Map<String, ValueChanged<String>> _javascriptChannels = {};

  @override
  Future<void> initialize() async {
    // 1. Initialize Manager
    if (!_cefManagerInitialized) {
      try {
        print("Initializing CEF Manager...");
        await _webviewManager.initialize();
        _cefManagerInitialized = true;
        print("CEF Manager initialized successfully.");
      } catch (e) {
        print("FATAL: Error initializing CEF Manager: $e");
        onLoadError?.call('', -1, "CEF Manager Initialization Failed: $e");
        rethrow;
      }
    }

    // 2. Create Controller (if needed)
    if (_controller == null) {
      try {
        print("Creating CEF WebViewController...");
        _controller = _webviewManager.createWebView(
          // loading: const Center(child: CircularProgressIndicator()), // Optional
        );
        print("CEF WebViewController created.");
        // 3. Set Listener immediately
        _controller!.setWebviewListener(
          WebviewEventsListener(
            onLoadStart: (ctrl, url) {
              print("[CEF Event] onLoadStart: $url");
              _pageLoadFinished = false; // Reset on new load start
            },
            onLoadEnd: (ctrl, url) {
              print("[CEF Event] onLoadEnd: $url");
              _pageLoadFinished = true;
              onLoadEnd?.call(url); // Call interface callback
              onPageFinished?.call(url); // Also call onPageFinished
            },
            onConsoleMessage: (
              int level,
              String message,
              String source,
              int line,
            ) {
              // Assume message is a String and print it, ignoring controllerId for now
              print("[JS Console]($source:$line): $message");
            },
            // Map other relevant events if needed by the interface in the future
            // onUrlChanged: (url) { ... }
            // onTitleChanged: (title) { ... }
          ),
        );
        print("CEF WebviewListener configured.");
        onWebViewCreated?.call(); // Notify creation
      } catch (e) {
        print("FATAL: Error creating CEF WebViewController: $e");
        _controller = null; // Ensure controller is null on error
        onLoadError?.call('', -1, "CEF Controller Creation Failed: $e");
        rethrow;
      }
    }
  }

  @override
  // Initialized means controller exists AND controller.initialize(url) was called
  // AND the first page load finished successfully.
  bool get isInitialized =>
      _controller != null && _controllerInitialized && _pageLoadFinished;

  @override
  Future<void> loadUrl(String url) async {
    if (_controller == null) {
      throw Exception(
        "DesktopWebViewAdapter controller not created. Call initialize() first.",
      );
    }
    if (!_cefManagerInitialized) {
      throw Exception("CEF Manager not initialized. Call initialize() first.");
    }
    try {
      print("Calling CEF controller.initialize with URL: $url");
      // Reset flags before loading
      _controllerInitialized = false;
      _pageLoadFinished = false;
      await _controller!.initialize(url); // This triggers the actual load
      _controllerInitialized = true; // Mark controller init called successfully
      print("CEF controller.initialize call completed for: $url");
      // Attempt to apply any pending JS channels now that init is done
      _applyJavaScriptChannels();
    } catch (e) {
      _controllerInitialized = false;
      _pageLoadFinished = false;
      print("Error in CEF controller.initialize: $e");
      onLoadError?.call(url, -1, "CEF controller.initialize failed: $e");
      rethrow;
    }
  }

  @override
  Future<dynamic> runJavaScript(String javaScript) async {
    if (_controller == null || !_controllerInitialized) {
      print(
        "Warning: runJavaScript called before controller fully initialized.",
      );
      // Allow potentially, but it might fail
      // throw Exception("DesktopWebViewAdapter not initialized.");
    }
    if (_controller == null) {
      throw Exception("DesktopWebViewAdapter controller is null.");
    }
    try {
      await _controller!.executeJavaScript(javaScript);
      return null;
    } catch (e) {
      print("Error running JavaScript (execute) on CEF: $e");
      rethrow;
    }
  }

  @override
  Future<String?> runJavaScriptReturningResult(String javaScript) async {
    if (_controller == null || !_controllerInitialized) {
      print(
        "Warning: runJavaScriptReturningResult called before controller fully initialized.",
      );
      // Allow potentially, but it might fail
      // throw Exception("DesktopWebViewAdapter not initialized.");
    }
    if (_controller == null) {
      throw Exception("DesktopWebViewAdapter controller is null.");
    }
    try {
      final result = await _controller!.evaluateJavascript(javaScript);
      return result?.toString();
    } catch (e) {
      print("Error running JavaScript (evaluate) on CEF: $e");
      return null;
    }
  }

  @override
  Future<void> addJavaScriptChannel(
    String name, {
    required ValueChanged<String> onMessageReceived,
  }) async {
    if (_controller == null) {
      throw Exception("DesktopWebViewAdapter controller not created.");
    }
    print("Adding JavaScript channel '$name'...");
    _javascriptChannels[name] = onMessageReceived;
    // Attempt to apply channels immediately ONLY IF controller is already initialized.
    // If not initialized, loadUrl will call _applyJavaScriptChannels later.
    if (_controllerInitialized) {
      print("Controller already initialized, applying channels now.");
      _applyJavaScriptChannels();
    } else {
      print(
        "JS Channel '$name' added, but setup deferred until controller init completes.",
      );
    }
  }

  // Helper to set/update channels on the controller
  void _applyJavaScriptChannels() {
    // Check if controller exists AND if controller.initialize(url) was called
    if (_controller == null || !_controllerInitialized) {
      print(
        "Warning: _applyJavaScriptChannels called but controller not ready. Deferring.",
      );
      return; // Don't set channels yet
    }

    // Don't attempt if there are no channels to set
    if (_javascriptChannels.isEmpty) {
      print("No JavaScript channels registered to apply.");
      return;
    }

    print("Building CEF channels for: ${_javascriptChannels.keys.join(', ')}");
    final Set<JavascriptChannel> cefChannels =
        _javascriptChannels.entries.map((entry) {
          return JavascriptChannel(
            name: entry.key,
            onMessageReceived: (JavascriptMessage message) {
              // Use try-catch for safety
              try {
                _javascriptChannels[entry.key]?.call(message.message);
              } catch (e) {
                print(
                  "Error processing JS message for channel ${entry.key}: $e",
                );
              }
            },
          );
        }).toSet();

    try {
      print(
        "Attempting to set CEF JavaScript channels: ${_javascriptChannels.keys.join(', ')}",
      );
      _controller!.setJavaScriptChannels(cefChannels);
      print("CEF JavaScript channels successfully set.");
    } catch (e) {
      print("Error setting JavaScript channels on CEF: $e");
      // Log the state for debugging
      print(
        "Controller state: _controller=$_controller, _controllerInitialized=$_controllerInitialized",
      );
      // Consider rethrowing or handling
    }
  }

  @override
  Future<void> setBackgroundColor(Color color) async {
    print(
      "Warning: setBackgroundColor is not supported by DesktopWebViewAdapter.",
    );
    return Future.value();
  }

  @override
  Widget buildView() {
    if (_controller == null) {
      return const Center(
        child: Text("Error: Desktop WebView Controller not created."),
      );
    }
    // Rely on the containing widget (CustomEpubViewer) to show loading state
    return _controller!.webviewWidget;
  }

  @override
  void dispose() {
    print("Disposing DesktopWebViewAdapter...");
    _controller?.dispose();
    _controller = null;
    _controllerInitialized = false;
    _pageLoadFinished = false;
    // Do NOT call WebviewManager().quit() here, as it affects all instances.
    // It should be called globally when the app exits if needed.
  }
}
