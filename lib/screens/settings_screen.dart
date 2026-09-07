import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/app_key_binding.dart';
import '../providers/settings_provider.dart';
import '../providers/dis_provider.dart';
import '../dis/constants.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  final _formKey = GlobalKey<FormState>();

  bool _capturingBinding = false;
  int? _pendingKeyCode;
  String _pendingKeyLabel = '';

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>().settings.copyWith();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onCaptureKey);
    super.dispose();
  }

  void _update(AppSettings s) => setState(() => _settings = s);

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final sp = context.read<SettingsProvider>();
    final dis = context.read<DisProvider>();

    await sp.updateSettings(_settings);
    dis.applySettings(_settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings applied'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  void _startCapturingBinding() {
    setState(() => _capturingBinding = true);
    HardwareKeyboard.instance.addHandler(_onCaptureKey);
  }

  bool _onCaptureKey(KeyEvent event) {
    if (event is KeyDownEvent && _capturingBinding) {
      HardwareKeyboard.instance.removeHandler(_onCaptureKey);
      final keyCode = event.physicalKey.usbHidUsage;
      final keyLabel = event.logicalKey.keyLabel;
      setState(() {
        _capturingBinding = false;
        _pendingKeyCode = keyCode;
        _pendingKeyLabel = keyLabel.isEmpty
            ? 'Key 0x${keyCode.toRadixString(16)}'
            : keyLabel;
      });
      _showBindingNameDialog(keyCode, _pendingKeyLabel);
      return true;
    }
    return false;
  }

  Future<void> _showBindingNameDialog(int keyCode, String keyLabel) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Name binding for "$keyLabel"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Optional name (e.g. "Push-to-talk")',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
    if (name != null) {
      final binding = AppKeyBinding(
        name: name,
        physicalKeyCode: keyCode,
        keyLabel: keyLabel,
      );
      _update(_settings.copyWith(
        keyBindings: [..._settings.keyBindings, binding],
      ));
    }
    setState(() {
      _pendingKeyCode = null;
      _pendingKeyLabel = '';
    });
  }

  void _deleteBinding(String id) {
    _update(_settings.copyWith(
      keyBindings: _settings.keyBindings.where((b) => b.id != id).toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          TextButton(
            onPressed: _apply,
            child: const Text('APPLY',
                style: TextStyle(color: AppColors.primaryGreen)),
          ),
          TextButton(
            onPressed: () async {
              await context.read<SettingsProvider>().resetToDefaults();
              setState(() {
                _settings = context.read<SettingsProvider>().settings.copyWith();
              });
            },
            child: const Text('RESET',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('KEY BINDINGS', [
              ..._settings.keyBindings.map((binding) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      binding.displayLabel,
                      style: const TextStyle(color: AppColors.text, fontSize: 13),
                    ),
                    subtitle: Text(
                      binding.fullKeyLabel,
                      style:
                          const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => _deleteBinding(binding.id),
                    ),
                  )),
              const SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: _capturingBinding ? null : _startCapturingBinding,
                icon: _capturingBinding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.amber),
                      )
                    : const Icon(Icons.add, size: 16),
                label: Text(_capturingBinding ? 'Press a key...' : 'ADD BINDING'),
              ),
            ]),
            _section('AUDIO DEFAULTS', [
              _dropdown<int>(
                label: 'Default Sample Rate',
                value: _settings.defaultSampleRate,
                items: const [
                  DropdownMenuItem(value: 8000, child: Text('8 kHz')),
                  DropdownMenuItem(value: 16000, child: Text('16 kHz')),
                  DropdownMenuItem(value: 32000, child: Text('32 kHz')),
                  DropdownMenuItem(value: 44100, child: Text('44.1 kHz')),
                  DropdownMenuItem(value: 48000, child: Text('48 kHz')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_settings.copyWith(defaultSampleRate: v));
                },
              ),
              _dropdown<int>(
                label: 'Default Encoding Type',
                value: _settings.defaultEncodingType,
                items: const [
                  DropdownMenuItem(
                      value: DisConstants.encodingMulaw,
                      child: Text('G.711 μ-law (8-bit)')),
                  DropdownMenuItem(
                      value: DisConstants.encodingAlaw,
                      child: Text('G.711 A-law (8-bit)')),
                  DropdownMenuItem(
                      value: DisConstants.encodingLinear16,
                      child: Text('PCM Linear 16-bit')),
                  DropdownMenuItem(
                      value: DisConstants.encodingCVSD,
                      child: Text('CVSD (32 kHz delta)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _update(_settings.copyWith(defaultEncodingType: v));
                  }
                },
              ),
            ]),
            _section('INTERFACE', [
              SwitchListTile(
                title: const Text('Dark Mode',
                    style: TextStyle(color: AppColors.text)),
                value: _settings.darkMode,
                activeColor: AppColors.primaryGreen,
                onChanged: (v) => _update(_settings.copyWith(darkMode: v)),
              ),
              SwitchListTile(
                title: const Text('Show Level Meters',
                    style: TextStyle(color: AppColors.text)),
                value: _settings.showLevelMeters,
                activeColor: AppColors.primaryGreen,
                onChanged: (v) =>
                    _update(_settings.copyWith(showLevelMeters: v)),
              ),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _apply,
              child: const Text('APPLY SETTINGS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required String initialValue,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required FormFieldSetter<String> onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: initialValue,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onSaved: onSave,
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            value: value,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
