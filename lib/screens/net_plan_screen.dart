import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/net_plan.dart';
import '../models/radio_config.dart';
import '../providers/radio_provider.dart';
import '../theme.dart';

class NetPlanScreen extends StatefulWidget {
  const NetPlanScreen({super.key});

  @override
  State<NetPlanScreen> createState() => _NetPlanScreenState();
}

class _NetPlanScreenState extends State<NetPlanScreen> {
  String? _selectedPlanId;

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RadioProvider>();
    final plans = rp.netPlans;
    NetPlan? selected;
    try {
      selected = plans.firstWhere((p) => p.id == _selectedPlanId);
    } catch (_) {
      selected = plans.isNotEmpty ? plans.first : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NET PLANS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import',
            onPressed: _importPlan,
          ),
          if (selected != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export',
              onPressed: () => _exportPlan(selected!),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Plan',
            onPressed: () {
              rp.addNetPlan();
              setState(() => _selectedPlanId = rp.netPlans.last.id);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: plan list
          SizedBox(
            width: 200,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: plans.length,
                    itemBuilder: (context, i) {
                      final plan = plans[i];
                      final isSelected = plan.id == (selected?.id);
                      return ListTile(
                        selected: isSelected,
                        selectedColor: AppColors.primaryGreen,
                        title: Text(plan.name,
                            style: const TextStyle(
                                fontFamily: 'Courier New', fontSize: 13)),
                        subtitle: Text('${plan.channels.length} channels',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                        onTap: () => setState(() => _selectedPlanId = plan.id),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: AppColors.textMuted,
                          onPressed: () {
                            rp.removeNetPlan(plan.id);
                            if (_selectedPlanId == plan.id) {
                              setState(() => _selectedPlanId = null);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (plans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No net plans',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right: plan editor
          Expanded(
            child: selected == null
                ? const Center(
                    child: Text('Select or create a net plan',
                        style: TextStyle(color: AppColors.textMuted)))
                : _NetPlanEditor(
                    key: ValueKey(selected.id),
                    plan: selected,
                    onUpdate: rp.updateNetPlan,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _importPlan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        final content = await File(result.files.single.path!).readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final plan = NetPlan.fromJson(json);
        context.read<RadioProvider>().importNetPlan(plan);
        setState(() => _selectedPlanId = plan.id);
      } catch (e) {
        _showError('Import failed: $e');
      }
    }
  }

  Future<void> _exportPlan(NetPlan plan) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Net Plan',
      fileName: '${plan.name.replaceAll(' ', '_')}.json',
      allowedExtensions: ['json'],
    );
    if (path != null) {
      try {
        final json = jsonEncode(plan.toJson());
        await File(path).writeAsString(json);
      } catch (e) {
        _showError('Export failed: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

class _NetPlanEditor extends StatefulWidget {
  final NetPlan plan;
  final Function(NetPlan) onUpdate;

  const _NetPlanEditor({super.key, required this.plan, required this.onUpdate});

  @override
  State<_NetPlanEditor> createState() => _NetPlanEditorState();
}

class _NetPlanEditorState extends State<_NetPlanEditor> {
  late NetPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  void _save() => widget.onUpdate(_plan);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _plan.name,
                  style: const TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Plan Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() => _plan = NetPlan(
                          id: _plan.id,
                          name: v,
                          description: _plan.description,
                          channels: _plan.channels,
                        ));
                    _save();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Channel'),
                onPressed: _addChannel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _plan.description,
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              setState(() => _plan = NetPlan(
                    id: _plan.id,
                    name: _plan.name,
                    description: v,
                    channels: _plan.channels,
                  ));
              _save();
            },
          ),
          const SizedBox(height: 16),
          const Text('CHANNELS',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3,
                  color: AppColors.textMuted,
                  fontFamily: 'Courier New')),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _plan.channels.length,
              itemBuilder: (context, i) {
                final ch = _plan.channels[i];
                return _ChannelTile(
                  channel: ch,
                  index: i,
                  onUpdate: (updated) {
                    final newChannels = List<NetChannel>.from(_plan.channels);
                    newChannels[i] = updated;
                    setState(() => _plan = NetPlan(
                          id: _plan.id,
                          name: _plan.name,
                          description: _plan.description,
                          channels: newChannels,
                        ));
                    _save();
                  },
                  onDelete: () {
                    final newChannels = List<NetChannel>.from(_plan.channels)
                      ..removeAt(i);
                    setState(() => _plan = NetPlan(
                          id: _plan.id,
                          name: _plan.name,
                          description: _plan.description,
                          channels: newChannels,
                        ));
                    _save();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addChannel() {
    final newCh = NetChannel(
      name: 'CH${_plan.channels.length + 1}',
      frequency: 225000000,
    );
    setState(() => _plan = NetPlan(
          id: _plan.id,
          name: _plan.name,
          description: _plan.description,
          channels: [..._plan.channels, newCh],
        ));
    _save();
  }
}

class _ChannelTile extends StatelessWidget {
  final NetChannel channel;
  final int index;
  final Function(NetChannel) onUpdate;
  final VoidCallback onDelete;

  const _ChannelTile({
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
                    fontFamily: 'Courier New',
                    fontSize: 14,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              channel.name,
              style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
            const SizedBox(width: 12),
            Text(
              '${(channel.frequency / 1e6).toStringAsFixed(3)} MHz',
              style: const TextStyle(
                  fontFamily: 'Courier New',
                  color: Color(0xFF39FF14),
                  fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              channel.modulationType.displayName,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.amber, fontFamily: 'Courier New'),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted),
          onPressed: onDelete,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
              child: _smallField('Name', _ch.name, (v) => _update(_ch.copyWith(name: v))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _smallField('Frequency (Hz)',
                  _ch.frequency.toStringAsFixed(0), (v) {
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
                style: const TextStyle(
                    color: AppColors.text, fontFamily: 'Courier New', fontSize: 12),
                items: RadioModulationType.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _update(_ch.copyWith(modulationType: v));
                },
              ),
            ),
          ],
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
                style: const TextStyle(
                    color: AppColors.text, fontFamily: 'Courier New', fontSize: 12),
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
              child: _smallField(
                  'Crypto Key ID', _ch.cryptoKeyId.toString(), (v) {
                final k = int.tryParse(v);
                if (k != null) _update(_ch.copyWith(cryptoKeyId: k));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _smallField('Description', _ch.description ?? '', (v) {
                _update(_ch.copyWith(description: v.isEmpty ? null : v));
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _smallField(String label, String value, ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: value,
      style: const TextStyle(
          color: AppColors.text, fontFamily: 'Courier New', fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
