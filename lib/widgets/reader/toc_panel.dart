import 'package:flutter/material.dart';

// Extracted from reader_screen.dart

// --- NEW: Toc Panel Content Widget ---
class TocPanelContent extends StatelessWidget {
  final List<Map<String, dynamic>> tocList;
  final Function(String loc) onItemTap;

  const TocPanelContent({
    super.key,
    required this.tocList,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          // Removed color, relying on Material wrapper in ReaderScreen
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Match SettingsPanel
            children: [
              // Use Header similar to Settings Panel
              const Padding(
                padding: EdgeInsets.only(
                  top: 16.0,
                  bottom: 8.0,
                ), // Adjusted padding
                child: Text(
                  "Table of Contents",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              // Use Flexible + ListView for scrollable content within constraints
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: tocList.length,
                  itemBuilder: (context, index) {
                    final item = tocList[index];
                    final String label = item['label'] ?? 'Untitled';
                    final String? loc = item['loc'];
                    final int depth = item['depth'] ?? 0;

                    return ListTile(
                      contentPadding: EdgeInsets.only(
                        left: 16.0 + (depth * 16.0),
                        right: 16.0,
                      ),
                      title: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                      onTap:
                          loc == null
                              ? null
                              : () {
                                print("ToC Navigating to: $loc");
                                onItemTap(loc);
                              },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8), // Add padding at the bottom if needed
            ],
          ),
        ),
      ),
    );
  }
}

// --- END NEW ---
