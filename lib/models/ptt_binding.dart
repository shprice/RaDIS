enum PttTriggerType { keyboardKey, mouseButton, joystickButton }

class PttBinding {
  final PttTriggerType triggerType;
  final String keyCode;
  final int physicalKeyCode;
  final String description;

  const PttBinding({
    required this.triggerType,
    required this.keyCode,
    required this.physicalKeyCode,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'triggerType': triggerType.name,
        'keyCode': keyCode,
        'physicalKeyCode': physicalKeyCode,
        'description': description,
      };

  factory PttBinding.fromJson(Map<String, dynamic> json) => PttBinding(
        triggerType: PttTriggerType.values.firstWhere(
          (t) => t.name == json['triggerType'],
          orElse: () => PttTriggerType.keyboardKey,
        ),
        keyCode: json['keyCode'] as String,
        physicalKeyCode: (json['physicalKeyCode'] as num).toInt(),
        description: json['description'] as String,
      );

  static PttBinding get spaceBar => const PttBinding(
        triggerType: PttTriggerType.keyboardKey,
        keyCode: 'Space',
        physicalKeyCode: 0x20,
        description: 'Space Bar',
      );

  static PttBinding get f12Key => const PttBinding(
        triggerType: PttTriggerType.keyboardKey,
        keyCode: 'F12',
        physicalKeyCode: 0x7B,
        description: 'F12',
      );
}
