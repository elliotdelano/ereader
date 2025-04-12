import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../models/custom_theme.dart'; // Import CustomTheme
import 'edit_theme_screen.dart'; // Import the new screen

class ThemeBuilderScreen extends StatefulWidget {
  // Changed to StatefulWidget
  const ThemeBuilderScreen({super.key});

  @override
  State<ThemeBuilderScreen> createState() => _ThemeBuilderScreenState();
}

class _ThemeBuilderScreenState extends State<ThemeBuilderScreen> {
  // Added State class
  @override
  Widget build(BuildContext context) {
    // Access the ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final customThemes = themeProvider.customThemes;
    final selectedThemeId = themeProvider.selectedThemeId;

    // Combine predefined and custom themes for display
    final List<dynamic> allThemes = [
      // Represent predefined themes with simple maps or a dedicated class
      {'id': lightThemeId, 'name': 'Light', 'type': 'predefined'},
      {'id': darkThemeId, 'name': 'Dark', 'type': 'predefined'},
      {'id': sepiaThemeId, 'name': 'Sepia', 'type': 'predefined'},
      ...customThemes, // Add custom themes directly
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Theme Builder')),
      // Display themes in a ListView
      body: ListView.builder(
        itemCount: allThemes.length,
        itemBuilder: (context, index) {
          final themeItem = allThemes[index];
          String themeId;
          String themeName;
          bool isCustom = false;

          if (themeItem is CustomTheme) {
            themeId = themeItem.id;
            themeName = themeItem.name;
            isCustom = true;
          } else if (themeItem is Map) {
            themeId = themeItem['id'] as String;
            themeName = themeItem['name'] as String;
          } else {
            return const SizedBox.shrink(); // Should not happen
          }

          final bool isSelected = themeId == selectedThemeId;

          Widget? trailingWidget;
          if (isCustom) {
            // For custom themes, show Edit/Delete menu
            trailingWidget = PopupMenuButton<String>(
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
              onSelected: (value) async {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => EditThemeScreen(
                            themeToEdit:
                                themeItem as CustomTheme, // Pass the theme
                          ),
                    ),
                  );
                } else if (value == 'delete') {
                  // Show confirmation dialog before deleting
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Theme?'),
                        content: Text(
                          'Are you sure you want to delete the "$themeName" theme?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          TextButton(
                            child: const Text('Delete'),
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true && mounted) {
                    // Call themeProvider.deleteCustomTheme
                    Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    ).deleteCustomTheme(themeId);
                    // Show a confirmation snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Theme "$themeName" deleted.')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.more_vert),
            );
          } else if (isSelected) {
            // For selected predefined themes, show checkmark
            trailingWidget = const Icon(
              Icons.check_circle,
              color: Colors.green,
            );
          }
          // Otherwise (unselected predefined theme), trailing is null

          return ListTile(
            title: Text(themeName),
            subtitle:
                isCustom
                    ? const Text('Custom Theme')
                    : const Text('Predefined Theme'),
            trailing: trailingWidget, // Use the determined trailing widget
            onTap: () {
              // Allow selecting any theme (predefined or custom)
              themeProvider.selectTheme(themeId);
            },
          );
        },
      ),
      // Add FloatingActionButton to create new themes
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the theme creation/editing screen for a new theme
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      const EditThemeScreen(), // Pass null for themeToEdit
            ),
          );
        },
        tooltip: 'Create New Theme',
        child: const Icon(Icons.add),
      ),
    );
  }
}
