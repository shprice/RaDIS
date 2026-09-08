import 'package:uuid/uuid.dart';
import '../dis/constants.dart';

const _unset = Object();

class IntercomChannel {
  final String id;
  String name;
  String? description;
  String? color;
  int communicationsDeviceId;
  int stationName;
  int channelType;
  int encodingType;
  int sampleRate;

  IntercomChannel({
    String? id,
    required this.name,
    this.description,
    this.color,
    this.communicationsDeviceId = 1,
    this.stationName = 0,
    this.channelType = DisConstants.intercomChannelTypeFdx,
    this.encodingType = DisConstants.encodingMulaw,
    this.sampleRate = DisConstants.sampleRate8kHz,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'communicationsDeviceId': communicationsDeviceId,
        'stationName': stationName,
        'channelType': channelType,
        'encodingType': encodingType,
        'sampleRate': sampleRate,
      };

  factory IntercomChannel.fromJson(Map<String, dynamic> json) =>
      IntercomChannel(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        color: json['color'] as String?,
        communicationsDeviceId:
            (json['communicationsDeviceId'] as num?)?.toInt() ?? 1,
        stationName: (json['stationName'] as num?)?.toInt() ?? 0,
        channelType: (json['channelType'] as num?)?.toInt() ??
            DisConstants.intercomChannelTypeFdx,
        encodingType: (json['encodingType'] as num?)?.toInt() ??
            DisConstants.encodingMulaw,
        sampleRate: (json['sampleRate'] as num?)?.toInt() ??
            DisConstants.sampleRate8kHz,
      );

  IntercomChannel copyWith({
    String? name,
    String? description,
    Object? color = _unset,
    int? communicationsDeviceId,
    int? stationName,
    int? channelType,
    int? encodingType,
    int? sampleRate,
  }) =>
      IntercomChannel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color == _unset ? this.color : color as String?,
        communicationsDeviceId:
            communicationsDeviceId ?? this.communicationsDeviceId,
        stationName: stationName ?? this.stationName,
        channelType: channelType ?? this.channelType,
        encodingType: encodingType ?? this.encodingType,
        sampleRate: sampleRate ?? this.sampleRate,
      );
}
