import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/radio_config.dart';
import '../providers/radio_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../dis/constants.dart';
import '../theme.dart';
import '../widgets/frequency_display.dart';

class RadioConfigScreen extends StatefulWidget {
  final RadioConfig radio;

  const RadioConfigScreen({super.key, required this.radio});

  @override
  State<RadioConfigScreen> createState() => _RadioConfigScreenState();
}

class _RadioConfigScreenState extends State<RadioConfigScreen> {
  late RadioConfig _radio;
  List<_AdapterOption> _adapters = const [
    _AdapterOption('0.0.0.0', 'Any (0.0.0.0)'),
  ];

  @override
  void initState() {
    super.initState();
    _radio = widget.radio;
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

  void _update(RadioConfig updated) => setState(() => _radio = updated);

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final radioProvider = context.read<RadioProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final allBindings = settingsProvider.settings.keyBindings;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configure: ${_radio.name}'),
        actions: [
          TextButton(
            onPressed: () {
              radioProvider.updateRadio(_radio);
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
              label: 'Radio Name',
              child: TextFormField(
                initialValue: _radio.name,
                style: _inputStyle,
                decoration: _inputDec('e.g. Pilot Radio'),
                onChanged: (v) => _update(_radio.copyWith(name: v)),
              ),
            ),
            SwitchListTile(
              title: const Text('TX Beep', style: TextStyle(color: AppColors.text)),
              subtitle: const Text('Play tone at start of transmission',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              value: _radio.txBeepEnabled,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) => _update(_radio.copyWith(txBeepEnabled: v)),
            ),
          ]),

          _Section(title: 'FREQUENCY', children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FrequencyDisplay(
                frequency: _radio.frequency,
                onChanged: (f) => _update(_radio.copyWith(frequency: f)),
              ),
            ),
            _Field(
              label: 'Bandwidth (Hz)',
              child: TextFormField(
                initialValue: _radio.bandwidth.toStringAsFixed(0),
                style: _inputStyle,
                decoration: _inputDec('25000'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final bw = double.tryParse(v);
                  if (bw != null) _update(_radio.copyWith(bandwidth: bw));
                },
              ),
            ),
            _Field(
              label: 'Modulation Type',
              child: DropdownButtonFormField<RadioModulationType>(
                value: _radio.modulationType,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: RadioModulationType.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _update(_radio.copyWith(modulationType: v));
                },
              ),
            ),
            _PowerField(
              watts: _radio.powerWatts,
              onChanged: (w) => _update(_radio.copyWith(powerWatts: w)),
            ),
          ]),

          _Section(title: 'CRYPTO', children: [
            _Field(
              label: 'Crypto System',
              child: DropdownButtonFormField<int>(
                value: _radio.cryptoSystem,
                dropdownColor: AppColors.surface,
                style: _inputStyle,
                decoration: _inputDec(''),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('NONE')),
                  DropdownMenuItem(value: 1, child: Text('KY-28')),
                  DropdownMenuItem(value: 2, child: Text('KY-57')),
                  DropdownMenuItem(value: 3, child: Text('KY-58')),
                  DropdownMenuItem(value: 4, child: Text('VINSON')),
                  DropdownMenuItem(value: 5, child: Text('ANDVT')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_radio.copyWith(cryptoSystem: v));
                },
              ),
            ),
            _Field(
              label: 'Crypto Key ID',
              child: TextFormField(
                initialValue: _radio.cryptoKeyId.toString(),
                style: _inputStyle,
                decoration: _inputDec('0'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final k = int.tryParse(v);
                  if (k != null) _update(_radio.copyWith(cryptoKeyId: k));
                },
              ),
            ),
          ]),

          _Section(title: 'AUDIO', children: [
            _Field(
              label: 'Input Device (Microphone)',
              child: DropdownButtonFormField<String?>(
                value: _radio.inputDeviceId,
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
                onChanged: (v) => _update(_radio.copyWith(inputDeviceId: v)),
              ),
            ),
            _Field(
              label: 'Output Device (Speaker)',
              child: DropdownButtonFormField<String?>(
                value: _radio.outputDeviceId,
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
                onChanged: (v) => _update(_radio.copyWith(outputDeviceId: v)),
              ),
            ),
            _LabeledSlider(
              label: 'Input Gain',
              value: _radio.inputGain,
              min: 0,
              max: 2,
              display: '${(_radio.inputGain * 100).round()}%',
              onChanged: (v) => _update(_radio.copyWith(inputGain: v)),
            ),
            _LabeledSlider(
              label: 'Output Volume',
              value: _radio.outputVolume,
              min: 0,
              max: 1,
              display: '${(_radio.outputVolume * 100).round()}%',
              onChanged: (v) => _update(_radio.copyWith(outputVolume: v)),
            ),
            _LabeledSlider(
              label: 'Squelch',
              value: _radio.squelch,
              min: 0,
              max: 1,
              display: '${(_radio.squelch * 100).round()}%',
              onChanged: (v) => _update(_radio.copyWith(squelch: v)),
            ),
            _LabeledSlider(
              label: 'Sidetone',
              value: _radio.sidetoneVolume,
              min: 0,
              max: 1,
              display: '${(_radio.sidetoneVolume * 100).round()}%',
              onChanged: (v) => _update(_radio.copyWith(sidetoneVolume: v)),
            ),
            _LabeledSlider(
              label: 'Pan',
              value: _radio.outputPan,
              min: -1,
              max: 1,
              display: _radio.outputPan.abs() < 0.01
                  ? 'C'
                  : _radio.outputPan < 0
                      ? 'L${(-_radio.outputPan * 100).round()}'
                      : 'R${(_radio.outputPan * 100).round()}',
              onChanged: (v) => _update(_radio.copyWith(outputPan: v)),
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
                final isSelected = _radio.pttBindingIds.contains(binding.id);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    binding.displayLabel,
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                  subtitle: Text(
                    binding.fullKeyLabel,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                  value: isSelected,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (checked) {
                    final ids = List<String>.from(_radio.pttBindingIds);
                    if (checked == true) {
                      ids.add(binding.id);
                    } else {
                      ids.remove(binding.id);
                    }
                    _update(_radio.copyWith(pttBindingIds: ids));
                  },
                );
              }),
            const SizedBox(height: 8),
            _Field(
              label: 'VOX Hang Time (ms)',
              child: TextFormField(
                initialValue: _radio.voxHangTime.inMilliseconds.toString(),
                style: _inputStyle,
                decoration: _inputDec('500'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final ms = int.tryParse(v);
                  if (ms != null) {
                    _update(_radio.copyWith(
                        voxHangTime: Duration(milliseconds: ms)));
                  }
                },
              ),
            ),
          ]),

          _Section(title: 'NET PLAN ASSIGNMENT', children: [
            Consumer<RadioProvider>(
              builder: (context, rp, _) {
                // Encode selection as "planId:channelIndex", null = Manual
                final currentKey = _radio.netPlanId != null &&
                        _radio.netChannelIndex != null
                    ? '${_radio.netPlanId}:${_radio.netChannelIndex}'
                    : null;

                final items = <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(value: null, child: Text('Manual')),
                  for (final plan in rp.netPlans)
                    for (var i = 0; i < plan.channels.length; i++)
                      DropdownMenuItem(
                        value: '${plan.id}:$i',
                        child: Text(
                          plan.channels[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ];

                // Guard: if current key isn't in the list, treat as Manual
                final safeKey = items.any((m) => m.value == currentKey)
                    ? currentKey
                    : null;

                return _Field(
                  label: 'Net / Channel',
                  child: DropdownButtonFormField<String?>(
                    value: safeKey,
                    dropdownColor: AppColors.surface,
                    style: _inputStyle,
                    decoration: _inputDec(''),
                    items: items,
                    onChanged: (v) {
                      if (v == null) {
                        _update(_radio.copyWith(
                            netPlanId: null, netChannelIndex: null));
                      } else {
                        final parts = v.split(':');
                        final planId = parts[0];
                        final idx = int.parse(parts[1]);
                        final plan = rp.getNetPlan(planId);
                        if (plan != null && idx < plan.channels.length) {
                          final ch = plan.channels[idx];
                          _update(_radio.copyWith(
                            netPlanId: planId,
                            netChannelIndex: idx,
                            frequency: ch.frequency,
                            modulationType: ch.modulationType,
                            cryptoSystem: ch.cryptoSystem,
                            cryptoKeyId: ch.cryptoKeyId,
                          ));
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ]),

          _Section(title: 'DIS NETWORK', children: [
            _Field(
              label: 'DIS Protocol Version',
              child: DropdownButtonFormField<int>(
                value: _radio.disProtocolVersion,
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
                  if (v != null) _update(_radio.copyWith(disProtocolVersion: v));
                },
              ),
            ),
            _Field(
              label: 'Local Address',
              child: DropdownButtonFormField<String>(
                value: _adapters.any((a) => a.address == _radio.disLocalAddress)
                    ? _radio.disLocalAddress
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
                  if (v != null) _update(_radio.copyWith(disLocalAddress: v));
                },
              ),
            ),
            _Field(
              label: 'Port',
              child: TextFormField(
                initialValue: _radio.disPort.toString(),
                style: _inputStyle,
                decoration: _inputDec('3000'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final p = int.tryParse(v);
                  if (p != null) _update(_radio.copyWith(disPort: p));
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Use Multicast',
                  style: TextStyle(color: AppColors.text)),
              subtitle: const Text('DIS multicast networking',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              value: _radio.disUseMulticast,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) => _update(_radio.copyWith(disUseMulticast: v)),
            ),
            if (_radio.disUseMulticast) ...[
              _Field(
                label: 'Multicast Group',
                child: TextFormField(
                  initialValue: _radio.disMulticastGroup,
                  style: _inputStyle,
                  decoration: _inputDec(DisConstants.defaultMulticastGroup),
                  onChanged: (v) {
                    if (v.isNotEmpty) _update(_radio.copyWith(disMulticastGroup: v));
                  },
                ),
              ),
              _Field(
                label: 'Network Interface (optional)',
                child: TextFormField(
                  initialValue: _radio.disNetworkInterface ?? '',
                  style: _inputStyle,
                  decoration: _inputDec('e.g. eth0  (leave blank for default)'),
                  onChanged: (v) => _update(_radio.copyWith(
                      disNetworkInterface: v.isEmpty ? null : v)),
                ),
              ),
            ] else
              _Field(
                label: 'Broadcast / Unicast Address',
                child: TextFormField(
                  initialValue: _radio.disUnicastAddress,
                  style: _inputStyle,
                  decoration: _inputDec(DisConstants.defaultBroadcastAddress),
                  onChanged: (v) {
                    if (v.isNotEmpty) _update(_radio.copyWith(disUnicastAddress: v));
                  },
                ),
              ),
          ]),

          _Section(title: 'DIS ENTITY', children: [
            _Field(
              label: 'Exercise ID',
              child: TextFormField(
                initialValue: _radio.exerciseId.toString(),
                style: _inputStyle,
                decoration: _inputDec('1'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null) _update(_radio.copyWith(exerciseId: n));
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Site ID',
                    child: TextFormField(
                      initialValue: _radio.entityId.siteId.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? _radio.entityId.siteId;
                        _update(_radio.copyWith(
                            entityId: _radio.entityId.copyWith(siteId: n)));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: 'App ID',
                    child: TextFormField(
                      initialValue: _radio.entityId.applicationId.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? _radio.entityId.applicationId;
                        _update(_radio.copyWith(
                            entityId: _radio.entityId.copyWith(applicationId: n)));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: 'Entity #',
                    child: TextFormField(
                      initialValue: _radio.entityId.entityNumber.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? _radio.entityId.entityNumber;
                        _update(_radio.copyWith(
                            entityId: _radio.entityId.copyWith(entityNumber: n)));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: 'Radio #',
                    child: TextFormField(
                      initialValue: _radio.radioNumber.toString(),
                      style: _inputStyle,
                      decoration: _inputDec('1'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) _update(_radio.copyWith(radioNumber: n));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    radioProvider.updateRadio(_radio);
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
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

// ---------------------------------------------------------------------------
// Power input: text field with Watts / dBm toggle
// ---------------------------------------------------------------------------

enum _PowerUnit { watts, dbm }

class _PowerField extends StatefulWidget {
  final double watts;
  final ValueChanged<double> onChanged;

  const _PowerField({required this.watts, required this.onChanged});

  @override
  State<_PowerField> createState() => _PowerFieldState();
}

class _PowerFieldState extends State<_PowerField> {
  _PowerUnit _unit = _PowerUnit.watts;
  late TextEditingController _ctrl;
  String? _error;

  static double _wToDbm(double w) =>
      w > 0 ? 10 * math.log(w * 1000) / math.ln10 : double.negativeInfinity;
  static double _dbmToW(double dbm) => math.pow(10, dbm / 10) / 1000 as double;

  String _formatWatts(double w) {
    if (w == w.truncate()) return w.truncate().toString();
    return w.toStringAsFixed(3);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _formatWatts(widget.watts));
  }

  @override
  void didUpdateWidget(_PowerField old) {
    super.didUpdateWidget(old);
    if (old.watts != widget.watts) {
      final current = _unit == _PowerUnit.watts
          ? _formatWatts(widget.watts)
          : _wToDbm(widget.watts).toStringAsFixed(2);
      if (_ctrl.text != current) {
        _ctrl.text = current;
        _ctrl.selection =
            TextSelection.collapsed(offset: current.length);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String v) {
    final parsed = double.tryParse(v);
    if (parsed == null) {
      setState(() => _error = 'Enter a valid number');
      return;
    }
    final watts = _unit == _PowerUnit.watts ? parsed : _dbmToW(parsed);
    if (watts < 0) {
      setState(() => _error = 'Power must be ≥ 0 W');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(watts);
  }

  void _switchUnit(_PowerUnit u) {
    if (u == _unit) return;
    setState(() {
      _unit = u;
      _ctrl.text = u == _PowerUnit.watts
          ? _formatWatts(widget.watts)
          : _wToDbm(widget.watts).toStringAsFixed(2);
      _ctrl.selection =
          TextSelection.collapsed(offset: _ctrl.text.length);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Power',
            style: TextStyle(
                fontSize: 10, color: AppColors.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    border: const OutlineInputBorder(),
                    errorText: _error,
                    errorStyle: const TextStyle(fontSize: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  onChanged: _onTextChanged,
                ),
              ),
              const SizedBox(width: 8),
              _UnitToggle(
                selected: _unit,
                onChanged: _switchUnit,
              ),
            ],
          ),
          if (_error == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _unit == _PowerUnit.watts
                    ? '≈ ${_wToDbm(widget.watts).toStringAsFixed(1)} dBm'
                    : '≈ ${_formatWatts(widget.watts)} W',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final _PowerUnit selected;
  final ValueChanged<_PowerUnit> onChanged;

  const _UnitToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: 'W',
          active: selected == _PowerUnit.watts,
          onTap: () => onChanged(_PowerUnit.watts),
        ),
        const SizedBox(width: 4),
        _Pill(
          label: 'dBm',
          active: selected == _PowerUnit.dbm,
          onTap: () => onChanged(_PowerUnit.dbm),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryGreen.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? AppColors.primaryGreen
                : AppColors.textMuted.withOpacity(0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color:
                active ? AppColors.primaryGreen : AppColors.textMuted,
            fontWeight:
                active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
