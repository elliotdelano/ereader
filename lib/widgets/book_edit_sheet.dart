import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../models/book_metadata.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';

class BookEditSheet extends StatefulWidget {
  final Book book;
  final Function(Book) onBookUpdated;

  const BookEditSheet({
    super.key,
    required this.book,
    required this.onBookUpdated,
  });

  @override
  State<BookEditSheet> createState() => _BookEditSheetState();
}

class _BookEditSheetState extends State<BookEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _seriesController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  bool _isLoading = false;
  bool _isCurrentlyReading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.book.title;
    _authorController.text = widget.book.author ?? '';
    _seriesController.text = widget.book.series ?? '';
    _loadCurrentlyReadingStatus();
  }

  Future<void> _loadCurrentlyReadingStatus() async {
    final currentSet = await _storageService.loadCurrentlyReading();
    if (mounted) {
      setState(() {
        _isCurrentlyReading = currentSet.contains(widget.book.path);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _seriesController.dispose();
    super.dispose();
  }

  Future<void> _toggleCurrentlyReading(bool value) async {
    setState(() {
      _isCurrentlyReading = value;
      _isLoading = true;
    });

    try {
      final currentSet = await _storageService.loadCurrentlyReading();
      if (value) {
        currentSet.add(widget.book.path);
      } else {
        currentSet.remove(widget.book.path);
      }
      await _storageService.saveCurrentlyReading(currentSet);
      print("Set currently reading for ${widget.book.path} to: $value");
    } catch (e) {
      setState(() {
        _isCurrentlyReading = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedMetadata = BookMetadata(
        path: widget.book.path,
        title: _titleController.text.trim(),
        author:
            _authorController.text.trim().isEmpty
                ? null
                : _authorController.text.trim(),
        series:
            _seriesController.text.trim().isEmpty
                ? null
                : _seriesController.text.trim(),
        coverImagePath: widget.book.coverImagePath,
        lastModified: widget.book.lastModified,
        dateAdded: widget.book.dateAdded,
        format: widget.book.format == BookFormat.epub ? 'epub' : 'pdf',
      );

      await _databaseService.updateBook(updatedMetadata);

      final updatedBook = Book.fromMetadata(updatedMetadata);

      widget.onBookUpdated(updatedBook);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving changes: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Book Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _seriesController,
                  decoration: const InputDecoration(
                    labelText: 'Series',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Currently Reading'),
                  value: _isCurrentlyReading,
                  onChanged: _isLoading ? null : _toggleCurrentlyReading,
                  secondary: Icon(
                    _isCurrentlyReading
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
