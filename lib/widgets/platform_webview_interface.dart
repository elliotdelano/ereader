import 'package:flutter/material.dart';

/// Abstract interface for platform-specific WebView controllers.
/// Defines common methods needed by CustomEpubViewer.
abstract class PlatformWebViewInterface {
  /// Initializes the underlying WebView controller.
  /// Should be called before other methods.
  Future<void> initialize();

  /// Checks if the underlying controller is initialized.
  bool get isInitialized;

  /// Loads the specified URL.
  Future<void> loadUrl(String url);

  /// Executes the given JavaScript code.
  /// Returns the result, if any (type might vary by platform).
  Future<dynamic> runJavaScript(String javaScript);

  /// Executes the given JavaScript code and expects a string result.
  /// Provides a consistent way to get string results across platforms.
  Future<String?> runJavaScriptReturningResult(String javaScript);

  /// Adds a JavaScript channel for two-way communication.
  Future<void> addJavaScriptChannel(
    String name, {
    required ValueChanged<String> onMessageReceived,
  });

  /// Sets the background color of the WebView.
  /// Note: May not be supported on all platforms/implementations.
  Future<void> setBackgroundColor(Color color);

  /// Builds the actual WebView widget for display.
  Widget buildView();

  /// Cleans up resources associated with the WebView controller.
  void dispose();

  // --- Callbacks --- //
  // These need to be settable so the implementation can call them.

  /// Callback invoked when a page finishes loading.
  ValueChanged<String>? onPageFinished;

  /// Callback invoked when a web resource loading error occurs.
  // Define a common error type or use dynamic for flexibility
  ValueChanged<Object>? onWebResourceError; // TODO: Refine error type

  /// Callback invoked when the WebView controller itself is created (useful for CEF).
  VoidCallback? onWebViewCreated;

  /// Callback for JavaScript messages (used internally by addJavaScriptChannel).
  // This might not need to be public if addJavaScriptChannel handles it.

  /// Callback when the view finishes loading (useful for CEF 'LoadEnd').
  ValueChanged<String>? onLoadEnd;

  /// Callback when a loading error occurs (useful for CEF 'LoadError').
  // Define a specific callback signature matching CEF if needed
  Function(String url, int errorCode, String errorMsg)? onLoadError;

  // Add other common methods or properties as needed, e.g.,
  // Future<void> reload();
  // Future<bool> canGoBack();
  // Future<void> goBack();
  // etc.
}
