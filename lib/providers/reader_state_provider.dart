import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:typed_data'; // For image bytes
import 'dart:convert'; // For utf8.decode
import 'package:image/image.dart' as img; // Import package:image

class ReaderStateProvider with ChangeNotifier {
  EpubBook? _currentBook;
  // Store Hrefs in spine order and the full manifest map
  List<String> _chapterHrefs = [];
  Map<String, EpubManifestItem> _manifestItems = {};
  int _currentChapterIndex = 0;
  String? _currentChapterHtmlContent;
  double _currentScrollOffset = 0;
  int _currentPageInChapter = 0;
  int _totalPagesInChapter = 1;
  bool _isLoading = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  // Store viewport height for pagination calculation
  double _viewportHeight = 0;

  // Store images for quick lookup by href
  Map<String, Uint8List> _images = {};

  EpubBook? get currentBook => _currentBook;
  List<String> get chapterHrefs => _chapterHrefs; // Expose hrefs if needed
  int get currentChapterIndex => _currentChapterIndex;
  String? get currentChapterHtmlContent => _currentChapterHtmlContent;
  double get currentScrollOffset => _currentScrollOffset;
  int get currentPageInChapter => _currentPageInChapter;
  int get totalPagesInChapter => _totalPagesInChapter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ScrollController get scrollController => _scrollController;

  ReaderStateProvider() {
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadBook(String path) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use Epubx to read the book
      final epubBook = await EpubReader.readBook(
        await File(path).readAsBytes(),
      );
      print("[ReaderStateProvider] Book loaded: ${epubBook.Title}");
      // ---- Debug epubx parsing ----
      print("[ReaderStateProvider] Parsed Author: ${epubBook.Author}");
      print(
        "[ReaderStateProvider] Parsed Schema/Package/Spine Item count: ${epubBook.Schema?.Package?.Spine?.Items?.length ?? 'N/A'}",
      );
      print(
        "[ReaderStateProvider] Parsed Schema/Navigation/TableOfContents Entry count: ${epubBook.Schema?.Navigation?.NavMap?.Points?.length ?? 'N/A'}",
      );
      // Print first few spine item IDs if they exist
      if (epubBook.Schema?.Package?.Spine?.Items != null &&
          epubBook.Schema!.Package!.Spine!.Items!.isNotEmpty) {
        final ids = epubBook.Schema!.Package!.Spine!.Items!
            .take(5)
            .map((e) => e.IdRef ?? '?')
            .join(', ');
        print("[ReaderStateProvider] First 5 Spine Item IDRefs: $ids");
      }
      // ---- End Debug epubx ----

      _currentBook = epubBook;

      // --- Rebuild chapter list from Spine and Manifest ---
      _chapterHrefs = [];
      _manifestItems = {};
      final spineItems = epubBook.Schema?.Package?.Spine?.Items;
      final manifestMap = <String, EpubManifestItem>{};
      epubBook.Schema?.Package?.Manifest?.Items?.forEach((item) {
        if (item.Id != null) {
          manifestMap[item.Id!] = item;
          _manifestItems[item.Id!] =
              item; // Store manifest separately if needed later
        }
      });

      if (spineItems != null && manifestMap.isNotEmpty) {
        for (var spineItem in spineItems) {
          if (spineItem.IdRef != null &&
              manifestMap.containsKey(spineItem.IdRef)) {
            final manifestItem = manifestMap[spineItem.IdRef!];
            if (manifestItem?.Href != null) {
              _chapterHrefs.add(manifestItem!.Href!);
            }
          }
        }
      }
      print(
        "[ReaderStateProvider] Constructed chapter list from spine. Found ${_chapterHrefs.length} chapter Hrefs.",
      );

      _currentChapterIndex = 0; // Start at the first chapter

      // Pre-process and store images - Attempt decoding with package:image
      _images = {};
      if (epubBook.Content?.Images != null) {
        print(
          "Decoding ${epubBook.Content!.Images!.length} images using package:image...",
        );
        epubBook.Content!.Images!.forEach((key, value) {
          final List<int>? rawBytesList =
              value.Content; // Still assuming Content property

          if (rawBytesList != null) {
            try {
              // Convert to Uint8List first
              final rawBytes = Uint8List.fromList(rawBytesList);
              // Attempt to decode using package:image
              img.Image? decodedImage = img.decodeImage(rawBytes);

              if (decodedImage != null) {
                // Successfully decoded! Re-encode as PNG for consistency
                // Using compute for encoding might be good for performance on many/large images
                final List<int> pngBytes = img.encodePng(decodedImage);
                _images[key] = Uint8List.fromList(pngBytes);
                // print("Successfully decoded and re-encoded image: $key");
              } else {
                // decodeImage returned null - format not recognized or corrupt
                print(
                  "Warning: package:image could not decode image format for key: $key",
                );
              }
            } catch (e) {
              // Decoding or encoding failed
              print("Error processing image $key with package:image: $e");
            }
          } else {
            print("Warning: Image content bytes are null for key: $key");
          }
        }); // Correctly close forEach
        print("Loaded ${_images.length} images using package:image.");
      }

      if (_chapterHrefs.isEmpty) {
        throw Exception("EPUB has no chapters.");
      }

      await _loadChapterContent(
        _currentChapterIndex,
      ); // Load initial chapter content

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print("Error loading EPUB: $e");
      _error = "Error loading EPUB: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadChapterContent(int index) async {
    if (_currentBook == null || index < 0 || index >= _chapterHrefs.length)
      return;

    final chapterHref = _chapterHrefs[index];
    print(
      "[ReaderStateProvider] Loading chapter content for href: $chapterHref",
    );

    // --- Find the HTML content directly ---
    final textContentFile = _currentBook!.Content?.Html?[chapterHref];

    if (textContentFile == null) {
      print(
        "[ReaderStateProvider] Error: HTML content file not found in Content.Html for href: $chapterHref",
      );
      _currentChapterHtmlContent = "<p>Error: Chapter content not found.</p>";
    } else {
      // Assuming EpubTextContentFile has a string property like 'Content' or 'HtmlContent'
      // Use ?. for safety, although if textContentFile is not null, Content should exist.
      _currentChapterHtmlContent = textContentFile.Content;
      if (_currentChapterHtmlContent == null) {
        print(
          "[ReaderStateProvider] Error: EpubTextContentFile.Content was null for href: $chapterHref",
        );
        _currentChapterHtmlContent =
            "<p>Error: Failed to read chapter content string.</p>";
      }
    }
    // --- End HTML content loading ---

    // Print snippet for verification
    final snippet =
        _currentChapterHtmlContent != null &&
                _currentChapterHtmlContent!.length > 100
            ? _currentChapterHtmlContent!.substring(0, 100)
            : _currentChapterHtmlContent;
    print(
      "[ReaderStateProvider] Loading Chapter $index content (snippet): $snippet...",
    );

    _currentChapterIndex = index;
    _currentScrollOffset = 0;
    _currentPageInChapter = 0;
    _totalPagesInChapter = 1; // Reset until calculated

    // Scroll to top when chapter changes
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    // Notify listeners that content is ready, calculation happens after layout
    notifyListeners();
  }

