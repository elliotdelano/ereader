import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:xml/xml.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/services.dart' show rootBundle;

class EpubServerService {
  HttpServer? _server;
  String? _epubPath;
  String? _tempDir;
  String? _contentBasePath;
  String? _viewerHtmlContent;
  String? _opfRelativePath;

  Future<Map<String, String>?> start(String epubPath) async {
    _epubPath = epubPath;
    try {
      await _unpackEpub();
      await _parseOpfAndDetermineBasePath();
      await _loadViewerHtml();

      // Create a completer to wait for the server to start
      final completer = Completer<Map<String, String>>();

      _startServer()
          .then((server) {
            _server = server;
            if (_server != null && _opfRelativePath != null) {
              final response = {
                'baseUrl': 'http://${_server!.address.host}:${_server!.port}',
                'opfRelativePath': _opfRelativePath!,
              };
              if (!completer.isCompleted) completer.complete(response);
            } else if (!completer.isCompleted) {
              completer.completeError(
                'Server started but OPF path is missing or server is null.',
              );
            }
          })
          .catchError((e) {
            print("Error starting server: $e");
            if (!completer.isCompleted) completer.completeError(e);
          });

      // Wait for the server to start with a timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print("Server start timed out");
          throw TimeoutException("Server start timed out");
        },
      );
    } catch (e) {
      print('Error starting EPUB server: $e');
      await stop();
      rethrow;
    }
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
    _contentBasePath = null;
    _viewerHtmlContent = null;
    _opfRelativePath = null;
  }

  Future<void> _unpackEpub() async {
    print('Starting EPUB unpacking process...');
    if (!File(_epubPath!).existsSync()) {
      print('EPUB file not found at path: $_epubPath');
      throw Exception('EPUB file not found: $_epubPath');
    }
    print('EPUB file found, reading bytes...');

    final bytes = await File(_epubPath!).readAsBytes();
    print('EPUB file read, decoding zip...');
    final archive = ZipDecoder().decodeBytes(bytes);
    print('Zip decoded, found ${archive.files.length} files');

    final containerEntry = archive.findFile('META-INF/container.xml');
    if (containerEntry == null) {
      print('container.xml not found in archive');
      throw Exception('Invalid EPUB: Missing container.xml');
    }
    print('container.xml found in archive');

    _tempDir =
        '${(await getTemporaryDirectory()).path}/epub_temp_${DateTime.now().millisecondsSinceEpoch}';
    print('Creating temp directory at: $_tempDir');

    if (await Directory(_tempDir!).exists()) {
      print('Removing existing temp directory');
      await Directory(_tempDir!).delete(recursive: true);
    }
    await Directory(_tempDir!).create(recursive: true);
    print('Temp directory created');

    print('Extracting files...');
    for (final file in archive) {
      // Skip directory entries as they're created automatically
      if (!file.isFile || file.name.endsWith('/')) {
        print('Skipping directory entry: ${file.name}');
        continue;
      }

      final filename = '$_tempDir/${file.name}';
      final outFile = File(filename);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    }
    print('EPUB unpacking completed successfully');
  }

  Future<void> _parseOpfAndDetermineBasePath() async {
    final containerXmlPath = '$_tempDir/META-INF/container.xml';
    print('Checking for container.xml at: $containerXmlPath');
    if (!await File(containerXmlPath).exists()) {
      print('Container.xml not found at: $containerXmlPath');
      throw Exception('Container.xml not found at: $containerXmlPath');
    }

    print('Container.xml found, reading content...');
    final containerDoc = XmlDocument.parse(
      await File(containerXmlPath).readAsString(),
    );

    final rootfilePathAttr = containerDoc
        .findAllElements('rootfile')
        .firstOrNull
        ?.getAttribute('full-path');

    if (rootfilePathAttr == null) {
      throw Exception('Could not find OPF file path in container.xml');
    }

    _opfRelativePath = rootfilePathAttr;

    _contentBasePath = p.dirname(rootfilePathAttr);
    if (_contentBasePath == '.') {
      _contentBasePath = '';
    } else if (!_contentBasePath!.endsWith('/')) {
      _contentBasePath = '$_contentBasePath/';
    }

    final opfFile = File('$_tempDir/$_opfRelativePath');
    print('Checking for OPF file at: ${opfFile.path}');
    if (!await opfFile.exists()) {
      print('OPF file not found at: ${opfFile.path}');
      throw Exception('OPF file not found at: ${opfFile.path}');
    }

    print("EPUB relative OPF path: $_opfRelativePath");
    print("EPUB content base path derived: $_contentBasePath");
  }

  Future<void> _loadViewerHtml() async {
    try {
      _viewerHtmlContent = await rootBundle.loadString('assets/viewer.html');
    } catch (e) {
      print("Error loading assets/viewer.html: $e");
      throw Exception(
        "Failed to load viewer.html from assets. Ensure it exists and is listed in pubspec.yaml",
      );
    }
  }

  Future<HttpServer?> _startServer() async {
    if (_tempDir == null || _viewerHtmlContent == null) {
      throw Exception(
        "Server cannot start: temp directory or viewer HTML not ready.",
      );
    }

    final router = Router();

    router.get('/viewer.html', (Request request) {
      return Response.ok(
        _viewerHtmlContent!,
        headers: {'Content-Type': 'text/html'},
      );
    });

    router.get('/js/epub.min.js', (Request request) async {
      try {
        final jsContent = await rootBundle.loadString('assets/js/epub.min.js');
        return Response.ok(
          jsContent,
          headers: {'Content-Type': 'application/javascript'},
        );
      } catch (e) {
        print("Error serving epub.min.js: $e");
        return Response.notFound('epub.min.js not found');
      }
    });

    final epubContentHandler = createStaticHandler(_tempDir!);
    final handler = Cascade().add(router.call).add(epubContentHandler).handler;

    try {
      final server = await shelf_io.serve(handler, 'localhost', 0);
      print(
        'Shelf server listening on http://${server.address.host}:${server.port}',
      );
      return server;
    } catch (e) {
      print("Error starting shelf server: $e");
      return null;
    }
  }
}
