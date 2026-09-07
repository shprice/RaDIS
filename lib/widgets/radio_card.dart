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
    final muted = disProvider.isRadioMuted(radio.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, txActive, rxState, disProvider),
            const SizedBox(height: 8),
            FrequencyDisplay(
              frequency: radio.frequency,
              onChanged: (hz) => radioProvider.updateRadioFrequency(radio.id, hz),
            ),
            const SizedBox(height: 6),
            _buildNetDropdown(context, radioProvider),
            const SizedBox(height: 8),
            _buildPttRow(context, txActive, rxState, disProvider, muted),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _buildControls(context, radioProvider, settingsProvider, disProvider, muted),
          ],
        ),
      ),
    );
  }

  Widget _buildNetDropdown(BuildContext context, RadioProvider rp) {
    final plans = rp.netPlans;
    final isManual = radio.netPlanId == null || radio.netChannelIndex == null;

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(
          'Manual',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ),
      ...plans.expand((plan) => plan.channels.asMap().entries.map((e) {
            final key = '${plan.id}:${e.key}';
            return DropdownMenuItem<String>(
              value: key,
              child: Text(
                e.value.name,
                style: const TextStyle(fontSize: 12, color: AppColors.amber),
                overflow: TextOverflow.ellipsis,
              ),
            );
          })),
    ];

    final currentKey =
        isManual ? '' : '${radio.netPlanId}:${radio.netChannelIndex}';

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        border: Border.all(
          color: isManual
              ? const Color(0xFF2E2E2E)
              : AppColors.amber.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.any((i) => i.value == currentKey) ? currentKey : '',
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: isManual ? AppColors.textMuted : AppColors.amber,
          ),
          style: TextStyle(
            fontSize: 12,
            color: isManual ? AppColors.textMuted : AppColors.amber,
          ),
          dropdownColor: const Color(0xFF0D1A0D),
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
      DisProvider disProvider) {
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
              Text(
                'ID: ${radio.radioNumber}',
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
      DisProvider disProvider, bool muted) {
    final mode = radio.triggerMode;
    final radioProvider = context.read<RadioProvider>();

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
        onReleased: () {},
      );
    } else {
      pttWidget = _AutoTxIndicator(txActive: txActive, mode: mode);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LabelledMeter(
          label: 'TX',
          labelColor: txActive ? AppColors.amber : AppColors.textMuted,
          levelStream: AudioManager.instance.inputLevel(radio.id),
          threshold: radio.voxThreshold,
          onThresholdChanged: (v) =>
              radioProvider.updateRadio(radio.copyWith(voxThreshold: v)),
        ),
        const SizedBox(width: 8),
        pttWidget,
        const SizedBox(width: 8),
        _LabelledMeter(
          label: 'RX',
          labelColor: muted
              ? Colors.red.shade400
              : (rxState.rxActive ? AppColors.rxGreen : AppColors.textMuted),
          levelStream: AudioManager.instance.rxLevel(radio.id),
          threshold: radio.squelch,
          onThresholdChanged: (v) =>
              radioProvider.updateRadio(radio.copyWith(squelch: v)),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildControls(BuildContext context, RadioProvider radioProvider,
      SettingsProvider settingsProvider, DisProvider dis, bool muted) {
    final isPtt = radio.triggerMode == TriggerMode.ptt ||
        radio.triggerMode == TriggerMode.latchedPtt;
    final allBindings = settingsProvider.settings.keyBindings;
    final assigned =
        allBindings.where((b) => radio.pttBindingIds.contains(b.id)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Audio output popup (volume + pan)
        _PopupControl(
          trigger: Tooltip(
            message: 'Volume / Pan',
            child: Icon(
              Icons.tune,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
          popupBuilder: (_) => _AudioOutputPopup(
            volume: radio.outputVolume,
            pan: radio.outputPan,
            onVolumeChanged: (v) =>
                radioProvider.updateRadio(radio.copyWith(outputVolume: v)),
            onPanChanged: (v) =>
                radioProvider.updateRadio(radio.copyWith(outputPan: v)),
          ),
        ),
        const SizedBox(width: 6),
        // Mute toggle
        GestureDetector(
          onTap: () => dis.toggleRadioMute(radio.id),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: muted ? 'Unmute' : 'Mute',
              child: Icon(
                muted ? Icons.volume_off : Icons.volume_up,
                size: 16,
                color: muted ? Colors.red.shade400 : AppColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const SizedBox(
          height: 16,
          child: VerticalDivider(width: 1, color: Color(0xFF333333)),
        ),
        const SizedBox(width: 10),
        // Trigger mode selector
        TriggerModeSelector(
          mode: radio.triggerMode,
          onChanged: (mode) {
            final updated = radio.copyWith(triggerMode: mode);
            radioProvider.updateRadio(updated);
            dis.updateRadios(
              radioProvider.radios.toList(),
              radioProvider.intercoms.toList(),
            );
          },
        ),
        // Keys pill — only in PTT/latched modes
        if (isPtt) ...[
          const SizedBox(width: 8),
          _KeysPill(
            radio: radio,
            assigned: assigned,
            radioProvider: radioProvider,
            settingsProvider: settingsProvider,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Popup control — shows an overlay anchored to the trigger widget
// ---------------------------------------------------------------------------

class _PopupControl extends StatefulWidget {
  final Widget trigger;
  final WidgetBuilder popupBuilder;

  const _PopupControl({required this.trigger, required this.popupBuilder});

  @override
  State<_PopupControl> createState() => _PopupControlState();
}

class _PopupControlState extends State<_PopupControl> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (ctx) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _controller.hide,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -4),
              child: Material(
                color: const Color(0xFF1A1A1A),
                elevation: 8,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF333333)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: widget.popupBuilder(ctx),
                ),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: _controller.toggle,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: widget.trigger,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio output popup content (volume + pan sliders)
// ---------------------------------------------------------------------------

class _AudioOutputPopup extends StatefulWidget {
  final double volume;
  final double pan;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onPanChanged;

  const _AudioOutputPopup({
    required this.volume,
    required this.pan,
    required this.onVolumeChanged,
    required this.onPanChanged,
  });

  @override
  State<_AudioOutputPopup> createState() => _AudioOutputPopupState();
}

class _AudioOutputPopupState extends State<_AudioOutputPopup> {
  late double _volume;
  late double _pan;

  @override
  void initState() {
    super.initState();
    _volume = widget.volume;
    _pan = widget.pan;
  }

  String get _panLabel {
    if (_pan.abs() < 0.01) return 'C';
    if (_pan < 0) return 'L${(-_pan * 100).round()}';
    return 'R${(_pan * 100).round()}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sliderRow(
            label: 'VOL ${(_volume * 100).round()}%',
            value: _volume,
            min: 0,
            max: 1,
            onChanged: (v) {
              setState(() => _volume = v);
              widget.onVolumeChanged(v);
            },
          ),
          _sliderRow(
            label: 'PAN $_panLabel',
            value: _pan,
            min: -1,
            max: 1,
            onChanged: (v) {
              setState(() => _pan = v);
              widget.onPanChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ),
        SizedBox(
          width: 120,
          height: 28,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Keys pill with tooltip showing bound key labels
// ---------------------------------------------------------------------------

class _KeysPill extends StatelessWidget {
  final RadioConfig radio;
  final List<dynamic> assigned;
  final RadioProvider radioProvider;
  final SettingsProvider settingsProvider;

  const _KeysPill({
    required this.radio,
    required this.assigned,
    required this.radioProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hasKeys = assigned.isNotEmpty;
    final tooltipText = hasKeys
        ? assigned.map((b) => b.fullKeyLabel).join('   ')
        : 'No keys assigned';

    return Tooltip(
      message: tooltipText,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(
        fontSize: 10,
        color: AppColors.amber,
        fontFamily: 'Courier New',
      ),
      preferBelow: false,
      child: SizedBox(
        height: 22,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            side: BorderSide(
              color: hasKeys
                  ? AppColors.amber.withValues(alpha: 0.5)
                  : const Color(0xFF333333),
            ),
            foregroundColor:
                hasKeys ? AppColors.amber : AppColors.textMuted,
          ),
          icon: const Icon(Icons.keyboard_outlined, size: 10),
          label: const Text('KEYS', style: TextStyle(fontSize: 10)),
          onPressed: () async {
            final result = await showPttBindingPicker(
              context: context,
              currentBindingIds: radio.pttBindingIds,
              settingsProvider: settingsProvider,
            );
            if (result != null) {
              radioProvider.updateRadio(radio.copyWith(pttBindingIds: result));
            }
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets (unchanged)
// ---------------------------------------------------------------------------

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
        color: txActive
            ? activeColor.withValues(alpha: 0.15)
            : const Color(0xFF1A1A1A),
        border: Border.all(
          color: txActive ? activeColor : const Color(0xFF444444),
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: txActive ? activeColor : AppColors.textMuted, size: 26),
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

class _LabelledMeter extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Stream<double> levelStream;
  final double? threshold;
  final ValueChanged<double>? onThresholdChanged;

  const _LabelledMeter({
    required this.label,
    required this.labelColor,
    required this.levelStream,
    this.threshold,
    this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LevelMeter(
          levelStream: levelStream,
          width: 12,
          height: 60,
          threshold: threshold,
          onThresholdChanged: onThresholdChanged,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 8, color: labelColor),
        ),
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
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
