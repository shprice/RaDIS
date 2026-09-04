import 'dart:typed_data';
import 'constants.dart';
import 'entity_id.dart';
import 'pdu_header.dart';

class IntercomControlPdu {
  final int controlType;
  final int communicationsChannelType;
  final EntityId sourceEntityId;
  final int sourceCommunicationsDeviceId;
  final int sourceLineId;
  final int transmitPriority;
  final int transmitLineState;
  final int command;
  final EntityId masterEntityId;
  final int masterCommunicationsDeviceId;
  final Uint8List intercomParameters;
  final int exerciseId;
  final int protocolVersion;

  IntercomControlPdu({
    required this.controlType,
    required this.sourceEntityId,
    required this.sourceCommunicationsDeviceId,
    required this.masterEntityId,
    required this.masterCommunicationsDeviceId,
    required this.transmitLineState,
    required this.exerciseId,
    this.communicationsChannelType = DisConstants.intercomChannelTypeFdx,
    this.sourceLineId = 0,
    this.transmitPriority = 0,
    this.command = 0,
    Uint8List? intercomParameters,
    this.protocolVersion = DisConstants.protocolVersion,
  }) : intercomParameters = intercomParameters ?? Uint8List(0);

  Uint8List encode() {
    // IEEE 1278.1-2012 Table B-66 Intercom Control PDU:
    // header(12) + controlType(1) + channelType(1) + sourceEntityId(6)
    // + sourceDevId(2) + sourceLineId(1) + priority(1) + lineState(1) + command(1)
    // + masterEntityId(6) + masterDevId(2) + padding(2) + parametersLength(4)
    // = 40 bytes fixed (padding aligns parametersLength to a 32-bit boundary)
    final totalSize = 40 + intercomParameters.length;
    final bytes = Uint8List(totalSize);
    final bd = ByteData.sublistView(bytes);

    final headerBytes = PduHeader(
      exerciseId: exerciseId,
      protocolVersion: protocolVersion,
      pduType: DisConstants.pduTypeIntercomControl,
      protocolFamily: DisConstants.protocolFamilyRadioCommunications,
      length: totalSize,
    ).withTimestampNow().encode();
    bytes.setRange(0, 12, headerBytes);

    int o = 12;
    bd.setUint8(o, controlType); o += 1;
    bd.setUint8(o, communicationsChannelType & 0xFF); o += 1;
    bytes.setRange(o, o + 6, sourceEntityId.toBytes()); o += 6;
    bd.setUint16(o, sourceCommunicationsDeviceId, Endian.big); o += 2;
    bd.setUint8(o, sourceLineId); o += 1;
    bd.setUint8(o, transmitPriority); o += 1;
    bd.setUint8(o, transmitLineState); o += 1;
    bd.setUint8(o, command); o += 1;
    bytes.setRange(o, o + 6, masterEntityId.toBytes()); o += 6;
    bd.setUint16(o, masterCommunicationsDeviceId, Endian.big); o += 2;
    o += 2; // padding — aligns parametersLength to 32-bit boundary
    bd.setUint32(o, intercomParameters.length, Endian.big); o += 4;
    if (intercomParameters.isNotEmpty) {
      bytes.setRange(o, o + intercomParameters.length, intercomParameters);
    }

    return bytes;
  }

  static IntercomControlPdu? decode(Uint8List bytes) {
    if (bytes.length < 40) return null;
    final bd = ByteData.sublistView(bytes);
    final header = PduHeader.decode(bytes);

    int o = 12;
    final controlType = bd.getUint8(o); o += 1;
    final channelType = bd.getUint8(o); o += 1;
    final sourceEntityId = EntityId.fromBytes(bytes, o); o += 6;
    final sourceDevId = bd.getUint16(o, Endian.big); o += 2;
    final sourceLineId = bd.getUint8(o); o += 1;
    final transmitPriority = bd.getUint8(o); o += 1;
    final transmitLineState = bd.getUint8(o); o += 1;
    final command = bd.getUint8(o); o += 1;
    final masterEntityId = EntityId.fromBytes(bytes, o); o += 6;
    final masterDevId = bd.getUint16(o, Endian.big); o += 2;
    o += 2; // skip padding
    final paramsLength = bd.getUint32(o, Endian.big); o += 4;

    Uint8List params = Uint8List(0);
    if (paramsLength > 0 && o + paramsLength <= bytes.length) {
      params = bytes.sublist(o, o + paramsLength.toInt());
    }

    return IntercomControlPdu(
      controlType: controlType,
      communicationsChannelType: channelType,
      sourceEntityId: sourceEntityId,
      sourceCommunicationsDeviceId: sourceDevId,
      sourceLineId: sourceLineId,
      transmitPriority: transmitPriority,
      transmitLineState: transmitLineState,
      command: command,
      masterEntityId: masterEntityId,
      masterCommunicationsDeviceId: masterDevId,
      intercomParameters: params,
      exerciseId: header.exerciseId,
    );
  }
}
