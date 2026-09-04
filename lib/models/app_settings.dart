import '../dis/constants.dart';
import 'app_key_binding.dart';

// Encoding types available in the Settings UI dropdown.
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
  String disLocalAddress;
  int disPort;
  bool disUseMulticast;
  String disMulticastGroup;
  String? disNetworkInterface;

  int siteId;
  int applicationId;
  int exerciseId;

  int defaultSampleRate;
  int defaultEncodingType;

  bool darkMode;
  bool showLevelMeters;

  int disProtocolVersion;

  List<AppKeyBinding> keyBindings;

  AppSettings({
    this.disLocalAddress = DisConstants.defaultLocalAddress,
    this.disPort = DisConstants.defaultPort,
    this.disUseMulticast = true,
    this.disMulticastGroup = DisConstants.defaultMulticastGroup,
    this.disNetworkInterface,
    this.siteId = 1,
    this.applicationId = 1,
    this.exerciseId = 1,
    this.defaultSampleRate = DisConstants.sampleRate8kHz,
    this.defaultEncodingType = DisConstants.encodingMulaw,
    this.darkMode = true,
    this.showLevelMeters = true,
    this.disProtocolVersion = DisConstants.protocolVersionDis6,
    List<AppKeyBinding>? keyBindings,
  }) : keyBindings = keyBindings ?? [];

  Map<String, dynamic> toJson() => {
        'disLocalAddress': disLocalAddress,
        'disPort': disPort,
        'disUseMulticast': disUseMulticast,
        'disMulticastGroup': disMulticastGroup,
        'disNetworkInterface': disNetworkInterface,
        'siteId': siteId,
        'applicationId': applicationId,
        'exerciseId': exerciseId,
        'defaultSampleRate': defaultSampleRate,
        'defaultEncodingType': defaultEncodingType,
        'darkMode': darkMode,
        'showLevelMeters': showLevelMeters,
        'disProtocolVersion': disProtocolVersion,
        'keyBindings': keyBindings.map((b) => b.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        disLocalAddress: json['disLocalAddress'] as String? ??
            DisConstants.defaultLocalAddress,
        disPort: (json['disPort'] as num?)?.toInt() ?? DisConstants.defaultPort,
        disUseMulticast: json['disUseMulticast'] as bool? ?? true,
        disMulticastGroup: json['disMulticastGroup'] as String? ??
            DisConstants.defaultMulticastGroup,
        disNetworkInterface: json['disNetworkInterface'] as String?,
        siteId: (json['siteId'] as num?)?.toInt() ?? 1,
        applicationId: (json['applicationId'] as num?)?.toInt() ?? 1,
        exerciseId: (json['exerciseId'] as num?)?.toInt() ?? 1,
        defaultSampleRate: (json['defaultSampleRate'] as num?)?.toInt() ??
            DisConstants.sampleRate8kHz,
        defaultEncodingType: _validatedEncodingType(
            (json['defaultEncodingType'] as num?)?.toInt()),
        darkMode: json['darkMode'] as bool? ?? true,
        showLevelMeters: json['showLevelMeters'] as bool? ?? true,
        disProtocolVersion: (json['disProtocolVersion'] as num?)?.toInt() ??
            DisConstants.protocolVersionDis6,
        keyBindings: (json['keyBindings'] as List<dynamic>?)
                ?.map((e) =>
                    AppKeyBinding.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  AppSettings copyWith({
    String? disLocalAddress,
    int? disPort,
    bool? disUseMulticast,
    String? disMulticastGroup,
    String? disNetworkInterface,
    int? siteId,
    int? applicationId,
    int? exerciseId,
    int? defaultSampleRate,
    int? defaultEncodingType,
    bool? darkMode,
    bool? showLevelMeters,
    int? disProtocolVersion,
    List<AppKeyBinding>? keyBindings,
  }) =>
      AppSettings(
        disLocalAddress: disLocalAddress ?? this.disLocalAddress,
        disPort: disPort ?? this.disPort,
        disUseMulticast: disUseMulticast ?? this.disUseMulticast,
        disMulticastGroup: disMulticastGroup ?? this.disMulticastGroup,
        disNetworkInterface: disNetworkInterface ?? this.disNetworkInterface,
        siteId: siteId ?? this.siteId,
        applicationId: applicationId ?? this.applicationId,
        exerciseId: exerciseId ?? this.exerciseId,
        defaultSampleRate: defaultSampleRate ?? this.defaultSampleRate,
        defaultEncodingType: defaultEncodingType ?? this.defaultEncodingType,
        darkMode: darkMode ?? this.darkMode,
        showLevelMeters: showLevelMeters ?? this.showLevelMeters,
        disProtocolVersion: disProtocolVersion ?? this.disProtocolVersion,
        keyBindings: keyBindings ?? this.keyBindings,
      );
}
