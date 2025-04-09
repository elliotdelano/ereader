import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'platform_webview_interface.dart';

/// Mobile implementation using webview_flutter.
class MobileWebViewAdapter implements PlatformWebViewInterface {
  WebViewController? _controller;
  bool _isInitialized = false; // Track if initial page load finished

  // Callbacks provided by CustomEpubViewer
  @override
  ValueChanged<String>? onPageFinished;
  @override
  ValueChanged<Object>? onWebResourceError; // TODO: Map WebResourceError
  @override
  VoidCallback? onWebViewCreated; // Less relevant for mobile
  @override
  ValueChanged<String>? onLoadEnd;
  @override
  Function(String url, int errorCode, String errorMsg)? onLoadError;

  // Internal callback for JS channel
  ValueChanged<String>? _onJavaScriptMessage;

  @override
  Future<void> initialize() async {
    // Initialization is mostly handled by the WebViewWidget creation,
    // but we create the controller here.
    if (_controller == null) {
      _controller = WebViewController();
      // Set navigation delegate immediately after creation
      _controller!.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print("Mobile Page finished: $url");
            // Consider initialized only after viewer.html load?
            _isInitialized = true;
            onPageFinished?.call(url);
            onLoadEnd?.call(
              url,
            ); // Treat page finished as load end for interface
          },
          onWebResourceError: (WebResourceError error) {
            // TODO: Map WebResourceError to a common error object or pass directly
            print(
              "Mobile Web resource error: ${error.description}, URL: ${error.url}",
            );
            onWebResourceError?.call(error);
            // Map to onLoadError signature (best effort)
            onLoadError?.call(
              error.url ?? '',
              error.errorCode,
              error.description,
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            // Basic navigation prevention logic (can be customized)
            // This delegate doesn't expose the base URL easily here.
            // Allow all for now, epub_server provides the isolation.
            // print("Mobile Nav Request: ${request.url}");
            return NavigationDecision.navigate;
          },
          // Other delegates like onProgress can be added here
        ),
      );
      // Set JS mode immediately
      _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
      print("Mobile WebViewController created and configured.");
      // Synthetically call onWebViewCreated after controller setup
      onWebViewCreated?.call();
    } else {
      print("Mobile WebViewController already created.");
    }
  }

  @override
  bool get isInitialized => _controller != null && _isInitialized;

  @override
  Future<void> loadUrl(String url) async {
    if (_controller == null) {
      throw Exception(
        "MobileWebViewAdapter not initialized. Call initialize() first.",
      );
    }
    try {
      await _controller!.loadRequest(Uri.parse(url));
    } catch (e) {
      print("Error loading URL in MobileWebView: $e");
      rethrow;
    }
  }

  @override
  Future<dynamic> runJavaScript(String javaScript) async {
    if (!isInitialized) {
      // Check if controller is initialized *and* page loaded
      print(
        "Warning: Running JS on MobileWebView before initial page load finished.",
      );
      // throw Exception("MobileWebViewAdapter not fully initialized.");
    }
    if (_controller == null) {
      throw Exception("MobileWebViewAdapter controller is null.");
    }
    try {
      return await _controller!.runJavaScript(javaScript);
    } catch (e) {
      print("Error running JavaScript on MobileWebView: $e");
      rethrow;
    }
  }

  @override
  Future<String?> runJavaScriptReturningResult(String javaScript) async {
    if (!isInitialized) {
      // Check if controller is initialized *and* page loaded
      print(
        "Warning: Running JS for result on MobileWebView before initial page load finished.",
      );
      // throw Exception("MobileWebViewAdapter not fully initialized.");
    }
    if (_controller == null) {
      throw Exception("MobileWebViewAdapter controller is null.");
    }
    try {
      final result = await _controller!.runJavaScriptReturningResult(
        javaScript,
      );
      return result?.toString(); // Convert result to String
    } catch (e) {
      print("Error running JavaScript for result on MobileWebView: $e");
      rethrow;
    }
  }

  @override
  Future<void> addJavaScriptChannel(
    String name, {
    required ValueChanged<String> onMessageReceived,
  }) async {
    if (_controller == null) {
      throw Exception("MobileWebViewAdapter not initialized.");
    }
    // Store the callback for internal use
    _onJavaScriptMessage = onMessageReceived;
    try {
      // Remove existing channel first is safer
      // await _controller!.removeJavaScriptChannel(name); // Requires controller v4.3.0+
      await _controller!.addJavaScriptChannel(
        name,
        onMessageReceived: (JavaScriptMessage message) {
          _onJavaScriptMessage?.call(message.message);
        },
      );
    } catch (e) {
      print("Error adding JavaScript channel on MobileWebView: $e");
      rethrow;
    }
  }

  @override
  Future<void> setBackgroundColor(Color color) async {
    if (_controller == null) {
      throw Exception("MobileWebViewAdapter not initialized.");
    }
    try {
      await _controller!.setBackgroundColor(color);
    } catch (e) {
      print("Error setting background color on MobileWebView: $e");
      // Don't rethrow, might not be critical
    }
  }

  @override
  Widget buildView() {
    if (_controller == null) {
      return const Center(
        child: Text("Error: Mobile WebView Controller not available."),
      );
    }
    return WebViewWidget(controller: _controller!);
  }

  @override
  void dispose() {
    print("Disposing MobileWebViewAdapter...");
    // WebViewWidget typically handles the controller's disposal.
    // Setting controller to null helps prevent late calls.
    _controller = null;
    _isInitialized = false;
  }
}
