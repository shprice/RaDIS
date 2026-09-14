import 'dart:io';
import 'package:flutter/material.dart';
import '../dis/constants.dart';
import '../theme.dart';

/// Tappable pill showing MC (multicast) or BC (broadcast/unicast).
/// Tapping opens a dialog to switch mode and edit the destination address.
class NetworkModePill extends StatelessWidget {
  final bool useMulticast;
  final String multicastGroup;
  final String unicastAddress;
  final void Function(bool useMulticast, String multicastGroup, String unicastAddress) onSave;

  const NetworkModePill({
    super.key,
    required this.useMulticast,
    required this.multicastGroup,
    required this.unicastAddress,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final color = useMulticast
        ? AppColorsX.of(context).primaryText
        : AppColorsX.of(context).amberText;
    final label = useMulticast ? 'MC' : 'BC';

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _NetworkModeDialog(
          initialUseMulticast: useMulticast,
          initialMulticastGroup: multicastGroup,
          initialUnicastAddress: unicastAddress,
          onSave: onSave,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _NetworkModeDialog extends StatefulWidget {
  final bool initialUseMulticast;
  final String initialMulticastGroup;
  final String initialUnicastAddress;
  final void Function(bool, String, String) onSave;

  const _NetworkModeDialog({
    required this.initialUseMulticast,
    required this.initialMulticastGroup,
    required this.initialUnicastAddress,
    required this.onSave,
  });

  @override
  State<_NetworkModeDialog> createState() => _NetworkModeDialogState();
}

class _NetworkModeDialogState extends State<_NetworkModeDialog> {
  late bool _useMulticast;
  late TextEditingController _ctrl;
  // Track the other mode's address so we can restore it on re-toggle.
  late String _savedMulticast;
  late String _savedUnicast;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useMulticast = widget.initialUseMulticast;
    _savedMulticast = widget.initialMulticastGroup;
    _savedUnicast = widget.initialUnicastAddress;
    _ctrl = TextEditingController(
      text: _useMulticast ? _savedMulticast : _savedUnicast,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onToggle(bool v) {
    // Persist the current text before switching so toggling back restores it.
    if (_useMulticast) {
      _savedMulticast = _ctrl.text;
    } else {
      _savedUnicast = _ctrl.text;
    }
    setState(() {
      _useMulticast = v;
      _ctrl.text = v ? _savedMulticast : _savedUnicast;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      _error = null;
    });
  }

  Future<String> _defaultBroadcastAddress() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4 && addr.address != '127.0.0.1') {
            return '${parts[0]}.${parts[1]}.${parts[2]}.255';
          }
        }
      }
    } catch (_) {}
    return DisConstants.defaultBroadcastAddress;
  }

  void _save() {
    final addr = _ctrl.text.trim();
    if (addr.isEmpty) {
      setState(() => _error = 'Address required');
      return;
    }
    final mg = _useMulticast ? addr : _savedMulticast;
    final ua = _useMulticast ? _savedUnicast : addr;
    widget.onSave(_useMulticast, mg, ua);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Network Mode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text(
              _useMulticast ? 'Multicast' : 'Broadcast / Unicast',
              style: const TextStyle(fontSize: 14),
            ),
            value: _useMulticast,
            activeColor: AppColors.primaryGreen,
            onChanged: (v) async {
              if (!v && _savedUnicast == DisConstants.defaultBroadcastAddress) {
                // Auto-detect subnet broadcast when first switching to BC mode
                final detected = await _defaultBroadcastAddress();
                _savedUnicast = detected;
              }
              _onToggle(v);
            },
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            _useMulticast ? 'Multicast Group' : 'Destination Address',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
              errorText: _error,
              errorStyle: const TextStyle(fontSize: 10),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('SAVE',
              style: TextStyle(color: AppColors.primaryGreen)),
        ),
      ],
    );
  }
}
