import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

// Helper to generate unique IDs
const _uuid = Uuid();

@immutable // Good practice for model classes
class CustomTheme {
  final String id;
  final String name;
  final Color primaryColor;
  final Color backgroundColor;
  final Color surfaceColor; // For cards, dialogs, etc.
  final Color textColor; // Main text color on background/surface

  // Constructor requires all core colors
  CustomTheme({
    String? id, // Allow providing an ID (for updates) or generate one
    required this.name,
    required this.primaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
  }) : id = id ?? _uuid.v4(); // Generate v4 UUID if no ID is provided

  // Serialization to JSON Map (storing colors as int values)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryColor': primaryColor.value,
      'backgroundColor': backgroundColor.value,
      'surfaceColor': surfaceColor.value,
      'textColor': textColor.value,
    };
  }

  // Deserialization from JSON Map
  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    // Add basic validation or default values if needed
    if (json['id'] == null ||
        json['name'] == null ||
        json['primaryColor'] == null ||
        json['backgroundColor'] == null ||
        json['surfaceColor'] == null ||
        json['textColor'] == null) {
      throw FormatException(
        "Invalid JSON for CustomTheme: Missing required keys.",
      );
    }

    return CustomTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryColor: Color(json['primaryColor'] as int),
      backgroundColor: Color(json['backgroundColor'] as int),
      surfaceColor: Color(json['surfaceColor'] as int),
      textColor: Color(json['textColor'] as int),
    );
  }

  // Optional: Implement equality operator and hashCode for comparisons
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomTheme &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          primaryColor == other.primaryColor &&
          backgroundColor == other.backgroundColor &&
          surfaceColor == other.surfaceColor &&
          textColor == other.textColor;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      primaryColor.hashCode ^
      backgroundColor.hashCode ^
      surfaceColor.hashCode ^
      textColor.hashCode;

  // Optional: copyWith method for easier updates
  CustomTheme copyWith({
    String? id,
    String? name,
    Color? primaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? textColor,
  }) {
    return CustomTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      textColor: textColor ?? this.textColor,
    );
  }
}
