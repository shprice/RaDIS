import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dis/entity_id.dart';
import '../models/net_plan.dart';
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
            _buildFrequencySection(context, radioProvider),
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

  NetChannel? _currentChannel(RadioProvider rp) =>
      rp.getRadioChannel(radio.radioChannelId);

  Widget _buildNetDropdown(BuildContext context, RadioProvider rp) {
    final channels = rp.radioChannels;
    final currentCh = _currentChannel(rp);
    final isManual = currentCh == null;
    final activeColor = _channelDisplayColor(currentCh?.color);

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(
          'Manual',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
        ),
      ),
      ...channels.map((ch) => DropdownMenuItem<String>(
            value: ch.id,
            child: Text(
              ch.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _channelDisplayColor(ch.color)),
              overflow: TextOverflow.ellipsis,
            ),
          )),
    ];

    final currentKey = radio.radioChannelId ?? '';

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        border: Border.all(
          color: isManual
              ? const Color(0xFF2E2E2E)
              : activeColor.withValues(alpha: 0.45),
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
            color: isManual ? AppColors.textMuted : activeColor,
          ),
          style: TextStyle(
            fontSize: 12,
            color: isManual ? AppColors.textMuted : activeColor,
          ),
          dropdownColor: const Color(0xFF0D1A0D),
          items: items,
          onChanged: (key) {
            rp.assignRadioChannel(radio.id, key?.isEmpty == true ? null : key);
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool txActive, RadioRxState rxState,
      DisProvider disProvider) {
    final rp = context.read<RadioProvider>();
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
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  _RadioIdPill(radio: radio, radioProvider: rp),
                  _EntityPill(radio: radio, disProvider: disProvider),
                ],
              ),
            ],
          ),
        ),
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
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LabelledMeter(
          label: 'TX',
          labelColor: txActive ? AppColors.amber : AppColors.textMuted,
          levelStream: AudioManager.instance.inputLevel(radio.id),
          threshold: radio.voxThreshold,
          tooltipMessage: 'VOX threshold: ${(radio.voxThreshold * 100).round()}%\nDrag to adjust',
          onThresholdChanged: (v) =>
              radioProvider.updateRadio(radio.copyWith(voxThreshold: v)),
        ),
        const SizedBox(width: 16),
        pttWidget,
        const SizedBox(width: 16),
        _LabelledMeter(
          label: 'RX',
          labelColor: muted
              ? Colors.red.shade400
              : (rxState.rxActive ? AppColors.rxGreen : AppColors.textMuted),
          levelStream: AudioManager.instance.rxLevel(radio.id),
          threshold: radio.squelch,
          tooltipMessage: 'Squelch: ${(radio.squelch * 100).round()}%\nDrag to adjust',
          mutedOverlay: muted,
          onThresholdChanged: (v) =>
              radioProvider.updateRadio(radio.copyWith(squelch: v)),
        ),
      ],
    );
  }

  Widget _buildFrequencySection(BuildContext context, RadioProvider rp) {
    if (!radio.splitEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FittedBox lets the row scale down slightly if pills + display > card width
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FrequencyDisplay(
                  frequency: radio.frequency,
                  onChanged: (hz) => rp.updateRadioFrequency(radio.id, hz),
                ),
                const SizedBox(width: 8),
                _buildPillsColumn(rp),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildNetDropdown(context, rp),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RX',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppColors.rxGreen.withValues(alpha: 0.7),
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  FrequencyDisplay(
                    frequency: radio.frequency,
                    compact: true,
                    onChanged: (hz) => rp.updateRadioFrequency(radio.id, hz),
                  ),
                  const SizedBox(height: 4),
                  _buildNetDropdown(context, rp),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TX',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppColors.primaryGreen.withValues(alpha: 0.7),
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  FrequencyDisplay(
                    frequency: radio.txFrequency,
                    compact: true,
                    onChanged: (hz) => rp.updateRadioTxFrequency(radio.id, hz),
                  ),
                  const SizedBox(height: 4),
                  _buildTxNetDropdown(context, rp),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildPillsRow(rp),
        _buildRepeaterRow(rp),
      ],
    );
  }

  // Vertical pill stack for non-split mode (right of freq display)
  Widget _buildPillsColumn(RadioProvider rp) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModPill(radio: radio, radioProvider: rp),
          const SizedBox(height: 3),
          _PowerPill(radio: radio, radioProvider: rp),
          const SizedBox(height: 3),
          _BandwidthPill(radio: radio, radioProvider: rp),
          const SizedBox(height: 3),
          _CryptoPill(radio: radio, radioProvider: rp),
        ],
      ),
    );
  }

  // Horizontal pills for split mode (below compact freq displays)
  Widget _buildPillsRow(RadioProvider rp) {
    return FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModPill(radio: radio, radioProvider: rp),
          const SizedBox(width: 4),
          _PowerPill(radio: radio, radioProvider: rp),
          const SizedBox(width: 4),
          _BandwidthPill(radio: radio, radioProvider: rp),
          const SizedBox(width: 4),
          _CryptoPill(radio: radio, radioProvider: rp),
        ],
      ),
    );
  }

  Widget _buildRepeaterRow(RadioProvider rp) {
    if (!radio.splitEnabled) return const SizedBox.shrink();
    final freqsDiffer = (radio.txFrequency - radio.frequency).abs() > 1.0;
    if (!freqsDiffer) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _MiniToggleButton(
        label: 'REPEAT',
        active: radio.repeaterActive,
        activeColor: const Color(0xFF42A5F5),
        tooltip: radio.repeaterActive
            ? 'Disable repeater mode'
            : 'Repeater: re-transmit RX audio on TX frequency',
        onTap: () => rp.updateRadio(
            radio.copyWith(repeaterEnabled: !radio.repeaterActive)),
      ),
    );
  }

  Widget _buildTxNetDropdown(BuildContext context, RadioProvider rp) {
    final channels = rp.radioChannels;
    final currentCh = rp.getRadioChannel(radio.txRadioChannelId);
    final isManual = currentCh == null;
    final activeColor = _channelDisplayColor(currentCh?.color);

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text('Manual',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
      ),
      ...channels.map((ch) => DropdownMenuItem<String>(
            value: ch.id,
            child: Text(ch.name,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _channelDisplayColor(ch.color)),
                overflow: TextOverflow.ellipsis),
          )),
    ];

    final currentKey = radio.txRadioChannelId ?? '';

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        border: Border.all(
          color: isManual
              ? const Color(0xFF2E2E2E)
              : activeColor.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.any((i) => i.value == currentKey) ? currentKey : '',
          isDense: true,
          icon: Icon(Icons.arrow_drop_down,
              size: 16,
              color: isManual ? AppColors.textMuted : activeColor),
          style: TextStyle(
              fontSize: 12,
              color: isManual ? AppColors.textMuted : activeColor),
          dropdownColor: const Color(0xFF0D1A0D),
          items: items,
          onChanged: (key) {
            rp.assignRadioTxChannel(radio.id, key?.isEmpty == true ? null : key);
          },
        ),
      ),
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
        _PulsingMuteButton(
          muted: muted,
          onToggle: () => dis.toggleRadioMute(radio.id),
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
// Pulsing mute button
// ---------------------------------------------------------------------------

class _PulsingMuteButton extends StatefulWidget {
  final bool muted;
  final VoidCallback onToggle;

  const _PulsingMuteButton({required this.muted, required this.onToggle});

  @override
  State<_PulsingMuteButton> createState() => _PulsingMuteButtonState();
}

class _PulsingMuteButtonState extends State<_PulsingMuteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.muted) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingMuteButton old) {
    super.didUpdateWidget(old);
    if (widget.muted != old.muted) {
      if (widget.muted) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.muted ? 'Unmute' : 'Mute',
      preferBelow: false,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: widget.muted
                      ? [
                          BoxShadow(
                            color: Colors.red
                                .withOpacity(_animation.value * 0.8),
                            blurRadius: 8 * _animation.value,
                            spreadRadius: 2 * _animation.value,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.muted ? Icons.volume_off : Icons.volume_up,
                  size: 16,
                  color: widget.muted
                      ? Colors.red.shade400
                      : AppColors.textMuted,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radio parameter pills (power, bandwidth, crypto)
// ---------------------------------------------------------------------------

class _PowerPill extends StatelessWidget {
  final RadioConfig radio;
  final RadioProvider radioProvider;

  const _PowerPill({required this.radio, required this.radioProvider});

  String get _label {
    if (radio.powerWatts <= 0) return '– dBm';
    final dbm = 10 * math.log(radio.powerWatts * 1000) / math.ln10;
    return '${dbm.toStringAsFixed(1)} dBm';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Power — click to edit',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A0A),
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _PowerDialog(watts: radio.powerWatts),
    );
    if (result != null && context.mounted) {
      radioProvider.updateRadio(radio.copyWith(powerWatts: result));
    }
  }
}

class _PowerDialog extends StatefulWidget {
  final double watts;
  const _PowerDialog({required this.watts});

  @override
  State<_PowerDialog> createState() => _PowerDialogState();
}

class _PowerDialogState extends State<_PowerDialog> {
  late final TextEditingController _dbmCtrl;
  late final TextEditingController _wCtrl;

  static double _wToDbm(double w) =>
      w > 0 ? 10 * math.log(w * 1000) / math.ln10 : -100;
  static double _dbmToW(double dbm) =>
      math.pow(10, dbm / 10).toDouble() / 1000;

  @override
  void initState() {
    super.initState();
    _dbmCtrl =
        TextEditingController(text: _wToDbm(widget.watts).toStringAsFixed(1));
    _wCtrl = TextEditingController(text: widget.watts.toStringAsFixed(3));
  }

  @override
  void dispose() {
    _dbmCtrl.dispose();
    _wCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      title: const Text(
        'POWER',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _dbmCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'dBm',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(signed: true, decimal: true),
            onChanged: (v) {
              final dbm = double.tryParse(v);
              if (dbm != null) {
                _wCtrl.text = _dbmToW(dbm).toStringAsFixed(3);
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Watts',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(signed: false, decimal: true),
            onChanged: (v) {
              final w = double.tryParse(v);
              if (w != null && w >= 0) {
                _dbmCtrl.text = _wToDbm(w).toStringAsFixed(1);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        TextButton(
          onPressed: () {
            final w = double.tryParse(_wCtrl.text);
            if (w != null && w >= 0) Navigator.pop(context, w);
          },
          child: const Text('APPLY',
              style: TextStyle(color: AppColors.primaryGreen)),
        ),
      ],
    );
  }
}

class _BandwidthPill extends StatelessWidget {
  final RadioConfig radio;
  final RadioProvider radioProvider;

  const _BandwidthPill({required this.radio, required this.radioProvider});

  String get _label {
    final bw = radio.bandwidth;
    if (bw >= 1000) return '${(bw / 1000).toStringAsFixed(1)} kHz';
    return '${bw.toStringAsFixed(0)} Hz';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Bandwidth — click to edit',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A0A),
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _BandwidthDialog(bandwidth: radio.bandwidth),
    );
    if (result != null && context.mounted) {
      radioProvider.updateRadio(radio.copyWith(bandwidth: result));
    }
  }
}

class _BandwidthDialog extends StatefulWidget {
  final double bandwidth;
  const _BandwidthDialog({required this.bandwidth});

  @override
  State<_BandwidthDialog> createState() => _BandwidthDialogState();
}

class _BandwidthDialogState extends State<_BandwidthDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.bandwidth.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      title: const Text(
        'BANDWIDTH',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Bandwidth (Hz)',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        TextButton(
          onPressed: () {
            final bw = double.tryParse(_ctrl.text);
            if (bw != null && bw > 0) Navigator.pop(context, bw);
          },
          child: const Text('APPLY',
              style: TextStyle(color: AppColors.primaryGreen)),
        ),
      ],
    );
  }
}

class _CryptoPill extends StatelessWidget {
  final RadioConfig radio;
  final RadioProvider radioProvider;

