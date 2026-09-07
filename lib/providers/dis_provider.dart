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
  final Map<String, DisNetwork> _radioNetworks = {};
  final Map<String, DisNetwork> _intercomNetworks = {};
  final Map<String, StreamSubscription> _rxSubscriptions = {};

  final Map<String, RadioRxState> _rxStates = {};
  final Map<String, bool> _txActive = {};
  final Map<String, VoxDetector> _voxDetectors = {};
  final Set<String> _autoTxIds = {};
  final Map<String, Timer> _rxTimeouts = {};
  final Map<String, CvsdDecoder> _cvsdDecoders = {};
  final Map<String, CvsdEncoder> _cvsdEncoders = {};
  final Set<String> _intercomInitialized = {};
  // Keyed by "siteId_appId_entityNum_radioId" — tracks last-known frequency of
  // remote transmitters so Signal PDUs can be frequency-filtered.
  final Map<String, int> _remoteTransmitterFreqs = {};

  bool _connected = false;
  AppSettings? _settings;
  List<RadioConfig> _radios = [];
  List<IntercomConfig> _intercoms = [];
  final Map<String, bool> _mutedRadios = {};
  Timer? _heartbeatTimer;

  int _packetsRx = 0;
  int _packetsTx = 0;
  DateTime? _connectedAt;

  bool get connected => _connected;
  int get packetsRx => _packetsRx;
  int get packetsTx => _packetsTx;
  Map<String, RadioRxState> get rxStates => Map.unmodifiable(_rxStates);

  bool isTxActive(String radioId) => _txActive[radioId] ?? false;
  bool isRadioMuted(String id) => _mutedRadios[id] ?? false;
  void toggleRadioMute(String id) {
    _mutedRadios[id] = !isRadioMuted(id);
    notifyListeners();
  }

  bool supportsIntercomFor(String intercomId) {
    final ic = _findIntercom(intercomId);
    return ic != null && ic.disProtocolVersion >= DisConstants.protocolVersionDis6;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> start(
    AppSettings settings,
    List<RadioConfig> radios,
    List<IntercomConfig> intercoms,
  ) async {
    await stop();
    _settings = settings;
    _radios = radios;
    _intercoms = intercoms;

    for (final radio in radios.where((r) => r.enabled)) {
      await _startRadioNetwork(radio);
    }
    for (final ic in intercoms.where((i) => i.enabled)) {
      await _startIntercomNetwork(ic);
    }

    _connected = true;
    _connectedAt = DateTime.now();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _sendHeartbeats());
    _sendHeartbeats();
    _applyAutoTransmit();
    notifyListeners();
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    for (final t in _rxTimeouts.values) t.cancel();
    _rxTimeouts.clear();
    for (final vox in _voxDetectors.values) vox.dispose();
    _voxDetectors.clear();
    _autoTxIds.clear();
    _cvsdDecoders.clear();
    _cvsdEncoders.clear();

    for (final ic in _intercoms) {
      _sendIntercomDisconnect(ic);
    }

    for (final sub in _rxSubscriptions.values) await sub.cancel();
    _rxSubscriptions.clear();

    for (final net in _radioNetworks.values) {
      await net.stop();
      net.dispose();
    }
    _radioNetworks.clear();

    for (final net in _intercomNetworks.values) {
      await net.stop();
      net.dispose();
    }
    _intercomNetworks.clear();
    _intercomInitialized.clear();

    _connected = false;
    notifyListeners();
  }

  Future<void> updateRadios(
      List<RadioConfig> radios, List<IntercomConfig> intercoms) async {
    if (!_connected) {
      _radios = radios;
      _intercoms = intercoms;
      _applyAutoTransmit();
      return;
    }

    final oldRadios = {for (final r in _radios) r.id: r};
    final newRadios = {for (final r in radios) r.id: r};

    // Stop networks for removed radios
    for (final id in oldRadios.keys.where((id) => !newRadios.containsKey(id))) {
      await _stopRadioNetwork(id);
    }

    // Handle changed and new radios
    for (final radio in radios) {
      final old = oldRadios[radio.id];
      if (old == null) {
        if (radio.enabled) await _startRadioNetwork(radio);
      } else if (!radio.enabled) {
        await _stopRadioNetwork(radio.id);
      } else if (!old.enabled || _radioNetworkConfigChanged(old, radio)) {
        await _stopRadioNetwork(radio.id);
        await _startRadioNetwork(radio);
      }
    }

    final oldIntercoms = {for (final i in _intercoms) i.id: i};
    final newIntercoms = {for (final i in intercoms) i.id: i};

    for (final id
        in oldIntercoms.keys.where((id) => !newIntercoms.containsKey(id))) {
      final old = oldIntercoms[id]!;
      _sendIntercomDisconnect(old);
      await _stopIntercomNetwork(id);
    }

    for (final ic in intercoms) {
      final old = oldIntercoms[ic.id];
      if (old == null) {
        if (ic.enabled) await _startIntercomNetwork(ic);
      } else if (!ic.enabled) {
        if (old.enabled) _sendIntercomDisconnect(old);
        await _stopIntercomNetwork(ic.id);
      } else if (!old.enabled || _intercomNetworkConfigChanged(old, ic)) {
        if (old.enabled) _sendIntercomDisconnect(old);
        await _stopIntercomNetwork(ic.id);
        _intercomInitialized.remove(ic.id);
        await _startIntercomNetwork(ic);
      }
    }

    _radios = radios;
    _intercoms = intercoms;
    _applyAutoTransmit();
    notifyListeners();
  }

  void applySettings(AppSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Per-instance network management
  // ---------------------------------------------------------------------------

  Future<void> _startRadioNetwork(RadioConfig radio) async {
    final network = DisNetwork();
    try {
      await network.start(radio.networkConfig);
      _radioNetworks[radio.id] = network;
      _rxSubscriptions[radio.id] =
          network.receivedPdus.listen((pdu) => _handlePduForRadio(pdu, radio.id));
    } catch (e) {
      print('DisProvider: radio "${radio.name}" network error: $e');
      network.dispose();
    }
  }

  Future<void> _startIntercomNetwork(IntercomConfig ic) async {
    final network = DisNetwork();
    try {
      await network.start(ic.networkConfig);
      _intercomNetworks[ic.id] = network;
      _rxSubscriptions['ic_${ic.id}'] =
          network.receivedPdus.listen((pdu) => _handlePduForIntercom(pdu, ic.id));
    } catch (e) {
      print('DisProvider: intercom "${ic.name}" network error: $e');
      network.dispose();
    }
  }

  Future<void> _stopRadioNetwork(String radioId) async {
    await _rxSubscriptions.remove(radioId)?.cancel();
    final net = _radioNetworks.remove(radioId);
    if (net != null) {
      await net.stop();
      net.dispose();
    }
  }

  Future<void> _stopIntercomNetwork(String intercomId) async {
    await _rxSubscriptions.remove('ic_$intercomId')?.cancel();
    final net = _intercomNetworks.remove(intercomId);
    if (net != null) {
      await net.stop();
      net.dispose();
    }
  }

  bool _radioNetworkConfigChanged(RadioConfig a, RadioConfig b) =>
      a.disLocalAddress != b.disLocalAddress ||
      a.disPort != b.disPort ||
      a.disUseMulticast != b.disUseMulticast ||
      a.disMulticastGroup != b.disMulticastGroup ||
      a.disNetworkInterface != b.disNetworkInterface;

  bool _intercomNetworkConfigChanged(IntercomConfig a, IntercomConfig b) =>
      a.disLocalAddress != b.disLocalAddress ||
      a.disPort != b.disPort ||
      a.disUseMulticast != b.disUseMulticast ||
      a.disMulticastGroup != b.disMulticastGroup ||
      a.disNetworkInterface != b.disNetworkInterface;

  // ---------------------------------------------------------------------------
  // Transmit
  // ---------------------------------------------------------------------------

  Future<void> startTransmit(String radioId) async {
    if (_txActive[radioId] == true) return;
    final radio = _findRadio(radioId);
    if (radio == null) return;

    _txActive[radioId] = true;
    notifyListeners();
    _sendTransmitterPdu(radio, DisConstants.transmitterStateOnTransmitting);
    if (radio.txBeepEnabled) AudioManager.instance.playAsset('assets/beep.wav');

    if (_autoTxIds.contains(radioId)) return;

    try {
      await AudioManager.instance.startCapture(
        radioId,
        radio.inputDeviceId,
        _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz,
        (pcmData) {
          final live = _radios.firstWhere((r) => r.id == radioId,
              orElse: () => radio);
          _onAudioCaptured(radioId, pcmData, live);
        },
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

    if (!_autoTxIds.contains(radioId)) {
      await AudioManager.instance.stopCapture(radioId);
    }
  }

  Future<void> startIntercomTransmit(String intercomId) async {
    if (_txActive[intercomId] == true) return;
    final intercom = _findIntercom(intercomId);
    if (intercom == null || !intercom.enabled) return;

    _txActive[intercomId] = true;
    notifyListeners();
    _sendIntercomControlPdu(intercom, transmitting: true);
    AudioManager.instance.playAsset('assets/beep.wav');

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

  // ---------------------------------------------------------------------------
  // Pre-capture (zero-latency PTT)
  // ---------------------------------------------------------------------------

  void _applyAutoTransmit() {
    for (final id in List.of(_autoTxIds)) {
      final radio = _findRadio(id);
      final ic = _findIntercom(id);
      final shouldStop = (radio != null && !radio.enabled) ||
          (ic != null && !ic.enabled) ||
          (radio == null && ic == null);
      if (shouldStop) {
        if (_txActive[id] == true) {
          _txActive[id] = false;
          if (radio != null) {
            _sendTransmitterPdu(
                radio, DisConstants.transmitterStateOnNotTransmitting);
          } else if (ic != null) {
            _sendIntercomControlPdu(ic, transmitting: false);
          }
        }
        AudioManager.instance.stopCapture(id);
        _voxDetectors.remove(id)?.dispose();
        _autoTxIds.remove(id);
        notifyListeners();
      } else {
        if (radio != null && radio.triggerMode != TriggerMode.vox) {
          _voxDetectors.remove(id)?.dispose();
        } else if (ic != null && ic.triggerMode != TriggerMode.vox) {
          _voxDetectors.remove(id)?.dispose();
        }
      }
    }

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
        (pcmData) {
          final live = _radios.firstWhere((r) => r.id == radio.id,
              orElse: () => radio);
          _onAudioCaptured(radio.id, pcmData, live);
        },
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
        (pcm) {
          final live = _intercoms.firstWhere((i) => i.id == intercom.id,
              orElse: () => intercom);
          _onIntercomAudioCaptured(intercom.id, pcm, live);
        },
      );
    } catch (e) {
      _autoTxIds.remove(intercom.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Audio capture callbacks → encode → send
  // ---------------------------------------------------------------------------

  void _onAudioCaptured(
      String radioId, Uint8List pcmData, RadioConfig radio) {
    if (radio.voxEnabled) {
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
        if (shouldTx && radio.txBeepEnabled) AudioManager.instance.playAsset('assets/beep.wav');
        notifyListeners();
      }
      if (!shouldTx) return;
    } else {
      if (_txActive[radioId] != true) return;
    }

    final gainedPcm = _applyGain(pcmData, radio.inputGain);

    if (radio.sidetoneVolume > 0) {
      final st = _applyGain(gainedPcm, radio.sidetoneVolume);
      AudioManager.instance.playAudioImmediate(
        st,
        _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz,
        pan: radio.outputPan,
      );
    }

    final encodingType =
        _settings?.defaultEncodingType ?? DisConstants.encodingMulaw;
    final Uint8List encoded;
    final int sampleCount;
    if (encodingType == DisConstants.encodingAlaw) {
      final pcmSamples = G711Codec.bytesToInt16(gainedPcm);
      encoded = G711Codec.encodeAlaw(pcmSamples);
      sampleCount = encoded.length;
    } else if (encodingType == DisConstants.encodingLinear16) {
      encoded = _swapBytes16(gainedPcm);
      sampleCount = encoded.length ~/ 2;
    } else if (encodingType == DisConstants.encodingLinear8) {
      encoded = _signed16ToUnsigned8(gainedPcm);
      sampleCount = encoded.length;
    } else if (encodingType == DisConstants.encodingCVSD) {
      final pcmSamples = G711Codec.bytesToInt16(gainedPcm);
      final encoder = _cvsdEncoders.putIfAbsent(radioId, CvsdEncoder.new);
      encoded = encoder.encode(pcmSamples);
      sampleCount = pcmSamples.length;
    } else {
      final pcmSamples = G711Codec.bytesToInt16(gainedPcm);
      encoded = G711Codec.encodeMulaw(pcmSamples);
      sampleCount = encoded.length;
    }

    final sampleRate =
        _settings?.defaultSampleRate ?? DisConstants.sampleRate8kHz;
    final signalPdu = SignalPdu(
      entityId: radio.entityId,
      radioId: radio.radioNumber,
      encodingScheme: SignalPdu.buildEncodingScheme(
          DisConstants.encodingClassEncodedAudio, encodingType),
      sampleRate: sampleRate,
      dataLengthBits: encoded.length * 8,
      samples: sampleCount,
      data: encoded,
      exerciseId: radio.exerciseId,
      protocolVersion: radio.disProtocolVersion,
    );
    _radioNetworks[radioId]?.sendSignal(signalPdu);
    _packetsTx++;
  }

  void _onIntercomAudioCaptured(
      String intercomId, Uint8List pcmData, IntercomConfig intercom) {
    if (!_intercomPduSupported(intercom)) return;

    if (intercom.voxEnabled) {
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
        if (shouldTx) AudioManager.instance.playAsset('assets/beep.wav');
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
      exerciseId: intercom.exerciseId,
      protocolVersion: intercom.disProtocolVersion,
    );
    _intercomNetworks[intercomId]?.sendIntercomSignal(pdu);
    _packetsTx++;
  }

  // ---------------------------------------------------------------------------
  // PDU send helpers
  // ---------------------------------------------------------------------------

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
      exerciseId: radio.exerciseId,
      protocolVersion: radio.disProtocolVersion,
    );
    _radioNetworks[radio.id]?.sendTransmitter(pdu);
    _packetsTx++;
  }

  void _sendIntercomControlPdu(IntercomConfig intercom,
      {required bool transmitting}) {
    if (!_intercomPduSupported(intercom)) return;

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
      exerciseId: intercom.exerciseId,
      protocolVersion: intercom.disProtocolVersion,
    );
    _intercomNetworks[intercom.id]?.sendIntercomControl(pdu);
    _packetsTx++;
  }

  void _sendIntercomDisconnect(IntercomConfig intercom) {
    if (!_intercomPduSupported(intercom)) return;
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
      exerciseId: intercom.exerciseId,
      protocolVersion: intercom.disProtocolVersion,
    );
    _intercomNetworks[intercom.id]?.sendIntercomControl(pdu);
    _packetsTx++;
  }

  bool _intercomPduSupported(IntercomConfig ic) =>
      ic.disProtocolVersion >= DisConstants.protocolVersionDis6;

  // ---------------------------------------------------------------------------
  // PDU receive handlers
  // ---------------------------------------------------------------------------

  void _handlePduForRadio(dynamic pdu, String radioId) {
    _packetsRx++;
    final radio = _findRadio(radioId);
    if (radio == null || !radio.enabled) return;

    if (pdu is SignalPdu) {
      _handleSignalPduForRadio(pdu, radio);
    } else if (pdu is dis.TransmitterPdu) {
      _handleTransmitterPduForRadio(pdu, radio);
    }
  }

  void _handleSignalPduForRadio(SignalPdu pdu, RadioConfig radio) {
    if (pdu.entityId == radio.entityId && pdu.radioId == radio.radioNumber) {
      return;
    }
    if (pdu.exerciseId != radio.exerciseId) return;

    // Only receive audio if the sender is known to be on our frequency.
    final senderKey =
        '${pdu.entityId.siteId}_${pdu.entityId.applicationId}_${pdu.entityId.entityNumber}_${pdu.radioId}';
    final senderFreq = _remoteTransmitterFreqs[senderKey];
    if (senderFreq == null) return; // no Transmitter PDU seen yet for this sender
    if ((radio.frequency - senderFreq).abs() >= radio.bandwidth / 2) return;

    Uint8List pcmBytes;
    int bitsPerSample = 16;
    final encodingType = pdu.encodingType;

    if (encodingType == DisConstants.encodingMulaw) {
      pcmBytes = G711Codec.int16ToBytes(G711Codec.decodeMulaw(pdu.data));
    } else if (encodingType == DisConstants.encodingAlaw) {
      pcmBytes = G711Codec.int16ToBytes(G711Codec.decodeAlaw(pdu.data));
    } else if (encodingType == DisConstants.encodingLinear16) {
      pcmBytes = _swapBytes16(pdu.data);
    } else if (encodingType == DisConstants.encodingLinear8) {
      pcmBytes = _unsigned8ToSigned16(pdu.data);
    } else if (encodingType == DisConstants.encodingCVSD) {
      final key =
          '${pdu.entityId.siteId}_${pdu.entityId.applicationId}_${pdu.entityId.entityNumber}_${pdu.radioId}';
      final decoder = _cvsdDecoders.putIfAbsent(key, CvsdDecoder.new);
      pcmBytes = decoder.decode(pdu.data);
    } else {
      pcmBytes = pdu.data;
    }

    final rms = _rmsOfPcm(pcmBytes);
    // Always update the RX level meter so the signal is visible regardless of squelch.
    AudioManager.instance.updateRxLevel(radio.id, rms);

    if (rms < radio.squelch) return;

    _setRxActive(radio.id, true, pdu.entityId, pdu.radioId);

    if (isRadioMuted(radio.id)) return;

    final volumed = _applyGain(pcmBytes, radio.outputVolume);
    AudioManager.instance.playAudio(
      radio.id,
      volumed,
      pdu.sampleRate,
      bitsPerSample: bitsPerSample,
      pan: radio.outputPan,
    );
  }

  void _handleTransmitterPduForRadio(dis.TransmitterPdu pdu, RadioConfig radio) {
    if (pdu.entityId == radio.entityId && pdu.radioId == radio.radioNumber) {
      return;
    }
    if (pdu.exerciseId != radio.exerciseId) return;

    // Cache this sender's frequency so Signal PDU handlers can use it.
    final senderKey =
        '${pdu.entityId.siteId}_${pdu.entityId.applicationId}_${pdu.entityId.entityNumber}_${pdu.radioId}';
    _remoteTransmitterFreqs[senderKey] = pdu.frequency;

    if ((radio.frequency - pdu.frequency).abs() < radio.bandwidth / 2) {
      if (pdu.transmitState == DisConstants.transmitterStateOnTransmitting) {
        _setRxActive(radio.id, true, pdu.entityId, pdu.radioId);
        final rxPdu = ReceiverPdu(
          entityId: radio.entityId,
          radioId: radio.radioNumber,
          receiverState: DisConstants.receiverStateOnReceiving,
          receivedPowerDbm: -60.0,
          transmitterEntityId: pdu.entityId,
          transmitterRadioId: pdu.radioId,
          exerciseId: radio.exerciseId,
          protocolVersion: radio.disProtocolVersion,
        );
        _radioNetworks[radio.id]?.sendReceiver(rxPdu);
      }
    }
  }

  void _handlePduForIntercom(dynamic pdu, String intercomId) {
    _packetsRx++;
    if (pdu is IntercomSignalPdu) {
      _handleIntercomSignalPduForIntercom(pdu, intercomId);
    }
  }

  void _handleIntercomSignalPduForIntercom(
      IntercomSignalPdu pdu, String intercomId) {
    final intercom = _findIntercom(intercomId);
    if (intercom == null) return;

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
      final key =
          '${pdu.entityId.siteId}_${pdu.entityId.applicationId}_${pdu.entityId.entityNumber}_${pdu.communicationsDeviceId}';
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
    _setRxActive(
        intercom.id, true, pdu.entityId, pdu.communicationsDeviceId);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setRxActive(
      String radioId, bool active, EntityId? entity, int? radioNum) {
    _rxStates[radioId] = RadioRxState(
      rxActive: active,
      signalDbm: active ? -60.0 : -100.0,
      transmittingEntity: active ? entity : null,
      transmittingRadioId: active ? radioNum : null,
    );
    _rxTimeouts[radioId]?.cancel();
    if (active) {
      _rxTimeouts[radioId] = Timer(const Duration(milliseconds: 800), () {
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

  IntercomConfig? _findIntercom(String id) {
    try {
      return _intercoms.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Uint8List _swapBytes16(Uint8List src) {
    final out = Uint8List(src.length);
    for (int i = 0; i < src.length - 1; i += 2) {
      out[i] = src[i + 1];
      out[i + 1] = src[i];
    }
    return out;
  }

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
    super.dispose();
  }
}

extension on double {
  double toFloat() => this;
}
