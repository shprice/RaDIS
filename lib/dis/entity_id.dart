import 'dart:typed_data';

class EntityId {
  final int siteId;
  final int applicationId;
  final int entityNumber;

  const EntityId({
    required this.siteId,
    required this.applicationId,
    required this.entityNumber,
  });

  factory EntityId.zero() => const EntityId(siteId: 0, applicationId: 0, entityNumber: 0);

  EntityId copyWith({int? siteId, int? applicationId, int? entityNumber}) {
    return EntityId(
      siteId: siteId ?? this.siteId,
      applicationId: applicationId ?? this.applicationId,
      entityNumber: entityNumber ?? this.entityNumber,
    );
  }

  /// Encodes to 6 bytes big-endian: site(2) + application(2) + entity(2)
  Uint8List toBytes() {
    final data = ByteData(6);
    data.setUint16(0, siteId, Endian.big);
    data.setUint16(2, applicationId, Endian.big);
    data.setUint16(4, entityNumber, Endian.big);
    return data.buffer.asUint8List();
  }

  static EntityId fromBytes(Uint8List bytes, [int offset = 0]) {
    final data = ByteData.sublistView(bytes, offset, offset + 6);
    return EntityId(
      siteId: data.getUint16(0, Endian.big),
      applicationId: data.getUint16(2, Endian.big),
      entityNumber: data.getUint16(4, Endian.big),
    );
  }

  Map<String, dynamic> toJson() => {
        'siteId': siteId,
        'applicationId': applicationId,
        'entityNumber': entityNumber,
      };

  factory EntityId.fromJson(Map<String, dynamic> json) => EntityId(
        siteId: (json['siteId'] as num).toInt(),
        applicationId: (json['applicationId'] as num).toInt(),
        entityNumber: (json['entityNumber'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is EntityId &&
      siteId == other.siteId &&
      applicationId == other.applicationId &&
      entityNumber == other.entityNumber;

  @override
  int get hashCode => Object.hash(siteId, applicationId, entityNumber);

  @override
  String toString() => '$siteId:$applicationId:$entityNumber';
}
