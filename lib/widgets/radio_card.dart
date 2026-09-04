import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/radio_config.dart';
import '../models/trigger_mode.dart';
import '../providers/dis_provider.dart';
import '../providers/radio_provider.dart';
import '../providers/settings_provider.dart';
import '../audio/audio_manager.dart';
import '../theme.dart';
import 'frequency_display.dart';
import 'ptt_button.dart';
import 'ptt_binding_picker.dart';
import 'rx_tx_indicator.dart';
import 'level_meter.dart';
import 'trigger_mode_selector.dart';

class RadioCard extends StatelessWidget {
  final RadioConfig radio;
  final VoidCallback? onConfigure;

  const RadioCard({
    super.key,
    required this.radio,
    this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final disProvider = context.watch<DisProvider>();
    final radioProvider = context.watch<RadioProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final rxState = disProvider.rxStates[radio.id] ?? const RadioRxState();
    final txActive = disProvider.isTxActive(radio.id);
    final netPlan = radioProvider.getNetPlan(radio.netPlanId);
    final channelName = (netPlan != null &&
            radio.netChannelIndex != null &&
            radio.netChannelIndex! < netPlan.channels.length)
        ? netPlan.channels[radio.netChannelIndex!].name
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, txActive, rxState, channelName, disProvider),
            const SizedBox(height: 8),
            FrequencyDisplay(
              frequency: radio.frequency,
              onChanged: (hz) =>
                  radioProvider.updateRadio(radio.copyWith(frequency: hz)),
            ),
            const SizedBox(height: 8),
            _buildNetDropdown(context, radioProvider),
            const SizedBox(height: 8),
            _buildPttRow(context, txActive, rxState, disProvider),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _buildControls(context, radioProvider, settingsProvider, disProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildNetDropdown(BuildContext context, RadioProvider rp) {
    final plans = rp.netPlans;

    // Encode selection as "planId:channelIndex" strings for DropdownButton.
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('— No net —', style: TextStyle(fontSize: 12)),
      ),
      ...plans.expand((plan) => plan.channels.asMap().entries.map((e) {
            final key = '${plan.id}:${e.key}';
            return DropdownMenuItem<String>(
              value: key,
              child: Text(
                '${plan.name} / ${e.value.name}',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          })),
    ];

    final currentKey =
        (radio.netPlanId != null && radio.netChannelIndex != null)
            ? '${radio.netPlanId}:${radio.netChannelIndex}'
            : '';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF2E2E2E)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.any((i) => i.value == currentKey) ? currentKey : '',
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          style: const TextStyle(fontSize: 12, color: AppColors.text),
          dropdownColor: const Color(0xFF1E1E1E),
          items: items,
          onChanged: (key) {
            if (key == null || key.isEmpty) {
              rp.assignRadioToChannel(radio.id, null, null);
            } else {
              final parts = key.split(':');
              rp.assignRadioToChannel(
                  radio.id, parts[0], int.parse(parts[1]));
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool txActive, RadioRxState rxState,
      String? channelName, DisProvider disProvider) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                radio.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                  letterSpacing: 2,
                ),
              ),
              if (channelName != null)
                Text(
                  channelName,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.amber,
                  ),
                ),
            ],
          ),
        ),
        _ModBadge(radio.modulationType),
        const SizedBox(width: 8),
        RxTxIndicator(rxActive: rxState.rxActive, txActive: txActive),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.settings, size: 16),
          color: AppColors.textMuted,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onConfigure,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 16),
          color: Colors.red.shade400,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _confirmDelete(context),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Radio'),
        content: Text('Delete "${radio.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final rp = context.read<RadioProvider>();
      final dis = context.read<DisProvider>();
      rp.removeRadio(radio.id);
      dis.updateRadios(rp.radios.toList(), rp.intercoms.toList());
    }
  }

  Widget _buildPttRow(BuildContext context, bool txActive, RadioRxState rxState,
      DisProvider disProvider) {
    final mode = radio.triggerMode;

    Widget pttWidget;
    if (mode == TriggerMode.ptt) {
      pttWidget = PttButton(
        active: txActive,
        onPressed: () => disProvider.startTransmit(radio.id),
        onReleased: () => disProvider.stopTransmit(radio.id),
      );
    } else if (mode == TriggerMode.latchedPtt) {
      pttWidget = PttButton(
        active: txActive,
        onPressed: () {
          if (txActive) {
            disProvider.stopTransmit(radio.id);
          } else {
            disProvider.startTransmit(radio.id);
          }
        },
        onReleased: () {}, // no-op — toggle happens on press
      );
    } else {
      // VOX — show auto indicator
      pttWidget = _AutoTxIndicator(txActive: txActive, mode: mode);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        pttWidget,
        const SizedBox(width: 12),
        // Level meter: always visible in VOX mode (with threshold line),
        // only visible when txActive in PTT/LTCH modes.
        if (mode == TriggerMode.vox)
          LevelMeter(
            levelStream: AudioManager.instance.inputLevel(radio.id),
            height: 72,
            threshold: radio.voxThreshold,
          )
        else if (txActive)
          LevelMeter(
            levelStream: AudioManager.instance.inputLevel(radio.id),
            height: 72,
          ),
        const Spacer(),
        if (rxState.rxActive)
          Column(
            children: [
              const Icon(Icons.signal_cellular_alt,
                  color: AppColors.rxGreen, size: 20),
              Text(
                '${rxState.signalDbm.toStringAsFixed(0)} dBm',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.rxGreen,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, RadioProvider radioProvider,
      SettingsProvider settingsProvider, DisProvider dis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volume_up, size: 12, color: AppColors.textMuted),
            Expanded(
              child: _CompactSlider(
                value: radio.outputVolume,
                label: 'VOL',
                onChanged: (v) =>
                    radioProvider.updateRadio(radio.copyWith(outputVolume: v)),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.graphic_eq, size: 12, color: AppColors.textMuted),
            Expanded(
              child: _CompactSlider(
                value: radio.squelch,
                label: 'SQL',
                onChanged: (v) =>
                    radioProvider.updateRadio(radio.copyWith(squelch: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.swap_horiz, size: 12, color: AppColors.textMuted),
            Expanded(
              child: _PanSlider(
                value: radio.outputPan,
                onChanged: (v) =>
                    radioProvider.updateRadio(radio.copyWith(outputPan: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TriggerModeSelector(
          mode: radio.triggerMode,
          voxThreshold: radio.voxThreshold,
          onChanged: (mode) {
            final updated = radio.copyWith(triggerMode: mode);
            radioProvider.updateRadio(updated);
            dis.updateRadios(
              radioProvider.radios.toList(),
              radioProvider.intercoms.toList(),
            );
          },
          onVoxThresholdChanged: (v) =>
              radioProvider.updateRadio(radio.copyWith(voxThreshold: v)),
        ),
        if (radio.triggerMode == TriggerMode.ptt ||
            radio.triggerMode == TriggerMode.latchedPtt) ...[
          const SizedBox(height: 6),
          _buildKeyBindingsRow(context, radioProvider, settingsProvider),
        ],
      ],
    );
  }

  Widget _buildKeyBindingsRow(BuildContext context, RadioProvider radioProvider,
      SettingsProvider settingsProvider) {
    final allBindings = settingsProvider.settings.keyBindings;
    final assigned = allBindings
        .where((b) => radio.pttBindingIds.contains(b.id))
        .toList();

    return Row(
      children: [
        const Icon(Icons.keyboard_outlined, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: assigned.isEmpty
              ? const Text(
                  'No keys assigned',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: assigned
                      .map((b) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              border:
                                  Border.all(color: const Color(0xFF333333)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              b.fullKeyLabel,
                              style: const TextStyle(
                                fontFamily: 'Courier New',
                                fontSize: 10,
                                color: AppColors.amber,
                              ),
                            ),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 24,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              side: const BorderSide(color: Color(0xFF333333)),
              foregroundColor: AppColors.textMuted,
            ),
            onPressed: () async {
              final result = await showPttBindingPicker(
                context: context,
                currentBindingIds: radio.pttBindingIds,
                settingsProvider: settingsProvider,
              );
              if (result != null) {
                radioProvider
                    .updateRadio(radio.copyWith(pttBindingIds: result));
              }
            },
            child: const Text('KEYS', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }
}

class _AutoTxIndicator extends StatelessWidget {
  final bool txActive;
  final TriggerMode mode;

  const _AutoTxIndicator({required this.txActive, required this.mode});

  @override
  Widget build(BuildContext context) {
    final Color activeColor;
    final IconData icon;
    final String label;

    if (mode == TriggerMode.latchedPtt) {
      activeColor = AppColors.amber;
      icon = Icons.radio_button_checked;
      label = 'LTCH';
    } else {
      activeColor = AppColors.primaryGreen;
      icon = Icons.mic;
      label = 'VOX';
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: txActive ? activeColor.withOpacity(0.15) : const Color(0xFF1A1A1A),
        border: Border.all(
          color: txActive ? activeColor : const Color(0xFF444444),
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: txActive ? activeColor : AppColors.textMuted, size: 26),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: txActive ? activeColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModBadge extends StatelessWidget {
  final RadioModulationType mod;
  const _ModBadge(this.mod);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        border: Border.all(color: AppColors.primaryGreen, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        mod.displayName,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${(value * 100).round()}%',
          style: const TextStyle(
            fontSize: 8,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(
          height: 20,
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0,
            max: 1,
          ),
        ),
      ],
    );
  }
}

class _PanSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PanSlider({required this.value, required this.onChanged});

  String get _label {
    if (value.abs() < 0.01) return 'PAN C';
    if (value < 0) return 'PAN L${(-value * 100).round()}';
    return 'PAN R${(value * 100).round()}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label,
          style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
        ),
        SizedBox(
          height: 20,
          child: Slider(
            value: value,
            min: -1,
            max: 1,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
