import 'package:uuid/uuid.dart';
import '../dis/entity_id.dart';
import '../dis/constants.dart';
import '../dis/dis_network.dart';
import 'trigger_mode.dart';

TriggerMode _parseTriggerMode(Map<String, dynamic> json) {
  final name = json['triggerMode'] as String?;
  if (name != null) {
    return TriggerMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => TriggerMode.ptt,
    );
  }
  if (json['permanentSend'] == true) return TriggerMode.latchedPtt;
  if (json['voxEnabled'] == true) return TriggerMode.vox;
  return TriggerMode.ptt;
}

class IntercomConfig {
  final String id;
  String name;
  bool enabled;
  String? inputDeviceId;
  String? outputDeviceId;
  double inputGain;
  double outputVolume;
  double sidetoneVolume;
  double outputPan;
  List<String> pttBindingIds;
  TriggerMode triggerMode;
  double voxThreshold;
  Duration voxHangTime;
  int exerciseId;
  EntityId entityId;

  /// DIS sourceCommunicationsDeviceId — identifies this intercom unit (UINT16)
  int communicationsDeviceId;

  /// DIS sourceLineId — station identifier within the intercom network (UINT8, 0–255)
  int stationName;

  /// communicationsChannelType (SISO-REF-010 ENUM8):
  /// 0=Reserved, 1=FDX, 2=HDX RX-only, 3=HDX TX-only, 4=HDX
  int channelType;

  int encodingType;
  int sampleRate;

  // Per-intercom DIS network settings
  String disLocalAddress;
  int disPort;
  bool disUseMulticast;
  String disMulticastGroup;
  String disUnicastAddress;
  String? disNetworkInterface;
  int disProtocolVersion;

  bool get voxEnabled => triggerMode == TriggerMode.vox;
  bool get permanentSend => triggerMode == TriggerMode.latchedPtt;

