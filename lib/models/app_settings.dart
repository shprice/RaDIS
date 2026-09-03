import '../dis/constants.dart';

// Encoding types available in the Settings UI dropdown.
const _kSupportedEncodingTypes = {
  DisConstants.encodingMulaw,
  DisConstants.encodingAlaw,
  DisConstants.encodingLinear16,
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
  });

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
      );
}
