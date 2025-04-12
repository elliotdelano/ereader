import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Import package_info_plus

// Convert to StatefulWidget
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

// Create State class
class _AppDrawerState extends State<AppDrawer> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  ); // Initialize with defaults

  @override
  void initState() {
    super.initState();
    _initPackageInfo(); // Fetch info on init
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      // Check if widget is still in the tree
      setState(() {
        _packageInfo = info;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current route to highlight the active screen
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: const Text('Library'),
                    selected:
                        currentRoute ==
                        '/', // Assuming library is the root route
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
                  // Optional: Settings, About, etc.
                ],
              ),
            ),
            // Spacer is removed, Divider and Text are direct children of Column
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                // Use the state variable
                'EReader v${_packageInfo.version}',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
