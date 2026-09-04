import 'dart:typed_data';
import 'constants.dart';
import 'entity_id.dart';
import 'pdu_header.dart';

class RadioEntityType {
  final int kind;
  final int domain;
  final int country; // 16-bit
  final int category;
  final int subcategory;
  final int specific;
  final int extra;

  const RadioEntityType({
    this.kind = DisConstants.radioEntityKindRadio,
    this.domain = 0,
    this.country = 0,
    this.category = 0,
    this.subcategory = 0,
    this.specific = 0,
    this.extra = 0,
  });

  factory RadioEntityType.fromJson(Map<String, dynamic> j) => RadioEntityType(
        kind: (j['kind'] as num?)?.toInt() ?? 1,
        domain: (j['domain'] as num?)?.toInt() ?? 0,
        country: (j['country'] as num?)?.toInt() ?? 0,
        category: (j['category'] as num?)?.toInt() ?? 0,
        subcategory: (j['subcategory'] as num?)?.toInt() ?? 0,
        specific: (j['specific'] as num?)?.toInt() ?? 0,
        extra: (j['extra'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'domain': domain,
        'country': country,
        'category': category,
        'subcategory': subcategory,
        'specific': specific,
        'extra': extra,
      };
}

class ModulationType {
  final int spreadSpectrum; // 16-bit
  final int major;          // 16-bit (modulation class)
  final int detail;         // 16-bit
  final int radioSystem;    // 16-bit

  const ModulationType({
    this.spreadSpectrum = DisConstants.spreadSpectrumNone,
    this.major = DisConstants.modulationClassAmplitude,
    this.detail = DisConstants.modulationDetailAm,
    this.radioSystem = DisConstants.radioSystemOther,
  });

  factory ModulationType.fm() => const ModulationType(
        major: DisConstants.modulationClassAngle,
        detail: DisConstants.modulationDetailFm,
      );

  factory ModulationType.am() => const ModulationType(
        major: DisConstants.modulationClassAmplitude,
        detail: DisConstants.modulationDetailAm,
      );

  factory ModulationType.usb() => const ModulationType(
        major: DisConstants.modulationClassAmplitude,
        detail: DisConstants.modulationDetailUsb,
      );

  factory ModulationType.lsb() => const ModulationType(
        major: DisConstants.modulationClassAmplitude,
        detail: DisConstants.modulationDetailLsb,
      );

  factory ModulationType.sincgars() => const ModulationType(
        major: DisConstants.modulationClassAngle,
        detail: DisConstants.modulationDetailFm,
        radioSystem: DisConstants.radioSystemSincgars,
      );

  factory ModulationType.haveQuick() => const ModulationType(
        major: DisConstants.modulationClassAmplitude,
        detail: DisConstants.modulationDetailAm,
        radioSystem: DisConstants.radioSystemHaveQuick,
        spreadSpectrum: DisConstants.spreadSpectrumFrequencyHopping,
      );

  factory ModulationType.fromJson(Map<String, dynamic> j) => ModulationType(
        spreadSpectrum: (j['spreadSpectrum'] as num?)?.toInt() ?? 0,
        major: (j['major'] as num?)?.toInt() ?? 1,
        detail: (j['detail'] as num?)?.toInt() ?? 1,
        radioSystem: (j['radioSystem'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'spreadSpectrum': spreadSpectrum,
        'major': major,
        'detail': detail,
        'radioSystem': radioSystem,
      };
}

class TransmitterPdu {
  final EntityId entityId;
  final int radioId;
  final RadioEntityType radioEntityType;
  final int transmitState;
  final int inputSource;
  // Antenna location (world coordinates in meters - ECEF)
  final double antennaLocationX;
  final double antennaLocationY;
  final double antennaLocationZ;
  // Relative antenna location (entity coordinates)
  final double relativeAntennaX;
  final double relativeAntennaY;
  final double relativeAntennaZ;
  final int antennaPatternType;
  final int frequency; // Hz as uint64
  final double transmitFrequencyBandwidth;
  final double power; // watts
  final ModulationType modulationType;
  final int cryptoSystem;
  final int cryptoKeyId;
  final Uint8List modulationParameters;
  final int exerciseId;
  final int protocolVersion;

  TransmitterPdu({
    required this.entityId,
    required this.radioId,
    required this.transmitState,
    required this.frequency,
    required this.modulationType,
    required this.exerciseId,
    this.radioEntityType = const RadioEntityType(),
    this.inputSource = DisConstants.inputSourceOther,
    this.antennaLocationX = 0,
    this.antennaLocationY = 0,
    this.antennaLocationZ = 0,
    this.relativeAntennaX = 0,
    this.relativeAntennaY = 0,
    this.relativeAntennaZ = 0,
    this.antennaPatternType = DisConstants.antennaPatternOmniDirectional,
    this.transmitFrequencyBandwidth = 0,
    this.power = 10.0,
    this.cryptoSystem = DisConstants.cryptoSystemNone,
    this.cryptoKeyId = 0,
    Uint8List? modulationParameters,
    this.protocolVersion = DisConstants.protocolVersion,
  }) : modulationParameters = modulationParameters ?? Uint8List(0);

  Uint8List encode() {
    // Fixed fields size: 12 (header) + 6 (entityId) + 2 (radioId) + 8 (radioEntityType)
    // + 1 (transmitState) + 1 (inputSource) + 2 (padding)
    // + 24 (antennaLocation) + 12 (relativeAntenna) + 2 (antennaPatternType)
    // + 2 (antennaPatternLength) + 8 (frequency) + 4 (bandwidth) + 4 (power)
    // + 8 (modulationType) + 2 (cryptoSystem) + 2 (cryptoKeyId)
    // + 1 (modulationParameterCount) + 3 (padding)
    // = 12 + 6 + 2 + 8 + 1 + 1 + 2 + 24 + 12 + 2 + 2 + 8 + 4 + 4 + 8 + 2 + 2 + 1 + 3 = 104 bytes fixed
    final fixedSize = 104;
    final totalSize = fixedSize + modulationParameters.length;
    final bytes = Uint8List(totalSize);
    final data = ByteData.sublistView(bytes);

    final header = PduHeader(
      exerciseId: exerciseId,
      protocolVersion: protocolVersion,
      pduType: DisConstants.pduTypeTransmitter,
      protocolFamily: DisConstants.protocolFamilyRadioCommunications,
      length: totalSize,
    ).withTimestampNow();

    final headerBytes = header.encode();
    bytes.setRange(0, 12, headerBytes);

    int o = 12;
    final idBytes = entityId.toBytes();
    bytes.setRange(o, o + 6, idBytes);
    o += 6;

    data.setUint16(o, radioId, Endian.big); o += 2;

    // Radio entity type (8 bytes)
    data.setUint8(o, radioEntityType.kind); o += 1;
    data.setUint8(o, radioEntityType.domain); o += 1;
    data.setUint16(o, radioEntityType.country, Endian.big); o += 2;
    data.setUint8(o, radioEntityType.category); o += 1;
    data.setUint8(o, radioEntityType.subcategory); o += 1;
    data.setUint8(o, radioEntityType.specific); o += 1;
    data.setUint8(o, radioEntityType.extra); o += 1;

    data.setUint8(o, transmitState); o += 1;
    data.setUint8(o, inputSource); o += 1;
    data.setUint16(o, 0, Endian.big); o += 2; // padding

    // Antenna location (3x float64 = 24 bytes)
    data.setFloat64(o, antennaLocationX, Endian.big); o += 8;
    data.setFloat64(o, antennaLocationY, Endian.big); o += 8;
    data.setFloat64(o, antennaLocationZ, Endian.big); o += 8;

    // Relative antenna location (3x float32 = 12 bytes)
    data.setFloat32(o, relativeAntennaX, Endian.big); o += 4;
    data.setFloat32(o, relativeAntennaY, Endian.big); o += 4;
    data.setFloat32(o, relativeAntennaZ, Endian.big); o += 4;

    data.setUint16(o, antennaPatternType, Endian.big); o += 2;
    data.setUint16(o, 0, Endian.big); o += 2; // antennaPatternLength

    // Frequency: stored as uint64 Hz. Dart int is 64-bit.
    // Split into two 32-bit values since ByteData doesn't have setUint64
    data.setUint32(o, frequency >> 32, Endian.big); o += 4;
    data.setUint32(o, frequency & 0xFFFFFFFF, Endian.big); o += 4;

    data.setFloat32(o, transmitFrequencyBandwidth, Endian.big); o += 4;
    data.setFloat32(o, power, Endian.big); o += 4;

    // Modulation type (8 bytes)
    data.setUint16(o, modulationType.spreadSpectrum, Endian.big); o += 2;
    data.setUint16(o, modulationType.major, Endian.big); o += 2;
    data.setUint16(o, modulationType.detail, Endian.big); o += 2;
    data.setUint16(o, modulationType.radioSystem, Endian.big); o += 2;

    data.setUint16(o, cryptoSystem, Endian.big); o += 2;
    data.setUint16(o, cryptoKeyId, Endian.big); o += 2;
    data.setUint8(o, modulationParameters.length); o += 1;
    data.setUint8(o, 0); o += 1; // padding
    data.setUint16(o, 0, Endian.big); o += 2; // padding

    if (modulationParameters.isNotEmpty) {
      bytes.setRange(o, o + modulationParameters.length, modulationParameters);
    }

    return bytes;
  }

  static TransmitterPdu? decode(Uint8List bytes) {
    if (bytes.length < 104) return null;
    final data = ByteData.sublistView(bytes);
    final header = PduHeader.decode(bytes);

    int o = 12;
    final entityId = EntityId.fromBytes(bytes, o); o += 6;
    final radioId = data.getUint16(o, Endian.big); o += 2;

    final radioEntityType = RadioEntityType(
      kind: data.getUint8(o),
      domain: data.getUint8(o + 1),
      country: data.getUint16(o + 2, Endian.big),
      category: data.getUint8(o + 4),
      subcategory: data.getUint8(o + 5),
      specific: data.getUint8(o + 6),
      extra: data.getUint8(o + 7),
    );
    o += 8;

    final transmitState = data.getUint8(o); o += 1;
    final inputSource = data.getUint8(o); o += 1;
    o += 2; // padding

    final antX = data.getFloat64(o, Endian.big); o += 8;
    final antY = data.getFloat64(o, Endian.big); o += 8;
    final antZ = data.getFloat64(o, Endian.big); o += 8;

    final relX = data.getFloat32(o, Endian.big); o += 4;
    final relY = data.getFloat32(o, Endian.big); o += 4;
    final relZ = data.getFloat32(o, Endian.big); o += 4;

    final antennaPatternType = data.getUint16(o, Endian.big); o += 2;
    final antennaPatternLength = data.getUint16(o, Endian.big); o += 2;

    final freqHigh = data.getUint32(o, Endian.big); o += 4;
    final freqLow = data.getUint32(o, Endian.big); o += 4;
    final frequency = (freqHigh << 32) | freqLow;

    final bandwidth = data.getFloat32(o, Endian.big); o += 4;
    final power = data.getFloat32(o, Endian.big); o += 4;

    final modType = ModulationType(
      spreadSpectrum: data.getUint16(o, Endian.big),
      major: data.getUint16(o + 2, Endian.big),
      detail: data.getUint16(o + 4, Endian.big),
      radioSystem: data.getUint16(o + 6, Endian.big),
    );
    o += 8;

    final cryptoSystem = data.getUint16(o, Endian.big); o += 2;
    final cryptoKeyId = data.getUint16(o, Endian.big); o += 2;
    final modParamCount = data.getUint8(o); o += 1;
    o += 3; // padding

    Uint8List modParams = Uint8List(0);
    if (modParamCount > 0 && o + modParamCount <= bytes.length) {
      modParams = bytes.sublist(o, o + modParamCount);
    }

    return TransmitterPdu(
      entityId: entityId,
      radioId: radioId,
      radioEntityType: radioEntityType,
      transmitState: transmitState,
      inputSource: inputSource,
      antennaLocationX: antX,
      antennaLocationY: antY,
      antennaLocationZ: antZ,
      relativeAntennaX: relX,
      relativeAntennaY: relY,
      relativeAntennaZ: relZ,
      antennaPatternType: antennaPatternType,
      frequency: frequency,
      transmitFrequencyBandwidth: bandwidth,
      power: power,
      modulationType: modType,
      cryptoSystem: cryptoSystem,
      cryptoKeyId: cryptoKeyId,
      modulationParameters: modParams,
      exerciseId: header.exerciseId,
    );
  }
}
