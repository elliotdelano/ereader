import 'dart:typed_data';

class BookMetadata {
  final int? id;
  final String path;
  final String title;
  final String? author;
  final String? series;
  final Uint8List? coverImage;
  final DateTime lastModified;
  final DateTime dateAdded;
  final String format; // 'epub' or 'pdf'

  BookMetadata({
    this.id,
    required this.path,
    required this.title,
    this.author,
    this.series,
    this.coverImage,
    required this.lastModified,
    required this.dateAdded,
    required this.format,
  });

  // Convert a BookMetadata instance into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'author': author,
      'series': series,
      'coverImage': coverImage,
      'lastModified': lastModified.toIso8601String(),
      'dateAdded': dateAdded.toIso8601String(),
      'format': format,
    };
  }

  // Create a BookMetadata instance from a Map
  factory BookMetadata.fromMap(Map<String, dynamic> map) {
    return BookMetadata(
      id: map['id'],
      path: map['path'],
      title: map['title'],
      author: map['author'],
      series: map['series'],
      coverImage: map['coverImage'] as Uint8List?,
      lastModified: DateTime.parse(map['lastModified']),
      dateAdded: DateTime.parse(map['dateAdded']),
      format: map['format'],
    );
  }
}
