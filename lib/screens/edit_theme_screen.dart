import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_theme.dart';
import '../providers/theme_provider.dart';

class EditThemeScreen extends StatefulWidget {
  final CustomTheme? themeToEdit; // Theme to edit (null if creating new)

  const EditThemeScreen({super.key, this.themeToEdit});

  @override
  State<EditThemeScreen> createState() => _EditThemeScreenState();
}

class _EditThemeScreenState extends State<EditThemeScreen> {
  late TextEditingController _nameController;
  late Color _primaryColor;
  late Color _backgroundColor;
  late Color _surfaceColor; // For cards, dialogs etc.
  late Color _textColor; // Added for text color

  bool get isEditing => widget.themeToEdit != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final theme = widget.themeToEdit!;
      _nameController = TextEditingController(text: theme.name);
      _primaryColor = theme.primaryColor;
      _backgroundColor = theme.backgroundColor;
      _surfaceColor = theme.surfaceColor;
      _textColor = theme.textColor; // Initialize text color
    } else {
      // Defaults for a new theme
      _nameController = TextEditingController();
      _primaryColor = Colors.blue; // Default primary
      _backgroundColor = Colors.white; // Default background
      _surfaceColor = Colors.grey.shade100; // Default surface
      _textColor = Colors.black; // Default text color
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final id = isEditing ? widget.themeToEdit!.id : const Uuid().v4();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      // Show error if name is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme name cannot be empty.')),
      );
      return;
    }

    final newTheme = CustomTheme(
      id: id,
      name: name,
      primaryColor: _primaryColor,
      backgroundColor: _backgroundColor,
      surfaceColor: _surfaceColor,
      textColor: _textColor, // Use _textColor
    );

    themeProvider.addOrUpdateCustomTheme(newTheme);

    // Optionally, select the newly created/edited theme immediately
    themeProvider.selectTheme(newTheme.id);

    Navigator.pop(context); // Go back to the theme builder screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Theme' : 'Create Theme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Theme',
            onPressed: _saveTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Theme Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // --- Color Pickers ---
            _buildColorPickerTile(
              title: 'Primary Color',
              color: _primaryColor,
              onColorSelected: (color) => setState(() => _primaryColor = color),
            ),
            const SizedBox(height: 12),
            _buildColorPickerTile(
              title: 'Background Color',
              color: _backgroundColor,
              onColorSelected:
                  (color) => setState(() => _backgroundColor = color),
            ),
            const SizedBox(height: 12),
            _buildColorPickerTile(
              title: 'Surface Color (Cards/Dialogs)',
              color: _surfaceColor,
              onColorSelected: (color) => setState(() => _surfaceColor = color),
            ),
            const SizedBox(height: 12),
            _buildColorPickerTile(
              // Added Text Color Picker
              title: 'Text Color',
              color: _textColor,
              onColorSelected: (color) => setState(() => _textColor = color),
            ),
            const SizedBox(height: 20),
            // --- Theme Preview (Optional but Recommended) ---
            // TODO: Add a small preview area showing key theme elements
            // using the currently selected colors.
          ],
        ),
      ),
    );
  }

  // Helper Widget for Color Picker ListTile
  Widget _buildColorPickerTile({
    required String title,
    required Color color,
    required ValueChanged<Color> onColorSelected,
  }) {
    // Temporary variable to hold the color selected in the dialog
    Color pickedColor = color;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: ColorIndicator(
        width: 44,
        height: 44,
        borderRadius: 4,
        color: color,
        onSelectFocus: false,
        onSelect: () async {
          // Reset pickedColor to the current color before opening the dialog
          pickedColor = color;
          final bool dialogOk = await ColorPicker(
            color: pickedColor, // Use the temp variable for initial state
            onColorChanged: (Color selected) {
              // Update the temporary variable when the color changes in the picker
              pickedColor = selected;
            },
            width: 40,
            height: 40,
            borderRadius: 4,
            spacing: 5,
            runSpacing: 5,
            wheelDiameter: 155,
            heading: Text(
              'Select color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subheading: Text(
              'Select color shade',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            wheelSubheading: Text(
              'Selected color and its shades',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            showMaterialName: true,
            showColorName: true,
            showColorCode: true,
            materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
            colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
            colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: false,
              ColorPickerType.bw: false,
              ColorPickerType.custom: true,
              ColorPickerType.wheel: true,
            },
          ).showPickerDialog(
            context,
            constraints: const BoxConstraints(
              minHeight: 480,
              minWidth: 300,
              maxWidth: 320,
            ),
          );

          // If the dialog was confirmed (OK pressed), update the state
          if (dialogOk) {
            onColorSelected(pickedColor);
          }
        },
      ),
    );
  }
}
