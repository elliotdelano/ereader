import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:ereader/providers/reader_state_provider.dart';
import 'package:ereader/providers/reader_settings_provider.dart';
import 'package:ereader/providers/theme_provider.dart';
import 'dart:typed_data'; // Needed for image rendering check

class HtmlEpubReaderView extends StatefulWidget {
  final String filePath;

  const HtmlEpubReaderView({super.key, required this.filePath});

  @override
  State<HtmlEpubReaderView> createState() => _HtmlEpubReaderViewState();
}

class _HtmlEpubReaderViewState extends State<HtmlEpubReaderView> {
  // Store last known metrics to avoid redundant calculations
  double _lastCalculatedViewportHeight = -1;
  double _lastCalculatedMaxScroll = -1;

  @override
  void initState() {
    super.initState();
    // Load the book shortly after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReaderStateProvider>(
        context,
        listen: false,
      ).loadBook(widget.filePath);
    });
  }

  // Helper to build the style object for flutter_html
  Map<String, Style> _buildHtmlStyle(
    ReaderSettingsProvider settings,
    ThemeProvider themeProvider,
  ) {
    final themeData = themeProvider.themeData; // Get current theme data
    final appTheme = themeProvider.currentTheme;

    // Determine text color based on theme brightness or specific theme
    final textColor =
        themeData.textTheme.bodyLarge?.color ??
        (appTheme == AppTheme.dark ? Colors.white70 : Colors.black87);

    // Return a Map where keys are selectors (like tags)
    final styleMap = {
      // Apply default styles using the universal selector or tag selectors
      'html': Style(
        backgroundColor: themeData.scaffoldBackgroundColor,
        color: textColor,
        // Basic styles, let layout handle sizing
        fontSize: FontSize(settings.fontSize),
        fontFamily: settings.fontFamily,
        lineHeight: const LineHeight(1.6),
      ),
      'body': Style(
        color: textColor,
        fontSize: FontSize(settings.fontSize),
        fontFamily: settings.fontFamily,
        lineHeight: const LineHeight(1.6),
        textAlign: TextAlign.justify,
        padding: HtmlPaddings.all(16.0), // Revert to simple padding
        margin: Margins.zero,
      ),
      // Override specific tags if needed
      'p': Style(
        margin: Margins.only(
          bottom: 1.0,
          unit: Unit.em,
        ), // Margin for paragraphs
        fontSize: FontSize(
          settings.fontSize,
        ), // Ensure p tags respect font size
        lineHeight: const LineHeight(1.6),
      ),
      'h1': Style(
        fontSize: FontSize(settings.fontSize * 1.8), // Example scaling
        lineHeight: const LineHeight(1.3),
        margin: Margins.symmetric(vertical: 0.8, unit: Unit.em),
      ),
      'h2': Style(
        fontSize: FontSize(settings.fontSize * 1.5),
        lineHeight: const LineHeight(1.3),
        margin: Margins.symmetric(vertical: 0.7, unit: Unit.em),
      ),
      'h3': Style(
        fontSize: FontSize(settings.fontSize * 1.3),
        lineHeight: const LineHeight(1.3),
        margin: Margins.symmetric(vertical: 0.6, unit: Unit.em),
      ),
      'h4': Style(
        fontSize: FontSize(settings.fontSize * 1.15),
        lineHeight: const LineHeight(1.3),
        margin: Margins.symmetric(vertical: 0.5, unit: Unit.em),
      ),
      'h5': Style(
        fontSize: FontSize(settings.fontSize * 1.0),
        lineHeight: const LineHeight(1.3),
        margin: Margins.symmetric(vertical: 0.4, unit: Unit.em),
      ),
      'h6': Style(
        fontSize: FontSize(settings.fontSize * 0.9),
        lineHeight: const LineHeight(1.3),
        margin: Margins.symmetric(vertical: 0.4, unit: Unit.em),
      ),
      'a': Style(
        color:
            themeData
                .colorScheme
                .primary, // Use theme's primary color for links
        textDecoration: TextDecoration.none,
      ),
      // Add styling for other elements like lists (ul, ol, li), blockquote, etc.
      'li': Style(
        fontSize: FontSize(settings.fontSize),
        lineHeight: const LineHeight(1.6),
        // Add margin/padding for list items if needed
        margin: Margins.only(left: 1.5, unit: Unit.em, bottom: 0.2, top: 0.2),
      ),
      'blockquote': Style(
        margin: Margins.symmetric(
          horizontal: 1.5,
          vertical: 0.5,
          unit: Unit.em,
        ),
        padding: HtmlPaddings.symmetric(
          horizontal: 1.0,
          vertical: 0.5,
          unit: Unit.em,
        ),
        border: Border(
          left: BorderSide(color: textColor.withAlpha(128), width: 3),
        ),
        fontStyle: FontStyle.italic,
      ),
    }; // Close the Map
    print("[HtmlEpubReaderView] Applying Styles: ${styleMap.keys.join(', ')}");
    return styleMap;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<
      ReaderStateProvider,
      ReaderSettingsProvider,
      ThemeProvider
    >(
      builder: (context, readerState, settings, theme, child) {
        if (readerState.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading Book...'),
              ],
            ),
          );
        }

        if (readerState.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(readerState.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => readerState.loadBook(widget.filePath),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (readerState.currentChapterHtmlContent == null) {
          print(
            "[HtmlEpubReaderView] Build: No HTML content in provider state.",
          );
          return const Center(child: Text('No content loaded.'));
        } else {
          // Print snippet of HTML received by the build method
          final snippet =
              readerState.currentChapterHtmlContent!.length > 100
                  ? readerState.currentChapterHtmlContent!.substring(0, 100)
                  : readerState.currentChapterHtmlContent!;
          print(
            "[HtmlEpubReaderView] Build: Rendering HTML content (snippet): $snippet...",
          );
        }

        // Use LayoutBuilder to get constraints but primarily use NotificationListener
        return LayoutBuilder(
          builder: (context, constraints) {
            print(
              "[HtmlEpubReaderView] LayoutBuilder Constraints: $constraints",
            );
            // We might still need initial viewport height from here if notification doesn't fire immediately
            // but the main trigger will be the ScrollMetricsNotification
            if (constraints.hasBoundedHeight) {
              Provider.of<ReaderStateProvider>(
                context,
                listen: false,
              ).setViewportHeight(constraints.maxHeight);
            }

            // --- Use RawGestureDetector for more control ---
            // Define the handler function separately
            void _handleHorizontalDragEnd(DragEndDetails details) {
              if (details.primaryVelocity == 0) return; // No swipe
              const double minSwipeVelocity = 100.0;
              print(
                "[HtmlEpubReaderView] Drag End Velocity: ${details.primaryVelocity}",
              );
              if (details.primaryVelocity!.abs() < minSwipeVelocity) {
                print("[HtmlEpubReaderView] Swipe ignored, velocity too low.");
                return;
              }

              if (details.primaryVelocity! < 0) {
                // Swiped Left (-> Next Page)
                print(
                  "[HtmlEpubReaderView] Swipe Left detected, calling nextPage().",
                );
                readerState.nextPage();
              } else {
                // Swiped Right (<- Previous Page)
                print(
                  "[HtmlEpubReaderView] Swipe Right detected, calling previousPage().",
                );
                readerState.previousPage();
              }
            }

            // Create the recognizer map
            final gestures = <Type, GestureRecognizerFactory>{
              HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                () => HorizontalDragGestureRecognizer(), // Factory
                (HorizontalDragGestureRecognizer instance) {
                  // Initializer
                  instance.onEnd = _handleHorizontalDragEnd;
                  // Optional: Set dragStartBehavior if needed, though often default is fine
                  // instance.dragStartBehavior = DragStartBehavior.down;
                },
              ),
            };
            return RawGestureDetector(
              gestures: gestures,
              // Opaque makes sure it participates in hit testing
              behavior: HitTestBehavior.opaque,
              child: Stack(
                fit: StackFit.expand, // Make stack fill the available space
                children: [
                  // Listen for scroll metrics changes
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) {
                      // Check if dimensions are stable and different from last calculation
                      if (notification.metrics.hasContentDimensions &&
                          notification.metrics.hasPixels) {
                        // Ensure scroll controller is attached

                        final currentViewport =
                            notification.metrics.viewportDimension;
                        final currentMaxScroll =
                            notification.metrics.maxScrollExtent;

                        // Use a tolerance to avoid calculation on tiny pixel changes
                        final tolerance = 1.0;
                        final viewportChanged =
                            (currentViewport - _lastCalculatedViewportHeight)
                                .abs() >
                            tolerance;
                        final maxScrollChanged =
                            (currentMaxScroll - _lastCalculatedMaxScroll)
                                .abs() >
                            tolerance;

                        if (viewportChanged || maxScrollChanged) {
                          print(
                            "[HtmlEpubReaderView] Scroll Metrics Notification: Triggering pagination calculation.",
                          );
                          final readerState = Provider.of<ReaderStateProvider>(
                            context,
                            listen: false,
                          );
                          readerState.setViewportHeight(currentViewport);
                          // Calculate immediately after setting height
                          readerState.calculatePagination();
                          // Store the metrics used for this calculation
                          _lastCalculatedViewportHeight = currentViewport;
                          _lastCalculatedMaxScroll = currentMaxScroll;
                        }
                      }
                      return true; // Keep processing notifications
                    },
                    child: SingleChildScrollView(
                      controller: readerState.scrollController,
                      // Ensure physics prevent overscroll, which might affect calculations
                      physics: const NeverScrollableScrollPhysics(),
                      child: Html(
                        data: readerState.currentChapterHtmlContent!,
                        style: _buildHtmlStyle(settings, theme),
                        // Custom render for images
                        extensions: [
                          TagExtension(
                            tagsToExtend: {"img"}, // Target the <img> tag
                            builder: (ExtensionContext extensionContext) {
                              if (extensionContext.buildContext == null) {
                                return const SizedBox.shrink(); // Cannot get provider without context
                              }
                              final provider = Provider.of<ReaderStateProvider>(
                                extensionContext
                                    .buildContext!, // Use null assertion after check
                                listen: false,
                              );
                              final attributes = extensionContext.attributes;
                              final src = attributes['src'];

                              if (src != null && src.isNotEmpty) {
                                final imageBytes = provider.getImageBytes(src);
                                if (imageBytes != null) {
                                  return Image.memory(
                                    imageBytes,
                                    fit: BoxFit.contain,
                                    semanticLabel:
                                        attributes['alt'] ?? 'EPUB image: $src',
                                    errorBuilder: (ctx, err, st) {
                                      print("Error loading image $src: $err");
                                      return const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                      );
                                    },
                                  );
                                } else {
                                  print("Bytes not found for image: $src");
                                  return const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                  );
                                }
                              }
                              return const SizedBox.shrink(); // Return empty if no src
                            },
                          ),
                          // Add other extensions if needed (e.g., for tables, svg, etc.)
                        ],
                        onLinkTap: (url, attributes, element) {
                          // TODO: Handle internal EPUB links (navigate chapters/sections)
                          // TODO: Handle external links (use url_launcher)
                          print('Link tapped: $url');
                          if (url != null && url.startsWith('http')) {
                            // Example: Launch external links
                            // launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                        // Key might help trigger rebuilds if needed, but Style change should suffice
                        key: ValueKey(
                          '${readerState.currentChapterIndex}_${settings.fontSize}_${theme.currentTheme}',
                        ),
                      ),
                    ),
                  ),
                  // Page number display
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Page ${readerState.currentPageInChapter + 1} of ${readerState.totalPagesInChapter > 0 ? readerState.totalPagesInChapter : 1}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withAlpha(179),
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor.withAlpha(153),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
