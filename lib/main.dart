import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/reader_settings_provider.dart';
import 'providers/reader_state_provider.dart';
import 'screens/library_screen.dart';

void main() {
  // Ensure widgets are initialized before loading preferences etc.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ReaderSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ReaderStateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the ThemeProvider to apply the selected theme
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Ebook Reader',
          theme: themeProvider.themeData, // Use dynamic theme data
          debugShowCheckedModeBanner: false, // Optional: hide debug banner
          home: const LibraryScreen(), // Set LibraryScreen as the home
        );
      },
    );
  }
}

// Removed the default MyHomePage and _MyHomePageState boilerplate