  IntercomConfig({
    String? id,
    required this.name,
    this.enabled = true,
    this.inputDeviceId,
    this.outputDeviceId,
    this.inputGain = 1.0,
    this.outputVolume = 0.8,
    this.sidetoneVolume = 0.0,
    this.outputPan = 0.0,
    List<String>? pttBindingIds,
    this.triggerMode = TriggerMode.ptt,
    this.voxThreshold = 0.05,
    this.voxHangTime = const Duration(milliseconds: 500),
    this.exerciseId = 1,
    EntityId? entityId,
    this.communicationsDeviceId = 1,
    this.stationName = 0,
    this.channelType = DisConstants.intercomChannelTypeFdx,
    this.encodingType = DisConstants.encodingMulaw,
    this.sampleRate = DisConstants.sampleRate8kHz,
    this.disLocalAddress = DisConstants.defaultLocalAddress,
    this.disPort = DisConstants.defaultPort,
    this.disUseMulticast = true,
    this.disMulticastGroup = DisConstants.defaultMulticastGroup,
    this.disUnicastAddress = DisConstants.defaultBroadcastAddress,
    this.disNetworkInterface,
    this.disProtocolVersion = DisConstants.protocolVersionDis6,
  })  : id = id ?? const Uuid().v4(),
        entityId = entityId ?? EntityId.zero(),
        pttBindingIds = pttBindingIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'inputDeviceId': inputDeviceId,
        'outputDeviceId': outputDeviceId,
        'inputGain': inputGain,
        'outputVolume': outputVolume,
        'sidetoneVolume': sidetoneVolume,
        'outputPan': outputPan,
        'pttBindingIds': pttBindingIds,
        'triggerMode': triggerMode.name,
        'voxThreshold': voxThreshold,
        'voxHangTimeMs': voxHangTime.inMilliseconds,
        'exerciseId': exerciseId,
        'entityId': entityId.toJson(),
        'communicationsDeviceId': communicationsDeviceId,
        'stationName': stationName,
        'channelType': channelType,
        'encodingType': encodingType,
        'sampleRate': sampleRate,
        'disLocalAddress': disLocalAddress,
        'disPort': disPort,
        'disUseMulticast': disUseMulticast,
        'disMulticastGroup': disMulticastGroup,
        'disUnicastAddress': disUnicastAddress,
        'disNetworkInterface': disNetworkInterface,
        'disProtocolVersion': disProtocolVersion,
      };

  factory IntercomConfig.fromJson(Map<String, dynamic> json) => IntercomConfig(
        id: json['id'] as String?,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        inputDeviceId: json['inputDeviceId'] as String?,
        outputDeviceId: json['outputDeviceId'] as String?,
        inputGain: (json['inputGain'] as num?)?.toDouble() ?? 1.0,
        outputVolume: (json['outputVolume'] as num?)?.toDouble() ?? 0.8,
        sidetoneVolume: (json['sidetoneVolume'] as num?)?.toDouble() ?? 0.0,
        outputPan: (json['outputPan'] as num?)?.toDouble() ?? 0.0,
        pttBindingIds: (json['pttBindingIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        triggerMode: _parseTriggerMode(json),
        voxThreshold: (json['voxThreshold'] as num?)?.toDouble() ?? 0.05,
        voxHangTime: Duration(
          milliseconds: (json['voxHangTimeMs'] as num?)?.toInt() ?? 500,
        ),
        exerciseId: (json['exerciseId'] as num?)?.toInt() ?? 1,
        entityId: json['entityId'] != null
            ? EntityId.fromJson(json['entityId'] as Map<String, dynamic>)
            : EntityId.zero(),
        communicationsDeviceId:
            (json['communicationsDeviceId'] as num?)?.toInt() ??
                // migrate from old nets-based config: use the old manual device ID
                (json['nets'] == null ? 1 : 1),
        stationName: (json['stationName'] as num?)?.toInt() ?? 0,
        channelType: (json['channelType'] as num?)?.toInt() ??
            DisConstants.intercomChannelTypeFdx,
        encodingType: (json['encodingType'] as num?)?.toInt() ??
            DisConstants.encodingMulaw,
        sampleRate: (json['sampleRate'] as num?)?.toInt() ??
            DisConstants.sampleRate8kHz,
        disLocalAddress: json['disLocalAddress'] as String? ?? DisConstants.defaultLocalAddress,
        disPort: (json['disPort'] as num?)?.toInt() ?? DisConstants.defaultPort,
        disUseMulticast: json['disUseMulticast'] as bool? ?? true,
        disMulticastGroup: json['disMulticastGroup'] as String? ?? DisConstants.defaultMulticastGroup,
        disUnicastAddress: json['disUnicastAddress'] as String? ?? DisConstants.defaultBroadcastAddress,
        disNetworkInterface: json['disNetworkInterface'] as String?,
        disProtocolVersion: (json['disProtocolVersion'] as num?)?.toInt() ?? DisConstants.protocolVersionDis6,
      );

  DisNetworkConfig get networkConfig => DisNetworkConfig(
        localAddress: disLocalAddress,
        port: disPort,
        useMulticast: disUseMulticast,
        multicastGroup: disMulticastGroup,
        unicastAddress: disUnicastAddress,
        networkInterface: disNetworkInterface,
      );

  IntercomConfig copyWith({
    String? name,
    bool? enabled,
    String? inputDeviceId,
    String? outputDeviceId,
    double? inputGain,
    double? outputVolume,
    double? sidetoneVolume,
    double? outputPan,
    List<String>? pttBindingIds,
    TriggerMode? triggerMode,
    double? voxThreshold,
    Duration? voxHangTime,
    int? exerciseId,
    EntityId? entityId,
    int? communicationsDeviceId,
    int? stationName,
    int? channelType,
    int? encodingType,
    int? sampleRate,
    String? disLocalAddress,
    int? disPort,
    bool? disUseMulticast,
    String? disMulticastGroup,
    String? disUnicastAddress,
    String? disNetworkInterface,
    int? disProtocolVersion,
  }) =>
      IntercomConfig(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        inputDeviceId: inputDeviceId ?? this.inputDeviceId,
        outputDeviceId: outputDeviceId ?? this.outputDeviceId,
        inputGain: inputGain ?? this.inputGain,
        outputVolume: outputVolume ?? this.outputVolume,
        sidetoneVolume: sidetoneVolume ?? this.sidetoneVolume,
        outputPan: outputPan ?? this.outputPan,
        pttBindingIds: pttBindingIds ?? this.pttBindingIds,
        triggerMode: triggerMode ?? this.triggerMode,
        voxThreshold: voxThreshold ?? this.voxThreshold,
        voxHangTime: voxHangTime ?? this.voxHangTime,
        exerciseId: exerciseId ?? this.exerciseId,
        entityId: entityId ?? this.entityId,
        communicationsDeviceId:
            communicationsDeviceId ?? this.communicationsDeviceId,
        stationName: stationName ?? this.stationName,
        channelType: channelType ?? this.channelType,
        encodingType: encodingType ?? this.encodingType,
        sampleRate: sampleRate ?? this.sampleRate,
        disLocalAddress: disLocalAddress ?? this.disLocalAddress,
        disPort: disPort ?? this.disPort,
        disUseMulticast: disUseMulticast ?? this.disUseMulticast,
        disMulticastGroup: disMulticastGroup ?? this.disMulticastGroup,
        disUnicastAddress: disUnicastAddress ?? this.disUnicastAddress,
        disNetworkInterface: disNetworkInterface ?? this.disNetworkInterface,
        disProtocolVersion: disProtocolVersion ?? this.disProtocolVersion,
      );
}
