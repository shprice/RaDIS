import 'package:uuid/uuid.dart';

/// Bitmask flags for required modifier keys.
class KeyModifiers {
  const KeyModifiers._();

  static const int none  = 0;
  static const int ctrl  = 1 << 0;
  static const int shift = 1 << 1;
  static const int alt   = 1 << 2;
  static const int meta  = 1 << 3;

  /// Human-readable prefix string for a modifier bitmask (e.g. "Ctrl+Shift").
  static String prefix(int flags) {
    final parts = <String>[];
    if (flags & ctrl  != 0) parts.add('Ctrl');
    if (flags & shift != 0) parts.add('Shift');
    if (flags & alt   != 0) parts.add('Alt');
    if (flags & meta  != 0) parts.add('Win');
    return parts.join('+');
  }
}

class AppKeyBinding {
  final String id;
  final String name;
  final int physicalKeyCode; // USB HID of the main (non-modifier) key
  final String keyLabel;     // display label for the main key
  final bool enabled;
  final int modifierFlags;   // KeyModifiers bitmask

  AppKeyBinding({
    String? id,
    required this.name,
    required this.physicalKeyCode,
    required this.keyLabel,
    this.enabled = true,
    this.modifierFlags = KeyModifiers.none,
  }) : id = id ?? const Uuid().v4();

  /// Full human-readable label including modifiers, e.g. "Ctrl+F1".
  String get fullKeyLabel {
    final pfx = KeyModifiers.prefix(modifierFlags);
    return pfx.isEmpty ? keyLabel : '$pfx+$keyLabel';
  }

  String get displayLabel => name.isNotEmpty ? name : fullKeyLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'physicalKeyCode': physicalKeyCode,
        'keyLabel': keyLabel,
        'enabled': enabled,
        'modifierFlags': modifierFlags,
      };

  factory AppKeyBinding.fromJson(Map<String, dynamic> json) => AppKeyBinding(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        physicalKeyCode: (json['physicalKeyCode'] as num).toInt(),
        keyLabel: json['keyLabel'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        modifierFlags: (json['modifierFlags'] as num?)?.toInt() ?? KeyModifiers.none,
      );

  AppKeyBinding copyWith({
    String? name,
    int? physicalKeyCode,
    String? keyLabel,
    bool? enabled,
    int? modifierFlags,
  }) =>
      AppKeyBinding(
        id: id,
        name: name ?? this.name,
        physicalKeyCode: physicalKeyCode ?? this.physicalKeyCode,
        keyLabel: keyLabel ?? this.keyLabel,
        enabled: enabled ?? this.enabled,
        modifierFlags: modifierFlags ?? this.modifierFlags,
      );
}
