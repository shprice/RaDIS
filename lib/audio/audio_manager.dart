import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'audio_device_model.dart';

// How many ms of audio to accumulate before triggering playback.
// Too low = choppy gaps; too high = noticeable latency.
const _kJitterTargetMs = 200;

// Minimum TX chunk size in bytes (16-bit PCM). Accumulate until we have
// at least this much before forwarding to the Signal PDU encoder.
// At 8kHz mono, 100ms = 1600 bytes; at 16kHz = 3200 bytes.
const _kTxTargetBytes = 1600;

class _CaptureSession {
  final StreamController<double> levelController;
  bool active;
  // TX accumulation buffer — collects PCM until _kTxTargetBytes reached.
  final List<Uint8List> txChunks = [];
  int txTotalBytes = 0;

  _CaptureSession()
      : levelController = StreamController<double>.broadcast(),
        active = false;

  void dispose() {
    levelController.close();
    txChunks.clear();
    txTotalBytes = 0;
  }
}

// Per-radio RX jitter buffer — smooths choppy playback caused by network
// jitter and the latency of loadMem+play calls.
class _RxBuffer {
  final List<Uint8List> chunks = [];
  int totalBytes = 0;
  int sampleRate = 8000;
  int bitsPerSample = 16;

  void push(Uint8List pcm, int rate, int bits) {
    chunks.add(pcm);
    totalBytes += pcm.length;
    sampleRate = rate;
    bitsPerSample = bits;
  }

  bool get hasEnough {
    final bytesPerMs = sampleRate * (bitsPerSample ~/ 8) ~/ 1000;
    return bytesPerMs > 0 && totalBytes >= bytesPerMs * _kJitterTargetMs;
  }

  Uint8List? drain() {
    if (chunks.isEmpty) return null;
    final out = Uint8List(totalBytes);
    int offset = 0;
    for (final c in chunks) {
      out.setRange(offset, offset + c.length, c);
      offset += c.length;
    }
    chunks.clear();
    totalBytes = 0;
    return out;
  }
}

class AudioManager {
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  bool _initialized = false;
  final Map<String, _CaptureSession> _captureSessions = {};
  final Map<String, AudioRecorder> _recorders = {};
  final Map<String, StreamSubscription<Uint8List>> _captureSubscriptions = {};
  final Map<String, _RxBuffer> _rxBuffers = {};
  final Map<String, StreamController<double>> _rxLevelControllers = {};

