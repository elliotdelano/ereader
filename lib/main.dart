import 'dart:async'; // Added for StreamSubscription
import 'package:ereader/screens/reader_screen.dart';
import 'package:ereader/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:receive_sharing_intent/receive_sharing_intent.dart'; // Added import

import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/reader_settings_provider.dart';
import 'providers/reader_state_provider.dart';
import 'screens/library_screen.dart';
import 'screens/theme_builder_screen.dart';

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ReaderSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ReaderStateProvider()),
      ],
      child:
          const EReaderApp(), // Keep const if EReaderApp constructor is const
    ),
  );
}

// Convert to StatefulWidget to handle initState/dispose for listener
class EReaderApp extends StatefulWidget {
  const EReaderApp({super.key});

  @override
  State<EReaderApp> createState() => _EReaderAppState();
}

class _EReaderAppState extends State<EReaderApp> {
  late StreamSubscription _intentDataStreamSubscription;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initIntentHandling();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  void _initIntentHandling() {
    // Use the singleton instance getter

    // Listener for intents received while the app is running
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              _handleOpenFile(value.first.path);
            }
          },
          onError: (err) {
            print("getMediaStream error: $err");
          },
        );

    // Handler for intent received when the app is initially launched
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        _handleOpenFile(value.first.path);
      }
    });
  }

  // Placeholder for the actual file handling logic
  Future<void> _handleOpenFile(String? path) async {
    if (path == null || path.isEmpty || _isNavigating) return;

    _isNavigating = true;

    final fileService = FileService();
    final book = await fileService.retrieveSingleFile(path);
    if (book != null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => ReaderScreen(book: book)),
        (route) => false,
      );
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Assign the GlobalKey
          title: 'Ebook Reader',
          theme: themeProvider.themeData,
          debugShowCheckedModeBanner: false,
          initialRoute: '/library',
          routes: {
            '/': (context) => const LibraryScreen(),
            '/library': (context) => const LibraryScreen(),
            '/theme-builder': (context) => const ThemeBuilderScreen(),
          },
        );
      },
    );
  }
}