  const _CryptoPill({required this.radio, required this.radioProvider});

  static String _cryptoName(int sys) {
    switch (sys) {
      case 1: return 'KY-28';
      case 2: return 'KY-57';
      case 3: return 'KY-58';
      case 4: return 'VINSON';
      case 5: return 'ANDVT';
      default: return 'NONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _cryptoName(radio.cryptoSystem);
    return Tooltip(
      message: 'Crypto system — click to edit',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A0A),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (_) =>
          _CryptoDialog(cryptoSystem: radio.cryptoSystem, cryptoKeyId: radio.cryptoKeyId),
    );
    if (result != null && context.mounted) {
      radioProvider.updateRadio(
          radio.copyWith(cryptoSystem: result.$1, cryptoKeyId: result.$2));
    }
  }
}

class _CryptoDialog extends StatefulWidget {
  final int cryptoSystem;
  final int cryptoKeyId;
  const _CryptoDialog({required this.cryptoSystem, required this.cryptoKeyId});

  @override
  State<_CryptoDialog> createState() => _CryptoDialogState();
}

class _CryptoDialogState extends State<_CryptoDialog> {
  late int _system;
  late final TextEditingController _keyCtrl;

  @override
  void initState() {
    super.initState();
    _system = widget.cryptoSystem;
    _keyCtrl = TextEditingController(text: widget.cryptoKeyId.toString());
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      title: const Text(
        'CRYPTO',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _system,
            dropdownColor: const Color(0xFF1A1A1A),
            decoration: const InputDecoration(
              labelText: 'Crypto System',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            items: const [
              DropdownMenuItem(value: 0, child: Text('NONE')),
              DropdownMenuItem(value: 1, child: Text('KY-28')),
              DropdownMenuItem(value: 2, child: Text('KY-57')),
              DropdownMenuItem(value: 3, child: Text('KY-58')),
              DropdownMenuItem(value: 4, child: Text('VINSON')),
              DropdownMenuItem(value: 5, child: Text('ANDVT')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _system = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Crypto Key ID',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        TextButton(
          onPressed: () {
            final keyId = int.tryParse(_keyCtrl.text) ?? 0;
            Navigator.pop(context, (_system, keyId));
          },
          child: const Text('APPLY',
              style: TextStyle(color: AppColors.primaryGreen)),
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
  final String? tooltipMessage;
  final Color? barColorOverride;
  final bool mutedOverlay;

  const _LabelledMeter({
    required this.label,
    required this.labelColor,
    required this.levelStream,
    this.threshold,
    this.onThresholdChanged,
    this.tooltipMessage,
    this.barColorOverride,
    this.mutedOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget meter = LevelMeter(
      levelStream: levelStream,
      width: 12,
      height: 60,
      threshold: threshold,
      onThresholdChanged: onThresholdChanged,
      barColorOverride: barColorOverride,
      mutedOverlay: mutedOverlay,
    );

    if (tooltipMessage != null) {
      meter = Tooltip(
        message: tooltipMessage!,
        preferBelow: false,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF444444)),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        child: meter,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        meter,
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 8, color: labelColor)),
      ],
    );
  }
}

class _MiniToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color? activeColor;
  final String? tooltip;
  final VoidCallback onTap;

  const _MiniToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.amber;
    Widget btn = GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : const Color(0xFF1A1A1A),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.7) : const Color(0xFF333333),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? color : AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, preferBelow: false, child: btn);
    }
    return btn;
  }
}

