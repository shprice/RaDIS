import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../dis/constants.dart';
import '../dis/dis_network.dart';
import '../dis/entity_id.dart';
import '../dis/transmitter_pdu.dart' as dis;
import '../dis/signal_pdu.dart';
import '../dis/receiver_pdu.dart';
import '../dis/intercom_signal_pdu.dart';
import '../dis/intercom_control_pdu.dart';
import '../audio/audio_manager.dart';
import '../audio/g711_codec.dart';
import '../audio/vox_detector.dart';
import '../models/radio_config.dart';
import '../models/intercom_config.dart';
import '../models/app_settings.dart';
import '../models/trigger_mode.dart';

class RadioRxState {
  final bool rxActive;
  final double signalDbm;
  final EntityId? transmittingEntity;
  final int? transmittingRadioId;

  const RadioRxState({
    this.rxActive = false,
    this.signalDbm = -100,
    this.transmittingEntity,
    this.transmittingRadioId,
  });

  RadioRxState copyWith({
    bool? rxActive,
    double? signalDbm,
    EntityId? transmittingEntity,
    int? transmittingRadioId,
  }) =>
      RadioRxState(
        rxActive: rxActive ?? this.rxActive,
        signalDbm: signalDbm ?? this.signalDbm,
        transmittingEntity: transmittingEntity ?? this.transmittingEntity,
        transmittingRadioId: transmittingRadioId ?? this.transmittingRadioId,
      );
}

class DisProvider extends ChangeNotifier {
  final DisNetwork _network = DisNetwork();
  final Map<String, RadioRxState> _rxStates = {};
  final Map<String, bool> _txActive = {};
  final Map<String, VoxDetector> _voxDetectors = {};
  final Set<String> _autoTxIds = {};
  final Map<String, Timer> _rxTimeouts = {};
  // Stateful CVSD decoders keyed by "site_app_entity_radioId" of the sender.
  final Map<String, CvsdDecoder> _cvsdDecoders = {};
  // Stateful CVSD encoders keyed by radioId (for TX).
  final Map<String, CvsdEncoder> _cvsdEncoders = {};

  bool _connected = false;
  AppSettings? _settings;
  List<RadioConfig> _radios = [];
  List<IntercomConfig> _intercoms = [];
  Timer? _heartbeatTimer;
  StreamSubscription? _rxSubscription;
  // Tracks which intercoms have had their Initialize PDU sent this session.
  final Set<String> _intercomInitialized = {};

  int _packetsRx = 0;
  int _packetsTx = 0;
  DateTime? _connectedAt;

  bool get connected => _connected;
  int get packetsRx => _packetsRx;
  int get packetsTx => _packetsTx;
  Map<String, RadioRxState> get rxStates => Map.unmodifiable(_rxStates);

  bool isTxActive(String radioId) => _txActive[radioId] ?? false;

  int get _protocolVersion =>
      _settings?.disProtocolVersion ?? DisConstants.protocolVersionDis6;
  bool get _supportsIntercom =>
      _protocolVersion >= DisConstants.protocolVersionDis6;
  bool get supportsIntercom => _supportsIntercom;

  Future<void> start(
    AppSettings settings,
    List<RadioConfig> radios,
    List<IntercomConfig> intercoms,
  ) async {
    await stop();
    _settings = settings;
    _radios = radios;
    _intercoms = intercoms;

    final config = DisNetworkConfig(
      localAddress: settings.disLocalAddress,
      port: settings.disPort,
      useMulticast: settings.disUseMulticast,
      multicastGroup: settings.disMulticastGroup,
      networkInterface: settings.disNetworkInterface,
    );

    try {
      await _network.start(config);
      _connected = true;
      _connectedAt = DateTime.now();

      _rxSubscription = _network.receivedPdus.listen(_handlePdu);

      // Heartbeat: send Transmitter PDUs every 5 seconds for all enabled radios
      _heartbeatTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _sendHeartbeats());
      _sendHeartbeats();
      _applyAutoTransmit();
    } catch (e) {
      _connected = false;
      print('DisProvider: failed to start: $e');
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _rxSubscription?.cancel();
    _rxSubscription = null;
    for (final t in _rxTimeouts.values) {
      t.cancel();
    }
    _rxTimeouts.clear();
    for (final vox in _voxDetectors.values) {
      vox.dispose();
    }
    _voxDetectors.clear();
    _autoTxIds.clear();
    _cvsdDecoders.clear();
    _cvsdEncoders.clear();
    // Send Disconnect for any initialized intercoms before closing the socket.
    for (final intercom in _intercoms) {
      _sendIntercomDisconnect(intercom);
    }
    await _network.stop();
    _connected = false;
    notifyListeners();
  }

