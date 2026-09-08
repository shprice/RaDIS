import 'dart:typed_data';
import 'entity_id.dart';

class EntityStatePdu {
  final EntityId entityId;
  final int forceId;
  final String marking;

  const EntityStatePdu({
    required this.entityId,
    required this.forceId,
    required this.marking,
  });

  static EntityStatePdu? tryDecode(Uint8List bytes) {
    if (bytes.length < 19) return null;
    final entityId = EntityId.fromBytes(bytes, 12);
    final forceId = bytes[18];
    String marking = '';
    if (bytes.length >= 140) {
      final charBytes = bytes.sublist(129, 140);
      final nullIdx = charBytes.indexOf(0);
      final end = nullIdx == -1 ? 11 : nullIdx;
      marking = String.fromCharCodes(charBytes.sublist(0, end)).trim();
    }
    return EntityStatePdu(entityId: entityId, forceId: forceId, marking: marking);
  }
}
