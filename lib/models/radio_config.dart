import 'package:uuid/uuid.dart';
import '../dis/entity_id.dart';
import '../dis/constants.dart';
import 'ptt_binding.dart';

enum RadioModulationType {
  am,
  fm,
  usb,
  lsb,
  cw,
  fmhq,
  am8,
  sincgars,
  havequick;

  String get displayName {
    switch (this) {
      case am: return 'AM';
      case fm: return 'FM';
      case usb: return 'USB';
      case lsb: return 'LSB';
      case cw: return 'CW';
      case fmhq: return 'FM-HQ';
      case am8: return 'AM-8';
      case sincgars: return 'SINCGARS';
      case havequick: return 'HAVE QUICK';
    }
  }
}

class RadioConfig {
  final String id;
  String name;
  bool enabled;

  double frequency; // Hz
  double bandwidth; // Hz
  RadioModulationType modulationType;
  double powerWatts;

  int cryptoSystem;
  int cryptoKeyId;

  String? inputDeviceId;
  String? outputDeviceId;
  double inputGain;
  double outputVolume;
  double squelch;

  PttBinding? pttBinding;
  bool voxEnabled;
  double voxThreshold;
  Duration voxHangTime;

  String? netPlanId;
  int? netChannelIndex;

  EntityId entityId;
  int radioNumber;

  RadioConfig({
    String? id,
    required this.name,
    this.enabled = true,
    this.frequency = 225000000,
    this.bandwidth = 25000,
    this.modulationType = RadioModulationType.am,
    this.powerWatts = 10.0,
    this.cryptoSystem = DisConstants.cryptoSystemNone,
    this.cryptoKeyId = 0,
    this.inputDeviceId,
    this.outputDeviceId,
    this.inputGain = 1.0,
    this.outputVolume = 0.8,
    this.squelch = 0.1,
    this.pttBinding,
    this.voxEnabled = false,
    this.voxThreshold = 0.05,
    this.voxHangTime = const Duration(milliseconds: 500),
    this.netPlanId,
    this.netChannelIndex,
    EntityId? entityId,
    this.radioNumber = 1,
  })  : id = id ?? const Uuid().v4(),
        entityId = entityId ?? EntityId.zero();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'frequency': frequency,
        'bandwidth': bandwidth,
        'modulationType': modulationType.name,
        'powerWatts': powerWatts,
        'cryptoSystem': cryptoSystem,
        'cryptoKeyId': cryptoKeyId,
        'inputDeviceId': inputDeviceId,
        'outputDeviceId': outputDeviceId,
        'inputGain': inputGain,
        'outputVolume': outputVolume,
        'squelch': squelch,
        'pttBinding': pttBinding?.toJson(),
        'voxEnabled': voxEnabled,
        'voxThreshold': voxThreshold,
        'voxHangTimeMs': voxHangTime.inMilliseconds,
        'netPlanId': netPlanId,
        'netChannelIndex': netChannelIndex,
        'entityId': entityId.toJson(),
        'radioNumber': radioNumber,
      };

  factory RadioConfig.fromJson(Map<String, dynamic> json) => RadioConfig(
        id: json['id'] as String?,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        frequency: (json['frequency'] as num?)?.toDouble() ?? 225000000,
        bandwidth: (json['bandwidth'] as num?)?.toDouble() ?? 25000,
        modulationType: RadioModulationType.values.firstWhere(
          (m) => m.name == json['modulationType'],
          orElse: () => RadioModulationType.am,
        ),
        powerWatts: (json['powerWatts'] as num?)?.toDouble() ?? 10.0,
        cryptoSystem: (json['cryptoSystem'] as num?)?.toInt() ?? 0,
        cryptoKeyId: (json['cryptoKeyId'] as num?)?.toInt() ?? 0,
        inputDeviceId: json['inputDeviceId'] as String?,
        outputDeviceId: json['outputDeviceId'] as String?,
        inputGain: (json['inputGain'] as num?)?.toDouble() ?? 1.0,
        outputVolume: (json['outputVolume'] as num?)?.toDouble() ?? 0.8,
        squelch: (json['squelch'] as num?)?.toDouble() ?? 0.1,
        pttBinding: json['pttBinding'] != null
            ? PttBinding.fromJson(json['pttBinding'] as Map<String, dynamic>)
            : null,
        voxEnabled: json['voxEnabled'] as bool? ?? false,
        voxThreshold: (json['voxThreshold'] as num?)?.toDouble() ?? 0.05,
        voxHangTime: Duration(
          milliseconds: (json['voxHangTimeMs'] as num?)?.toInt() ?? 500,
        ),
        netPlanId: json['netPlanId'] as String?,
        netChannelIndex: (json['netChannelIndex'] as num?)?.toInt(),
        entityId: json['entityId'] != null
            ? EntityId.fromJson(json['entityId'] as Map<String, dynamic>)
            : EntityId.zero(),
        radioNumber: (json['radioNumber'] as num?)?.toInt() ?? 1,
      );

  RadioConfig copyWith({
    String? name,
    bool? enabled,
    double? frequency,
    double? bandwidth,
    RadioModulationType? modulationType,
    double? powerWatts,
    int? cryptoSystem,
    int? cryptoKeyId,
    String? inputDeviceId,
    String? outputDeviceId,
    double? inputGain,
    double? outputVolume,
    double? squelch,
    PttBinding? pttBinding,
    bool? voxEnabled,
    double? voxThreshold,
    Duration? voxHangTime,
    String? netPlanId,
    int? netChannelIndex,
    EntityId? entityId,
    int? radioNumber,
  }) =>
      RadioConfig(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        frequency: frequency ?? this.frequency,
        bandwidth: bandwidth ?? this.bandwidth,
        modulationType: modulationType ?? this.modulationType,
        powerWatts: powerWatts ?? this.powerWatts,
        cryptoSystem: cryptoSystem ?? this.cryptoSystem,
        cryptoKeyId: cryptoKeyId ?? this.cryptoKeyId,
        inputDeviceId: inputDeviceId ?? this.inputDeviceId,
        outputDeviceId: outputDeviceId ?? this.outputDeviceId,
        inputGain: inputGain ?? this.inputGain,
        outputVolume: outputVolume ?? this.outputVolume,
        squelch: squelch ?? this.squelch,
        pttBinding: pttBinding ?? this.pttBinding,
        voxEnabled: voxEnabled ?? this.voxEnabled,
        voxThreshold: voxThreshold ?? this.voxThreshold,
        voxHangTime: voxHangTime ?? this.voxHangTime,
        netPlanId: netPlanId ?? this.netPlanId,
        netChannelIndex: netChannelIndex ?? this.netChannelIndex,
        entityId: entityId ?? this.entityId,
        radioNumber: radioNumber ?? this.radioNumber,
      );
}
