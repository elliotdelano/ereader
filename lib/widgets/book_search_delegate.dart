import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
// Removed ReaderScreen import - navigation should happen in LibraryScreen

class BookSearchDelegate extends SearchDelegate<Book?> {
  final List<Book> allBooks;
  List<Book> _filteredBooks = []; // To store filtered results

  BookSearchDelegate({required this.allBooks});

  // Helper function to filter books based on the query
  void _filterBooks(String query) {
    if (query.isEmpty) {
      _filteredBooks = []; // No results if query is empty
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    _filteredBooks =
        allBooks.where((book) {
          final titleMatch = book.title.toLowerCase().contains(lowerCaseQuery);
          final authorMatch =
              book.author?.toLowerCase().contains(lowerCaseQuery) ?? false;
          final seriesMatch =
              book.series?.toLowerCase().contains(lowerCaseQuery) ?? false;
          // Ensure matches only return true if the field exists and contains the query
          return titleMatch || (authorMatch) || (seriesMatch);
        }).toList();
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    // Customize search app bar theme if desired
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        // Keep app bar consistent with the main theme
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        foregroundColor:
            Theme.of(context).appBarTheme.foregroundColor ??
            Theme.of(context).colorScheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 1.0, // Add subtle elevation
      ),
      inputDecorationTheme:
          searchFieldDecorationTheme ??
          InputDecorationTheme(
            hintStyle: TextStyle(color: Theme.of(context).hintColor),
            // Remove underline
            border: InputBorder.none,
          ),
    );
  }

  // Action button (e.g., clear query)
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: () {
            query = '';
            showSuggestions(context); // Rebuild suggestions with empty query
          },
        ),
    ];
  }

  // Leading button (e.g., back)
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        close(context, null); // Close search returning null
      },
    );
  }

  // Build results page (shown when user submits the search)
  @override
  Widget buildResults(BuildContext context) {
    _filterBooks(query); // Ensure filtering happens on submit
    // Typically looks same as suggestions for this use case
    return _buildBookListView(_filteredBooks);
  }

  // Build suggestions list (shown while user is typing)
  @override
  Widget buildSuggestions(BuildContext context) {
    _filterBooks(query); // Filter as user types
    return _buildBookListView(_filteredBooks);
  }

  // Helper to build the list view for both suggestions and results
  Widget _buildBookListView(List<Book> booksToShow) {
    // Provide initial prompt or no results message
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Search by title, author, or series.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (booksToShow.isEmpty) {
      return const Center(child: Text('No books found.'));
    }

    return ListView.builder(
      itemCount: booksToShow.length,
      itemBuilder: (context, index) {
        final book = booksToShow[index];
        // Using a slightly modified ListTile for search results/suggestions
        return ListTile(
          leading:
              book.coverImagePath != null && book.coverImagePath!.isNotEmpty
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(book.coverImagePath!),
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              _buildDefaultIcon(context, book),
                    ),
                  )
                  : _buildDefaultIcon(context, book),
          title: Text(book.title),
          subtitle: Text(book.author ?? 'Unknown Author'),
          onTap: () {
            // When a suggestion/result is tapped:
            // 1. Close the search interface
            // 2. Pass the selected book back to the LibraryScreen
            close(context, book);
            // Navigation happens in the LibraryScreen's .then() block
          },
        );
      },
    );
  }

  // Reusable default icon builder (needs context for Theme)
  Widget _buildDefaultIcon(BuildContext context, Book book) {
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
