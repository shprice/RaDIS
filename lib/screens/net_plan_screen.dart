import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/net_plan.dart';
import '../models/radio_config.dart';
import '../providers/radio_provider.dart';
import '../theme.dart';

class NetPlanScreen extends StatelessWidget {
  const NetPlanScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final rp = context.read<RadioProvider>();
    final err = await rp.exportChannelsToFile();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $err'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final rp = context.read<RadioProvider>();
    final err = await rp.importChannelsFromFile();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $err'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RadioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHANNELS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import channels',
            onPressed: () => _import(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export channels',
            onPressed: () => _export(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            label: 'RADIO CHANNELS',
            onAdd: rp.addRadioChannel,
          ),
          const SizedBox(height: 8),
          ...rp.radioChannels.asMap().entries.map((e) => _ChannelTile(
                key: ValueKey(e.value.id),
                channel: e.value,
                index: e.key,
                onUpdate: rp.updateRadioChannel,
                onDelete: () => rp.removeRadioChannel(e.value.id),
              )),
          if (rp.radioChannels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No radio channels',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final VoidCallback onAdd;

  const _SectionHeader({required this.label, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, letterSpacing: 3, color: AppColors.textMuted)),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('ADD', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Radio channel tile + editor

class _ChannelTile extends StatelessWidget {
  final NetChannel channel;
  final int index;
  final Function(NetChannel) onUpdate;
  final VoidCallback onDelete;

  const _ChannelTile({
    super.key,
    required this.channel,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(channel.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(width: 12),
            Text(
              '${(channel.frequency / 1e6).toStringAsFixed(3)} MHz',
              style: const TextStyle(color: Color(0xFF39FF14), fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(channel.modulationType.displayName,
                style: const TextStyle(fontSize: 10, color: AppColors.amber)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted),
          onPressed: onDelete,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: _ChannelEditor(channel: channel, onUpdate: onUpdate),
          ),
        ],
      ),
    );
  }
}

class _ChannelEditor extends StatefulWidget {
  final NetChannel channel;
  final Function(NetChannel) onUpdate;

  const _ChannelEditor({required this.channel, required this.onUpdate});

  @override
  State<_ChannelEditor> createState() => _ChannelEditorState();
}

class _ChannelEditorState extends State<_ChannelEditor> {
  late NetChannel _ch;

  @override
  void initState() {
    super.initState();
    _ch = widget.channel;
  }

  void _update(NetChannel ch) {
    setState(() => _ch = ch);
    widget.onUpdate(ch);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _field('Name', _ch.name,
                  (v) => _update(_ch.copyWith(name: v))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field('Frequency (Hz)', _ch.frequency.toStringAsFixed(0), (v) {
                final hz = double.tryParse(v);
                if (hz != null) _update(_ch.copyWith(frequency: hz));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<RadioModulationType>(
                value: _ch.modulationType,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                    labelText: 'Modulation',
                    isDense: true,
                    border: OutlineInputBorder()),
                style: const TextStyle(color: AppColors.text, fontSize: 12),
                items: RadioModulationType.values
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _update(_ch.copyWith(modulationType: v));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ColorPicker(
          selected: _ch.color,
          onChanged: (c) => _update(_ch.copyWith(color: c)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _ch.cryptoSystem,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                    labelText: 'Crypto',
                    isDense: true,
                    border: OutlineInputBorder()),
                style: const TextStyle(color: AppColors.text, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('NONE')),
                  DropdownMenuItem(value: 1, child: Text('KY-28')),
                  DropdownMenuItem(value: 2, child: Text('KY-57')),
                  DropdownMenuItem(value: 3, child: Text('KY-58')),
                  DropdownMenuItem(value: 4, child: Text('VINSON')),
                ],
                onChanged: (v) {
                  if (v != null) _update(_ch.copyWith(cryptoSystem: v));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field('Crypto Key ID', _ch.cryptoKeyId.toString(), (v) {
                final k = int.tryParse(v);
                if (k != null) _update(_ch.copyWith(cryptoKeyId: k));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field('Description', _ch.description ?? '', (v) {
                _update(_ch.copyWith(description: v.isEmpty ? null : v));
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: value,
      style: const TextStyle(color: AppColors.text, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared color picker

class _ColorPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ColorPicker({required this.selected, required this.onChanged});

  static const _options = <String?, Color>{
    null: Color(0xFF555555),
    'red': Color(0xFFEF5350),
    'orange': Color(0xFFFF9800),
    'yellow': Color(0xFFFFEE58),
    'green': Color(0xFF66BB6A),
    'blue': Color(0xFF42A5F5),
    'purple': Color(0xFFAB47BC),
    'white': Color(0xFFEEEEEE),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Colour',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(width: 12),
        ..._options.entries.map((e) {
          final isSelected = e.key == selected;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: e.value,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: e.value.withValues(alpha: 0.6), blurRadius: 6)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black54)
                  : null,
            ),
          );
        }),
      ],
    );
  }
}
