import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:xml/xml.dart';

class EpubServerService {
  HttpServer? _server;
  String? _epubPath;
  String? _tempDir;
  String? _startPath;
  String? _customCss; // Store the current CSS
  Map<String, String>? _manifest;
  List<String>? _spine;

  // Add getter for the spine
  List<String>? get spineHrefs => _spine;

  Future<String?> start(String epubPath, {String? customCss}) async {
    _epubPath = epubPath;
    _customCss = customCss;
    try {
      await _unpackEpub();
      await _parseOpf();
      _startServer();
      return _startPath;
    } catch (e) {
      print('Error starting EPUB server: $e');
      await stop(); // Clean up on error
      return null;
    }
  }

  // Call this to update the CSS, for example when ReaderSettingsProvider changes.
  void updateCss(String css) {
    _customCss = css;
  }

  Future<void> stop() async {
    await _server?.close();
    if (_tempDir != null) {
      try {
        await Directory(_tempDir!).delete(recursive: true);
      } catch (e) {
        print('Error cleaning up temp directory: $e');
      }
    }
    _server = null;
    _tempDir = null;
    _startPath = null;
    _manifest = null;
    _spine = null;
  }

  Future<void> _unpackEpub() async {
    if (!File(_epubPath!).existsSync()) {
      throw Exception('EPUB file not found: $_epubPath');
    }

    final bytes = await File(_epubPath!).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find container.xml to locate the OPF file
    final containerEntry = archive.findFile('META-INF/container.xml');
    if (containerEntry == null) {
      throw Exception('Invalid EPUB: Missing container.xml');
    }

    _tempDir = '${(await getTemporaryDirectory()).path}/epub_temp';
    await Directory(_tempDir!).create(recursive: true);

    for (final file in archive) {
      final filename = '$_tempDir/${file.name}';
      if (file.isFile) {
        final outFile = File(filename);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filename).create(recursive: true);
      }
    }
  }

  Future<void> _parseOpf() async {
    // First find the OPF file from container.xml
    final containerXml = File('$_tempDir/META-INF/container.xml');
    if (!await containerXml.exists()) {
      throw Exception('Container.xml not found');
    }

    final containerDoc = XmlDocument.parse(await containerXml.readAsString());
    final rootfilePath = containerDoc
        .findAllElements('rootfile')
        .first
        .getAttribute('full-path');

    if (rootfilePath == null) {
      throw Exception('Could not find OPF file path in container.xml');
    }

    final opfFile = File('$_tempDir/$rootfilePath');
    if (!await opfFile.exists()) {
      throw Exception('OPF file not found at: $rootfilePath');
    }

    final opfDoc = XmlDocument.parse(await opfFile.readAsString());

    // Parse manifest
    _manifest = {};
    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        _manifest![id] = href;
      }
    }

    // Parse spine
    _spine = [];
    for (final itemref in opfDoc.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null && _manifest!.containsKey(idref)) {
        _spine!.add(_manifest![idref]!);
      }
    }

    if (_spine!.isEmpty) {
      throw Exception('No content found in EPUB spine');
    }

    // Set the start path to the first item in the spine
    _startPath = 'http://localhost:8080/${_spine!.first}';
  }

  // Custom handler that will inject CSS into HTML pages on the fly.
  Handler _customStaticHandler() {
    final staticHandler = createStaticHandler(
      _tempDir ?? '',
      defaultDocument: 'index.html',
    );

    return (Request request) async {
      final response = await staticHandler(request);
      // Check if the response has an HTML content type and a body to modify
      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('html') == true &&
          _customCss != null) {
        // Read the entire response body
        final body = await response.readAsString();
        // Inject our custom CSS inside the <head> tag.
        // Use a more robust regex for the <head> tag
        final injectedBody = body.replaceFirst(
          RegExp(r'<head.*?>', caseSensitive: false),
          '<head><style>${_customCss!}</style>',
        );
        return response.change(body: injectedBody);
      }
      return response;
    };
  }

  void _startServer() {
    final handler = Cascade().add(_customStaticHandler()).handler;

    shelf_io.serve(handler, 'localhost', 8080).then((server) {
      _server = server;
      print('Serving at http://${server.address.host}:${server.port}');
    });
  }
}
