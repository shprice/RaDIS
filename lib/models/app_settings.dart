import '../dis/constants.dart';
import 'app_key_binding.dart';

const _kSupportedEncodingTypes = {
  DisConstants.encodingMulaw,
  DisConstants.encodingAlaw,
  DisConstants.encodingLinear16,
  DisConstants.encodingCVSD,
};

int _validatedEncodingType(int? stored) {
  if (stored != null && _kSupportedEncodingTypes.contains(stored)) return stored;
  return DisConstants.encodingMulaw;
}

class AppSettings {
  int defaultSampleRate;
  int defaultEncodingType;

  bool darkMode;
  bool showLevelMeters;

  List<AppKeyBinding> keyBindings;

  AppSettings({
    this.defaultSampleRate = DisConstants.sampleRate8kHz,
    this.defaultEncodingType = DisConstants.encodingMulaw,
    this.darkMode = true,
    this.showLevelMeters = true,
    List<AppKeyBinding>? keyBindings,
  }) : keyBindings = keyBindings ?? [];

  Map<String, dynamic> toJson() => {
        'defaultSampleRate': defaultSampleRate,
        'defaultEncodingType': defaultEncodingType,
        'darkMode': darkMode,
        'showLevelMeters': showLevelMeters,
        'keyBindings': keyBindings.map((b) => b.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        defaultSampleRate: (json['defaultSampleRate'] as num?)?.toInt() ??
            DisConstants.sampleRate8kHz,
        defaultEncodingType: _validatedEncodingType(
            (json['defaultEncodingType'] as num?)?.toInt()),
        darkMode: json['darkMode'] as bool? ?? true,
        showLevelMeters: json['showLevelMeters'] as bool? ?? true,
        keyBindings: (json['keyBindings'] as List<dynamic>?)
                ?.map((e) =>
                    AppKeyBinding.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  AppSettings copyWith({
    int? defaultSampleRate,
    int? defaultEncodingType,
    bool? darkMode,
    bool? showLevelMeters,
    List<AppKeyBinding>? keyBindings,
  }) =>
      AppSettings(
        defaultSampleRate: defaultSampleRate ?? this.defaultSampleRate,
        defaultEncodingType: defaultEncodingType ?? this.defaultEncodingType,
        darkMode: darkMode ?? this.darkMode,
        showLevelMeters: showLevelMeters ?? this.showLevelMeters,
        keyBindings: keyBindings ?? this.keyBindings,
      );
}