  void setViewportHeight(double height) {
    if (height > 0 && _viewportHeight != height) {
      _viewportHeight = height;
      // Calculation is now triggered by ScrollMetricsNotification listener
      print("[ReaderStateProvider] Viewport height set: $_viewportHeight");
    }
  }

  void calculatePagination() {
    if (!_scrollController.hasClients || _viewportHeight <= 0) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final newTotalPages = (maxScroll / _viewportHeight).ceil() + 1;
    final newCurrentPage = (_scrollController.offset / _viewportHeight).floor();

    if (newTotalPages != _totalPagesInChapter ||
        newCurrentPage != _currentPageInChapter) {
      _totalPagesInChapter = newTotalPages > 0 ? newTotalPages : 1;
      _currentPageInChapter = newCurrentPage.clamp(0, _totalPagesInChapter - 1);
      print(
        "Pagination Calculated: Page ${_currentPageInChapter + 1} of $_totalPagesInChapter",
      );
      // Use WidgetsBinding to avoid calling notifyListeners during build/layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          // Check if provider is still mounted
          notifyListeners();
        }
      });
    }
  }

  void _onScroll() {
    if (_viewportHeight <= 0 || !_scrollController.hasClients) return;

    _currentScrollOffset = _scrollController.offset;
    final double pageAsDouble = _currentScrollOffset / _viewportHeight;
    int newCurrentPage;

    // Check if we are very close to the max scroll extent
    final maxScroll = _scrollController.position.maxScrollExtent;
    final double scrollEndTolerance = 1.0; // Tolerance in pixels
    if ((maxScroll - _currentScrollOffset).abs() < scrollEndTolerance &&
        _totalPagesInChapter > 0) {
      // If at the end, force calculation to the last page index
      newCurrentPage = _totalPagesInChapter - 1;
      print(
        "[ReaderStateProvider] _onScroll: At scroll end, forcing page to last index: $newCurrentPage",
      );
    } else {
      // Otherwise, use floor for intermediate pages
      newCurrentPage = pageAsDouble.floor();
    }

    // Log the exact values used for calculation
    print(
      "[ReaderStateProvider] _onScroll: Offset=$_currentScrollOffset, Viewport=$_viewportHeight, MaxScroll=$maxScroll, pageAsDouble=$pageAsDouble, CalcPage=$newCurrentPage, TotalPages=$_totalPagesInChapter",
    );

    if (newCurrentPage != _currentPageInChapter) {
      _currentPageInChapter = newCurrentPage.clamp(0, _totalPagesInChapter - 1);
      print("Scrolled to Page: ${_currentPageInChapter + 1}");
      // Use WidgetsBinding to avoid calling notifyListeners during scroll callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }

  // --- Navigation Methods ---

  Future<void> nextPage() async {
    print(
      "[ReaderStateProvider] nextPage() called. CurrentPage: $_currentPageInChapter, TotalPages: $_totalPagesInChapter",
    );
    if (_chapterHrefs.isEmpty || !_scrollController.hasClients) return;

    print(
      "[ReaderStateProvider] Current Scroll Offset: ${_scrollController.offset}, Viewport: $_viewportHeight, MaxScroll: ${_scrollController.position.maxScrollExtent}",
    );

    final targetPage = _currentPageInChapter + 1;
    print(
      "[ReaderStateProvider] Checking condition: targetPage ($targetPage) < totalPagesInChapter ($_totalPagesInChapter)?",
    );
    if (targetPage < _totalPagesInChapter) {
      // Go to next page within the chapter
      print(
        "[ReaderStateProvider] Navigating to next page ($_currentPageInChapter -> $targetPage) in chapter $_currentChapterIndex.",
      );
      final targetOffset = targetPage * _viewportHeight;
      _scrollController.jumpTo(targetOffset); // Use jumpTo for instant change
    } else {
      // Go to the first page of the next chapter
      final nextChapterIndex = _currentChapterIndex + 1;
      if (nextChapterIndex < _chapterHrefs.length) {
        print(
          "[ReaderStateProvider] End of chapter $_currentChapterIndex, moving to next chapter $nextChapterIndex...",
        );
        await _loadChapterContent(nextChapterIndex);
        // Pagination will be recalculated on layout
      } else {
        print(
          "[ReaderStateProvider] Already on the last page of the last chapter.",
        );
      }
    }
  }

  Future<void> previousPage() async {
    print(
      "[ReaderStateProvider] previousPage() called. CurrentPage: $_currentPageInChapter",
    );
    if (_chapterHrefs.isEmpty || !_scrollController.hasClients) return;

    final targetPage = _currentPageInChapter - 1;
    if (targetPage >= 0) {
      // Go to previous page within the chapter
      print(
        "[ReaderStateProvider] Navigating to previous page ($_currentPageInChapter -> $targetPage) in chapter $_currentChapterIndex.",
      );
      final targetOffset = targetPage * _viewportHeight;
      _scrollController.jumpTo(targetOffset); // Use jumpTo for instant change
    } else {
      // Go to the *start* of the previous chapter (simplification)
      final prevChapterIndex = _currentChapterIndex - 1;
      if (prevChapterIndex >= 0) {
        print(
          "[ReaderStateProvider] Start of chapter $_currentChapterIndex, moving to previous chapter $prevChapterIndex (start)...",
        );
        await _loadChapterContent(prevChapterIndex);
        // Pagination will be recalculated on layout
        // TODO: Implement logic to go to *last* page if desired
      } else {
        print(
          "[ReaderStateProvider] Already on the first page of the first chapter.",
        );
      }
    }
  }

  // Helper to get image bytes (used by HtmlEpubReaderView)
  Uint8List? getImageBytes(String href) {
    // epubx might store hrefs relative to OPF, adjust if needed
    // Check based on how hrefs appear in HTML content vs _images keys
    return _images[href];
    // Example adjustment if needed:
    // final adjustedHref = href.startsWith('../') ? href.substring(3) : href;
    // return _images[adjustedHref];
  }
}
