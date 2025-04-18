import 'dart:io';

import 'package:ereader/models/book.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/reader_settings_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsPanelContent extends StatefulWidget {
  final BookFormat format;
  const SettingsPanelContent({super.key, required this.format});

  @override
  State<SettingsPanelContent> createState() => _SettingsPanelContentState();
}

class _SettingsPanelContentState extends State<SettingsPanelContent> {
  List<DropdownMenuItem<T>> _buildEnumDropdownItems<T extends Enum>(
    List<T> enumValues,
  ) {
    return enumValues.map((T value) {
      String name = value.name;
      String titleCaseName =
          name[0].toUpperCase() + name.substring(1).toLowerCase();
      return DropdownMenuItem<T>(value: value, child: Text(titleCaseName));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<ReaderSettingsProvider>(context);

    final String selectedThemeId = themeProvider.selectedThemeId;
    final double currentFontSize = settingsProvider.fontSize;
    final String currentFontFamily = settingsProvider.fontFamily;
    final double currentLineSpacing = settingsProvider.lineSpacing;
    final MarginSize currentMarginSize = settingsProvider.marginSize;
    final EpubFlow currentEpubFlow = settingsProvider.epubFlow;
    final EpubSpread currentEpubSpread = settingsProvider.epubSpread;

    var themeEnabled = true;
    final fontFamilyEnabled = widget.format == BookFormat.epub;
    final fontSizeEnabled = widget.format == BookFormat.epub;
    final lineSpacingEnabled = widget.format == BookFormat.epub;
    final pageMarginsEnabled = widget.format == BookFormat.epub;
    final readingModeEnabled = widget.format == BookFormat.epub;
    final pageSpreadEnabled =
        widget.format == BookFormat.epub &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Padding(
      padding: EdgeInsets.zero, // Keep outer padding zero for ClipRRect
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          // color: Theme.of(context).scaffoldBackgroundColor,
          // Use Column instead of ListView
          child: SingleChildScrollView(
            // Wrap content in SingleChildScrollView
            padding: const EdgeInsets.all(16.0),
            child: ButtonTheme(
              alignedDropdown: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Add Header like BookEditSheet (without close button)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Reader Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Theme Dropdown - Use DropdownButtonFormField
                  AbsorbPointer(
                    absorbing: !themeEnabled,
                    child: Opacity(
                      opacity: themeEnabled ? 1.0 : 0.5,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Theme',
                          border: OutlineInputBorder(),
                        ),
                        // dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8.0),
                        value: selectedThemeId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: lightThemeId,
                            child: Text('Light'),
                          ),
                          const DropdownMenuItem<String>(
                            value: darkThemeId,
                            child: Text('Dark'),
                          ),
                          const DropdownMenuItem<String>(
                            value: sepiaThemeId,
                            child: Text('Sepia'),
                          ),
                          ...themeProvider.customThemes.map((customTheme) {
                            return DropdownMenuItem<String>(
                              value: customTheme.id,
                              child: Text(customTheme.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            themeProvider.selectTheme(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wrap Font Family Dropdown
                  Opacity(
                    opacity: fontFamilyEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !fontFamilyEnabled,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Font Family',
                          border: OutlineInputBorder(),
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                        value: currentFontFamily,
                        items:
                            settingsProvider.availableFontFamilies.map((font) {
                              return DropdownMenuItem(
                                value: font,
                                child: Text(font),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            settingsProvider.setFontFamily(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wrap Font Size Slider
                  Opacity(
                    opacity: fontSizeEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !fontSizeEnabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Font Size (${currentFontSize.round()})'),
                          Slider(
                            value: currentFontSize,
                            min: 10.0,
                            max: 30.0,
                            divisions: 20,
                            label: currentFontSize.round().toString(),
                            onChanged: settingsProvider.setFontSize,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Wrap Line Spacing Slider
                  Opacity(
                    opacity: lineSpacingEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !lineSpacingEnabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Line Spacing (${currentLineSpacing.toStringAsFixed(1)})',
                          ),
                          Slider(
                            value: currentLineSpacing,
                            min: 1.0,
                            max: 2.5,
                            divisions: 15,
                            label: currentLineSpacing.toStringAsFixed(1),
                            onChanged: settingsProvider.setLineSpacing,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Wrap Page Margins Dropdown
                  Opacity(
                    opacity: pageMarginsEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !pageMarginsEnabled,
                      child: DropdownButtonFormField<MarginSize>(
                        decoration: const InputDecoration(
                          labelText: 'Page Margins',
                          border: OutlineInputBorder(),
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                        value: currentMarginSize,
                        items: _buildEnumDropdownItems(MarginSize.values),
                        onChanged: (value) {
                          if (value != null) {
                            settingsProvider.setMarginSize(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wrap Reading Mode Dropdown
                  Opacity(
                    opacity: readingModeEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !readingModeEnabled,
                      child: DropdownButtonFormField<EpubFlow>(
                        decoration: const InputDecoration(
                          labelText: 'Reading Mode (Flow)',
                          border: OutlineInputBorder(),
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                        value: currentEpubFlow,
                        items: _buildEnumDropdownItems(EpubFlow.values),
                        onChanged: (value) {
                          if (value != null) {
                            settingsProvider.setEpubFlow(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wrap Page Spread Dropdown
                  Opacity(
                    opacity: pageSpreadEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !pageSpreadEnabled,
                      child: DropdownButtonFormField<EpubSpread>(
                        decoration: const InputDecoration(
                          labelText: 'Page Spread (Desktop)',
                          border: OutlineInputBorder(),
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                        value: currentEpubSpread,
                        items: _buildEnumDropdownItems(EpubSpread.values),
                        onChanged: (value) {
                          if (value != null) {
                            settingsProvider.setEpubSpread(value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
