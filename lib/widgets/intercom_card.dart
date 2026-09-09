import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dis/entity_id.dart';
import '../models/intercom_config.dart';
import '../models/trigger_mode.dart';
import '../providers/dis_provider.dart';
import '../providers/radio_provider.dart';
import '../providers/settings_provider.dart';
import '../audio/audio_manager.dart';
import '../theme.dart';
import 'level_meter.dart';
import 'ptt_button.dart';
import 'ptt_binding_picker.dart';
import 'rx_tx_indicator.dart';
import 'trigger_mode_selector.dart';
import '../screens/intercom_config_screen.dart';

class IntercomCard extends StatelessWidget {
  final IntercomConfig intercom;

  const IntercomCard({super.key, required this.intercom});

  @override
  Widget build(BuildContext context) {
    final dis = context.watch<DisProvider>();
    final rp = context.watch<RadioProvider>();
    final sp = context.watch<SettingsProvider>();

    final txActive = dis.isTxActive(intercom.id);
    final rxState = dis.rxStates[intercom.id] ?? const RadioRxState();
    final muted = dis.isIntercomMuted(intercom.id);
    final intercomSupported = dis.supportsIntercomFor(intercom.id);

    final isDuplicate = intercom.enabled &&
        rp.intercoms.any((other) =>
            other.id != intercom.id &&
            other.enabled &&
            other.entityId == intercom.entityId &&
            other.communicationsDeviceId == intercom.communicationsDeviceId &&
            other.sourceChannelId == intercom.sourceChannelId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!intercomSupported)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        size: 13, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'INTERCOM PDUs SUPPRESSED — DIS v4/v5',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            _buildHeader(context, txActive, rxState, dis, rp, isDuplicate),
            const SizedBox(height: 8),
            _buildPttRow(context, txActive, rxState, dis, rp, muted),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            _buildControls(context, dis, rp, sp, muted),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool txActive, RadioRxState rxState,
      DisProvider dis, RadioProvider rp, bool isDuplicate) {
    return Row(
      children: [
        Icon(Icons.headset_mic,
            color: AppColors.amber, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intercom.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amber,
                  letterSpacing: 2,
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  _IcIdPill(intercom: intercom, radioProvider: rp, isDuplicate: isDuplicate),
                  _IntercomEntityPill(intercom: intercom, disProvider: dis, isDuplicate: isDuplicate),
                  if (isDuplicate) const _DuplicateWarningChip(),
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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IntercomConfigScreen(intercom: intercom),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _confirmDelete(context, rp, dis),
        ),
      ],
    );
  }

