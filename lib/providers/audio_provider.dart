import 'package:flutter/foundation.dart';
import '../audio/audio_device_model.dart';
import '../audio/audio_manager.dart';

class AudioProvider extends ChangeNotifier {
  List<AudioDevice> _inputDevices = [];
  List<AudioDevice> _outputDevices = [];
  bool _initialized = false;
  String? _error;

  List<AudioDevice> get inputDevices => _inputDevices;
  List<AudioDevice> get outputDevices => _outputDevices;
  bool get initialized => _initialized;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      await AudioManager.instance.initialize();
      _initialized = true;
      await refreshDevices();
    } catch (e) {
      _error = e.toString();
      _inputDevices = [AudioDevice.defaultInput];
      _outputDevices = [AudioDevice.defaultOutput];
      notifyListeners();
    }
  }

  Future<void> refreshDevices() async {
    if (!_initialized) return;
    try {
      _inputDevices = await AudioManager.instance.listInputDevices();
      _outputDevices = await AudioManager.instance.listOutputDevices();
      if (_inputDevices.isEmpty) _inputDevices = [AudioDevice.defaultInput];
      if (_outputDevices.isEmpty) _outputDevices = [AudioDevice.defaultOutput];
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  AudioDevice? findDevice(String? id, {required bool input}) {
    if (id == null) return null;
    final list = input ? _inputDevices : _outputDevices;
    try {
      return list.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    AudioManager.instance.dispose();
    super.dispose();
  }
}
