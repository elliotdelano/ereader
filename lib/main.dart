import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/reader_settings_provider.dart';
import 'providers/reader_state_provider.dart';
import 'screens/library_screen.dart';
import 'screens/theme_builder_screen.dart';

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
      child: const EReaderApp(),
    ),
  );
}

class EReaderApp extends StatelessWidget {
  const EReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Ebook Reader',
          theme: themeProvider.themeData,
          debugShowCheckedModeBanner: false,
          initialRoute: '/library',
          routes: {
            '/library': (context) => const LibraryScreen(),
            '/theme-builder': (context) => const ThemeBuilderScreen(),
          },
        );
      },
    );
  }
}