  Widget _buildPttRow(BuildContext context, bool txActive, RadioRxState rxState,
      DisProvider dis, RadioProvider rp, bool muted) {
    final mode = intercom.triggerMode;

    Widget pttWidget;
    if (mode == TriggerMode.ptt) {
      pttWidget = PttButton(
        active: txActive,
        onPressed: () => dis.startIntercomTransmit(intercom.id),
        onReleased: () => dis.stopIntercomTransmit(intercom.id),
        activeIcon: Icons.headset_mic,
        idleIcon: Icons.headset_mic_outlined,
      );
    } else if (mode == TriggerMode.latchedPtt) {
      pttWidget = PttButton(
        active: txActive,
        onPressed: () {
          if (txActive) {
            dis.stopIntercomTransmit(intercom.id);
          } else {
            dis.startIntercomTransmit(intercom.id);
          }
        },
        onReleased: () {},
        activeIcon: Icons.headset_mic,
        idleIcon: Icons.headset_mic_outlined,
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
          levelStream: AudioManager.instance.inputLevel(intercom.id),
          threshold: intercom.voxThreshold,
          tooltipMessage:
              'VOX threshold: ${(intercom.voxThreshold * 100).round()}%\nDrag to adjust',
          onThresholdChanged: (v) =>
              rp.updateIntercom(intercom.copyWith(voxThreshold: v)),
        ),
        const SizedBox(width: 8),
        pttWidget,
        const SizedBox(width: 8),
        _LabelledMeter(
          label: 'RX',
          labelColor: muted
              ? Colors.red.shade400
              : (rxState.rxActive ? AppColors.rxGreen : AppColors.textMuted),
          levelStream: AudioManager.instance.rxLevel(intercom.id),
          mutedOverlay: muted,
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildControls(BuildContext context, DisProvider dis, RadioProvider rp,
      SettingsProvider sp, bool muted) {
    final isPtt = intercom.triggerMode == TriggerMode.ptt ||
        intercom.triggerMode == TriggerMode.latchedPtt;
    final allBindings = sp.settings.keyBindings;
    final assigned =
        allBindings.where((b) => intercom.pttBindingIds.contains(b.id)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Audio output popup (volume + pan)
        _PopupControl(
          trigger: Tooltip(
            message: 'Volume / Pan',
            child: Icon(Icons.tune, size: 16, color: AppColors.textMuted),
          ),
          popupBuilder: (_) => _AudioOutputPopup(
            volume: intercom.outputVolume,
            pan: intercom.outputPan,
            onVolumeChanged: (v) =>
                rp.updateIntercom(intercom.copyWith(outputVolume: v)),
            onPanChanged: (v) =>
                rp.updateIntercom(intercom.copyWith(outputPan: v)),
          ),
        ),
        const SizedBox(width: 6),
        _PulsingMuteButton(
          muted: muted,
          onToggle: () => dis.toggleIntercomMute(intercom.id),
        ),
        const SizedBox(width: 10),
        const SizedBox(
          height: 16,
          child: VerticalDivider(width: 1, color: Color(0xFF333333)),
        ),
        const SizedBox(width: 10),
        // Trigger mode selector
        TriggerModeSelector(
          mode: intercom.triggerMode,
          onChanged: (mode) {
            final updated = intercom.copyWith(triggerMode: mode);
            rp.updateIntercom(updated);
            dis.updateRadios(rp.radios.toList(), rp.intercoms.toList());
          },
        ),
        // Keys pill — only in PTT/latched modes
        if (isPtt) ...[
          const SizedBox(width: 8),
          _KeysPill(
            intercom: intercom,
            assigned: assigned,
            radioProvider: rp,
            settingsProvider: sp,
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, RadioProvider rp, DisProvider dis) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Intercom'),
        content: Text('Delete "${intercom.name}"?'),
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
      rp.removeIntercom(intercom.id);
      dis.updateRadios(rp.radios.toList(), rp.intercoms.toList());
    }
  }
}

// ---------------------------------------------------------------------------
// IC ID / Station green pill
// ---------------------------------------------------------------------------

class _IcIdPill extends StatelessWidget {
  final IntercomConfig intercom;
  final RadioProvider radioProvider;
  final bool isDuplicate;

  const _IcIdPill({required this.intercom, required this.radioProvider, required this.isDuplicate});

  @override
  Widget build(BuildContext context) {
    final borderColor = isDuplicate
        ? Colors.orange.withValues(alpha: 0.8)
        : AppColors.primaryGreen.withValues(alpha: 0.5);
    final bgColor = isDuplicate ? const Color(0xFF1A0A00) : const Color(0xFF0A1A0A);
    final textColor = isDuplicate ? Colors.orange : AppColors.primaryGreen;

    return Tooltip(
      message: 'IC ID / Source Channel — click to edit',
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _openDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'IC ID:${intercom.communicationsDeviceId} CH:${intercom.sourceChannelId}',
              style: TextStyle(
                fontSize: 9,
                color: textColor,
                letterSpacing: 0.5,
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
      builder: (_) => _IcIdDialog(
        deviceId: intercom.communicationsDeviceId,
        sourceChannelId: intercom.sourceChannelId,
      ),
    );
    if (result != null && context.mounted) {
      radioProvider.updateIntercom(
        intercom.copyWith(
          communicationsDeviceId: result.$1,
          sourceChannelId: result.$2,
        ),
      );
    }
  }
}

class _IcIdDialog extends StatefulWidget {
  final int deviceId;
  final int sourceChannelId;

  const _IcIdDialog({required this.deviceId, required this.sourceChannelId});

  @override
  State<_IcIdDialog> createState() => _IcIdDialogState();
}

class _IcIdDialogState extends State<_IcIdDialog> {
  late final TextEditingController _deviceCtrl;
  late final TextEditingController _channelCtrl;

  @override
  void initState() {
    super.initState();
    _deviceCtrl = TextEditingController(text: widget.deviceId.toString());
    _channelCtrl = TextEditingController(text: widget.sourceChannelId.toString());
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      title: const Text(
        'INTERCOM ID',
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
            controller: _deviceCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Comms Device ID',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _channelCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Source Channel ID',
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
            final id = int.tryParse(_deviceCtrl.text);
            final ch = int.tryParse(_channelCtrl.text);
            if (id != null && ch != null) {
              Navigator.pop(context, (id, ch));
            }
          },
          child: const Text('APPLY',
              style: TextStyle(color: AppColors.primaryGreen)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Intercom entity ID pill (amber, like radio card)
// ---------------------------------------------------------------------------

class _IntercomEntityPill extends StatelessWidget {
  final IntercomConfig intercom;
  final DisProvider disProvider;
  final bool isDuplicate;

  const _IntercomEntityPill(
      {required this.intercom, required this.disProvider, required this.isDuplicate});

  bool get _isSet =>
      intercom.entityId.siteId != 0 ||
      intercom.entityId.applicationId != 0 ||
      intercom.entityId.entityNumber != 0;

  String get _label => _isSet
      ? '${intercom.entityId.siteId}:${intercom.entityId.applicationId}:${intercom.entityId.entityNumber}'
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
              color: isDuplicate ? const Color(0xFF1A0A00) : const Color(0xFF0A0A1A),
              border: Border.all(
                color: isDuplicate
                    ? Colors.orange.withValues(alpha: 0.8)
                    : (_isSet
                        ? AppColors.amber.withValues(alpha: 0.5)
                        : const Color(0xFF333333)),
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 9,
                color: isDuplicate
                    ? Colors.orange
                    : (_isSet ? AppColors.amber : AppColors.textMuted),
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
        current: _isSet ? intercom.entityId : null,
        seenEntities: disProvider.seenEntities,
      ),
    );
    if (result != null && context.mounted) {
      context
          .read<RadioProvider>()
          .updateIntercom(intercom.copyWith(entityId: result));
    }
  }
}

// ---------------------------------------------------------------------------
// Duplicate warning chip
// ---------------------------------------------------------------------------

class _DuplicateWarningChip extends StatelessWidget {
  const _DuplicateWarningChip();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Two or more intercoms share the same Entity ID, Intercom ID,\n'
          'and Source Channel ID. Only one will properly send/receive.',
      preferBelow: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          '⚠ DUPLICATE ID',
          style: TextStyle(
            fontSize: 9,
            color: Colors.orange,
            letterSpacing: 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                  color:
                      widget.muted ? Colors.red.shade400 : AppColors.textMuted,
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
// Auto TX indicator (VOX / latched mode)
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

// ---------------------------------------------------------------------------
// Labelled level meter
// ---------------------------------------------------------------------------

class _LabelledMeter extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Stream<double> levelStream;
  final double? threshold;
  final ValueChanged<double>? onThresholdChanged;
  final String? tooltipMessage;
  final bool mutedOverlay;

  const _LabelledMeter({
    required this.label,
    required this.labelColor,
    required this.levelStream,
    this.threshold,
    this.onThresholdChanged,
    this.tooltipMessage,
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
        textStyle:
            const TextStyle(fontSize: 10, color: AppColors.textMuted),
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

// ---------------------------------------------------------------------------
// Popup control (overlay anchored to trigger)
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
// Audio output popup (volume + pan sliders)
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
          child: Text(label,
              style:
                  const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ),
        SizedBox(
          width: 120,
          height: 28,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
                value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Keys pill
// ---------------------------------------------------------------------------

class _KeysPill extends StatelessWidget {
  final IntercomConfig intercom;
  final List<dynamic> assigned;
  final RadioProvider radioProvider;
  final SettingsProvider settingsProvider;

  const _KeysPill({
    required this.intercom,
    required this.assigned,
    required this.radioProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hasKeys = assigned.isNotEmpty;
    final tooltipText =
        hasKeys ? assigned.map((b) => b.fullKeyLabel).join('   ') : 'No keys assigned';

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
            foregroundColor: hasKeys ? AppColors.amber : AppColors.textMuted,
          ),
          icon: const Icon(Icons.keyboard_outlined, size: 10),
          label: const Text('KEYS', style: TextStyle(fontSize: 10)),
          onPressed: () async {
            final result = await showPttBindingPicker(
              context: context,
              currentBindingIds: intercom.pttBindingIds,
              settingsProvider: settingsProvider,
            );
            if (result != null) {
              radioProvider
                  .updateIntercom(intercom.copyWith(pttBindingIds: result));
            }
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entity picker dialog (same as radio_card but for intercom)
// ---------------------------------------------------------------------------

class _EntityPickerDialog extends StatefulWidget {
  final EntityId? current;
  final List<SeenEntity> seenEntities;

  const _EntityPickerDialog(
      {required this.current, required this.seenEntities});

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
              style: TextStyle(
                  fontSize: 9, color: AppColors.textMuted, letterSpacing: 1),
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
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 4),
                        child: Row(
                          children: [
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
                              const Icon(Icons.check,
                                  size: 12, color: AppColors.amber)
                            else
                              const SizedBox(width: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                e.displayLabel.isNotEmpty
                                    ? e.displayLabel
                                    : '(unknown)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? AppColors.amber
                                      : affColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
                      _showManual
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Enter manually',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
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
        Text(label,
            style:
                const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }
}

Color _affiliationColor(int forceId) {
  switch (forceId) {
    case 1:
    case 4:
      return const Color(0xFF42A5F5);
    case 2:
    case 5:
      return const Color(0xFFEF5350);
    case 3:
    case 6:
      return const Color(0xFF66BB6A);
    default:
      return const Color(0xFFFFB300);
  }
}
