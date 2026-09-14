import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'audio_device_model.dart';

// How many ms of audio to accumulate before triggering playback.
const _kJitterTargetMs = 200;

// Minimum TX chunk size in bytes (16-bit PCM). At 8kHz mono, 100ms = 1600 bytes.
const _kTxTargetBytes = 1600;

// One subscriber per radio/intercom ID sharing a recorder.
class _CaptureSubscriber {
  final StreamController<double> levelController;
  final void Function(Uint8List) onData;
  final List<Uint8List> txChunks = [];
  int txTotalBytes = 0;

  _CaptureSubscriber({required this.onData})
      : levelController = StreamController<double>.broadcast();

  void feed(Uint8List chunk, double rms) {
    levelController.add(rms);
    txChunks.add(chunk);
    txTotalBytes += chunk.length;
    if (txTotalBytes >= _kTxTargetBytes) {
      final combined = Uint8List(txTotalBytes);
      int offset = 0;
      for (final c in txChunks) {
        combined.setRange(offset, offset + c.length, c);
        offset += c.length;
      }
      txChunks.clear();
      txTotalBytes = 0;
      onData(combined);
    }
  }

  void dispose() {
    levelController.close();
    txChunks.clear();
    txTotalBytes = 0;
  }
}

// One shared AudioRecorder per (deviceId, sampleRate) combination.
// All radios/intercoms using the same device+rate share a single parecord
// process on Linux, eliminating device contention.
class _SharedRecorder {
  final AudioRecorder recorder;
  StreamSubscription<Uint8List>? subscription;
  final Map<String, _CaptureSubscriber> subscribers = {};
  int _chunkCount = 0;

  _SharedRecorder(this.recorder);

  void dispatchChunk(Uint8List chunk, double Function(Uint8List) computeRms) {
    _chunkCount++;
    final rms = computeRms(chunk);
    if (_chunkCount <= 3) {
      print('AudioManager: shared chunk #$_chunkCount  bytes=${chunk.length}  subscribers=${subscribers.length}');
    }
    for (final sub in subscribers.values) {
      sub.feed(chunk, rms);
    }
  }

  Future<void> dispose() async {
    await subscription?.cancel();
    subscription = null;
    try {
      await recorder.stop();
    } catch (_) {}
    await recorder.dispose();
    for (final s in subscribers.values) {
      s.dispose();
    }
    subscribers.clear();
  }
}

// Per-radio RX jitter buffer — smooths choppy playback caused by network jitter.
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

  // keyed by "deviceId:sampleRate" — one recorder shared across all subscribers
  final Map<String, _SharedRecorder> _sharedRecorders = {};
  // radioId -> shared recorder key (reverse index for fast lookup)
  final Map<String, String> _radioToKey = {};

  final Map<String, _RxBuffer> _rxBuffers = {};
  final Map<String, StreamController<double>> _rxLevelControllers = {};

  int _chunkSeq = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    await SoLoud.instance.init();
    _initialized = true;
  }

  Future<void> dispose() async {
    for (final sr in List.of(_sharedRecorders.values)) {
      await sr.dispose();
    }
    _sharedRecorders.clear();
    _radioToKey.clear();
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
  /// If another radio/intercom is already capturing from the same
  /// [deviceId]+[sampleRate] combination, the existing recorder is reused and
  /// [onData] is added as an additional subscriber — no second parecord process
  /// is spawned. This fixes the Linux device-contention problem where only one
  /// parecord process receives audio at a time.
  Future<void> startCapture(
    String radioId,
    String? deviceId,
    int sampleRate,
    void Function(Uint8List) onData,
  ) async {
    if (!_initialized) await initialize();
    await stopCapture(radioId);

    final key = '${deviceId ?? "default"}:$sampleRate';
    _radioToKey[radioId] = key;

    final subscriber = _CaptureSubscriber(onData: onData);

    if (_sharedRecorders.containsKey(key)) {
      // Reuse existing recorder — just add this subscriber.
      _sharedRecorders[key]!.subscribers[radioId] = subscriber;
      print('AudioManager: joined shared capture $key for $radioId  (${_sharedRecorders[key]!.subscribers.length} subscribers)');
      return;
    }

    // No existing recorder for this device+rate — create one.
    final recorder = AudioRecorder();
    final shared = _SharedRecorder(recorder);
    shared.subscribers[radioId] = subscriber;
    _sharedRecorders[key] = shared;

    try {
      InputDevice? inputDevice;
      if (deviceId != null && deviceId != AudioDevice.defaultInput.id) {
        final available = await recorder.listInputDevices();
        try {
          inputDevice = available.firstWhere((d) => d.id == deviceId);
        } catch (_) {}
      }

      print('AudioManager: starting capture $key  device=${inputDevice?.id ?? "default"}  rate=$sampleRate');
      final stream = await recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        device: inputDevice,
        streamBufferSize: sampleRate * 2 ~/ 20,
      ));
      print('AudioManager: capture stream open for $key');

      shared.subscription = stream.listen(
        (chunk) {
          if (!_sharedRecorders.containsKey(key)) return;
          shared.dispatchChunk(chunk, _computeRms);
        },
        onError: (e) => print('AudioManager: capture stream error for $key: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      print('AudioManager: failed to start capture for $key: $e');
      _sharedRecorders.remove(key);
      _radioToKey.remove(radioId);
      await shared.dispose();
    }
  }

  Future<void> stopCapture(String radioId) async {
    final key = _radioToKey.remove(radioId);
    if (key == null) return;

    final shared = _sharedRecorders[key];
    if (shared == null) return;

    shared.subscribers[radioId]?.dispose();
    shared.subscribers.remove(radioId);

    if (shared.subscribers.isEmpty) {
      _sharedRecorders.remove(key);
      await shared.dispose();
      print('AudioManager: stopped shared capture $key (no subscribers left)');
    } else {
      print('AudioManager: removed subscriber $radioId from $key  (${shared.subscribers.length} remaining)');
    }
  }

  Stream<double> inputLevel(String radioId) {
    final key = _radioToKey[radioId];
    if (key == null) return const Stream.empty();
    return _sharedRecorders[key]?.subscribers[radioId]?.levelController.stream ??
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

  /// Queue [pcmBytes] for [radioId]. Audio is accumulated into a jitter
  /// buffer and played once [_kJitterTargetMs] ms of audio is available.
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
