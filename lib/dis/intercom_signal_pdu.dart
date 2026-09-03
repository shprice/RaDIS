import 'dart:typed_data';
import 'dart:math' as math;
import 'constants.dart';
import 'entity_id.dart';
import 'pdu_header.dart';

class IntercomSignalPdu {
  final EntityId entityId;
  final int communicationsDeviceId;
  final int encodingScheme;
  final int tdlType;
  final int sampleRate;
  final int dataLengthBits;
  final int samples;
  final Uint8List data;
  final int exerciseId;

  const IntercomSignalPdu({
    required this.entityId,
    required this.communicationsDeviceId,
    required this.encodingScheme,
    required this.sampleRate,
    required this.dataLengthBits,
    required this.samples,
    required this.data,
    required this.exerciseId,
    this.tdlType = DisConstants.tdlTypeOther,
  });

  int get encodingClass => (encodingScheme >> 14) & 0x3;
  int get encodingType => encodingScheme & 0x3FFF;

  Uint8List encode() {
    final dataBytes = (dataLengthBits + 7) ~/ 8;
    final paddedDataBytes = (dataBytes + 3) & ~3;
    final totalSize = 12 + 6 + 2 + 2 + 2 + 4 + 2 + 2 + paddedDataBytes;

    final bytes = Uint8List(totalSize);
    final bd = ByteData.sublistView(bytes);

    final headerBytes = PduHeader(
      exerciseId: exerciseId,
      pduType: DisConstants.pduTypeIntercomSignal,
      protocolFamily: DisConstants.protocolFamilyRadioCommunications,
      length: totalSize,
    ).withTimestampNow().encode();
    bytes.setRange(0, 12, headerBytes);

    int o = 12;
    bytes.setRange(o, o + 6, entityId.toBytes()); o += 6;
    bd.setUint16(o, communicationsDeviceId, Endian.big); o += 2;
    bd.setUint16(o, encodingScheme, Endian.big); o += 2;
    bd.setUint16(o, tdlType, Endian.big); o += 2;
    bd.setUint32(o, sampleRate, Endian.big); o += 4;
    bd.setUint16(o, dataLengthBits, Endian.big); o += 2;
    bd.setUint16(o, samples, Endian.big); o += 2;
    final copyLen = math.min(data.length, dataBytes);
    bytes.setRange(o, o + copyLen, data);

    return bytes;
  }

  static IntercomSignalPdu? decode(Uint8List bytes) {
    if (bytes.length < 32) return null;
    final bd = ByteData.sublistView(bytes);
    final header = PduHeader.decode(bytes);

    int o = 12;
    final entityId = EntityId.fromBytes(bytes, o); o += 6;
    final devId = bd.getUint16(o, Endian.big); o += 2;
    final encodingScheme = bd.getUint16(o, Endian.big); o += 2;
    final tdlType = bd.getUint16(o, Endian.big); o += 2;
    final sampleRate = bd.getUint32(o, Endian.big); o += 4;
    final dataLengthBits = bd.getUint16(o, Endian.big); o += 2;
    final samples = bd.getUint16(o, Endian.big); o += 2;

    final dataBytes = (dataLengthBits + 7) ~/ 8;
    Uint8List data = Uint8List(0);
    if (o + dataBytes <= bytes.length) {
      data = bytes.sublist(o, o + dataBytes);
    }

    return IntercomSignalPdu(
      entityId: entityId,
      communicationsDeviceId: devId,
      encodingScheme: encodingScheme,
      tdlType: tdlType,
      sampleRate: sampleRate,
      dataLengthBits: dataLengthBits,
      samples: samples,
      data: data,
      exerciseId: header.exerciseId,
    );
  }
}
