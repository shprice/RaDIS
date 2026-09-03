import 'package:uuid/uuid.dart';
import '../dis/entity_id.dart';
import '../dis/constants.dart';
import 'ptt_binding.dart';

class IntercomConfig {
  final String id;
  String name;
  bool enabled;
  String? inputDeviceId;
  String? outputDeviceId;
  double inputGain;
  double outputVolume;
  PttBinding? pttBinding;
  bool voxEnabled;
  double voxThreshold;
  Duration voxHangTime;
  EntityId entityId;
  int communicationsDeviceId;
  int encodingType;
  int sampleRate;

  IntercomConfig({
    String? id,
    required this.name,
    this.enabled = true,
    this.inputDeviceId,
    this.outputDeviceId,
    this.inputGain = 1.0,
    this.outputVolume = 0.8,
    this.pttBinding,
    this.voxEnabled = false,
    this.voxThreshold = 0.05,
    this.voxHangTime = const Duration(milliseconds: 500),
    EntityId? entityId,
    this.communicationsDeviceId = 1,
    this.encodingType = DisConstants.encodingMulaw,
    this.sampleRate = DisConstants.sampleRate8kHz,
  })  : id = id ?? const Uuid().v4(),
        entityId = entityId ?? EntityId.zero();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'inputDeviceId': inputDeviceId,
        'outputDeviceId': outputDeviceId,
        'inputGain': inputGain,
        'outputVolume': outputVolume,
        'pttBinding': pttBinding?.toJson(),
        'voxEnabled': voxEnabled,
        'voxThreshold': voxThreshold,
        'voxHangTimeMs': voxHangTime.inMilliseconds,
        'entityId': entityId.toJson(),
        'communicationsDeviceId': communicationsDeviceId,
        'encodingType': encodingType,
        'sampleRate': sampleRate,
      };

  factory IntercomConfig.fromJson(Map<String, dynamic> json) => IntercomConfig(
        id: json['id'] as String?,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        inputDeviceId: json['inputDeviceId'] as String?,
        outputDeviceId: json['outputDeviceId'] as String?,
        inputGain: (json['inputGain'] as num?)?.toDouble() ?? 1.0,
        outputVolume: (json['outputVolume'] as num?)?.toDouble() ?? 0.8,
        pttBinding: json['pttBinding'] != null
            ? PttBinding.fromJson(json['pttBinding'] as Map<String, dynamic>)
            : null,
        voxEnabled: json['voxEnabled'] as bool? ?? false,
        voxThreshold: (json['voxThreshold'] as num?)?.toDouble() ?? 0.05,
        voxHangTime: Duration(
          milliseconds: (json['voxHangTimeMs'] as num?)?.toInt() ?? 500,
        ),
        entityId: json['entityId'] != null
            ? EntityId.fromJson(json['entityId'] as Map<String, dynamic>)
            : EntityId.zero(),
        communicationsDeviceId:
            (json['communicationsDeviceId'] as num?)?.toInt() ?? 1,
        encodingType: (json['encodingType'] as num?)?.toInt() ??
            DisConstants.encodingMulaw,
        sampleRate: (json['sampleRate'] as num?)?.toInt() ??
            DisConstants.sampleRate8kHz,
      );
}
