import 'package:uuid/uuid.dart';
import 'radio_config.dart';

class NetChannel {
  final String id;
  String name;
  double frequency; // Hz
  RadioModulationType modulationType;
  double bandwidth;
  int cryptoSystem;
  int cryptoKeyId;
  String? description;

  NetChannel({
    String? id,
    required this.name,
    required this.frequency,
    this.modulationType = RadioModulationType.am,
    this.bandwidth = 25000,
    this.cryptoSystem = 0,
    this.cryptoKeyId = 0,
    this.description,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'frequency': frequency,
        'modulationType': modulationType.name,
        'bandwidth': bandwidth,
        'cryptoSystem': cryptoSystem,
        'cryptoKeyId': cryptoKeyId,
        'description': description,
      };

  factory NetChannel.fromJson(Map<String, dynamic> json) => NetChannel(
        id: json['id'] as String?,
        name: json['name'] as String,
        frequency: (json['frequency'] as num).toDouble(),
        modulationType: RadioModulationType.values.firstWhere(
          (m) => m.name == json['modulationType'],
          orElse: () => RadioModulationType.am,
        ),
        bandwidth: (json['bandwidth'] as num?)?.toDouble() ?? 25000,
        cryptoSystem: (json['cryptoSystem'] as num?)?.toInt() ?? 0,
        cryptoKeyId: (json['cryptoKeyId'] as num?)?.toInt() ?? 0,
        description: json['description'] as String?,
      );

  NetChannel copyWith({
    String? name,
    double? frequency,
    RadioModulationType? modulationType,
    double? bandwidth,
    int? cryptoSystem,
    int? cryptoKeyId,
    String? description,
  }) =>
      NetChannel(
        id: id,
        name: name ?? this.name,
        frequency: frequency ?? this.frequency,
        modulationType: modulationType ?? this.modulationType,
        bandwidth: bandwidth ?? this.bandwidth,
        cryptoSystem: cryptoSystem ?? this.cryptoSystem,
        cryptoKeyId: cryptoKeyId ?? this.cryptoKeyId,
        description: description ?? this.description,
      );
}

class NetPlan {
  final String id;
  String name;
  String description;
  List<NetChannel> channels;

  NetPlan({
    String? id,
    required this.name,
    this.description = '',
    List<NetChannel>? channels,
  })  : id = id ?? const Uuid().v4(),
        channels = channels ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'channels': channels.map((c) => c.toJson()).toList(),
      };

  factory NetPlan.fromJson(Map<String, dynamic> json) => NetPlan(
        id: json['id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        channels: (json['channels'] as List?)
                ?.map((c) => NetChannel.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static NetPlan get example => NetPlan(
        name: 'Exercise Alpha',
        description: 'Example net plan',
        channels: [
          NetChannel(name: 'ADMIN', frequency: 225000000),
          NetChannel(name: 'OPS', frequency: 225025000),
          NetChannel(name: 'FIRES', frequency: 225050000),
          NetChannel(name: 'MEDEVAC', frequency: 243000000, modulationType: RadioModulationType.am),
        ],
      );
}
