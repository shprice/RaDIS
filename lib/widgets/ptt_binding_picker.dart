import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_key_binding.dart';
import '../providers/settings_provider.dart';

const _kGreen = Color(0xFF39FF14);
const _kGreenDim = Color(0xFF1A4A1A);
const _kBg = Color(0xFF0D0D0D);

/// Shows the PTT key binding picker dialog.
///
/// Returns the updated list of binding IDs selected for a radio/intercom,
/// and also writes any newly created bindings to [settingsProvider].
Future<List<String>?> showPttBindingPicker({
  required BuildContext context,
  required List<String> currentBindingIds,
  required SettingsProvider settingsProvider,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _PttBindingPickerDialog(
      currentBindingIds: currentBindingIds,
      settingsProvider: settingsProvider,
    ),
  );
}

// ---------------------------------------------------------------------------

class _PttBindingPickerDialog extends StatefulWidget {
  final List<String> currentBindingIds;
  final SettingsProvider settingsProvider;

  const _PttBindingPickerDialog({
    required this.currentBindingIds,
    required this.settingsProvider,
  });

  @override
  State<_PttBindingPickerDialog> createState() =>
      _PttBindingPickerDialogState();
}

class _PttBindingPickerDialogState extends State<_PttBindingPickerDialog> {
  late Set<String> _selected;
  bool _capturing = false;
  int _captureModifiers = 0; // live modifier state during capture
  String? _captureError;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.currentBindingIds);
  }

  @override
  void dispose() {
    if (_capturing) HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  List<AppKeyBinding> get _bindings =>
      widget.settingsProvider.settings.keyBindings;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _startCapture() {
    setState(() {
      _capturing = true;
      _captureModifiers = 0;
      _captureError = null;
    });
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _cancelCapture() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    setState(() {
      _capturing = false;
      _captureModifiers = 0;
    });
  }

  int _readModifiers() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    int mods = 0;
    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) mods |= KeyModifiers.ctrl;
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) mods |= KeyModifiers.shift;
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) mods |= KeyModifiers.alt;
    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight)) mods |= KeyModifiers.meta;
    return mods;
  }

  bool _isModifierPhysical(PhysicalKeyboardKey key) =>
      key == PhysicalKeyboardKey.controlLeft ||
      key == PhysicalKeyboardKey.controlRight ||
      key == PhysicalKeyboardKey.shiftLeft ||
      key == PhysicalKeyboardKey.shiftRight ||
      key == PhysicalKeyboardKey.altLeft ||
      key == PhysicalKeyboardKey.altRight ||
      key == PhysicalKeyboardKey.metaLeft ||
      key == PhysicalKeyboardKey.metaRight;

  bool _onKey(KeyEvent event) {
    if (!_capturing) return false;

    // Update live modifier display on any key event.
    final newMods = _readModifiers();
    if (newMods != _captureModifiers) {
      setState(() => _captureModifiers = newMods);
    }

    // Only finalize on a non-modifier key-down.
    if (event is! KeyDownEvent) return false;
    if (_isModifierPhysical(event.physicalKey)) return false;

    HardwareKeyboard.instance.removeHandler(_onKey);

    final hid = event.physicalKey.usbHidUsage;
    if (hid == 0) {
      setState(() {
        _capturing = false;
        _captureModifiers = 0;
        _captureError = 'Key not recognised — try another key.';
      });
      return true;
    }

    final label = _keyLabel(event);
    final mods = _captureModifiers;

    // Check for exact duplicate (same key + same modifiers).
    final dup = _bindings.where((b) =>
        b.physicalKeyCode == hid && b.modifierFlags == mods).toList();
    if (dup.isNotEmpty) {
      setState(() {
        _capturing = false;
        _captureModifiers = 0;
        _selected.add(dup.first.id);
      });
      return true;
    }

    final binding = AppKeyBinding(
      name: '',
      physicalKeyCode: hid,
      keyLabel: label,
      modifierFlags: mods,
    );

    final settings = widget.settingsProvider.settings;
    widget.settingsProvider.updateSettings(
      settings.copyWith(keyBindings: [...settings.keyBindings, binding]),
    );

    setState(() {
      _capturing = false;
      _captureModifiers = 0;
      _selected.add(binding.id);
    });
    return true;
  }

  String _keyLabel(KeyEvent event) {
    final logical = event.logicalKey.keyLabel;
    return logical.isNotEmpty
        ? logical
        : 'Key(${event.physicalKey.usbHidUsage.toRadixString(16)})';
  }

  void _deleteBinding(String id) {
    final settings = widget.settingsProvider.settings;
    widget.settingsProvider.updateSettings(
      settings.copyWith(
        keyBindings: settings.keyBindings.where((b) => b.id != id).toList(),
      ),
    );
    setState(() => _selected.remove(id));
  }

  Future<void> _renameBinding(AppKeyBinding binding) async {
    final controller = TextEditingController(text: binding.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kBg,
        title: const Text('Rename Binding'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final settings = widget.settingsProvider.settings;
      widget.settingsProvider.updateSettings(
        settings.copyWith(
          keyBindings: settings.keyBindings
              .map((b) => b.id == binding.id ? b.copyWith(name: result) : b)
              .toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bindings = _bindings;

    return AlertDialog(
      backgroundColor: _kBg,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      title: const Text(
        'PTT KEY BINDINGS',
        style: TextStyle(
          color: _kGreen,
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                'Check bindings to assign to this radio. '
                'Double-click a name to rename.',
                style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A)),
            if (bindings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Text(
                  'No key bindings defined yet.\nUse "Capture New Key" below.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              )
            else
              ...bindings.map((b) => _BindingRow(
                    binding: b,
                    selected: _selected.contains(b.id),
                    onToggle: () => _toggle(b.id),
                    onRename: () => _renameBinding(b),
                    onDelete: () => _deleteBinding(b.id),
                  )),
            const Divider(color: Color(0xFF2A2A2A)),
            _buildCaptureSection(),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('APPLY'),
        ),
      ],
    );
  }

  Widget _buildCaptureSection() {
    if (_capturing) {
      final modLabel = KeyModifiers.prefix(_captureModifiers);
      final hint = modLabel.isEmpty ? 'PRESS A KEY...' : '$modLabel + ...';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                border: Border.all(color: const Color(0xFF1A3A1A), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kGreen),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hint,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontFamily: 'Courier New',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              modLabel.isEmpty
                  ? 'Hold modifiers (Ctrl, Shift, Alt) then press the key.'
                  : 'Now press the main key.',
              style:
                  const TextStyle(fontSize: 10, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _cancelCapture,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('CANCEL CAPTURE',
                  style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.keyboard, size: 14),
            label: const Text('CAPTURE NEW KEY COMBINATION',
                style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kGreen,
              side: const BorderSide(color: _kGreenDim),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            onPressed: _startCapture,
          ),
          if (_captureError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _captureError!,
                style:
                    const TextStyle(fontSize: 10, color: Colors.orangeAccent),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BindingRow extends StatelessWidget {
  final AppKeyBinding binding;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _BindingRow({
    required this.binding,
    required this.selected,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                activeColor: _kGreen,
                side: const BorderSide(color: Color(0xFF444444)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onDoubleTap: onRename,
                child: Text(
                  binding.displayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : const Color(0xFF888888),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Key combo chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                binding.fullKeyLabel,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 11,
                  color: Color(0xFFFFB300),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 14),
              color: Colors.red.shade700,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Delete binding',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
