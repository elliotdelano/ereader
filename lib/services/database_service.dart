import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book_metadata.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ereader.db');
    return await openDatabase(
      path,
      version: 5, // Increment version for coverImagePath
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT UNIQUE,
        title TEXT NOT NULL,
        author TEXT,
        series TEXT,
        coverImagePath TEXT,
        lastModified TEXT NOT NULL,
        dateAdded TEXT NOT NULL,
        format TEXT NOT NULL,
        readingPercentage REAL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.delete('books');
      print("Database upgraded to V5 (deleted books table)");
    }
  }

  // Insert a new book metadata
  Future<int> insertBook(BookMetadata book) async {
    final db = await database;
    return await db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all books
  Future<List<BookMetadata>> getAllBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(maps.length, (i) => BookMetadata.fromMap(maps[i]));
  }

  // Get a book by path
  Future<BookMetadata?> getBookByPath(String path) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (maps.isEmpty) return null;
    return BookMetadata.fromMap(maps.first);
  }

  // Update a book's metadata
  Future<int> updateBook(BookMetadata book) async {
    final db = await database;
    final map = book.toMap();
    // Remove id from the update operation
    map.remove('id');
    return await db.update(
      'books',
      map,
      where: 'path = ?',
      whereArgs: [book.path],
    );
  }

  // Delete a book by path
  Future<int> deleteBook(String path) async {
    final db = await database;
    return await db.delete('books', where: 'path = ?', whereArgs: [path]);
  }

  // Delete all books
  Future<void> deleteAllBooks() async {
    final db = await database;
    await db.delete('books');
  }

  // Get books that don't exist in the filesystem
  Future<List<BookMetadata>> getOrphanedBooks(
    List<String> existingPaths,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(
      maps.length,
      (i) => BookMetadata.fromMap(maps[i]),
    ).where((book) => !existingPaths.contains(book.path)).toList();
  }
}
