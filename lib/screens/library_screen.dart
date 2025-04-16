import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../widgets/book_edit_sheet.dart';
import 'reader_screen.dart';
import '../widgets/book_search_delegate.dart';
import '../widgets/app_drawer.dart';

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
  Set<String> _currentlyReadingPaths = {};
  List<Book> _currentlyReadingBooks = [];
  List<Book> _otherBooks = [];

  @override
  void initState() {
    super.initState();
    _loadSavedDirectory();
  }

  Future<void> _loadSavedDirectory() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait([
      _storageService.loadSortSettings(),
      _storageService.loadCurrentlyReading(),
    ]);

    final (loadedSortOption, loadedSortAscending) =
        results[0] as (SortOption, bool);
    _currentlyReadingPaths = results[1] as Set<String>;

    try {
      final savedPath = await _storageService.getSelectedFolderPath();
      if (savedPath != null) {
        setState(() {
          _currentSort = loadedSortOption;
          _sortAscending = loadedSortAscending;
          _selectedDirectory = savedPath;
        });
        await _loadBooks();
      } else {
        setState(() {
          _currentSort = loadedSortOption;
          _sortAscending = loadedSortAscending;
        });
      }
    } catch (e) {
      print('Error loading saved directory or settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _processAndSortBooks() {
    _currentlyReadingBooks =
        _books
            .where((book) => _currentlyReadingPaths.contains(book.path))
            .toList();
    _otherBooks =
        _books
            .where((book) => !_currentlyReadingPaths.contains(book.path))
            .toList();

    _sortBookList(_currentlyReadingBooks);
    _sortBookList(_otherBooks);
  }

  void _sortBookList(List<Book> listToSort) {
    listToSort.sort((a, b) {
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      _currentlyReadingPaths = await _storageService.loadCurrentlyReading();

      List<Book> initialBooks = await _fileService.scanForBooks(
        _selectedDirectory!,
      );
      List<Book> booksWithProgress = [];

      for (final book in initialBooks) {
        final progressData = await _storageService.loadReadingProgress(
          book.path,
        );
        booksWithProgress.add(
          book.copyWith(
            readingPercentage: progressData?['percentage'] as double?,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _books = booksWithProgress;
          _processAndSortBooks();
        });
      }
    } catch (e) {
      print('Error loading books: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading books: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSortSettings() async {
    await _storageService.saveSortSettings(_currentSort, _sortAscending);
  }

  void _updateCurrentlyReadingStatus(String path, bool isReading) async {
    if (isReading) {
      _currentlyReadingPaths.add(path);
    } else {
      _currentlyReadingPaths.remove(path);
    }
    setState(() {
      _processAndSortBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    // final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // final Color currentlyReadingColor = colorScheme.surfaceContainerHighest;
    // final Color defaultItemColor = colorScheme.surface;

    final List<Book> combinedList = [..._currentlyReadingBooks, ..._otherBooks];
    final int currentlyReadingCount = _currentlyReadingBooks.length;

    return Scaffold(
      // backgroundColor: defaultItemColor,
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open Menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: const Text('Library'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Books',
            onSelected: (SortOption option) {
              setState(() {
                if (_currentSort == option) {
                  _sortAscending = !_sortAscending;
                } else {
                  _currentSort = option;
                  _sortAscending = true;
                }
                _processAndSortBooks();
                _saveSortSettings();
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
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            tooltip: _sortAscending ? 'Sort Descending' : 'Sort Ascending',
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _processAndSortBooks();
                _saveSortSettings();
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
              final Book? selectedBook = await showSearch<Book?>(
                context: context,
                delegate: BookSearchDelegate(allBooks: combinedList),
              );

              if (selectedBook != null && mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(book: selectedBook),
                  ),
                );
                await _loadBooks();
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
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
              : combinedList.isEmpty
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
                  itemCount:
                      _otherBooks.length + (currentlyReadingCount > 0 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (currentlyReadingCount > 0 && index == 0) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // color: currentlyReadingColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 12.0,
                                left: 16.0,
                                bottom: 4.0,
                              ),
                              child: Text(
                                "Currently Reading",
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: currentlyReadingCount,
                              itemBuilder: (context, crIndex) {
                                final book = _currentlyReadingBooks[crIndex];
                                return _buildBookListItem(book, crIndex, true);
                              },
                            ),
                          ],
                        ),
                      );
                    } else {
                      final otherIndex =
                          index - (currentlyReadingCount > 0 ? 1 : 0);
                      if (otherIndex >= _otherBooks.length) return null;

                      final book = _otherBooks[otherIndex];
                      return Container(
                        // color: defaultItemColor,
                        child: _buildBookListItem(book, otherIndex, false),
                      );
                    }
                  },
                ),
              ),
    );
  }

  Widget _buildBookListItem(
    Book book,
    int index,
    bool partOfCurrentlyReadingList,
  ) {
    final bool isActive = book.active;
    final double opacity = isActive ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: ListTile(
        enabled: isActive,
        leading:
            book.coverImagePath != null && book.coverImagePath!.isNotEmpty
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
        title: Text(book.title, overflow: TextOverflow.ellipsis, maxLines: 1),
        isThreeLine:
            book.readingPercentage != null && book.readingPercentage! > 0.01,
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
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.mode_edit_outline_rounded),
              tooltip: 'Edit Book Info',
              onPressed: () async {
                await showModalBottomSheet<bool?>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder:
                      (context) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: BookEditSheet(
                          book: book,
                          onBookUpdated: (updatedBook) {
                            final originalIndex = _books.indexWhere(
                              (b) => b.path == updatedBook.path,
                            );
                            if (originalIndex != -1) {
                              setState(() {
                                _books[originalIndex] = updatedBook;
                                _processAndSortBooks();
                              });
                            }
                          },
                        ),
                      ),
                );
                await _loadBooks();
              },
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Delete Book',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Delete Book?'),
                      content: Text(
                        'Are you sure you want to delete "${book.title}"?\n(This action cannot be undone)',
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true && mounted) {
                  print("TODO: Delete book at path: ${book.path}");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Deletion for "${book.title}" not yet implemented.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        onTap: () async {
          if (isActive) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ReaderScreen(book: book)),
            );
            await _loadBooks();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${book.title} is unavailable (file missing or invalid).',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDefaultIcon(Book book) {
    return Container(
      width: 40,
      height: 60,
      decoration: BoxDecoration(
        // color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        book.format == BookFormat.epub ? Icons.book : Icons.picture_as_pdf,
        // color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
