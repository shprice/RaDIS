import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

class VoxDetector {
  double threshold;
  Duration hangTime;

  final _controller = StreamController<bool>.broadcast();
  bool _active = false;
  DateTime? _lastVoiceTime;
  int _consecutiveVoiceChunks = 0;

  static const int _activationChunks = 3; // 3 chunks (~60ms) to activate

  VoxDetector({
    this.threshold = 0.05,
    this.hangTime = const Duration(milliseconds: 500),
  });

  Stream<bool> get voxActive => _controller.stream;
  bool get isActive => _active;

  /// Returns true if voice is currently detected.
  /// Call this with each ~20ms chunk of 16-bit PCM (little-endian bytes).
  bool processAudio(Uint8List pcmData) {
    final rms = _calculateRms(pcmData);
    final hasVoice = rms >= threshold;

    if (hasVoice) {
      _consecutiveVoiceChunks++;
      _lastVoiceTime = DateTime.now();

      if (!_active && _consecutiveVoiceChunks >= _activationChunks) {
        _active = true;
        _controller.add(true);
      }
    } else {
      _consecutiveVoiceChunks = 0;
      if (_active && _lastVoiceTime != null) {
        final elapsed = DateTime.now().difference(_lastVoiceTime!);
        if (elapsed >= hangTime) {
          _active = false;
          _controller.add(false);
        }
      }
    }

    return _active;
  }

  double _calculateRms(Uint8List pcmData) {
    if (pcmData.isEmpty) return 0;
    final bd = ByteData.sublistView(pcmData);
    final sampleCount = pcmData.length ~/ 2;
    if (sampleCount == 0) return 0;

    double sumSq = 0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sumSq += sample * sample;
    }
    return math.sqrt(sumSq / sampleCount);
  }

  void reset() {
    _active = false;
    _consecutiveVoiceChunks = 0;
    _lastVoiceTime = null;
    _controller.add(false);
  }

  void dispose() {
    _controller.close();
  }
}
