import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/dis_provider.dart';
import '../providers/radio_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>().settings.copyWith();
  }

  void _update(AppSettings s) => setState(() => _settings = s);

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final sp = context.read<SettingsProvider>();
    final dis = context.read<DisProvider>();
    final rp = context.read<RadioProvider>();
    await sp.updateSettings(_settings);
    // Restart DIS network so new settings take effect immediately.
    // dis.start() calls stop() internally before re-binding the socket.
    await dis.start(_settings, rp.radios.toList(), rp.intercoms.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings applied'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
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
            _section('DIS NETWORK', [
              _field(
                label: 'Local Address',
                initialValue: _settings.disLocalAddress,
                hint: '0.0.0.0',
                onSave: (v) =>
                    _update(_settings.copyWith(disLocalAddress: v ?? '0.0.0.0')),
              ),
              _field(
                label: 'Port',
                initialValue: _settings.disPort.toString(),
                hint: '3000',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSave: (v) => _update(
                    _settings.copyWith(disPort: int.tryParse(v ?? '') ?? 3000)),
              ),
              SwitchListTile(
                title: const Text('Use Multicast',
                    style: TextStyle(color: AppColors.text)),
                subtitle: const Text('DIS multicast networking',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                value: _settings.disUseMulticast,
                activeColor: AppColors.primaryGreen,
                onChanged: (v) =>
                    _update(_settings.copyWith(disUseMulticast: v)),
              ),
              if (_settings.disUseMulticast)
                _field(
                  label: 'Multicast Group',
                  initialValue: _settings.disMulticastGroup,
                  hint: '239.1.2.3',
                  onSave: (v) => _update(
                      _settings.copyWith(disMulticastGroup: v ?? '239.1.2.3')),
                ),
              _field(
                label: 'Network Interface (optional)',
                initialValue: _settings.disNetworkInterface ?? '',
                hint: 'e.g. eth0',
                onSave: (v) => _update(_settings.copyWith(
                    disNetworkInterface: v?.isEmpty == true ? null : v)),
              ),
            ]),
            _section('DIS ENTITY', [
              Row(
                children: [
                  Expanded(
                    child: _field(
                      label: 'Site ID',
                      initialValue: _settings.siteId.toString(),
                      hint: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSave: (v) => _update(
                          _settings.copyWith(siteId: int.tryParse(v ?? '') ?? 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      label: 'Application ID',
                      initialValue: _settings.applicationId.toString(),
                      hint: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSave: (v) => _update(_settings.copyWith(
                          applicationId: int.tryParse(v ?? '') ?? 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      label: 'Exercise ID',
                      initialValue: _settings.exerciseId.toString(),
                      hint: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSave: (v) => _update(_settings.copyWith(
                          exerciseId: int.tryParse(v ?? '') ?? 1)),
                    ),
                  ),
                ],
              ),
            ]),
            _section('AUDIO DEFAULTS', [
              _dropdown<int>(
                label: 'Default Sample Rate',
                value: _settings.defaultSampleRate,
                items: const [
                  DropdownMenuItem(value: 8000, child: Text('8 kHz')),
                  DropdownMenuItem(value: 16000, child: Text('16 kHz')),
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
              fontFamily: 'Courier New',
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
            style: const TextStyle(
                color: AppColors.text, fontFamily: 'Courier New', fontSize: 13),
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
            style: const TextStyle(
                color: AppColors.text, fontFamily: 'Courier New', fontSize: 13),
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