  void updateRadios(List<RadioConfig> radios, List<IntercomConfig> intercoms) {
    _radios = radios;
    _intercoms = intercoms;
    _applyAutoTransmit();
  }

  /// Updates settings without reconnecting. Call when only non-network settings
  /// change (protocol version, exercise ID, audio defaults, key bindings…).
  /// The caller is responsible for calling [start] when network parameters change.
  void applySettings(AppSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  Future<void> startTransmit(String radioId) async {
    if (_txActive[radioId] == true) return;
    final radio = _findRadio(radioId);
    if (radio == null) return;

    _txActive[radioId] = true;
    notifyListeners();
    _sendTransmitterPdu(radio, DisConstants.transmitterStateOnTransmitting);

    // Pre-capture already running — no recorder startup needed.
    if (_autoTxIds.contains(radioId)) return;

    try {
      await AudioManager.instance.startCapture(
        radioId,
        radio.inputDeviceId,
        _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz,
        (pcmData) => _onAudioCaptured(radioId, pcmData, radio),
      );
    } catch (e) {
      _txActive[radioId] = false;
      _sendTransmitterPdu(radio, DisConstants.transmitterStateOnNotTransmitting);
      notifyListeners();
    }
  }

  Future<void> stopTransmit(String radioId) async {
    if (_txActive[radioId] != true) return;
    _txActive[radioId] = false;

    final radio = _findRadio(radioId);
    if (radio != null) {
      _sendTransmitterPdu(radio, DisConstants.transmitterStateOnNotTransmitting);
    }
    notifyListeners();

    // Keep capture running if pre-capture is active — avoids recorder startup
    // latency on the next PTT press.
    if (!_autoTxIds.contains(radioId)) {
      await AudioManager.instance.stopCapture(radioId);
    }
  }

  IntercomConfig? _findIntercom(String id) {
    try {
      return _intercoms.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> startIntercomTransmit(String intercomId) async {
    if (_txActive[intercomId] == true) return;
    final intercom = _findIntercom(intercomId);
    if (intercom == null || !intercom.enabled) return;

    _txActive[intercomId] = true;
    notifyListeners();
    _sendIntercomControlPdu(intercom, transmitting: true);

    if (_autoTxIds.contains(intercomId)) return;

    try {
      await AudioManager.instance.startCapture(
        intercomId,
        intercom.inputDeviceId,
        intercom.sampleRate,
        (pcm) => _onIntercomAudioCaptured(intercomId, pcm, intercom),
      );
    } catch (e) {
      _txActive[intercomId] = false;
      _sendIntercomControlPdu(intercom, transmitting: false);
      notifyListeners();
    }
  }

  Future<void> stopIntercomTransmit(String intercomId) async {
    if (_txActive[intercomId] != true) return;
    _txActive[intercomId] = false;

    final intercom = _findIntercom(intercomId);
    if (intercom != null) {
      _sendIntercomControlPdu(intercom, transmitting: false);
    }
    notifyListeners();

    if (!_autoTxIds.contains(intercomId)) {
      await AudioManager.instance.stopCapture(intercomId);
    }
  }

  void _applyAutoTransmit() {
    // Stop pre-capture for IDs that are disabled or no longer exist.
    for (final id in List.of(_autoTxIds)) {
      final radio = _findRadio(id);
      final ic = _findIntercom(id);
      final shouldStop =
          (radio != null && !radio.enabled) ||
          (ic != null && !ic.enabled) ||
          (radio == null && ic == null);
      if (shouldStop) {
        if (_txActive[id] == true) {
          _txActive[id] = false;
          if (radio != null) {
            _sendTransmitterPdu(radio, DisConstants.transmitterStateOnNotTransmitting);
          } else if (ic != null) {
            _sendIntercomControlPdu(ic, transmitting: false);
          }
        }
        AudioManager.instance.stopCapture(id);
        _voxDetectors.remove(id)?.dispose();
        _autoTxIds.remove(id);
        notifyListeners();
      } else {
        // Dispose stale VoxDetector when mode switches away from VOX.
        if (radio != null && radio.triggerMode != TriggerMode.vox) {
          _voxDetectors.remove(id)?.dispose();
        } else if (ic != null && ic.triggerMode != TriggerMode.vox) {
          _voxDetectors.remove(id)?.dispose();
        }
      }
    }

    // Pre-start capture for all enabled radios/intercoms so PTT has zero startup
    // latency. The audio callback gates forwarding on _txActive; VOX uses its own
    // detector. Capture stays open until the radio is disabled or removed.
    for (final radio in _radios) {
      if (radio.enabled && !_autoTxIds.contains(radio.id)) {
        _startPreCapture(radio);
      }
    }
    for (final ic in _intercoms) {
      if (ic.enabled && !_autoTxIds.contains(ic.id)) {
        _startIntercomPreCapture(ic);
      }
    }
  }

  Future<void> _startPreCapture(RadioConfig radio) async {
    _autoTxIds.add(radio.id);
    try {
      await AudioManager.instance.startCapture(
        radio.id,
        radio.inputDeviceId,
        _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz,
        (pcmData) => _onAudioCaptured(radio.id, pcmData, radio),
      );
    } catch (e) {
      _autoTxIds.remove(radio.id);
    }
  }

  Future<void> _startIntercomPreCapture(IntercomConfig intercom) async {
    _autoTxIds.add(intercom.id);
    try {
      await AudioManager.instance.startCapture(
        intercom.id,
        intercom.inputDeviceId,
        intercom.sampleRate,
        (pcm) => _onIntercomAudioCaptured(intercom.id, pcm, intercom),
      );
    } catch (e) {
      _autoTxIds.remove(intercom.id);
    }
  }

  void _onIntercomAudioCaptured(
      String intercomId, Uint8List pcmData, IntercomConfig intercom) {
    if (!_supportsIntercom) return;

    if (intercom.voxEnabled) {
      // VOX owns TX state: drive transitions from detector output.
      final vox = _voxDetectors.putIfAbsent(
        intercomId,
        () => VoxDetector(
          threshold: intercom.voxThreshold,
          hangTime: intercom.voxHangTime,
        ),
      )
        ..threshold = intercom.voxThreshold
        ..hangTime = intercom.voxHangTime;
      final shouldTx = vox.processAudio(pcmData);
      final wasTx = _txActive[intercomId] == true;
      if (shouldTx != wasTx) {
        _txActive[intercomId] = shouldTx;
        _sendIntercomControlPdu(intercom, transmitting: shouldTx);
        notifyListeners();
      }
      if (!shouldTx) return;
    } else {
      if (_txActive[intercomId] != true) return;
    }

    final gained = _applyGain(pcmData, intercom.inputGain);

    if (intercom.sidetoneVolume > 0) {
      final st = _applyGain(gained, intercom.sidetoneVolume);
      AudioManager.instance.playAudioImmediate(
        st,
        intercom.sampleRate,
        pan: intercom.outputPan,
      );
    }

    final int encodingType = intercom.encodingType;
    final Uint8List encoded;
    final int sampleCount;

    if (encodingType == DisConstants.encodingAlaw) {
      final pcmSamples = G711Codec.bytesToInt16(gained);
      encoded = G711Codec.encodeAlaw(pcmSamples);
      sampleCount = encoded.length;
    } else if (encodingType == DisConstants.encodingLinear16) {
      encoded = _swapBytes16(gained);
      sampleCount = encoded.length ~/ 2;
    } else if (encodingType == DisConstants.encodingCVSD) {
      final pcmSamples = G711Codec.bytesToInt16(gained);
      final encoder = _cvsdEncoders.putIfAbsent(intercomId, CvsdEncoder.new);
      encoded = encoder.encode(pcmSamples);
      sampleCount = pcmSamples.length;
    } else {
      // µ-law (default)
      final pcmSamples = G711Codec.bytesToInt16(gained);
      encoded = G711Codec.encodeMulaw(pcmSamples);
      sampleCount = encoded.length;
    }

    final pdu = IntercomSignalPdu(
      entityId: intercom.entityId,
      communicationsDeviceId: intercom.communicationsDeviceId,
      encodingScheme: SignalPdu.buildEncodingScheme(
          DisConstants.encodingClassEncodedAudio, encodingType),
      sampleRate: intercom.sampleRate,
      dataLengthBits: encoded.length * 8,
      samples: sampleCount,
      data: encoded,
      exerciseId: _settings?.exerciseId ?? 1,
      protocolVersion: _protocolVersion,
    );
    _network.sendIntercomSignal(pdu);
    _packetsTx++;
  }

  void _sendIntercomControlPdu(IntercomConfig intercom,
      {required bool transmitting}) {
    if (!_supportsIntercom) return;

    final bool isFirst = !_intercomInitialized.contains(intercom.id);
    if (isFirst) _intercomInitialized.add(intercom.id);

    final pdu = IntercomControlPdu(
      controlType: DisConstants.intercomControlStatus,
      communicationsChannelType: intercom.channelType,
      sourceEntityId: intercom.entityId,
      sourceCommunicationsDeviceId: intercom.communicationsDeviceId,
      sourceLineId: intercom.stationName,
      masterEntityId: intercom.entityId,
      masterCommunicationsDeviceId: intercom.communicationsDeviceId,
      transmitLineState: transmitting
          ? DisConstants.intercomTransmitLineStateTransmitting
          : DisConstants.intercomTransmitLineStateIdle,
      command: isFirst
          ? DisConstants.intercomCommandInitialize
          : DisConstants.intercomCommandChangeState,
      exerciseId: _settings?.exerciseId ?? 1,
      protocolVersion: _protocolVersion,
    );
    _network.sendIntercomControl(pdu);
    _packetsTx++;
  }

  void _sendIntercomDisconnect(IntercomConfig intercom) {
    if (!_supportsIntercom) return;
    if (!_intercomInitialized.contains(intercom.id)) return;
    _intercomInitialized.remove(intercom.id);

    final pdu = IntercomControlPdu(
      controlType: DisConstants.intercomControlStatus,
      communicationsChannelType: intercom.channelType,
      sourceEntityId: intercom.entityId,
      sourceCommunicationsDeviceId: intercom.communicationsDeviceId,
      sourceLineId: intercom.stationName,
      masterEntityId: intercom.entityId,
      masterCommunicationsDeviceId: intercom.communicationsDeviceId,
      transmitLineState: DisConstants.intercomTransmitLineStateIdle,
      command: DisConstants.intercomCommandDisconnect,
      exerciseId: _settings?.exerciseId ?? 1,
      protocolVersion: _protocolVersion,
    );
    _network.sendIntercomControl(pdu);
    _packetsTx++;
  }

  void _onAudioCaptured(
      String radioId, Uint8List pcmData, RadioConfig radio) {
    if (radio.voxEnabled) {
      // VOX owns TX state: drive transitions from detector output.
      final vox = _voxDetectors.putIfAbsent(
        radioId,
        () => VoxDetector(
          threshold: radio.voxThreshold,
          hangTime: radio.voxHangTime,
        ),
      )
        ..threshold = radio.voxThreshold
        ..hangTime = radio.voxHangTime;
      final shouldTx = vox.processAudio(pcmData);
      final wasTx = _txActive[radioId] == true;
      if (shouldTx != wasTx) {
        _txActive[radioId] = shouldTx;
        _sendTransmitterPdu(
          radio,
          shouldTx
              ? DisConstants.transmitterStateOnTransmitting
              : DisConstants.transmitterStateOnNotTransmitting,
        );
        notifyListeners();
      }
      if (!shouldTx) return;
    } else {
      if (_txActive[radioId] != true) return;
    }

    // Apply input gain
    final gainedPcm = _applyGain(pcmData, radio.inputGain);

    // Sidetone: feed mic back to speaker at configured level
    if (radio.sidetoneVolume > 0) {
      final st = _applyGain(gainedPcm, radio.sidetoneVolume);
      AudioManager.instance.playAudioImmediate(
        st,
        _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz,
        pan: radio.outputPan,
      );
    }

    final encodingType = _settings?.defaultEncodingType ?? DisConstants.encodingMulaw;
    final Uint8List encoded;
    final int sampleCount;
    if (encodingType == DisConstants.encodingAlaw) {
      final pcmSamples = G711Codec.bytesToInt16(gainedPcm);
      encoded = G711Codec.encodeAlaw(pcmSamples);
      sampleCount = encoded.length; // 1 byte per sample
    } else if (encodingType == DisConstants.encodingLinear16) {
      // 16-bit little-endian PCM → big-endian (DIS network byte order)
      encoded = _swapBytes16(gainedPcm);
      sampleCount = encoded.length ~/ 2; // 2 bytes per sample
    } else if (encodingType == DisConstants.encodingLinear8) {
      // 16-bit signed LE PCM → 8-bit unsigned PCM
      encoded = _signed16ToUnsigned8(gainedPcm);
      sampleCount = encoded.length; // 1 byte per sample
    } else if (encodingType == DisConstants.encodingCVSD) {
      // CVSD: 1 bit/sample, MSB-first packed. Encoder is stateful per radioId.
      final pcmSamples = G711Codec.bytesToInt16(gainedPcm);
      final encoder = _cvsdEncoders.putIfAbsent(radioId, CvsdEncoder.new);
      encoded = encoder.encode(pcmSamples);
      sampleCount = pcmSamples.length; // 1 bit per original sample
    } else {
      // µ-law (default) and unrecognised types
      final pcmSamples = G711Codec.bytesToInt16(gainedPcm);
      encoded = G711Codec.encodeMulaw(pcmSamples);
      sampleCount = encoded.length; // 1 byte per sample
    }

    final sampleRate = _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz;
    final signalPdu = SignalPdu(
      entityId: radio.entityId,
      radioId: radio.radioNumber,
      encodingScheme: SignalPdu.buildEncodingScheme(
          DisConstants.encodingClassEncodedAudio, encodingType),
      sampleRate: sampleRate,
      dataLengthBits: encoded.length * 8,
      samples: sampleCount,
      data: encoded,
      exerciseId: _settings?.exerciseId ?? 1,
      protocolVersion: _protocolVersion,
    );

    _network.sendSignal(signalPdu);
    _packetsTx++;
  }

  void _sendHeartbeats() {
    for (final radio in _radios) {
      if (!radio.enabled) continue;
      final txState = _txActive[radio.id] == true
          ? DisConstants.transmitterStateOnTransmitting
          : DisConstants.transmitterStateOnNotTransmitting;
      _sendTransmitterPdu(radio, txState);
    }
    for (final intercom in _intercoms) {
      if (!intercom.enabled) continue;
      _sendIntercomControlPdu(
        intercom,
        transmitting: _txActive[intercom.id] == true,
      );
    }
  }

  void _sendTransmitterPdu(RadioConfig radio, int state) {
    final modType = _getDisModulationType(radio.modulationType);
    final pdu = dis.TransmitterPdu(
      entityId: radio.entityId,
      radioId: radio.radioNumber,
      transmitState: state,
      frequency: radio.frequency.toInt(),
      modulationType: modType,
      power: radio.powerWatts,
      transmitFrequencyBandwidth: radio.bandwidth.toFloat(),
      cryptoSystem: radio.cryptoSystem,
      cryptoKeyId: radio.cryptoKeyId,
      exerciseId: _settings?.exerciseId ?? 1,
      protocolVersion: _protocolVersion,
    );
    _network.sendTransmitter(pdu);
    _packetsTx++;
  }

  void _handlePdu(dynamic pdu) {
    _packetsRx++;
    if (pdu is SignalPdu) {
      _handleSignalPdu(pdu);
    } else if (pdu is dis.TransmitterPdu) {
      _handleTransmitterPdu(pdu);
    } else if (pdu is IntercomSignalPdu) {
      _handleIntercomSignalPdu(pdu);
    }
  }

  void _handleSignalPdu(SignalPdu pdu) {
    // Find matching radio by entity+radioId (our own transmissions) or by frequency
    final matchingRadio = _findMatchingReceiver(pdu);
    if (matchingRadio == null) return;

    // Don't play back own transmissions
    if (pdu.entityId == matchingRadio.entityId &&
        pdu.radioId == matchingRadio.radioNumber) {
      return;
    }

    // Decode audio → always produce 16-bit little-endian PCM for playback,
    // except 8-bit unsigned which we hand off at 8 bits.
    Uint8List pcmBytes;
    int bitsPerSample = 16;
    final encodingType = pdu.encodingType;

    if (encodingType == DisConstants.encodingMulaw) {
      // G.711 µ-law: decode to 16-bit signed little-endian PCM.
      final decoded = G711Codec.decodeMulaw(pdu.data);
      pcmBytes = G711Codec.int16ToBytes(decoded);
    } else if (encodingType == DisConstants.encodingAlaw) {
      // G.711 A-law: decode to 16-bit signed little-endian PCM.
      final decoded = G711Codec.decodeAlaw(pdu.data);
      pcmBytes = G711Codec.int16ToBytes(decoded);
    } else if (encodingType == DisConstants.encodingLinear16) {
      // 16-bit linear PCM from DIS is big-endian (network byte order).
      // Swap to little-endian for WAV playback.
      pcmBytes = _swapBytes16(pdu.data);
    } else if (encodingType == DisConstants.encodingLinear8) {
      // 8-bit unsigned linear PCM: upsample to 16-bit signed for consistency.
      pcmBytes = _unsigned8ToSigned16(pdu.data);
    } else if (encodingType == DisConstants.encodingCVSD) {
      // CVSD: 1 bit/sample MSB-first packed. Decoder is stateful per sender.
      final key = '${pdu.entityId.siteId}_${pdu.entityId.applicationId}_${pdu.entityId.entityNumber}_${pdu.radioId}';
      final decoder = _cvsdDecoders.putIfAbsent(key, CvsdDecoder.new);
      pcmBytes = decoder.decode(pdu.data);
    } else {
      // Unknown encoding — pass raw bytes and hope for the best.
      pcmBytes = pdu.data;
    }

    // Apply output volume and squelch.
    final rms = _rmsOfPcm(pcmBytes);
    if (rms < matchingRadio.squelch * 0.1) return;

    final volumed = _applyGain(pcmBytes, matchingRadio.outputVolume);

    AudioManager.instance.playAudio(
      matchingRadio.id,
      volumed,
      pdu.sampleRate,
      bitsPerSample: bitsPerSample,
      pan: matchingRadio.outputPan,
    );

    // Update RX state
    _setRxActive(matchingRadio.id, true, pdu.entityId, pdu.radioId);
  }

  void _handleTransmitterPdu(dis.TransmitterPdu pdu) {
    // Update receiver PDU for any radio tuned to this frequency
    for (final radio in _radios) {
      if (!radio.enabled) continue;
      // Ignore our own transmissions.
      if (pdu.entityId == radio.entityId && pdu.radioId == radio.radioNumber) {
        continue;
      }
      if ((radio.frequency - pdu.frequency).abs() < radio.bandwidth / 2) {
        if (pdu.transmitState == DisConstants.transmitterStateOnTransmitting) {
          _setRxActive(radio.id, true, pdu.entityId, pdu.radioId);
          // Send receiver PDU
          final rxPdu = ReceiverPdu(
            entityId: radio.entityId,
            radioId: radio.radioNumber,
            receiverState: DisConstants.receiverStateOnReceiving,
            receivedPowerDbm: -60.0,
            transmitterEntityId: pdu.entityId,
            transmitterRadioId: pdu.radioId,
            exerciseId: _settings?.exerciseId ?? 1,
            protocolVersion: _protocolVersion,
          );
          _network.sendReceiver(rxPdu);
        }
      }
    }
  }

  void _handleIntercomSignalPdu(IntercomSignalPdu pdu) {
    IntercomConfig? intercom;
    try {
      intercom = _intercoms.firstWhere(
        (i) => i.communicationsDeviceId == pdu.communicationsDeviceId,
      );
    } catch (_) {
      if (_intercoms.isEmpty) return;
      intercom = _intercoms.first;
    }

    // Don't play back own transmissions.
    if (pdu.entityId == intercom.entityId) return;

    Uint8List pcmBytes;
    final et = pdu.encodingType;
    if (et == DisConstants.encodingMulaw) {
      pcmBytes = G711Codec.int16ToBytes(G711Codec.decodeMulaw(pdu.data));
    } else if (et == DisConstants.encodingAlaw) {
      pcmBytes = G711Codec.int16ToBytes(G711Codec.decodeAlaw(pdu.data));
    } else if (et == DisConstants.encodingLinear16) {
      pcmBytes = _swapBytes16(pdu.data);
    } else if (et == DisConstants.encodingLinear8) {
      pcmBytes = _unsigned8ToSigned16(pdu.data);
    } else if (et == DisConstants.encodingCVSD) {
      final key = '${pdu.entityId.siteId}_${pdu.entityId.applicationId}_${pdu.entityId.entityNumber}_${pdu.communicationsDeviceId}';
      final decoder = _cvsdDecoders.putIfAbsent(key, CvsdDecoder.new);
      pcmBytes = decoder.decode(pdu.data);
    } else {
      pcmBytes = pdu.data;
    }

    AudioManager.instance.playAudio(
      intercom.id,
      pcmBytes,
      pdu.sampleRate,
      pan: intercom.outputPan,
    );
    _setRxActive(intercom.id, true, pdu.entityId, pdu.communicationsDeviceId);
  }

  void _setRxActive(String radioId, bool active, EntityId? entity, int? radioNum) {
    _rxStates[radioId] = RadioRxState(
      rxActive: active,
      signalDbm: active ? -60.0 : -100.0,
      transmittingEntity: active ? entity : null,
      transmittingRadioId: active ? radioNum : null,
    );

    // Clear RX state after 300ms of no packets
    _rxTimeouts[radioId]?.cancel();
    if (active) {
      _rxTimeouts[radioId] = Timer(const Duration(milliseconds: 300), () {
        _rxStates[radioId] = const RadioRxState();
        notifyListeners();
      });
    }
    notifyListeners();
  }

  RadioConfig? _findRadio(String id) {
    try {
      return _radios.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  RadioConfig? _findMatchingReceiver(SignalPdu pdu) {
    // First try exact entity+radio match (our own radios receiving from others)
    for (final radio in _radios) {
      if (!radio.enabled) continue;
      // Don't match our own entity
      if (radio.entityId == pdu.entityId && radio.radioNumber == pdu.radioId) continue;
      return radio; // simplified: first enabled radio receives all
    }
    return null;
  }

  /// Byte-swap 16-bit samples from big-endian (DIS/network) to little-endian (WAV).
  Uint8List _swapBytes16(Uint8List src) {
    final out = Uint8List(src.length);
    for (int i = 0; i < src.length - 1; i += 2) {
      out[i] = src[i + 1];
      out[i + 1] = src[i];
    }
    return out;
  }

  /// Convert 16-bit signed little-endian PCM to 8-bit unsigned PCM for TX.
  Uint8List _signed16ToUnsigned8(Uint8List src) {
    final bd = ByteData.sublistView(src);
    final count = src.length ~/ 2;
    final out = Uint8List(count);
    for (int i = 0; i < count; i++) {
      final s = bd.getInt16(i * 2, Endian.little);
      out[i] = ((s ~/ 256) + 128).clamp(0, 255);
    }
    return out;
  }

  /// Convert 8-bit unsigned PCM (0–255) to 16-bit signed little-endian PCM.
  Uint8List _unsigned8ToSigned16(Uint8List src) {
    final bd = ByteData(src.length * 2);
    for (int i = 0; i < src.length; i++) {
      final s = ((src[i] - 128) * 256).clamp(-32768, 32767);
      bd.setInt16(i * 2, s, Endian.little);
    }
    return bd.buffer.asUint8List();
  }

  Uint8List _applyGain(Uint8List pcmBytes, double gain) {
    if ((gain - 1.0).abs() < 0.01) return pcmBytes;
    final bd = ByteData.sublistView(pcmBytes);
    final out = ByteData(pcmBytes.length);
    final count = pcmBytes.length ~/ 2;
    for (int i = 0; i < count; i++) {
      final s = bd.getInt16(i * 2, Endian.little);
      var g = (s * gain).round().clamp(-32768, 32767);
      out.setInt16(i * 2, g, Endian.little);
    }
    return out.buffer.asUint8List();
  }

  double _rmsOfPcm(Uint8List pcmBytes) {
    if (pcmBytes.length < 2) return 0;
    final bd = ByteData.sublistView(pcmBytes);
    final count = pcmBytes.length ~/ 2;
    double sum = 0;
    for (int i = 0; i < count; i++) {
      final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    return sum / count > 0 ? sum / count : 0;
  }

  dis.ModulationType _getDisModulationType(RadioModulationType mod) {
    switch (mod) {
      case RadioModulationType.fm:
      case RadioModulationType.fmhq:
        return dis.ModulationType.fm();
      case RadioModulationType.usb:
        return dis.ModulationType.usb();
      case RadioModulationType.lsb:
        return dis.ModulationType.lsb();
      case RadioModulationType.sincgars:
        return dis.ModulationType.sincgars();
      case RadioModulationType.havequick:
        return dis.ModulationType.haveQuick();
      default:
        return dis.ModulationType.am();
    }
  }

  @override
  void dispose() {
    stop();
    _network.dispose();
    super.dispose();
  }
}

extension on double {
  double toFloat() => this;
}
