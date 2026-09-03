import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/radio_config.dart';
import '../providers/dis_provider.dart';
import '../providers/radio_provider.dart';
import '../audio/audio_manager.dart';
import '../theme.dart';
import 'frequency_display.dart';
import 'ptt_button.dart';
import 'rx_tx_indicator.dart';
import 'level_meter.dart';

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
            FrequencyDisplay(frequency: radio.frequency),
            const SizedBox(height: 2),
            const Text(
              'MHz',
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'Courier New',
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            _buildPttRow(context, txActive, rxState, disProvider),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _buildControls(context, radioProvider),
          ],
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
                  fontFamily: 'Courier New',
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
                    fontFamily: 'Courier New',
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
            child: const Text('DELETE',
                style: TextStyle(color: Colors.red)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PttButton(
          active: txActive,
          onPressed: () => disProvider.startTransmit(radio.id),
          onReleased: () => disProvider.stopTransmit(radio.id),
        ),
        const SizedBox(width: 12),
        if (txActive)
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
                  fontFamily: 'Courier New',
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, RadioProvider radioProvider) {
    return Row(
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
        if (radio.voxEnabled) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A1A),
              border: Border.all(color: AppColors.primaryGreen, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'VOX',
              style: TextStyle(
                  fontSize: 8,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Courier New'),
            ),
          ),
        ],
      ],
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
          fontFamily: 'Courier New',
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
            fontFamily: 'Courier New',
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
