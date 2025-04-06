import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as pathlib;
import 'package:epubx/epubx.dart';
import 'book_metadata.dart';

enum BookFormat { epub, pdf, unknown }

class Book {
  final String path;
  final String title;
  final String? author;
  final String? series;
  final Uint8List? coverImage;
  final DateTime lastModified;
  final DateTime dateAdded;
  final BookFormat format;

  Book({
    required this.path,
    required this.title,
    this.author,
    this.series,
    this.coverImage,
    required this.lastModified,
    required this.dateAdded,
    required this.format,
  });

  // Factory method to create a Book from a BookMetadata
  factory Book.fromMetadata(BookMetadata metadata) {
    return Book(
      path: metadata.path,
      title: metadata.title,
      author: metadata.author,
      series: metadata.series,
      coverImage: metadata.coverImage,
      lastModified: metadata.lastModified,
      dateAdded: metadata.dateAdded,
      format: metadata.format == 'epub' ? BookFormat.epub : BookFormat.pdf,
    );
  }

  // Static method to determine format from file extension
  static BookFormat getFormatFromPath(String filePath) {
    final extension = pathlib.extension(filePath).toLowerCase();
    switch (extension) {
      case '.epub':
        return BookFormat.epub;
      case '.pdf':
        return BookFormat.pdf;
      default:
        return BookFormat.unknown;
    }
  }

  // Static method to extract title from file path
  static String getTitleFromPath(String filePath) {
    final fileName = pathlib.basenameWithoutExtension(filePath);
    // Replace underscores and hyphens with spaces
    return fileName.replaceAll(RegExp(r'[_-]'), ' ');
  }

  // New async factory method for creating a Book and extracting EPUB title
  static Future<Book> createFromPath(String path) async {
    final format = getFormatFromPath(path);
    String title;
    if (format == BookFormat.epub) {
      try {
        final bytes = await File(path).readAsBytes();
        final epubBook = await EpubReader.readBook(bytes);
        // Use the EPUB title if available, otherwise fallback.
        title =
            (epubBook.Title?.isNotEmpty ?? false)
                ? epubBook.Title!
                : getTitleFromPath(path);
      } catch (e) {
        print("Error reading EPUB title: $e");
        title = getTitleFromPath(path);
      }
    } else {
      title = getTitleFromPath(path);
    }
    return Book(
      path: path,
      title: title,
      format: format,
      lastModified: File(path).lastModifiedSync(),
      dateAdded: DateTime.now(),
    );
  }
}
