import 'package:flutter/services.dart';

/// Callback type for global hotkey events. [modifiers] is a [KeyModifiers]
/// bitmask of the modifier keys that were held when the event fired.
typedef HotkeyCallback = void Function(int usbHid, bool isDown, int modifiers);

/// Receives key events from a native low-level keyboard hook so that PTT
/// bindings fire even when the application window does not have focus.
///
/// On Windows: uses WH_KEYBOARD_LL (all keys intercepted; modifiers tracked
/// internally and included in each event).
/// On Linux/X11: uses XGrabKey on the root window; X11 state supplies modifiers.
/// On Wayland: not supported; falls back to in-app HardwareKeyboard handler.
class GlobalHotkeyService {
  GlobalHotkeyService._();
  static final instance = GlobalHotkeyService._();

  static const _channel = MethodChannel('dis_radio/global_hotkeys');

  HotkeyCallback? _onKey;
  bool _active = false;

  bool get isActive => _active;

  /// Start the native keyboard hook. [usbHidCodes] are the USB HID usage
  /// values (from [PhysicalKeyboardKey.usbHidUsage]) of the main keys to
  /// monitor (used on Linux for XGrabKey; ignored on Windows).
  Future<void> start(List<int> usbHidCodes, HotkeyCallback onKey) async {
    _onKey = onKey;
    _channel.setMethodCallHandler(_handleNativeCall);
    try {
      await _channel.invokeMethod<void>('start', {'hidCodes': usbHidCodes});
      _active = true;
    } catch (_) {
      _active = false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
    _active = false;
    _onKey = null;
    _channel.setMethodCallHandler(null);
  }

  /// Called from native with {'hidCode': int, 'isDown': bool, 'modifiers': int}.
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onKey' && _onKey != null) {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final modifiers = (args['modifiers'] as num?)?.toInt() ?? 0;
      _onKey!(
        (args['hidCode'] as num).toInt(),
        args['isDown'] as bool,
        modifiers,
      );
    }
  }
}