  // Monotonic counter ensures each loadMem call uses a unique key so
  // flutter_soloud never returns a stale cached AudioSource.
  int _chunkSeq = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    await SoLoud.instance.init();
    _initialized = true;
  }

  Future<void> dispose() async {
    for (final id in List.of(_captureSessions.keys)) {
      await stopCapture(id);
    }
    _rxBuffers.clear();
    for (final c in _rxLevelControllers.values) {
      c.close();
    }
    _rxLevelControllers.clear();
    if (_initialized) {
      SoLoud.instance.deinit();
      _initialized = false;
    }
  }

  Future<List<AudioDevice>> listInputDevices() async {
    final recorder = AudioRecorder();
    try {
      final devices = await recorder.listInputDevices();
      return [
        AudioDevice.defaultInput,
        ...devices.map((d) => AudioDevice(
              id: d.id,
              name: d.label,
              isInput: true,
              isOutput: false,
              supportedSampleRates: d.sampleRates.isNotEmpty
                  ? d.sampleRates
                  : const [8000, 16000, 44100, 48000],
            )),
      ];
    } catch (_) {
      return [AudioDevice.defaultInput];
    } finally {
      await recorder.dispose();
    }
  }

  Future<List<AudioDevice>> listOutputDevices() async {
    try {
      final devices = SoLoud.instance.listPlaybackDevices();
      return [
        AudioDevice.defaultOutput,
        ...devices.map((d) => AudioDevice(
              id: d.id.toString(),
              name: d.name,
              isInput: false,
              isOutput: true,
            )),
      ];
    } catch (_) {
      return [AudioDevice.defaultOutput];
    }
  }

  /// Start microphone capture for [radioId].
  ///
  /// [onData] receives accumulated PCM16 chunks of at least [_kTxTargetBytes]
  /// bytes, reducing the number of Signal PDUs sent and ensuring each PDU
  /// carries a meaningful amount of audio.
  Future<void> startCapture(
    String radioId,
    String? deviceId,
    int sampleRate,
    void Function(Uint8List) onData,
  ) async {
    if (!_initialized) await initialize();
    await stopCapture(radioId);

    final recorder = AudioRecorder();
    _recorders[radioId] = recorder;

    final session = _CaptureSession();
    _captureSessions[radioId] = session;
    session.active = true;

    try {
      InputDevice? inputDevice;
      if (deviceId != null && deviceId != AudioDevice.defaultInput.id) {
        final available = await recorder.listInputDevices();
        try {
          inputDevice = available.firstWhere((d) => d.id == deviceId);
        } catch (_) {}
      }

      final stream = await recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        device: inputDevice,
        // Request ~50ms chunks from the OS; accumulate to _kTxTargetBytes
        // before forwarding so each Signal PDU carries ~100 ms of audio.
        streamBufferSize: sampleRate * 2 ~/ 20,
      ));

      final sub = stream.listen(
        (chunk) {
          if (!session.active) return;
          final rms = _computeRms(chunk);
          session.levelController.add(rms);

          // Accumulate until we have a full TX target chunk.
          session.txChunks.add(chunk);
          session.txTotalBytes += chunk.length;
          if (session.txTotalBytes >= _kTxTargetBytes) {
            final combined = Uint8List(session.txTotalBytes);
            int offset = 0;
            for (final c in session.txChunks) {
              combined.setRange(offset, offset + c.length, c);
              offset += c.length;
            }
            session.txChunks.clear();
            session.txTotalBytes = 0;
            onData(combined);
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
      _captureSubscriptions[radioId] = sub;
    } catch (e) {
      session.active = false;
      await recorder.dispose();
      _recorders.remove(radioId);
      _captureSessions.remove(radioId)?.dispose();
    }
  }

  Future<void> stopCapture(String radioId) async {
    final sub = _captureSubscriptions.remove(radioId);
    await sub?.cancel();

    final session = _captureSessions.remove(radioId);
    session?.active = false;
    session?.dispose();

    final recorder = _recorders.remove(radioId);
    try {
      await recorder?.stop();
    } catch (_) {}
    await recorder?.dispose();
  }

  /// Queue [pcmBytes] for [radioId].  Audio is accumulated into a jitter
  /// buffer and played once [_kJitterTargetMs] ms of audio is available.
  ///
  /// [bitsPerSample] must match the actual sample width: 16 for decoded
  /// G.711 / raw 16-bit PCM, 8 for 8-bit unsigned PCM.
  /// [pan] is stereo position: -1.0 = full left, 0.0 = centre, 1.0 = full right.
  Future<void> playAudio(
    String radioId,
    Uint8List pcmBytes,
    int sampleRate, {
    int bitsPerSample = 16,
    double pan = 0.0,
  }) async {
    _ensureInitialized();
    if (pcmBytes.isEmpty) return;

    final buf = _rxBuffers.putIfAbsent(radioId, _RxBuffer.new);
    buf.push(pcmBytes, sampleRate, bitsPerSample);

    if (!buf.hasEnough) return;

    final combined = buf.drain()!;
    try {
      final wavBytes = _wrapInWav(combined, sampleRate, bitsPerSample: bitsPerSample);
      final key = 'rx_${radioId}_${_chunkSeq++}';
      final source = await SoLoud.instance.loadMem(key, wavBytes,
          autoDispose: true);
      SoLoud.instance.play(source, pan: pan);
    } catch (_) {}
  }

  /// Play [pcmBytes] immediately without the jitter buffer — for sidetone.
  Future<void> playAudioImmediate(
    Uint8List pcmBytes,
    int sampleRate, {
    int bitsPerSample = 16,
    double volume = 1.0,
    double pan = 0.0,
  }) async {
    _ensureInitialized();
    if (pcmBytes.isEmpty) return;
    try {
      final wavBytes = _wrapInWav(pcmBytes, sampleRate, bitsPerSample: bitsPerSample);
      final key = 'imm_${_chunkSeq++}';
      final source = await SoLoud.instance.loadMem(key, wavBytes,
          autoDispose: true);
      SoLoud.instance.play(source, volume: volume, pan: pan);
    } catch (_) {}
  }

  /// Load and play a Flutter asset file (e.g. a WAV sound effect).
  Future<void> playAsset(String assetPath) async {
    _ensureInitialized();
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final key = 'asset_${assetPath}_${_chunkSeq++}';
      final source = await SoLoud.instance.loadMem(key, bytes, autoDispose: true);
      SoLoud.instance.play(source);
    } catch (_) {}
  }

  Stream<double> inputLevel(String radioId) {
    return _captureSessions[radioId]?.levelController.stream ??
        const Stream.empty();
  }

  void updateRxLevel(String radioId, double level) {
    final ctrl = _rxLevelControllers.putIfAbsent(
      radioId,
      () => StreamController<double>.broadcast(),
    );
    if (!ctrl.isClosed) ctrl.add(level);
  }

  Stream<double> rxLevel(String radioId) {
    return (_rxLevelControllers.putIfAbsent(
      radioId,
      () => StreamController<double>.broadcast(),
    )).stream;
  }

  double _computeRms(Uint8List pcmData) {
    if (pcmData.length < 2) return 0;
    final bd = ByteData.sublistView(pcmData);
    final count = pcmData.length ~/ 2;
    double sum = 0;
    for (int i = 0; i < count; i++) {
      final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    return math.sqrt(sum / count);
  }

  Uint8List _wrapInWav(Uint8List pcm, int sampleRate, {int bitsPerSample = 16}) {
    final dataSize = pcm.length;
    final blockAlign = bitsPerSample ~/ 8;
    final byteRate = sampleRate * blockAlign;
    final header = ByteData(44);

    void setFcc(int o, String s) {
      for (int i = 0; i < 4; i++) header.setUint8(o + i, s.codeUnitAt(i));
    }

    setFcc(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    setFcc(8, 'WAVE');
    setFcc(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);           // PCM
    header.setUint16(22, 1, Endian.little);           // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    setFcc(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcm);
    return result;
  }

  void _ensureInitialized() {
    if (!_initialized) throw StateError('AudioManager not initialized.');
  }
}
