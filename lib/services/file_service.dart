import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
// Use prefix to avoid conflicts
import 'package:permission_handler/permission_handler.dart';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';
import '../models/book_metadata.dart';
import 'database_service.dart';
import 'dart:ui' as ui;

class FileService {
  final DatabaseService _databaseService = DatabaseService();

  // Pick a directory using file_picker
  Future<String?> pickDirectory() async {
    // Request permissions first (especially important on Android)
    // On Desktop, file_picker often handles this implicitly, but good practice.
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Handle permission denial (e.g., show a message)
          return null;
        }
      } else {
        print("Storage permission already granted."); // Log if already granted
      }
      // Android 11+ might need manage external storage, but start with basic storage.
      // Consider adding Permission.manageExternalStorage if needed, but it requires
      // special declaration and user redirection to settings.
    } else {
      print(
        "Not on Android, skipping permission request.",
      ); // Log if not Android
    }
    // On Linux, permissions are generally handled by system file picker.

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Ebook Folder',
      );
      return selectedDirectory;
    } catch (e) {
      print("Error picking directory: $e");
      return null;
    }
  }

  // Extract metadata from an EPUB file
  Future<BookMetadata?> _extractEpubMetadata(String epubPath) async {
    try {
      final bytes = await File(epubPath).readAsBytes();
      final epubBook = await EpubReader.openBook(bytes);

      // Extract cover image using epubx's built-in functionality
      Uint8List? coverImage;

      try {
        final coverImageContent = await epubBook.readCover();
        if (coverImageContent != null) {
          final rawBytes = coverImageContent.getBytes();
          if (rawBytes != null) {
            // Create an ImageData object from the raw RGBA pixels
            final imageData = await ui.ImageDescriptor.raw(
              await ui.ImmutableBuffer.fromUint8List(rawBytes),
              width: coverImageContent.width,
              height: coverImageContent.height,
              pixelFormat: ui.PixelFormat.rgba8888,
            );

            // Convert to an Image object
            final codec = await imageData.instantiateCodec();
            final frame = await codec.getNextFrame();

            // Convert the frame to a byte array in PNG format
            final pngBytes = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (pngBytes != null) {
              coverImage = pngBytes.buffer.asUint8List();
            }

            // Clean up
            frame.image.dispose();
            codec.dispose();
          }
        }
      } catch (e) {
        print("Error extracting cover image: $e");
        // Continue without cover image if extraction fails
      }

      return BookMetadata(
        path: epubPath,
        title: epubBook.Title ?? Book.getTitleFromPath(epubPath),
        author: epubBook.Author,
        series: null, // EPUB standard doesn't have a series field
        coverImage: coverImage,
        lastModified: File(epubPath).lastModifiedSync(),
        dateAdded: DateTime.now(),
        format: 'epub',
      );
    } catch (e) {
      print("Error extracting EPUB metadata: $e");
      return null;
    }
  }

  // Extract metadata from a PDF file
  Future<BookMetadata?> _extractPdfMetadata(String path) async {
    try {
      // For PDFs, we'll just use basic file information for now
      // In a real app, you might want to use a PDF parsing library
      return BookMetadata(
        path: path,
        title: Book.getTitleFromPath(path),
        author: null,
        series: null,
        coverImage: null,
        lastModified: File(path).lastModifiedSync(),
        dateAdded: DateTime.now(),
        format: 'pdf',
      );
    } catch (e) {
      print("Error extracting PDF metadata: $e");
      return null;
    }
  }

  // Scan a directory recursively for supported book files
  Future<List<Book>> scanForBooks(String directoryPath) async {
    final List<Book> books = [];
    final List<String> existingPaths = [];
    final directory = Directory(directoryPath);

    if (!await directory.exists()) {
      print("Directory does not exist: $directoryPath");
      return books; // Return empty list if directory doesn't exist
    }

    try {
      // List entities recursively
      await for (final FileSystemEntity entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final format = Book.getFormatFromPath(entity.path);
          if (format != BookFormat.unknown) {
            existingPaths.add(entity.path);

            // Check if we already have this book in the database
            BookMetadata? existingMetadata = await _databaseService
                .getBookByPath(entity.path);

            if (existingMetadata == null) {
              // New book found, extract and store metadata
              BookMetadata? metadata;
              if (format == BookFormat.epub) {
                metadata = await _extractEpubMetadata(entity.path);
              } else if (format == BookFormat.pdf) {
                metadata = await _extractPdfMetadata(entity.path);
              }

              if (metadata != null) {
                await _databaseService.insertBook(metadata);
                existingMetadata = metadata;
              }
            }

            // Create Book instance for the UI
            books.add(
              Book(
                path: entity.path,
                title:
                    existingMetadata?.title ??
                    Book.getTitleFromPath(entity.path),
                format: format,
                lastModified: File(entity.path).lastModifiedSync(),
                dateAdded: existingMetadata?.dateAdded ?? DateTime.now(),
                author: existingMetadata?.author,
                series: existingMetadata?.series,
                coverImage: existingMetadata?.coverImage,
              ),
            );
          }
        }
      }

      // Remove books that no longer exist in the filesystem
      final orphanedBooks = await _databaseService.getOrphanedBooks(
        existingPaths,
      );
      for (final book in orphanedBooks) {
        await _databaseService.deleteBook(book.path);
      }
    } catch (e) {
      print("Error scanning directory: $e");
      // Depending on the error, you might want to return partial results or empty
    }

    return books;
  }
}
