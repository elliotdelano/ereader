import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Get current route to highlight the active screen
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Drawer Header (Optional, can customize)
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Text(
              'Ereader Menu',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 24,
              ),
            ),
          ),
          // Library Item
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Library'),
            selected: currentRoute == '/', // Assuming library is the root route
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate only if not already on the library screen
              if (currentRoute != '/') {
                // Use pushReplacement to avoid stacking library screens
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          // Theme Builder Item
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme Builder'),
            selected: currentRoute == '/theme-builder',
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate only if not already on the theme builder screen
              if (currentRoute != '/theme-builder') {
                // Use pushNamed to allow returning to the previous screen (library)
                Navigator.pushNamed(context, '/theme-builder');
              }
            },
          ),
          // Add more ListTiles here for future screens
          const Divider(),
          // Optional: Settings, About, etc.
        ],
      ),
    );
  }
}
