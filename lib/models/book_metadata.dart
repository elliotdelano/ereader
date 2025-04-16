class BookMetadata {
  final int? id;
  final String path;
  final String title;
  final String? author;
  final String? series;
  final String? coverImagePath; // Path to saved cover image file
  final DateTime lastModified;
  final DateTime dateAdded;
  final String format; // 'epub' or 'pdf'
  final double? readingPercentage;
  final bool active;

  BookMetadata({
    this.id,
    required this.path,
    required this.title,
    this.author,
    this.series,
    this.coverImagePath,
    required this.lastModified,
    required this.dateAdded,
    required this.format,
    this.readingPercentage,
    this.active = true,
  });

  // Convert a BookMetadata instance into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'author': author,
      'series': series,
      'coverImagePath': coverImagePath,
      'lastModified': lastModified.toIso8601String(),
      'dateAdded': dateAdded.toIso8601String(),
      'format': format,
      'readingPercentage': readingPercentage,
      'active': active ? 1 : 0,
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
      coverImagePath: map['coverImagePath'] as String?,
      lastModified: DateTime.parse(map['lastModified']),
      dateAdded: DateTime.parse(map['dateAdded']),
      format: map['format'],
      readingPercentage: map['readingPercentage'] as double?,
      active: map['active'] == 1,
    );
  }

  BookMetadata copyWith({bool? active}) {
    return BookMetadata(
      id: id,
      path: path,
      title: title,
      author: author,
      series: series,
      coverImagePath: coverImagePath,
      lastModified: lastModified,
      dateAdded: dateAdded,
      format: format,
      readingPercentage: readingPercentage,
      active: active ?? this.active,
    );
  }
}
