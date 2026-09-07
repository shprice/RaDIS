import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../platform/global_hotkey_service.dart';
import '../models/app_key_binding.dart';
import '../models/intercom_config.dart';
import '../widgets/ptt_binding_picker.dart';
import '../models/trigger_mode.dart';
import '../providers/dis_provider.dart';
import '../providers/radio_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../audio/audio_manager.dart';
import '../widgets/level_meter.dart';
import '../widgets/ptt_button.dart';
import '../widgets/radio_card.dart';
import '../widgets/rx_tx_indicator.dart';
import '../widgets/trigger_mode_selector.dart';
import 'radio_config_screen.dart';
import 'intercom_config_screen.dart';
import 'net_plan_screen.dart';
import 'audio_devices_screen.dart';
import 'settings_screen.dart';

enum _NavDest { radios, netPlans, audio, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _NavDest _dest = _NavDest.radios;

  // Cached provider references for use in key handlers (no BuildContext needed).
  RadioProvider? _radioProvider;
  DisProvider? _disProvider;
  SettingsProvider? _settingsProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _radioProvider = context.read<RadioProvider>();
      _disProvider = context.read<DisProvider>();
      _settingsProvider = context.read<SettingsProvider>();
      _settingsProvider!.addListener(_onSettingsChanged);
      _startNetwork();
      HardwareKeyboard.instance.addHandler(_onInAppKey);
      _startGlobalHotkeys();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onInAppKey);
    _settingsProvider?.removeListener(_onSettingsChanged);
    GlobalHotkeyService.instance.stop();
    super.dispose();
  }

  void _onSettingsChanged() => _startGlobalHotkeys();

  Future<void> _startGlobalHotkeys() async {
    final sp = _settingsProvider;
    if (sp == null) return;
    final hidCodes = sp.settings.keyBindings
        .where((b) => b.enabled)
        .map((b) => b.physicalKeyCode)
        .toList();
    await GlobalHotkeyService.instance.start(hidCodes, _onGlobalHotkeyEvent);
  }

  void _onGlobalHotkeyEvent(int usbHid, bool isDown, int modifiers) {
    final sp = _settingsProvider;
    if (sp == null) return;
    final matchingIds = sp.settings.keyBindings
        .where((kb) =>
            kb.enabled &&
            kb.physicalKeyCode == usbHid &&
            kb.modifierFlags == modifiers)
        .map((kb) => kb.id)
        .toSet();
    for (final id in matchingIds) {
      if (isDown) _handleKeyDown(id);
      else _handleKeyUp(id);
    }
  }

  /// Bitmask of currently held modifier keys from HardwareKeyboard.
  int _currentModifiers() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    int mods = 0;
    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) mods |= 1;
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) mods |= 2;
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) mods |= 4;
    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight)) mods |= 8;
    return mods;
  }

  bool _isModifierKey(PhysicalKeyboardKey key) =>
      key == PhysicalKeyboardKey.controlLeft ||
      key == PhysicalKeyboardKey.controlRight ||
      key == PhysicalKeyboardKey.shiftLeft ||
      key == PhysicalKeyboardKey.shiftRight ||
      key == PhysicalKeyboardKey.altLeft ||
      key == PhysicalKeyboardKey.altRight ||
      key == PhysicalKeyboardKey.metaLeft ||
      key == PhysicalKeyboardKey.metaRight;

  /// In-app fallback: used only when the global hook is not active (e.g. Wayland).
  bool _onInAppKey(KeyEvent event) {
    if (GlobalHotkeyService.instance.isActive) return false;
    if (_isModifierKey(event.physicalKey)) return false;

    final sp = _settingsProvider;
    if (sp == null) return false;

    final usbHid = event.physicalKey.usbHidUsage;
    final modifiers = _currentModifiers();
    final matchingBindingIds = sp.settings.keyBindings
        .where((kb) =>
            kb.enabled &&
            kb.physicalKeyCode == usbHid &&
            kb.modifierFlags == modifiers)
        .map((kb) => kb.id)
        .toSet();
    if (matchingBindingIds.isEmpty) return false;

    for (final id in matchingBindingIds) {
      if (event is KeyDownEvent) _handleKeyDown(id);
      if (event is KeyUpEvent) _handleKeyUp(id);
    }
    return false;
  }

  void _handleKeyDown(String bindingId) {
    final rp = _radioProvider;
    final dis = _disProvider;
    if (rp == null || dis == null) return;

    for (final radio in rp.radios) {
      if (!radio.pttBindingIds.contains(bindingId)) continue;
      if (radio.triggerMode == TriggerMode.latchedPtt) {
        if (dis.isTxActive(radio.id)) {
          dis.stopTransmit(radio.id);
        } else {
          dis.startTransmit(radio.id);
        }
      } else if (radio.triggerMode == TriggerMode.ptt) {
        dis.startTransmit(radio.id);
      }
    }
    for (final intercom in rp.intercoms) {
      if (!intercom.pttBindingIds.contains(bindingId)) continue;
      if (intercom.triggerMode == TriggerMode.latchedPtt) {
        if (dis.isTxActive(intercom.id)) {
          dis.stopIntercomTransmit(intercom.id);
        } else {
          dis.startIntercomTransmit(intercom.id);
        }
      } else if (intercom.triggerMode == TriggerMode.ptt) {
        dis.startIntercomTransmit(intercom.id);
      }
    }
  }

  void _handleKeyUp(String bindingId) {
    final rp = _radioProvider;
    final dis = _disProvider;
    if (rp == null || dis == null) return;

    for (final radio in rp.radios) {
      if (radio.triggerMode == TriggerMode.ptt &&
          radio.pttBindingIds.contains(bindingId)) {
        dis.stopTransmit(radio.id);
      }
    }
    for (final intercom in rp.intercoms) {
      if (intercom.triggerMode == TriggerMode.ptt &&
          intercom.pttBindingIds.contains(bindingId)) {
        dis.stopIntercomTransmit(intercom.id);
      }
    }
  }

  Future<void> _startNetwork() async {
    final settings = context.read<SettingsProvider>().settings;
    _radioProvider ??= context.read<RadioProvider>();
    _disProvider ??= context.read<DisProvider>();
    final rp = _radioProvider!;
    final dis = _disProvider!;
    await dis.start(settings, rp.radios.toList(), rp.intercoms.toList());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildNavRail(),
          const VerticalDivider(width: 1),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildStatusBar(),
    );
  }

  Widget _buildNavRail() {
    return NavigationRail(
      selectedIndex: _NavDest.values.indexOf(_dest),
      onDestinationSelected: (i) =>
          setState(() => _dest = _NavDest.values[i]),
      extended: false,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const Icon(Icons.radio, color: AppColors.primaryGreen, size: 28),
            const SizedBox(height: 4),
            const Text(
              'DIS',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.primaryGreen,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.radio),
          selectedIcon: Icon(Icons.radio),
          label: Text('Radios'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.list_alt),
          selectedIcon: Icon(Icons.list_alt),
          label: Text('Channels'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.headset),
          selectedIcon: Icon(Icons.headset),
          label: Text('Audio'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_dest) {
      case _NavDest.radios:
        return _RadiosPanel();
      case _NavDest.netPlans:
        return const NetPlanScreen();
      case _NavDest.audio:
        return const AudioDevicesScreen();
      case _NavDest.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildStatusBar() {
    return Consumer<DisProvider>(
      builder: (context, dis, _) {
        final connected = dis.connected;
        return Container(
          height: 28,
          color: const Color(0xFF111111),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? AppColors.primaryGreen : Colors.red,
                  boxShadow: connected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryGreen.withOpacity(0.5),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'DIS ACTIVE' : 'DIS OFFLINE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: connected ? AppColors.primaryGreen : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'RX: ${dis.packetsRx}  TX: ${dis.packetsTx}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (!connected)
                TextButton(
                  onPressed: _startNetwork,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'CONNECT',
                    style: TextStyle(fontSize: 10, color: AppColors.amber),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RadiosPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RadioProvider>();
    final sp = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('DIS RADIO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_outlined),
            tooltip: 'Key Bindings',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _KeyBindingsDialog(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Export Config',
            onPressed: () async {
              final err = await rp.exportToFile();
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $err'),
                      backgroundColor: Colors.red.shade800),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Import Config',
            onPressed: () async {
              // Warn before overwriting
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Import Configuration'),
                  content: const Text(
                      'This will replace all current radios, intercoms and '
                      'channels. Audio device assignments will not be '
                      'imported.\n\nContinue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCEL'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('IMPORT'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;

              final dis = context.read<DisProvider>();
              final err = await rp.importFromFile();
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import failed: $err'),
                      backgroundColor: Colors.red.shade800),
                );
              } else {
                dis.updateRadios(rp.radios.toList(), rp.intercoms.toList());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configuration imported.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Radio',
            onPressed: () => rp.addRadio(),
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            tooltip: 'Add Intercom',
            onPressed: () => rp.addIntercom(),
          ),
        ],
      ),
      body: rp.radios.isEmpty && rp.intercoms.isEmpty
          ? _EmptyState(
              onAddRadio: () => rp.addRadio(),
            )
          : _buildGrid(context, rp, sp),
    );
  }

  Widget _buildGrid(
      BuildContext context, RadioProvider rp, SettingsProvider sp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...rp.radios.map((radio) => SizedBox(
                width: 320,
                child: RadioCard(
                  radio: radio,
                  onConfigure: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RadioConfigScreen(radio: radio),
                    ),
                  ),
                ),
              )),
          ...rp.intercoms.map((intercom) => SizedBox(
                width: 320,
                child: _IntercomCard(intercom: intercom),
              )),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddRadio;
  const _EmptyState({required this.onAddRadio});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radio, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No radios configured',
            style: TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a radio to get started',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('ADD RADIO'),
            onPressed: onAddRadio,
          ),
        ],
      ),
    );
  }
}

