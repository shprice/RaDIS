import 'dart:typed_data';
import 'constants.dart';
import 'entity_id.dart';
import 'pdu_header.dart';

class ReceiverPdu {
  final EntityId entityId;
  final int radioId;
  final int receiverState;
  final double receivedPowerDbm;
  final EntityId transmitterEntityId;
  final int transmitterRadioId;
  final int exerciseId;
  final int protocolVersion;

  const ReceiverPdu({
    required this.entityId,
    required this.radioId,
    required this.receiverState,
    required this.transmitterEntityId,
    required this.transmitterRadioId,
    required this.exerciseId,
    this.receivedPowerDbm = 0.0,
    this.protocolVersion = DisConstants.protocolVersion,
  });

  Uint8List encode() {
    // Header(12) + entityId(6) + radioId(2) + receiverState(2) + padding(2)
    // + receivedPower(4) + transmitterEntityId(6) + transmitterRadioId(2) = 36 bytes
    const totalSize = 36;
    final bytes = Uint8List(totalSize);
    final bd = ByteData.sublistView(bytes);

    final headerBytes = PduHeader(
      exerciseId: exerciseId,
      protocolVersion: protocolVersion,
      pduType: DisConstants.pduTypeReceiver,
      protocolFamily: DisConstants.protocolFamilyRadioCommunications,
      length: totalSize,
    ).withTimestampNow().encode();
    bytes.setRange(0, 12, headerBytes);

    int o = 12;
    bytes.setRange(o, o + 6, entityId.toBytes()); o += 6;
    bd.setUint16(o, radioId, Endian.big); o += 2;
    bd.setUint16(o, receiverState, Endian.big); o += 2;
    bd.setUint16(o, 0, Endian.big); o += 2; // padding
    bd.setFloat32(o, receivedPowerDbm, Endian.big); o += 4;
    bytes.setRange(o, o + 6, transmitterEntityId.toBytes()); o += 6;
    bd.setUint16(o, transmitterRadioId, Endian.big);

    return bytes;
  }

  static ReceiverPdu? decode(Uint8List bytes) {
    if (bytes.length < 36) return null;
    final bd = ByteData.sublistView(bytes);
    final header = PduHeader.decode(bytes);

    int o = 12;
    final entityId = EntityId.fromBytes(bytes, o); o += 6;
    final radioId = bd.getUint16(o, Endian.big); o += 2;
    final receiverState = bd.getUint16(o, Endian.big); o += 2;
    o += 2; // padding
    final receivedPower = bd.getFloat32(o, Endian.big); o += 4;
    final txEntityId = EntityId.fromBytes(bytes, o); o += 6;
    final txRadioId = bd.getUint16(o, Endian.big);

    return ReceiverPdu(
      entityId: entityId,
      radioId: radioId,
      receiverState: receiverState,
      receivedPowerDbm: receivedPower,
      transmitterEntityId: txEntityId,
      transmitterRadioId: txRadioId,
      exerciseId: header.exerciseId,
    );
  }
}
