import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

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
  Color? _secondaryColor;
  Color? _tertiaryColor;
  late Brightness _selectedBrightness;

  bool get isEditing => widget.themeToEdit != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final theme = widget.themeToEdit!;
      _nameController = TextEditingController(text: theme.name);
      _primaryColor = theme.primaryColor;
      _secondaryColor = theme.secondaryColor;
      _tertiaryColor = theme.tertiaryColor;
      _selectedBrightness = theme.brightness;
    } else {
      _nameController = TextEditingController();
      _primaryColor = Colors.blue;
      _secondaryColor = null;
      _tertiaryColor = null;
      _selectedBrightness = Brightness.light;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme name cannot be empty.')),
      );
      return;
    }

    final newTheme = CustomTheme(
      id: id,
      name: name,
      primaryColor: _primaryColor,
      secondaryColor: _secondaryColor,
      tertiaryColor: _tertiaryColor,
      brightness: _selectedBrightness,
    );

    themeProvider.addOrUpdateCustomTheme(newTheme);
    themeProvider.selectTheme(newTheme.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isPreviewDark = _selectedBrightness == Brightness.dark;
    final FlexColorScheme flexScheme =
        isPreviewDark
            ? FlexColorScheme.dark(
              primary: _primaryColor,
              secondary: _secondaryColor,
              tertiary: _tertiaryColor,
              surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
              appBarStyle: FlexAppBarStyle.scaffoldBackground,
              blendLevel: 40,
              subThemesData: const FlexSubThemesData(
                interactionEffects: true,
                tintedDisabledControls: true,
                blendOnLevel: 30,
                useM2StyleDividerInM3: true,
                adaptiveElevationShadowsBack:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveAppBarScrollUnderOff:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
                defaultRadiusAdaptive: 10.0,
                elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
                elevatedButtonSecondarySchemeColor:
                    SchemeColor.primaryContainer,
                outlinedButtonOutlineSchemeColor: SchemeColor.primary,
                toggleButtonsBorderSchemeColor: SchemeColor.primary,
                segmentedButtonSchemeColor: SchemeColor.primary,
                segmentedButtonBorderSchemeColor: SchemeColor.primary,
                unselectedToggleIsColored: true,
                sliderValueTinted: true,
                inputDecoratorSchemeColor: SchemeColor.primary,
                inputDecoratorIsFilled: true,
                inputDecoratorBackgroundAlpha: 19,
                inputDecoratorBorderType: FlexInputBorderType.outline,
                inputDecoratorUnfocusedHasBorder: false,
                inputDecoratorFocusedBorderWidth: 1.0,
                inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
                fabUseShape: true,
                fabAlwaysCircular: true,
                fabSchemeColor: SchemeColor.tertiary,
                cardRadius: 14.0,
                popupMenuRadius: 6.0,
                popupMenuElevation: 3.0,
                alignedDropdown: true,
                dialogRadius: 18.0,
                appBarScrolledUnderElevation: 1.0,
                drawerElevation: 1.0,
                drawerIndicatorSchemeColor: SchemeColor.primary,
                bottomSheetRadius: 18.0,
                bottomSheetElevation: 2.0,
                bottomSheetModalElevation: 4.0,
                bottomNavigationBarMutedUnselectedLabel: false,
                bottomNavigationBarMutedUnselectedIcon: false,
                menuRadius: 6.0,
                menuElevation: 3.0,
                menuBarRadius: 0.0,
                menuBarElevation: 1.0,
                menuBarShadowColor: Color(0x00000000),
                searchBarElevation: 4.0,
                searchViewElevation: 4.0,
                searchUseGlobalShape: true,
                navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
                navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationBarIndicatorSchemeColor: SchemeColor.primary,
                navigationBarElevation: 1.0,
                navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
                navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationRailUseIndicator: true,
                navigationRailIndicatorSchemeColor: SchemeColor.primary,
                navigationRailIndicatorOpacity: 1.00,
                navigationRailBackgroundSchemeColor: SchemeColor.surface,
              ),
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
            )
            : FlexColorScheme.light(
              primary: _primaryColor,
              secondary: _secondaryColor,
              tertiary: _tertiaryColor,
              surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
              appBarStyle: FlexAppBarStyle.scaffoldBackground,
              blendLevel: 40,
              subThemesData: const FlexSubThemesData(
                interactionEffects: true,
                tintedDisabledControls: true,
                blendOnLevel: 30,
                useM2StyleDividerInM3: true,
                adaptiveElevationShadowsBack:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveAppBarScrollUnderOff:
                    FlexAdaptive.excludeWebAndroidFuchsia(),
                adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
                defaultRadiusAdaptive: 10.0,
                elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
                elevatedButtonSecondarySchemeColor:
                    SchemeColor.primaryContainer,
                outlinedButtonOutlineSchemeColor: SchemeColor.primary,
                toggleButtonsBorderSchemeColor: SchemeColor.primary,
                segmentedButtonSchemeColor: SchemeColor.primary,
                segmentedButtonBorderSchemeColor: SchemeColor.primary,
                unselectedToggleIsColored: true,
                sliderValueTinted: true,
                inputDecoratorSchemeColor: SchemeColor.primary,
                inputDecoratorIsFilled: true,
                inputDecoratorBackgroundAlpha: 19,
                inputDecoratorBorderType: FlexInputBorderType.outline,
                inputDecoratorUnfocusedHasBorder: false,
                inputDecoratorFocusedBorderWidth: 1.0,
                inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
                fabUseShape: true,
                fabAlwaysCircular: true,
                fabSchemeColor: SchemeColor.tertiary,
                cardRadius: 14.0,
                popupMenuRadius: 6.0,
                popupMenuElevation: 3.0,
                alignedDropdown: true,
                dialogRadius: 18.0,
                appBarScrolledUnderElevation: 1.0,
                drawerElevation: 1.0,
                drawerIndicatorSchemeColor: SchemeColor.primary,
                bottomSheetRadius: 18.0,
                bottomSheetElevation: 2.0,
                bottomSheetModalElevation: 4.0,
                bottomNavigationBarMutedUnselectedLabel: false,
                bottomNavigationBarMutedUnselectedIcon: false,
                menuRadius: 6.0,
                menuElevation: 3.0,
                menuBarRadius: 0.0,
                menuBarElevation: 1.0,
                menuBarShadowColor: Color(0x00000000),
                searchBarElevation: 4.0,
                searchViewElevation: 4.0,
                searchUseGlobalShape: true,
                navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
                navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationBarIndicatorSchemeColor: SchemeColor.primary,
                navigationBarElevation: 1.0,
                navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
                navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
                navigationRailUseIndicator: true,
                navigationRailIndicatorSchemeColor: SchemeColor.primary,
                navigationRailIndicatorOpacity: 1.00,
                navigationRailBackgroundSchemeColor: SchemeColor.surface,
              ),
              visualDensity: FlexColorScheme.comfortablePlatformDensity,
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
            );
    final ThemeData previewTheme = flexScheme.toTheme;

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
            const SizedBox(height: 16),

            DropdownButtonFormField<Brightness>(
              decoration: const InputDecoration(
                labelText: 'Mode (Light/Dark)',
                border: OutlineInputBorder(),
              ),
              value: _selectedBrightness,
              items: const [
                DropdownMenuItem(
                  value: Brightness.light,
                  child: Text('Light Mode'),
                ),
                DropdownMenuItem(
                  value: Brightness.dark,
                  child: Text('Dark Mode'),
                ),
              ],
              onChanged: (Brightness? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedBrightness = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            _buildColorPickerTile(
              title: 'Primary Seed Color (Required)',
              color: _primaryColor,
              onColorSelected: (color) => setState(() => _primaryColor = color),
            ),
            const SizedBox(height: 12),
            _buildOptionalColorPickerTile(
              title: 'Secondary Seed Color (Optional)',
              color: _secondaryColor,
              onColorSelected:
                  (color) => setState(() => _secondaryColor = color),
              onClear: () => setState(() => _secondaryColor = null),
            ),
            const SizedBox(height: 12),
            _buildOptionalColorPickerTile(
              title: 'Tertiary Seed Color (Optional)',
              color: _tertiaryColor,
              onColorSelected:
                  (color) => setState(() => _tertiaryColor = color),
              onClear: () => setState(() => _tertiaryColor = null),
            ),
            const SizedBox(height: 20),

            // --- Live Preview Section Title ---
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Live Preview',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            // --- Live Preview Panel ---
            _buildPreviewPanel(previewTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPickerTile({
    required String title,
    required Color color,
    required ValueChanged<Color> onColorSelected,
  }) {
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
          pickedColor = color;
          final bool dialogOk = await ColorPicker(
            color: pickedColor,
            onColorChanged: (Color selected) {
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

          if (dialogOk) {
            onColorSelected(pickedColor);
          }
        },
      ),
    );
  }

  Widget _buildOptionalColorPickerTile({
    required String title,
    required Color? color,
    required ValueChanged<Color> onColorSelected,
    required VoidCallback onClear,
  }) {
    Color pickedColor = color ?? Colors.grey;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Color',
              onPressed: onClear,
            ),
          ColorIndicator(
            width: 44,
            height: 44,
            borderRadius: 4,
            color: color ?? Colors.transparent,
            borderColor: color == null ? Theme.of(context).dividerColor : null,
            onSelectFocus: false,
            onSelect: () async {
              pickedColor = color ?? _primaryColor;
              final bool dialogOk = await ColorPicker(
                color: pickedColor,
                onColorChanged: (Color selected) {
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

              if (dialogOk) {
                onColorSelected(pickedColor);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(ThemeData previewTheme) {
    final String loremIpsum =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. " *
        3; // Repeat text to ensure scrolling/length

    return Padding(
      padding: const EdgeInsets.only(top: 0.0),
      child: Theme(
        key: ValueKey(previewTheme.brightness),
        data: previewTheme,
        child: Material(
          color: previewTheme.scaffoldBackgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: previewTheme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 8, right: 8, top: 8),
                  decoration: BoxDecoration(
                    color: previewTheme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        title: Text('Title'),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.list),
                            tooltip: 'Table of Contents',
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            tooltip: 'Settings',
                            onPressed: () {},
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 20,
                        child: SliderTheme(
                          data: previewTheme.sliderTheme.copyWith(
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12.0,
                            ),
                          ),
                          child: Slider(
                            value: 0.35,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (value) {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loremIpsum,
                      style: previewTheme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