// ---------------------------------------------------------------------------
// Host Entity pill + picker dialog
// ---------------------------------------------------------------------------

class _EntityPill extends StatelessWidget {
  final RadioConfig radio;
  final DisProvider disProvider;

  const _EntityPill({required this.radio, required this.disProvider});

  bool get _isSet =>
      radio.entityId.siteId != 0 ||
      radio.entityId.applicationId != 0 ||
      radio.entityId.entityNumber != 0;

  String get _label => _isSet
      ? '${radio.entityId.siteId}:${radio.entityId.applicationId}:${radio.entityId.entityNumber}'
      : 'None';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Host Entity ID — click to assign',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openPicker(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A1A),
              border: Border.all(
                color: _isSet
                    ? AppColors.amber.withValues(alpha: 0.5)
                    : const Color(0xFF333333),
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 9,
                color: _isSet ? AppColors.amber : AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<EntityId>(
      context: context,
      builder: (_) => _EntityPickerDialog(
        current: _isSet ? radio.entityId : null,
        seenEntities: disProvider.seenEntities,
      ),
    );
    if (result != null && context.mounted) {
      context.read<RadioProvider>().updateRadio(radio.copyWith(entityId: result));
    }
  }
}

class _EntityPickerDialog extends StatefulWidget {
  final EntityId? current;
  final List<SeenEntity> seenEntities;

