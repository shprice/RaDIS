import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/audio_device_model.dart';
import '../providers/audio_provider.dart';
import '../theme.dart';

class AudioDevicesScreen extends StatelessWidget {
  const AudioDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AudioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AUDIO DEVICES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Devices',
            onPressed: ap.refreshDevices,
          ),
        ],
      ),
      body: ap.error != null
          ? _ErrorPanel(error: ap.error!)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DeviceList(
                    title: 'INPUT DEVICES',
                    icon: Icons.mic,
                    devices: ap.inputDevices,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _DeviceList(
                    title: 'OUTPUT DEVICES',
                    icon: Icons.speaker,
                    devices: ap.outputDevices,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String error;
  const _ErrorPanel({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: AppColors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Audio system unavailable',
              style: TextStyle(
                  color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<AudioProvider>().initialize(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<AudioDevice> devices;
  final Color color;

  const _DeviceList({
    required this.title,
    required this.icon,
    required this.devices,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${devices.length})',
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: devices.isEmpty
              ? const Center(
                  child: Text('No devices found',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, i) => _DeviceTile(device: devices[i]),
                ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final AudioDevice device;

  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.name,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Chip('ID: ${device.id}'),
                const SizedBox(width: 8),
                _Chip('${device.channels}ch'),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: device.supportedSampleRates
                  .map((r) => _Chip('${r ~/ 1000}kHz'))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF2E2E2E)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
