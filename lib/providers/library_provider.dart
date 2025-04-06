import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_metadata.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';

enum SortOption { title, author, dateAdded, lastModified, series }

class LibraryProvider with ChangeNotifier {
  List<Book> _books = [];
  String? _selectedFolderPath;
  bool _isLoading = false;
  SortOption _currentSort = SortOption.title;
  bool _sortAscending = true;
  final FileService _fileService = FileService();
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();

  LibraryProvider() {
    _loadInitialData();
  }

  List<Book> get books => _books;
  String? get selectedFolderPath => _selectedFolderPath;
  bool get isLoading => _isLoading;
  SortOption get currentSort => _currentSort;
  bool get sortAscending => _sortAscending;

  void setSortOption(SortOption option) {
    if (_currentSort == option) {
      // Toggle direction if same option selected
      _sortAscending = !_sortAscending;
    } else {
      _currentSort = option;
      _sortAscending = true;
    }
    _sortBooks();
    notifyListeners();
  }

  void _sortBooks() {
    _books.sort((a, b) {
      int comparison;
      switch (_currentSort) {
        case SortOption.title:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case SortOption.author:
          final aAuthor = a.author?.toLowerCase() ?? '';
          final bAuthor = b.author?.toLowerCase() ?? '';
          comparison = aAuthor.compareTo(bAuthor);
          if (comparison == 0) {
            // If authors are equal, sort by title
            comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
        case SortOption.dateAdded:
          comparison = a.dateAdded.compareTo(b.dateAdded);
          break;
        case SortOption.lastModified:
          comparison = a.lastModified.compareTo(b.lastModified);
          break;
        case SortOption.series:
          final aSeries = a.series?.toLowerCase() ?? '';
          final bSeries = b.series?.toLowerCase() ?? '';
          comparison = aSeries.compareTo(bSeries);
          if (comparison == 0) {
            // If series are equal, sort by title
            comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  Future<void> _loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    _selectedFolderPath = await _storageService.getSelectedFolderPath();
    if (_selectedFolderPath != null) {
      await scanDirectory(_selectedFolderPath!);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectDirectory() async {
    _isLoading = true;
    notifyListeners();

    final path = await _fileService.pickDirectory();
    if (path != null) {
      _selectedFolderPath = path;
      await _storageService.setSelectedFolderPath(path);
      await scanDirectory(path);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> scanDirectory(String path) async {
    _isLoading = true;
    notifyListeners();

    try {
      // First, get all books from the database
      final List<BookMetadata> storedBooks =
          await _databaseService.getAllBooks();

      // Then scan the directory for current books
      _books = await _fileService.scanForBooks(path);

      // Update the UI with the latest metadata from the database
      for (int i = 0; i < _books.length; i++) {
        final storedBook = storedBooks.firstWhere(
          (b) => b.path == _books[i].path,
          orElse:
              () => BookMetadata(
                path: _books[i].path,
                title: _books[i].title,
                format: _books[i].format == BookFormat.epub ? 'epub' : 'pdf',
                lastModified: _books[i].lastModified,
                dateAdded: _books[i].dateAdded,
              ),
        );
        _books[i] = Book.fromMetadata(storedBook);
      }

      // Sort books according to current sort option
      _sortBooks();
    } catch (e) {
      print("Error scanning directory: $e");
      _books = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void updateBook(Book updatedBook) {
    final index = _books.indexWhere((book) => book.path == updatedBook.path);
    if (index != -1) {
      _books[index] = updatedBook;
      _sortBooks();
      notifyListeners();
    }
  }

  // Add methods for managing books if needed (e.g., removing)
}
