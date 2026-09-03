import 'dart:typed_data';
import 'constants.dart';

class PduHeader {
  final int protocolVersion;
  final int exerciseId;
  final int pduType;
  final int protocolFamily;
  final int timestamp;
  final int length;

  const PduHeader({
    required this.exerciseId,
    required this.pduType,
    required this.protocolFamily,
    required this.length,
    this.protocolVersion = DisConstants.protocolVersion,
    this.timestamp = 0,
  });

  /// Encodes to 12 bytes big-endian.
  Uint8List encode() {
    final data = ByteData(12);
    data.setUint8(0, protocolVersion);
    data.setUint8(1, exerciseId);
    data.setUint8(2, pduType);
    data.setUint8(3, protocolFamily);
    data.setUint32(4, timestamp, Endian.big);
    data.setUint16(8, length, Endian.big);
    data.setUint16(10, 0, Endian.big); // padding
    return data.buffer.asUint8List();
  }

  static PduHeader decode(Uint8List bytes, [int offset = 0]) {
    final data = ByteData.sublistView(bytes, offset, offset + 12);
    return PduHeader(
      protocolVersion: data.getUint8(0),
      exerciseId: data.getUint8(1),
      pduType: data.getUint8(2),
      protocolFamily: data.getUint8(3),
      timestamp: data.getUint32(4, Endian.big),
      length: data.getUint16(8, Endian.big),
    );
  }

  /// DIS relative timestamp: microseconds since top of hour mapped to 0..(2^31 - 1).
  static int disTimestampNow() {
    final now = DateTime.now().toUtc();
    final topOfHour = DateTime.utc(now.year, now.month, now.day, now.hour);
    final microseconds = now.difference(topOfHour).inMicroseconds;
    // Scale to 2^31 units per hour (3600 * 1e6 microseconds per hour)
    const totalUnits = 1 << 31;
    const microsecondsPerHour = 3600 * 1000000;
    final units = (microseconds * totalUnits ~/ microsecondsPerHour) & 0xFFFFFFFE;
    return units; // bit 0 = 0 → relative timestamp
  }

  PduHeader withTimestampNow() => PduHeader(
        protocolVersion: protocolVersion,
        exerciseId: exerciseId,
        pduType: pduType,
        protocolFamily: protocolFamily,
        length: length,
        timestamp: disTimestampNow(),
      );
}
