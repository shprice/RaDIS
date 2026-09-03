import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/radio_config.dart';
import '../models/intercom_config.dart';
import '../providers/radio_provider.dart';
import '../providers/dis_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/audio_provider.dart';
import '../theme.dart';
import '../widgets/radio_card.dart';
import 'radio_config_screen.dart';
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
  bool _networkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNetwork());
  }

  Future<void> _startNetwork() async {
    final settings = context.read<SettingsProvider>().settings;
    final rp = context.read<RadioProvider>();
    final dis = context.read<DisProvider>();
    await dis.start(settings, rp.radios.toList(), rp.intercoms.toList());
    setState(() => _networkStarted = true);
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
            Text(
              'DIS',
              style: const TextStyle(
                fontFamily: 'Courier New',
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
          label: Text('Net Plans'),
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
                  fontFamily: 'Courier New',
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: connected ? AppColors.primaryGreen : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'RX: ${dis.packetsRx}  TX: ${dis.packetsTx}',
                style: const TextStyle(
                  fontFamily: 'Courier New',
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
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.amber,
                        fontFamily: 'Courier New'),
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
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Radio',
            onPressed: () => rp.addRadio(
              siteId: sp.settings.siteId,
              applicationId: sp.settings.applicationId,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            tooltip: 'Add Intercom',
            onPressed: () => rp.addIntercom(
              siteId: sp.settings.siteId,
              applicationId: sp.settings.applicationId,
            ),
          ),
        ],
      ),
      body: rp.radios.isEmpty && rp.intercoms.isEmpty
          ? _EmptyState(
              onAddRadio: () => rp.addRadio(
                siteId: sp.settings.siteId,
                applicationId: sp.settings.applicationId,
              ),
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
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 16, fontFamily: 'Courier New'),
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
            child: const Text('DELETE',
                style: TextStyle(color: Colors.red)),
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
    final txActive = dis.isTxActive(intercom.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headset_mic, color: AppColors.amber, size: 16),
                const SizedBox(width: 8),
                Text(
                  intercom.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.amber,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  'INTERCOM',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontFamily: 'Courier New',
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
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTapDown: (_) => dis.startTransmit(intercom.id),
                  onTapUp: (_) => dis.stopTransmit(intercom.id),
                  onTapCancel: () => dis.stopTransmit(intercom.id),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: txActive
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF2A1A00),
                      border: Border.all(
                        color: txActive ? AppColors.amber : const Color(0xFF555555),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            txActive ? Icons.headset_mic : Icons.headset_mic_outlined,
                            color: txActive ? Colors.white : AppColors.amber,
                            size: 24,
                          ),
                          Text(
                            'IC',
                            style: TextStyle(
                              fontFamily: 'Courier New',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: txActive ? Colors.white : AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device ID: ${intercom.communicationsDeviceId}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontFamily: 'Courier New'),
                    ),
                    Text(
                      'Sample: ${intercom.sampleRate ~/ 1000} kHz',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontFamily: 'Courier New'),
                    ),
                    if (intercom.voxEnabled)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.amber, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'VOX',
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.amber,
                            fontFamily: 'Courier New',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