  const _EntityPickerDialog({required this.current, required this.seenEntities});

  @override
  State<_EntityPickerDialog> createState() => _EntityPickerDialogState();
}

class _EntityPickerDialogState extends State<_EntityPickerDialog> {
  bool _showManual = false;
  final _siteCtrl = TextEditingController();
  final _appCtrl = TextEditingController();
  final _entityCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.current != null) {
      _siteCtrl.text = widget.current!.siteId.toString();
      _appCtrl.text = widget.current!.applicationId.toString();
      _entityCtrl.text = widget.current!.entityNumber.toString();
    }
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    _appCtrl.dispose();
    _entityCtrl.dispose();
    super.dispose();
  }

  EntityId? get _parsedManual {
    final site = int.tryParse(_siteCtrl.text);
    final app = int.tryParse(_appCtrl.text);
    final entity = int.tryParse(_entityCtrl.text);
    if (site == null || app == null || entity == null) return null;
    return EntityId(siteId: site, applicationId: app, entityNumber: entity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      title: const Text(
        'HOST ENTITY',
        style: TextStyle(
          color: AppColors.amber,
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ACTIVE DIS ENTITIES',
              style: TextStyle(fontSize: 9, color: AppColors.textMuted, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _AffDot(color: Color(0xFF42A5F5), label: 'Friendly'),
                SizedBox(width: 10),
                _AffDot(color: Color(0xFFEF5350), label: 'Opposing'),
                SizedBox(width: 10),
                _AffDot(color: Color(0xFF66BB6A), label: 'Neutral'),
                SizedBox(width: 10),
                _AffDot(color: Color(0xFFFFB300), label: 'Unknown'),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.seenEntities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No entities detected on network',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.seenEntities.length,
                  itemBuilder: (_, i) {
                    final e = widget.seenEntities[i];
                    final isSelected = widget.current == e.id;
                    final affColor = _affiliationColor(e.forceId);
                    return InkWell(
                      onTap: () => Navigator.pop(context, e.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        child: Row(
                          children: [
                            // Affiliation dot
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: affColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isSelected)
                              const Icon(Icons.check, size: 12, color: AppColors.amber)
                            else
                              const SizedBox(width: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                e.displayLabel.isNotEmpty ? e.displayLabel : '(unknown)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? AppColors.amber : affColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            Text(
                              e.idLabel,
                              style: TextStyle(
                                fontSize: 10,
                                                color: affColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const Divider(color: Color(0xFF333333)),
            InkWell(
              onTap: () => setState(() => _showManual = !_showManual),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _showManual ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Enter manually',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (_showManual) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  _numField('Site', _siteCtrl),
                  const SizedBox(width: 6),
                  _numField('App', _appCtrl),
                  const SizedBox(width: 6),
                  _numField('Entity', _entityCtrl),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    final id = _parsedManual;
                    if (id != null) Navigator.pop(context, id);
                  },
                  child: const Text('APPLY MANUAL'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, EntityId.zero()),
          child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        ),
      ),
    );
  }
}

class _AffDot extends StatelessWidget {
  final Color color;
  final String label;
  const _AffDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }
}

// DIS Force ID → affiliation colour (IEEE 1278.1 Table B.6)
// 0=Other/Unknown, 1=Friendly, 2=Opposing, 3=Neutral, 4=Friendly2, 5=Opposing2, 6=Neutral2
Color _affiliationColor(int forceId) {
  switch (forceId) {
    case 1:
    case 4:
      return const Color(0xFF42A5F5); // blue — friendly
    case 2:
    case 5:
      return const Color(0xFFEF5350); // red — opposing
    case 3:
    case 6:
      return const Color(0xFF66BB6A); // green — neutral
    default:
      return const Color(0xFFFFB300); // amber — unknown / other
  }
}

Color _channelDisplayColor(String? colorName) {
  switch (colorName) {
    case 'red':
      return const Color(0xFFEF5350);
    case 'orange':
      return const Color(0xFFFF9800);
    case 'yellow':
      return const Color(0xFFFFEE58);
    case 'green':
      return const Color(0xFF66BB6A);
    case 'blue':
      return const Color(0xFF42A5F5);
    case 'purple':
      return const Color(0xFFAB47BC);
    case 'white':
      return const Color(0xFFEEEEEE);
    default:
      return AppColors.amber;
  }
}

// ---------------------------------------------------------------------------
// Radio ID pill (clickable)
// ---------------------------------------------------------------------------

class _RadioIdPill extends StatelessWidget {
  final RadioConfig radio;
  final RadioProvider radioProvider;

  const _RadioIdPill({required this.radio, required this.radioProvider});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Radio ID — click to edit',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A0A),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'RADIO ID:${radio.radioNumber}',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.primaryGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: radio.radioNumber.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'RADIO ID',
          style: TextStyle(
            color: AppColors.primaryGreen,
            fontSize: 13,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Radio Number',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n > 0) Navigator.pop(context, n);
            },
            child: const Text('APPLY',
                style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && context.mounted) {
      radioProvider.updateRadio(radio.copyWith(radioNumber: result));
    }
  }
}

// ---------------------------------------------------------------------------
// Modulation pill (clickable)
// ---------------------------------------------------------------------------

class _ModPill extends StatelessWidget {
  final RadioConfig radio;
  final RadioProvider radioProvider;

  const _ModPill({required this.radio, required this.radioProvider});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Modulation — click to edit',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A0A),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              radio.modulationType.displayName,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    RadioModulationType selected = radio.modulationType;
    final result = await showDialog<RadioModulationType>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0D0D0D),
          title: const Text(
            'MODULATION',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: RadioModulationType.values.map((m) {
              return RadioListTile<RadioModulationType>(
                value: m,
                groupValue: selected,
                activeColor: AppColors.primaryGreen,
                title: Text(
                  m.displayName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                      ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => selected = v);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('APPLY',
                  style: TextStyle(color: AppColors.primaryGreen)),
            ),
          ],
        ),
      ),
    );
    if (result != null && context.mounted) {
      radioProvider.updateRadio(radio.copyWith(modulationType: result));
    }
  }
}
