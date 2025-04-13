import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

// Helper to generate unique IDs
const _uuid = Uuid();

@immutable // Good practice for model classes
class CustomTheme {
  final String id;
  final String name;
  final Color primaryColor; // Required seed color
  final Color? secondaryColor; // Optional seed color
  final Color? tertiaryColor; // Optional seed color
  final Brightness brightness; // Explicit brightness

  // Constructor requires primary, brightness, accepts optional secondary/tertiary
  CustomTheme({
    String? id,
    required this.name,
    required this.primaryColor,
    this.secondaryColor,
    this.tertiaryColor,
    required this.brightness,
  }) : id = id ?? _uuid.v4();

  // Serialization to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor':
          secondaryColor?.toARGB32(), // Store optional color value or null
      'tertiaryColor':
          tertiaryColor?.toARGB32(), // Store optional color value or null
      'brightness': brightness == Brightness.dark ? 'dark' : 'light',
    };
  }

  // Deserialization from JSON Map
  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null ||
        json['name'] == null ||
        json['primaryColor'] == null ||
        json['brightness'] == null) {
      throw FormatException(
        "Invalid JSON for CustomTheme: Missing required keys.",
      );
    }

    // Helper to safely decode optional colors
    Color? decodeColor(dynamic value) {
      return value == null ? null : Color(value as int);
    }

    return CustomTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryColor: Color(json['primaryColor'] as int),
      secondaryColor: decodeColor(json['secondaryColor']),
      tertiaryColor: decodeColor(json['tertiaryColor']),
      brightness:
          (json['brightness'] as String) == 'dark'
              ? Brightness.dark
              : Brightness.light,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomTheme &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          tertiaryColor == other.tertiaryColor &&
          brightness == other.brightness;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      primaryColor.hashCode ^
      secondaryColor.hashCode ^
      tertiaryColor.hashCode ^
      brightness.hashCode;

  CustomTheme copyWith({
    String? id,
    String? name,
    Color? primaryColor,
    // Use Object() as a sentinel for clearing optional fields
    Object? secondaryColor = const Object(),
    Object? tertiaryColor = const Object(),
    Brightness? brightness,
  }) {
    // Check if sentinel was passed to clear the field
    final bool clearSecondary = identical(secondaryColor, const Object());
    final bool clearTertiary = identical(tertiaryColor, const Object());

    return CustomTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor:
          clearSecondary ? this.secondaryColor : secondaryColor as Color?,
      tertiaryColor:
          clearTertiary ? this.tertiaryColor : tertiaryColor as Color?,
      brightness: brightness ?? this.brightness,
    );
  }
}
