import 'package:flutter/material.dart';

// Extracted from reader_screen.dart

// --- NEW: Toc Panel Content Widget ---
class TocPanelContent extends StatelessWidget {
  final List<Map<String, dynamic>> tocList;
  final Function(String href) onItemTap;

  const TocPanelContent({
    super.key,
    required this.tocList,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      // Use ClipRRect to ensure content respects rounded corners of parent Material
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor, // Match background
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important for constrained height
            children: [
              // Optional: Drag Handle Visual
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 8.0,
                  left: 16.0,
                  right: 16.0,
                ),
                child: Text(
                  "Table of Contents",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // Use Flexible + ListView for scrollable content within constraints
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.zero, // Explicitly add zero padding
                  shrinkWrap: true, // Important for Flexible
                  itemCount: tocList.length,
                  itemBuilder: (context, index) {
                    final item = tocList[index];
                    final String label = item['label'] ?? 'Untitled';
                    final String? href = item['href'];
                    final int depth = item['depth'] ?? 0;

                    return ListTile(
                      contentPadding: EdgeInsets.only(
                        left: 16.0 + (depth * 16.0),
                        right: 16.0,
                      ), // Indentation
                      title: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                      onTap:
                          href == null
                              ? null
                              : () {
                                print("ToC Navigating to: $href");
                                onItemTap(href);
                              },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- END NEW ---
