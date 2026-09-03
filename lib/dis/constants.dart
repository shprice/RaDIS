class DisConstants {
  // Protocol
  static const int protocolVersion = 7; // IEEE 1278.1-2012
  static const int protocolFamilyRadioCommunications = 4;

  // PDU Types
  static const int pduTypeTransmitter = 25;
  static const int pduTypeSignal = 26;
  static const int pduTypeReceiver = 27;
  static const int pduTypeIntercomSignal = 31;
  static const int pduTypeIntercomControl = 32;

  // Network defaults
  static const int defaultPort = 3000;
  static const String defaultMulticastGroup = '239.1.2.3';
  static const String defaultLocalAddress = '0.0.0.0';

  // Encoding class (bits 15-14 of encoding scheme) — IEEE 1278.1-2012 Table 32
  static const int encodingClassEncodedAudio = 0;
  static const int encodingClassRawBinary = 1;
  static const int encodingClassApplicationSpecific = 2;
  static const int encodingClassDatabaseIndex = 3;

  // Encoding type (bits 13-0 of encoding scheme) — IEEE 1278.1-2012 Table 33
  static const int encodingMulaw = 1;    // 8-bit µ-law (G.711)
  static const int encodingCVSD = 2;     // CVSD
  static const int encodingAlaw = 3;     // 8-bit A-law (G.711)
  static const int encodingLinear16 = 4; // 16-bit linear PCM
  static const int encodingLinear8 = 5;  // 8-bit linear PCM

  // Transmitter state
  static const int transmitterStateOff = 0;
  static const int transmitterStateOnNotTransmitting = 1;
  static const int transmitterStateOnTransmitting = 2;

  // Receiver state
  static const int receiverStateOff = 0;
  static const int receiverStateOnNotReceiving = 1;
  static const int receiverStateOnReceiving = 2;

  // Input source
  static const int inputSourceOther = 0;
  static const int inputSourcePilot = 1;
  static const int inputSourceCopilot = 2;
  static const int inputSourceFirstOfficer = 3;
  static const int inputSourceDriver = 4;
  static const int inputSourceLoader = 5;
  static const int inputSourceGunner = 6;
  static const int inputSourceCommander = 7;
  static const int inputSourceDigital = 8;
  static const int inputSourceIntercom = 9;
  static const int inputSourceAudio = 10;

  // Modulation class (major modulation type)
  static const int modulationClassAmplitude = 1;
  static const int modulationClassAmplitudeAndAngle = 2;
  static const int modulationClassAngle = 3;
  static const int modulationClassCombination = 4;
  static const int modulationClassPulse = 5;
  static const int modulationClassUnmodulated = 6;
  static const int modulationClassCpsm = 7; // Carrier Phase Shift

  // Modulation detail for Amplitude (class 1)
  static const int modulationDetailAm = 1;
  static const int modulationDetailDsb = 2; // Double Sideband
  static const int modulationDetailUsb = 3; // Upper Sideband
  static const int modulationDetailLsb = 4; // Lower Sideband
  static const int modulationDetailAm8 = 5;

  // Modulation detail for Angle (class 3)
  static const int modulationDetailFm = 1;
  static const int modulationDetailFsk = 2;

  // Radio system
  static const int radioSystemOther = 0;
  static const int radioSystemHaveQuick = 1;
  static const int radioSystemHaveQuickII = 2;
  static const int radioSystemHaveQuickIIA = 3;
  static const int radioSystemSincgars = 4;
  static const int radioSystemCCTT_SINCGARS = 5;

  // Spread spectrum
  static const int spreadSpectrumNone = 0;
  static const int spreadSpectrumFrequencyHopping = 1;
  static const int spreadSpectrumPseudoNoise = 2;
  static const int spreadSpectrumDirectSequence = 4;

  // Crypto systems
  static const int cryptoSystemNone = 0;
  static const int cryptoSystemKY28 = 1;
  static const int cryptoSystemKY57 = 2;
  static const int cryptoSystemKY58 = 3;
  static const int cryptoSystemVinson = 4;
  static const int cryptoSystemAndvt = 5;
  static const int cryptoSystemKY75 = 6;
  static const int cryptoSystemKY100 = 7;

  // Antenna pattern type
  static const int antennaPatternOmniDirectional = 0;
  static const int antennaPatternBeam = 1;
  static const int antennaPatternSpherical = 2;

  // Radio entity kind
  static const int radioEntityKindOther = 0;
  static const int radioEntityKindRadio = 1;

  // TDL type
  static const int tdlTypeOther = 0;

  // PDU header size in bytes
  static const int pduHeaderSize = 12;

  // Sample rates
  static const int sampleRate8kHz = 8000;
  static const int sampleRate16kHz = 16000;

  // Intercom control types
  static const int intercomControlStatus = 1;
  static const int intercomControlRequest = 2;
  static const int intercomControlAcknowledge = 3;

  // Intercom channel types
  static const int intercomChannelTypeSimulated = 1;
  static const int intercomChannelTypeUnsimulated = 2;
}
