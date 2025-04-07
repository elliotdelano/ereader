import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../widgets/book_edit_sheet.dart';
import 'reader_screen.dart';
import '../widgets/book_search_delegate.dart';

enum SortOption { title, author, dateAdded, lastModified, series }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FileService _fileService = FileService();
  final StorageService _storageService = StorageService();
  List<Book> _books = [];
  bool _isLoading = false;
  String? _selectedDirectory;
  SortOption _currentSort = SortOption.title;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadSavedDirectory();
  }

  Future<void> _loadSavedDirectory() async {
    setState(() {
      _isLoading = true;
    });

    // Load sort settings first
    final (loadedSortOption, loadedSortAscending) =
        await _storageService.loadSortSettings();

    try {
      final savedPath = await _storageService.getSelectedFolderPath();
      if (savedPath != null) {
        setState(() {
          // Apply loaded settings before loading books
          _currentSort = loadedSortOption;
          _sortAscending = loadedSortAscending;
          _selectedDirectory = savedPath;
        });
        await _loadBooks();
      } else {
        // No saved path, but still apply loaded/default sort settings
        setState(() {
          _currentSort = loadedSortOption;
          _sortAscending = loadedSortAscending;
        });
      }
    } catch (e) {
      print('Error loading saved directory or settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _selectDirectory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await _fileService.pickDirectory();
      if (directory != null) {
        await _storageService.setSelectedFolderPath(directory);
        setState(() {
          _selectedDirectory = directory;
        });
        await _loadBooks();
      } else {
        // User canceled directory selection
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error selecting directory: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBooks() async {
    if (_selectedDirectory == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Load initial book list (without percentage)
      List<Book> initialBooks = await _fileService.scanForBooks(
        _selectedDirectory!,
      );

      // Create a new list to hold books with percentages
      List<Book> booksWithProgress = [];

      // Load progress for each book
      for (final book in initialBooks) {
        final progressData = await _storageService.loadReadingProgress(
          book.path,
        );
        if (progressData != null && progressData['percentage'] is double) {
          // Create a new book instance with the loaded percentage
          booksWithProgress.add(
            book.copyWith(
              readingPercentage: progressData['percentage'] as double,
            ),
          );
        } else {
          // Add the book without progress if none was saved
          booksWithProgress.add(book);
        }
      }

      setState(() {
        _books =
            booksWithProgress; // Update state with the list containing percentages
        _sortBooks();
      });
    } catch (e) {
      // Handle error
      print('Error loading books: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSortSettings() async {
    await _storageService.saveSortSettings(_currentSort, _sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          // Sort menu
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Books',
            onSelected: (SortOption option) {
              setState(() {
                if (_currentSort == option) {
                  // Direction is toggled by the dedicated button now
                  _sortAscending = !_sortAscending;
                } else {
                  _currentSort = option;
                  _sortAscending =
                      true; // Default to ascending when changing sort type
                }
                _sortBooks();
                _saveSortSettings(); // Save settings when sort type changes
              });
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<SortOption>>[
                  const PopupMenuItem<SortOption>(
                    value: SortOption.title,
                    child: Text('Sort by Title'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.author,
                    child: Text('Sort by Author'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.series,
                    child: Text('Sort by Series'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.dateAdded,
                    child: Text('Sort by Date Added'),
                  ),
                  const PopupMenuItem<SortOption>(
                    value: SortOption.lastModified,
                    child: Text('Sort by Last Modified'),
                  ),
                ],
          ),
          // Sort Direction Toggle Button
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            tooltip: _sortAscending ? 'Sort Descending' : 'Sort Ascending',
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _sortBooks();
                _saveSortSettings(); // Save settings when direction changes
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _selectDirectory,
            tooltip: 'Select Ebook Folder',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Library',
            onPressed: () async {
              // Show the search page and wait for a result (a selected Book or null)
              final Book? selectedBook = await showSearch<Book?>(
                context: context,
                delegate: BookSearchDelegate(allBooks: _books),
              );

              // If the user selected a book from search, navigate to it
              if (selectedBook != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(book: selectedBook),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _selectedDirectory == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Select a folder to start your library.'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Folder'),
                      onPressed: _selectDirectory,
                    ),
                  ],
                ),
              )
              : _books.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No books found in the selected folder.'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Another Folder'),
                      onPressed: _selectDirectory,
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadBooks,
                child: ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return ListTile(
                      leading:
                          book.coverImagePath != null &&
                                  book.coverImagePath!.isNotEmpty
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  File(book.coverImagePath!),
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultIcon(book);
                                  },
                                ),
                              )
                              : _buildDefaultIcon(book),
                      title: Text(book.title),
                      isThreeLine:
                          book.readingPercentage != null &&
                          book.readingPercentage! > 0.01,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book.author ?? 'Unknown Author'),
                          if (book.readingPercentage != null &&
                              book.readingPercentage! > 0.01) ...[
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: book.readingPercentage!,
                              minHeight: 6,
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder:
                                  (context) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          MediaQuery.of(
                                            context,
                                          ).viewInsets.bottom,
                                    ),
                                    child: BookEditSheet(
                                      book: book,
                                      onBookUpdated: (updatedBook) {
                                        setState(() {
                                          _books[index] = updatedBook;
                                          _sortBooks();
                                        });
                                      },
                                    ),
                                  ),
                            );
                          } else if (value == 'delete') {
                            // Handle delete
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReaderScreen(book: book),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
    );
  }

  Widget _buildDefaultIcon(Book book) {
    return Container(
      width: 40,
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        book.format == BookFormat.epub ? Icons.book : Icons.picture_as_pdf,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
