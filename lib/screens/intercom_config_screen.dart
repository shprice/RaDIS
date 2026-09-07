import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/intercom_config.dart';
import '../providers/radio_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../dis/constants.dart';
import '../theme.dart';

class IntercomConfigScreen extends StatefulWidget {
  final IntercomConfig intercom;

  const IntercomConfigScreen({super.key, required this.intercom});

  @override
  State<IntercomConfigScreen> createState() => _IntercomConfigScreenState();
}

class _IntercomConfigScreenState extends State<IntercomConfigScreen> {
  late IntercomConfig _intercom;
  List<_AdapterOption> _adapters = const [
    _AdapterOption('0.0.0.0', 'Any (0.0.0.0)'),
  ];

  @override
  void initState() {
    super.initState();
    _intercom = widget.intercom;
    _loadAdapters();
  }

  Future<void> _loadAdapters() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      final options = <_AdapterOption>[
        const _AdapterOption('0.0.0.0', 'Any (0.0.0.0)'),
        for (final iface in interfaces)
          for (final addr in iface.addresses)
            _AdapterOption(addr.address, '${iface.name}  ${addr.address}'),
      ];
      if (mounted) setState(() => _adapters = options);
    } catch (_) {}
  }

  void _update(IntercomConfig updated) => setState(() => _intercom = updated);

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final radioProvider = context.read<RadioProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final allBindings = settingsProvider.settings.keyBindings;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configure: ${_intercom.name}'),
        actions: [
          TextButton(
            onPressed: () {
              radioProvider.updateIntercom(_intercom);
              Navigator.pop(context);
            },
            child: const Text('SAVE',
                style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: 'IDENTITY', children: [
            _Field(
              label: 'Intercom Name',
              child: TextFormField(
                initialValue: _intercom.name,
                style: _inputStyle,
                decoration: _inputDec('e.g. Crew Intercom'),
                onChanged: (v) => _update(_intercom.copyWith(name: v)),
              ),
            ),
            SwitchListTile(
              title: const Text('Enabled', style: TextStyle(color: AppColors.text)),
              value: _intercom.enabled,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) => _update(_intercom.copyWith(enabled: v)),
            ),
          ]),

          _Section(title: 'DIS PARAMETERS', children: [
            _Field(
              label: 'Exercise ID',
              child: TextFormField(
                initialValue: _intercom.exerciseId.toString(),
                style: _inputStyle,
                decoration: _inputDec('1'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null) _update(_intercom.copyWith(exerciseId: n));
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Site ID',
                    child: TextFormField(
                      initialValue: _intercom.entityId.siteId.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? _intercom.entityId.siteId;
                        _update(_intercom.copyWith(
                            entityId: _intercom.entityId.copyWith(siteId: n)));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: 'App ID',
                    child: TextFormField(
                      initialValue:
                          _intercom.entityId.applicationId.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v) ??
                            _intercom.entityId.applicationId;
                        _update(_intercom.copyWith(
                            entityId: _intercom.entityId
                                .copyWith(applicationId: n)));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: 'Entity #',
                    child: TextFormField(
                      initialValue: _intercom.entityId.entityNumber.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v) ??
                            _intercom.entityId.entityNumber;
                        _update(_intercom.copyWith(
                            entityId: _intercom.entityId
                                .copyWith(entityNumber: n)));
                      },
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Intercom ID (UINT16)',
                    child: TextFormField(
                      initialValue: _intercom.communicationsDeviceId.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 0 && n <= 65535) {
                          _update(_intercom.copyWith(
                              communicationsDeviceId: n));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: 'Station Name (UINT8)',
                    child: TextFormField(
                      initialValue: _intercom.stationName.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('0'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 0 && n <= 255) {
                          _update(_intercom.copyWith(stationName: n));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            _Field(
              label: 'Channel Type',
              child: DropdownButtonFormField<int>(
                value: _intercom.channelType,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: const [
                  DropdownMenuItem(
                    value: DisConstants.intercomChannelTypeFdx,
                    child: Text('1 – FDX (Full Duplex)'),
                  ),
                  DropdownMenuItem(
                    value: DisConstants.intercomChannelTypeHdxRxOnly,
                    child: Text('2 – HDX – Dest RX Only'),
                  ),
                  DropdownMenuItem(
                    value: DisConstants.intercomChannelTypeHdxTxOnly,
                    child: Text('3 – HDX – Dest TX Only'),
                  ),
                  DropdownMenuItem(
                    value: DisConstants.intercomChannelTypeHdx,
                    child: Text('4 – HDX (Half Duplex)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _update(_intercom.copyWith(channelType: v));
                },
              ),
            ),
          ]),

          _Section(title: 'PUSH-TO-TALK', children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'PTT Key Bindings',
                style: TextStyle(color: AppColors.text, fontSize: 14),
              ),
            ),
            if (allBindings.isEmpty)
              const Text(
                'No key bindings defined. Add bindings in Settings.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              )
            else
              ...allBindings.map((binding) {
                final isSelected = _intercom.pttBindingIds.contains(binding.id);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    binding.displayLabel,
                    style:
                        const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                  subtitle: Text(
                    binding.fullKeyLabel,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                  value: isSelected,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (checked) {
                    final ids = List<String>.from(_intercom.pttBindingIds);
                    if (checked == true) {
                      ids.add(binding.id);
                    } else {
                      ids.remove(binding.id);
                    }
                    _update(_intercom.copyWith(pttBindingIds: ids));
                  },
                );
              }),
            const SizedBox(height: 8),
            _Field(
              label: 'VOX Hang Time (ms)',
              child: TextFormField(
                initialValue: _intercom.voxHangTime.inMilliseconds.toString(),
                style: _inputStyle,
                decoration: _inputDec('500'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final ms = int.tryParse(v);
                  if (ms != null) {
                    _update(_intercom.copyWith(
                        voxHangTime: Duration(milliseconds: ms)));
                  }
                },
              ),
            ),
          ]),

          _Section(title: 'AUDIO', children: [
            _Field(
              label: 'Input Device (Microphone)',
              child: DropdownButtonFormField<String?>(
                value: _intercom.inputDeviceId,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default')),
                  ...audioProvider.inputDevices.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) =>
                    _update(_intercom.copyWith(inputDeviceId: v)),
              ),
            ),
            _Field(
              label: 'Output Device (Speaker)',
              child: DropdownButtonFormField<String?>(
                value: _intercom.outputDeviceId,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default')),
                  ...audioProvider.outputDevices.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) =>
                    _update(_intercom.copyWith(outputDeviceId: v)),
              ),
            ),
            _LabeledSlider(
              label: 'Input Gain',
              value: _intercom.inputGain,
              min: 0,
              max: 2,
              display: '${(_intercom.inputGain * 100).round()}%',
              onChanged: (v) => _update(_intercom.copyWith(inputGain: v)),
            ),
            _LabeledSlider(
              label: 'Output Volume',
              value: _intercom.outputVolume,
              min: 0,
              max: 1,
              display: '${(_intercom.outputVolume * 100).round()}%',
              onChanged: (v) => _update(_intercom.copyWith(outputVolume: v)),
            ),
            _LabeledSlider(
              label: 'Sidetone',
              value: _intercom.sidetoneVolume,
              min: 0,
              max: 1,
              display: '${(_intercom.sidetoneVolume * 100).round()}%',
              onChanged: (v) => _update(_intercom.copyWith(sidetoneVolume: v)),
            ),
            _LabeledSlider(
              label: 'Pan',
              value: _intercom.outputPan,
              min: -1,
              max: 1,
              display: _intercom.outputPan.abs() < 0.01
                  ? 'C'
                  : _intercom.outputPan < 0
                      ? 'L${(-_intercom.outputPan * 100).round()}'
                      : 'R${(_intercom.outputPan * 100).round()}',
              onChanged: (v) => _update(_intercom.copyWith(outputPan: v)),
            ),
          ]),

          _Section(title: 'DIS NETWORK', children: [
            _Field(
              label: 'DIS Protocol Version',
              child: DropdownButtonFormField<int>(
                value: _intercom.disProtocolVersion,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: const [
                  DropdownMenuItem(value: 4, child: Text('v4 — IEEE 1278.1-1993')),
                  DropdownMenuItem(value: 5, child: Text('v5 — IEEE 1278.1a-1998')),
                  DropdownMenuItem(value: 6, child: Text('v6 — IEEE 1278.1-2012')),
                  DropdownMenuItem(value: 7, child: Text('v7 — SISO-STD-002.1-2017')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_intercom.copyWith(disProtocolVersion: v));
                },
              ),
            ),
            if (_intercom.disProtocolVersion < 6)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        size: 13, color: Colors.orange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Intercom PDU types 31/32 are not defined in DIS v4/v5 '
                        'and will be suppressed.',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            _Field(
              label: 'Local Address',
              child: DropdownButtonFormField<String>(
                value: _adapters.any((a) => a.address == _intercom.disLocalAddress)
                    ? _intercom.disLocalAddress
                    : '0.0.0.0',
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: _adapters
                    .map((a) => DropdownMenuItem(
                          value: a.address,
                          child: Text(a.label, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null)
                    _update(_intercom.copyWith(disLocalAddress: v));
                },
              ),
            ),
            _Field(
              label: 'Port',
              child: TextFormField(
                initialValue: _intercom.disPort.toString(),
                style: _inputStyle,
                decoration: _inputDec('3000'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final p = int.tryParse(v);
                  if (p != null) _update(_intercom.copyWith(disPort: p));
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Use Multicast',
                  style: TextStyle(color: AppColors.text)),
              subtitle: const Text('DIS multicast networking',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11)),
              value: _intercom.disUseMulticast,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) =>
                  _update(_intercom.copyWith(disUseMulticast: v)),
            ),
            if (_intercom.disUseMulticast) ...[
              _Field(
                label: 'Multicast Group',
                child: TextFormField(
                  initialValue: _intercom.disMulticastGroup,
                  style: _inputStyle,
                  decoration:
                      _inputDec(DisConstants.defaultMulticastGroup),
                  onChanged: (v) {
                    if (v.isNotEmpty)
                      _update(_intercom.copyWith(disMulticastGroup: v));
                  },
                ),
              ),
              _Field(
                label: 'Network Interface (optional)',
                child: TextFormField(
                  initialValue: _intercom.disNetworkInterface ?? '',
                  style: _inputStyle,
                  decoration: _inputDec(
                      'e.g. eth0  (leave blank for default)'),
                  onChanged: (v) => _update(_intercom.copyWith(
                      disNetworkInterface: v.isEmpty ? null : v)),
                ),
              ),
            ] else
              _Field(
                label: 'Broadcast / Unicast Address',
                child: TextFormField(
                  initialValue: _intercom.disUnicastAddress,
                  style: _inputStyle,
                  decoration:
                      _inputDec(DisConstants.defaultBroadcastAddress),
                  onChanged: (v) {
                    if (v.isNotEmpty)
                      _update(_intercom.copyWith(disUnicastAddress: v));
                  },
                ),
              ),
          ]),

          _Section(title: 'ENCODING', children: [
            _Field(
              label: 'Encoding Type',
              child: DropdownButtonFormField<int>(
                value: _intercom.encodingType,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: const [
                  DropdownMenuItem(
                      value: DisConstants.encodingMulaw,
                      child: Text('µ-law G.711 (8-bit)')),
                  DropdownMenuItem(
                      value: DisConstants.encodingAlaw,
                      child: Text('A-law G.711 (8-bit)')),
                  DropdownMenuItem(
                      value: DisConstants.encodingLinear16,
                      child: Text('Linear PCM (16-bit)')),
                  DropdownMenuItem(
                      value: DisConstants.encodingCVSD,
                      child: Text('CVSD (32 kHz delta)')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_intercom.copyWith(encodingType: v));
                },
              ),
            ),
            _Field(
              label: 'Sample Rate',
              child: DropdownButtonFormField<int>(
                value: _intercom.sampleRate,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: const [
                  DropdownMenuItem(
                      value: DisConstants.sampleRate8kHz,
                      child: Text('8 kHz')),
                  DropdownMenuItem(
                      value: DisConstants.sampleRate16kHz,
                      child: Text('16 kHz')),
                  DropdownMenuItem(
                      value: DisConstants.sampleRate32kHz,
                      child: Text('32 kHz')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_intercom.copyWith(sampleRate: v));
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    radioProvider.updateIntercom(_intercom);
                    Navigator.pop(context);
                  },
                  child: const Text('SAVE CONFIGURATION'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      );

  TextStyle get _inputStyle =>
      const TextStyle(color: AppColors.text, fontSize: 13);
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
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
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.text)),
          ),
          Expanded(
            child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged),
          ),
          SizedBox(
            width: 60,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdapterOption {
  final String address;
  final String label;
  const _AdapterOption(this.address, this.label);
}
