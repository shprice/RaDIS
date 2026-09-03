import 'dart:typed_data';
import 'dart:math' as math;
import 'constants.dart';
import 'entity_id.dart';
import 'pdu_header.dart';

class SignalPdu {
  final EntityId entityId;
  final int radioId;
  final int encodingScheme; // bits 15-14 = class, bits 13-0 = type
  final int tdlType;
  final int sampleRate;
  final int dataLengthBits; // data length in bits
  final int samples;
  final Uint8List data;
  final int exerciseId;

  const SignalPdu({
    required this.entityId,
    required this.radioId,
    required this.encodingScheme,
    required this.sampleRate,
    required this.dataLengthBits,
    required this.samples,
    required this.data,
    required this.exerciseId,
    this.tdlType = DisConstants.tdlTypeOther,
  });

  static int buildEncodingScheme(int encodingClass, int encodingType) {
    return ((encodingClass & 0x3) << 14) | (encodingType & 0x3FFF);
  }

  int get encodingClass => (encodingScheme >> 14) & 0x3;
  int get encodingType => encodingScheme & 0x3FFF;

  Uint8List encode() {
    // Header(12) + entityId(6) + radioId(2) + encodingScheme(2) + tdlType(2)
    // + sampleRate(4) + dataLength(2) + samples(2) + data(variable)
    // Pad data to 32-bit boundary
    final dataBytes = (dataLengthBits + 7) ~/ 8;
    final paddedDataBytes = (dataBytes + 3) & ~3; // round up to 4-byte boundary
    final totalSize = 12 + 6 + 2 + 2 + 2 + 4 + 2 + 2 + paddedDataBytes;

    final bytes = Uint8List(totalSize);
    final bd = ByteData.sublistView(bytes);

    final headerBytes = PduHeader(
      exerciseId: exerciseId,
      pduType: DisConstants.pduTypeSignal,
      protocolFamily: DisConstants.protocolFamilyRadioCommunications,
      length: totalSize,
    ).withTimestampNow().encode();
    bytes.setRange(0, 12, headerBytes);

    int o = 12;
    bytes.setRange(o, o + 6, entityId.toBytes()); o += 6;
    bd.setUint16(o, radioId, Endian.big); o += 2;
    bd.setUint16(o, encodingScheme, Endian.big); o += 2;
    bd.setUint16(o, tdlType, Endian.big); o += 2;
    bd.setUint32(o, sampleRate, Endian.big); o += 4;
    bd.setUint16(o, dataLengthBits, Endian.big); o += 2;
    bd.setUint16(o, samples, Endian.big); o += 2;
    final copyLen = math.min(data.length, dataBytes);
    bytes.setRange(o, o + copyLen, data);

    return bytes;
  }

  static SignalPdu? decode(Uint8List bytes) {
    if (bytes.length < 32) return null;
    final bd = ByteData.sublistView(bytes);
    final header = PduHeader.decode(bytes);

    int o = 12;
    final entityId = EntityId.fromBytes(bytes, o); o += 6;
    final radioId = bd.getUint16(o, Endian.big); o += 2;
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

    return SignalPdu(
      entityId: entityId,
      radioId: radioId,
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
