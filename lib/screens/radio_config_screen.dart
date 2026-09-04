import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/radio_config.dart';
import '../providers/radio_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _radio = widget.radio;
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
              title: const Text('Enabled', style: TextStyle(color: AppColors.text)),
              value: _radio.enabled,
              activeColor: AppColors.primaryGreen,
              onChanged: (v) => _update(_radio.copyWith(enabled: v)),
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
              label: 'Frequency (Hz)',
              child: TextFormField(
                initialValue: _radio.frequency.toStringAsFixed(0),
                style: _inputStyle,
                decoration: _inputDec('225000000'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final hz = double.tryParse(v);
                  if (hz != null) _update(_radio.copyWith(frequency: hz));
                },
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
            _LabeledSlider(
              label: 'Power',
              value: _radio.powerWatts,
              min: 0.1,
              max: 100,
              display: '${_radio.powerWatts.toStringAsFixed(1)} W',
              onChanged: (v) => _update(_radio.copyWith(powerWatts: v)),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(
                      label: 'Net Plan',
                      child: DropdownButtonFormField<String?>(
                        value: _radio.netPlanId,
                        dropdownColor: AppColors.surface,
                        style: _inputStyle,
                        decoration: _inputDec(''),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Manual')),
                          ...rp.netPlans.map((n) => DropdownMenuItem(
                                value: n.id,
                                child: Text(n.name),
                              )),
                        ],
                        onChanged: (v) => _update(_radio.copyWith(
                          netPlanId: v,
                          netChannelIndex: null,
                        )),
                      ),
                    ),
                    if (_radio.netPlanId != null)
                      _Field(
                        label: 'Channel',
                        child: DropdownButtonFormField<int?>(
                          value: _radio.netChannelIndex,
                          dropdownColor: AppColors.surface,
                          style: _inputStyle,
                          decoration: _inputDec(''),
                          items: () {
                            final plan = rp.getNetPlan(_radio.netPlanId);
                            if (plan == null) return <DropdownMenuItem<int?>>[];
                            return [
                              const DropdownMenuItem(
                                  value: null, child: Text('Select...')),
                              ...plan.channels.asMap().entries.map((e) =>
                                  DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                        '${e.value.name} — ${(e.value.frequency / 1e6).toStringAsFixed(3)} MHz'),
                                  )),
                            ];
                          }(),
                          onChanged: (v) => _update(_radio.copyWith(
                            netChannelIndex: v,
                          )),
                        ),
                      ),
                  ],
                );
              },
            ),
          ]),

          _Section(title: 'DIS ENTITY', children: [
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