class _IntercomCard extends StatelessWidget {
  final IntercomConfig intercom;
  const _IntercomCard({required this.intercom});

  Future<void> _confirmDelete(BuildContext context) async {
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
      final rp = context.read<RadioProvider>();
      rp.removeIntercom(intercom.id);
      context.read<DisProvider>().updateRadios(
            rp.radios.toList(),
            rp.intercoms.toList(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dis = context.watch<DisProvider>();
    final rp = context.watch<RadioProvider>();
    final sp = context.watch<SettingsProvider>();
    final txActive = dis.isTxActive(intercom.id);
    final rxState = dis.rxStates[intercom.id] ?? const RadioRxState();
    final intercomSupported = dis.supportsIntercomFor(intercom.id);

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
            // Header row
            Row(
              children: [
                Icon(Icons.headset_mic,
                    color: intercomSupported
                        ? AppColors.amber
                        : AppColors.textMuted,
                    size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    intercom.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amber,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                RxTxIndicator(
                  rxActive: rxState.rxActive,
                  txActive: txActive,
                ),
                const SizedBox(width: 8),
                const Text(
                  'INTERCOM',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
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
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: Colors.red.shade400),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // PTT / status row
            Row(
              children: [
                if (intercom.triggerMode == TriggerMode.ptt)
                  PttButton(
                    active: txActive,
                    onPressed: () => dis.startIntercomTransmit(intercom.id),
                    onReleased: () => dis.stopIntercomTransmit(intercom.id),
                    activeIcon: Icons.headset_mic,
                    idleIcon: Icons.headset_mic_outlined,
                  )
                else if (intercom.triggerMode == TriggerMode.latchedPtt)
                  PttButton(
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
                  )
                else
                  _IntercomAutoTxIndicator(
                    txActive: txActive,
                    mode: intercom.triggerMode,
                  ),
                const SizedBox(width: 12),
                LevelMeter(
                  levelStream: AudioManager.instance.inputLevel(intercom.id),
                  height: 64,
                  threshold: intercom.voxThreshold,
                  onThresholdChanged: (v) =>
                      rp.updateIntercom(intercom.copyWith(voxThreshold: v)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IC ID: ${intercom.communicationsDeviceId}  '
                        'STA: ${intercom.stationName}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                      Text(
                        'CH: ${_channelTypeName(intercom.channelType)}  '
                        '${intercom.sampleRate ~/ 1000} kHz',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TriggerModeSelector(
              mode: intercom.triggerMode,
              onChanged: (mode) {
                final updated = intercom.copyWith(triggerMode: mode);
                rp.updateIntercom(updated);
                dis.updateRadios(rp.radios.toList(), rp.intercoms.toList());
              },
            ),
            if (intercom.triggerMode == TriggerMode.ptt ||
                intercom.triggerMode == TriggerMode.latchedPtt) ...[
              const SizedBox(height: 6),
              _IntercomKeyBindingsRow(
                intercom: intercom,
                rp: rp,
                sp: sp,
              ),
            ],
            const SizedBox(height: 8),

            // Volume and pan sliders
            Row(
              children: [
                const Icon(Icons.volume_up, size: 12, color: AppColors.textMuted),
                Expanded(
                  child: _CompactSlider(
                    value: intercom.outputVolume,
                    label: 'VOL',
                    onChanged: (v) =>
                        rp.updateIntercom(intercom.copyWith(outputVolume: v)),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.swap_horiz, size: 12, color: AppColors.textMuted),
                Expanded(
                  child: _PanSlider(
                    value: intercom.outputPan,
                    onChanged: (v) =>
                        rp.updateIntercom(intercom.copyWith(outputPan: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _IntercomAutoTxIndicator extends StatelessWidget {
  final bool txActive;
  final TriggerMode mode;

  const _IntercomAutoTxIndicator({required this.txActive, required this.mode});

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
          style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
        ),
        SizedBox(
          height: 20,
          child: Slider(value: value, onChanged: onChanged, min: 0, max: 1),
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
        Text(_label,
            style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
        SizedBox(
          height: 20,
          child: Slider(value: value, min: -1, max: 1, onChanged: onChanged),
        ),
      ],
    );
  }
}

String _channelTypeName(int type) {
  switch (type) {
    case 1: return 'FDX';
    case 2: return 'HDX-RX';
    case 3: return 'HDX-TX';
    case 4: return 'HDX';
    default: return '?';
  }
}

class _IntercomKeyBindingsRow extends StatelessWidget {
  final IntercomConfig intercom;
  final RadioProvider rp;
  final SettingsProvider sp;

  const _IntercomKeyBindingsRow({
    required this.intercom,
    required this.rp,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    final allBindings = sp.settings.keyBindings;
    final assigned =
        allBindings.where((b) => intercom.pttBindingIds.contains(b.id)).toList();

    return Row(
      children: [
        const Icon(Icons.keyboard_outlined, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: assigned.isEmpty
              ? const Text('No keys assigned',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted))
              : Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: assigned
                      .map((b) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              border: Border.all(color: const Color(0xFF333333)),
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
                currentBindingIds: intercom.pttBindingIds,
                settingsProvider: sp,
              );
              if (result != null) {
                rp.updateIntercom(intercom.copyWith(pttBindingIds: result));
              }
            },
            child: const Text('KEYS', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _KeyBindingsDialog extends StatelessWidget {
  const _KeyBindingsDialog();

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final bindings = sp.settings.keyBindings;

    return AlertDialog(
      title: const Text(
        'KEY BINDINGS',
        style: TextStyle(letterSpacing: 2, fontSize: 14),
      ),
      content: SizedBox(
        width: 380,
        child: bindings.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No key bindings configured.\nAdd them in Settings.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('BINDING',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                    letterSpacing: 1))),
                        Text('KEY',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                letterSpacing: 1)),
                        SizedBox(width: 56),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  ...bindings.map(
                      (b) => _KeyBindingRow(binding: b)),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }
}

class _KeyBindingRow extends StatelessWidget {
  final AppKeyBinding binding;

  const _KeyBindingRow({required this.binding});

  @override
  Widget build(BuildContext context) {
    final sp = context.read<SettingsProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              binding.displayLabel,
              style: TextStyle(
                fontSize: 12,
                color: binding.enabled ? AppColors.text : AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              border: Border.all(color: const Color(0xFF333333)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              binding.fullKeyLabel,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 11,
                color: AppColors.amber,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Switch(
              value: binding.enabled,
              onChanged: (v) {
                final settings = sp.settings;
                final updated = settings.keyBindings
                    .map((b) =>
                        b.id == binding.id ? b.copyWith(enabled: v) : b)
                    .toList();
                sp.updateSettings(settings.copyWith(keyBindings: updated));
              },
            ),
          ),
        ],
      ),
    );
  }
}
