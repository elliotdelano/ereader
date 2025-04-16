import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';
import '../models/book_metadata.dart';
import 'database_service.dart';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FileService {
  final DatabaseService _databaseService = DatabaseService();

  Future<PermissionStatus> _requestLegacyStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      return await Permission.storage.request();
    }
    return status;
  }

  Future<PermissionStatus> _requestManageExternalStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      return await Permission.manageExternalStorage.request();
    }
    return status;
  }

  // Pick a directory using file_picker
  Future<String?> pickDirectory() async {
    // Request permissions first (especially important on Android)
    // On Desktop, file_picker often handles this implicitly, but good practice.
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt < 29) {
        status = await _requestLegacyStoragePermission();
      } else {
        status = await _requestManageExternalStoragePermission();
      }
      if (!status.isGranted) {
        print("Storage permission already granted."); // Log if already granted
      }
    } else {
      print(
        "Not on Android, skipping permission request.",
      ); // Log if not Android
    }
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

      // Extract and save cover image
      String? coverImagePath;

      try {
        final coverImageContent = await epubBook.readCover();
        if (coverImageContent != null) {
          final rawBytes = coverImageContent.getBytes();
          // Create an ImageData object from the raw RGBA pixels
          final imageData = ui.ImageDescriptor.raw(
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
            // Get app docs directory
            final docDir = await getApplicationDocumentsDirectory();
            final coversDir = Directory(path.join(docDir.path, 'covers'));
            if (!await coversDir.exists()) {
              await coversDir.create(recursive: true);
            }

            // Generate filename from hash of book path
            final bookPathBytes = utf8.encode(epubPath);
            final digest = sha1.convert(bookPathBytes);
            final filename = '${digest.toString()}.png';
            final filePath = path.join(coversDir.path, filename);

            // Save the image file
            final imageFile = File(filePath);
            await imageFile.writeAsBytes(pngBytes.buffer.asUint8List());
            coverImagePath = filePath;
            // print("Saved cover image to: $coverImagePath");
          }

          // Clean up
          frame.image.dispose();
          codec.dispose();
        }
      } catch (e) {
        print("Error processing or saving cover image: $e");
        // Continue without cover image if extraction fails
      }

      return BookMetadata(
        path: epubPath,
        title: epubBook.Title ?? Book.getTitleFromPath(epubPath),
        author: epubBook.Author,
        series: null, // EPUB standard doesn't have a series field
        coverImagePath: coverImagePath,
        lastModified: File(epubPath).lastModifiedSync(),
        dateAdded: DateTime.now(),
        format: 'epub',
        active: true,
      );
    } catch (e) {
      print("Error extracting EPUB metadata for $epubPath: $e");
      return null;
    }
  }

  // Extract metadata from a PDF file
  Future<BookMetadata?> _extractPdfMetadata(String path) async {
    try {
      return BookMetadata(
        path: path,
        title: Book.getTitleFromPath(path),
        author: null,
        series: null,
        coverImagePath: null,
        lastModified: File(path).lastModifiedSync(),
        dateAdded: DateTime.now(),
        format: 'pdf',
        active: true,
      );
    } catch (e) {
      print("Error extracting PDF metadata: $e");
      return null;
    }
  }

  Future<List<Book>> getActiveBooks() async {
    final books = await _databaseService.getAllBooks();

    // For each book, check if the file still exists in the filesystem
    // if not set its active status to false
    for (final book in books) {
      if (!File(book.path).existsSync()) {
        await _databaseService.updateBook(book.copyWith(active: false));
      }
    }

    return books.map((book) => Book.fromMetadata(book)).toList();
  }

  //TODO: redo scan to support multiple directories and individual files
  // Scan a directory recursively for supported book files
  Future<List<Book>> scanForBooks(String directoryPath) async {
    // final List<Book> books = [];
    // final List<String> existingPaths = [];
    final directory = Directory(directoryPath);

    if (!await directory.exists()) {
      print("Directory does not exist: $directoryPath");
      return []; // Return empty list if directory doesn't exist
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
            // existingPaths.add(entity.path);

            // Check if we already have this book in the database
            BookMetadata? existingMetadata = await _databaseService
                .getBookByPath(entity.path);

            bool metadataNeedsUpdate = false;
            if (existingMetadata == null) {
              // New book: Extract, store metadata, set flag
              metadataNeedsUpdate = true;
            } else {
              // Existing book: Check if file modified time is newer than stored
              final fileLastModified = File(entity.path).lastModifiedSync();
              if (fileLastModified.isAfter(existingMetadata.lastModified)) {
                // File changed: Re-extract, update metadata, set flag
                metadataNeedsUpdate = true;
                // print(
                //   "File modified, re-extracting metadata for: ${entity.path}",
                // );
              }
            }

            // If new or changed, extract/update metadata in DB
            if (metadataNeedsUpdate) {
              BookMetadata? extractedMetadata;
              if (format == BookFormat.epub) {
                extractedMetadata = await _extractEpubMetadata(entity.path);
              } else if (format == BookFormat.pdf) {
                extractedMetadata = await _extractPdfMetadata(entity.path);
              }

              if (extractedMetadata != null) {
                if (existingMetadata == null) {
                  await _databaseService.insertBook(extractedMetadata);
                } else {
                  // Preserve ID when updating
                  await _databaseService.updateBook(extractedMetadata);
                }
                existingMetadata = await _databaseService.getBookByPath(
                  entity.path,
                );
              }
            }

            // Create Book instance using the latest metadata (either existing or updated)
            // if (existingMetadata != null) {
            //   books.add(Book.fromMetadata(existingMetadata));
            // } else {
            //   print(
            //     "Warning: Could not get metadata for ${entity.path}, creating Book with fallback title.",
            //   );
            //   books.add(
            //     Book(
            //       path: entity.path,
            //       title: Book.getTitleFromPath(entity.path),
            //       format: format,
            //       lastModified: File(entity.path).lastModifiedSync(),
            //       dateAdded: DateTime.now(),
            //     ),
            //   );
            // }
          }
        }
      }

      // Remove books that no longer exist in the filesystem - REMOVED LOGIC
      // final orphanedBooks = await _databaseService.getOrphanedBooks(
      //   existingPaths,
      // );
      // for (final book in orphanedBooks) {
      //   await _databaseService.deleteBook(book.path);
      // }
    } catch (e) {
      print("Error scanning directory: $e");
      // Depending on the error, you might want to return partial results or empty
    }

    return getActiveBooks();
  }

  Future<Book?> retrieveSingleFile(String path) async {
    final format = Book.getFormatFromPath(path);
    if (format != BookFormat.epub) {
      return null;
    }

    BookMetadata? metadata = await _databaseService.getBookByPath(path);
    if (metadata == null) {
      metadata = await _extractEpubMetadata(path);
      if (metadata != null) {
        await _databaseService.insertBook(metadata);
      }
    }

    if (metadata == null) {
      return null;
    }

    return Book.fromMetadata(metadata);
  }
}
