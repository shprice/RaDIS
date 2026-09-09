import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../models/radio_config.dart';
import '../models/intercom_config.dart';
import '../models/net_plan.dart';
import '../dis/entity_id.dart';

class RadioProvider extends ChangeNotifier {
  static const _radiosKey = 'radios';
  static const _intercomsKey = 'intercoms';
  static const _netPlansKey = 'net_plans'; // kept for migration only
  static const _radioChannelsKey = 'radio_channels';

  List<RadioConfig> _radios = [];
  List<IntercomConfig> _intercoms = [];
  List<NetChannel> _radioChannels = [];

  List<RadioConfig> get radios => List.unmodifiable(_radios);
  List<IntercomConfig> get intercoms => List.unmodifiable(_intercoms);
  List<NetChannel> get radioChannels => List.unmodifiable(_radioChannels);

  NetChannel? getRadioChannel(String? id) {
    if (id == null) return null;
    try {
      return _radioChannels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load old net plans for migration (may be null if already migrated)
    List<NetPlan> oldNetPlans = [];
    final netPlansJson = prefs.getString(_netPlansKey);
    if (netPlansJson != null) {
      try {
        final list = jsonDecode(netPlansJson) as List;
        oldNetPlans =
            list.map((e) => NetPlan.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Load radio channels (new flat format), migrating from net plans if needed
    final radioChJson = prefs.getString(_radioChannelsKey);
    if (radioChJson != null) {
      try {
        final list = jsonDecode(radioChJson) as List;
        _radioChannels = list
            .map((e) => NetChannel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    } else if (oldNetPlans.isNotEmpty) {
      _radioChannels = oldNetPlans.expand((p) => p.channels).toList();
      await _saveRadioChannels();
    }

    // Load radios
    final radiosJson = prefs.getString(_radiosKey);
    if (radiosJson != null) {
      try {
        final list = jsonDecode(radiosJson) as List;
        _radios = list
            .map((e) => RadioConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Migrate radio channel assignments from old netPlanId+index format
    bool didMigrateRadios = false;
    for (int i = 0; i < _radios.length; i++) {
      final r = _radios[i];
      if (r.radioChannelId == null &&
          r.netPlanId != null &&
          r.netChannelIndex != null) {
        try {
          final plan = oldNetPlans.firstWhere((p) => p.id == r.netPlanId);
          final idx = r.netChannelIndex!;
          if (idx < plan.channels.length) {
            _radios[i] =
                _radios[i].copyWith(radioChannelId: plan.channels[idx].id);
            didMigrateRadios = true;
          }
        } catch (_) {}
      }
      if (r.txRadioChannelId == null &&
          r.txNetPlanId != null &&
          r.txNetChannelIndex != null) {
        try {
          final plan = oldNetPlans.firstWhere((p) => p.id == r.txNetPlanId);
          final idx = r.txNetChannelIndex!;
          if (idx < plan.channels.length) {
            _radios[i] =
                _radios[i].copyWith(txRadioChannelId: plan.channels[idx].id);
            didMigrateRadios = true;
          }
        } catch (_) {}
      }
    }
    if (didMigrateRadios) await _saveRadios();

    // Load intercoms
    final intercomsJson = prefs.getString(_intercomsKey);
    if (intercomsJson != null) {
      try {
        final list = jsonDecode(intercomsJson) as List;
        _intercoms = list
            .map((e) => IntercomConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> _saveRadios() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _radiosKey, jsonEncode(_radios.map((r) => r.toJson()).toList()));
  }

  Future<void> _saveIntercoms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _intercomsKey, jsonEncode(_intercoms.map((i) => i.toJson()).toList()));
  }

  Future<void> _saveRadioChannels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_radioChannelsKey,
        jsonEncode(_radioChannels.map((c) => c.toJson()).toList()));
  }

  // ---------------------------------------------------------------------------
  // Radio CRUD
  // ---------------------------------------------------------------------------

  void addRadio({int siteId = 1, int applicationId = 1}) {
    final idx = _radios.length + 1;
    _radios.add(RadioConfig(
      name: 'Radio $idx',
      entityId: EntityId(
          siteId: siteId, applicationId: applicationId, entityNumber: idx),
      radioNumber: idx,
    ));
    _saveRadios();
    notifyListeners();
  }

  void removeRadio(String id) {
    _radios.removeWhere((r) => r.id == id);
    _saveRadios();
    notifyListeners();
  }

  void updateRadio(RadioConfig updated) {
    final idx = _radios.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) {
      _radios[idx] = updated;
      _saveRadios();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Intercom CRUD
  // ---------------------------------------------------------------------------

  void addIntercom({int siteId = 1, int applicationId = 1}) {
    final idx = _intercoms.length + 1;
    _intercoms.add(IntercomConfig(
      name: 'Intercom $idx',
      entityId: EntityId(
          siteId: siteId, applicationId: applicationId, entityNumber: 100 + idx),
      communicationsDeviceId: idx,
    ));
    _saveIntercoms();
    notifyListeners();
  }

  void removeIntercom(String id) {
    _intercoms.removeWhere((i) => i.id == id);
    _saveIntercoms();
    notifyListeners();
  }

  void updateIntercom(IntercomConfig updated) {
    final idx = _intercoms.indexWhere((i) => i.id == updated.id);
    if (idx >= 0) {
      _intercoms[idx] = updated;
      _saveIntercoms();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Radio channel CRUD
  // ---------------------------------------------------------------------------

  void addRadioChannel() {
    _radioChannels.add(NetChannel(
      name: 'CH${_radioChannels.length + 1}',
      frequency: 225000000,
    ));
    _saveRadioChannels();
    notifyListeners();
  }

  void removeRadioChannel(String id) {
    _radioChannels.removeWhere((c) => c.id == id);
    // Clear references from radios
    for (int i = 0; i < _radios.length; i++) {
      if (_radios[i].radioChannelId == id) {
        _radios[i] = _radios[i].copyWith(radioChannelId: null);
      }
      if (_radios[i].txRadioChannelId == id) {
        _radios[i] = _radios[i].copyWith(txRadioChannelId: null);
      }
    }
    _saveRadioChannels();
    _saveRadios();
    notifyListeners();
  }

  void updateRadioChannel(NetChannel updated) {
    final idx = _radioChannels.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      _radioChannels[idx] = updated;
      _saveRadioChannels();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Channel assignment
  // ---------------------------------------------------------------------------

  void assignRadioChannel(String radioId, String? channelId) {
    final idx = _radios.indexWhere((r) => r.id == radioId);
    if (idx < 0) return;
    final r = _radios[idx];

    if (channelId == null) {
      _radios[idx] = r.copyWith(radioChannelId: null);
    } else {
      final ch = getRadioChannel(channelId);
      if (ch != null) {
        _radios[idx] = r.copyWith(
          radioChannelId: channelId,
          frequency: ch.frequency,
          modulationType: ch.modulationType,
          cryptoSystem: ch.cryptoSystem,
          cryptoKeyId: ch.cryptoKeyId,
        );
      }
    }
    _saveRadios();
    notifyListeners();
  }

  void assignRadioTxChannel(String radioId, String? channelId) {
    final idx = _radios.indexWhere((r) => r.id == radioId);
    if (idx < 0) return;
    final r = _radios[idx];

    if (channelId == null) {
      _radios[idx] = r.copyWith(txRadioChannelId: null);
    } else {
      final ch = getRadioChannel(channelId);
      if (ch != null) {
        _radios[idx] = r.copyWith(
          txRadioChannelId: channelId,
          txFrequency: ch.frequency,
        );
      }
    }
    _saveRadios();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Frequency tuning (auto-match to channel)
  // ---------------------------------------------------------------------------

  void updateRadioFrequency(String radioId, double hz) {
    for (final ch in _radioChannels) {
      if ((ch.frequency - hz).abs() < 1.0) {
        assignRadioChannel(radioId, ch.id);
        return;
      }
    }
    final idx = _radios.indexWhere((r) => r.id == radioId);
    if (idx < 0) return;
    _radios[idx] = _radios[idx].copyWith(radioChannelId: null, frequency: hz);
    _saveRadios();
    notifyListeners();
  }

  void updateRadioTxFrequency(String radioId, double hz) {
    for (final ch in _radioChannels) {
      if ((ch.frequency - hz).abs() < 1.0) {
        assignRadioTxChannel(radioId, ch.id);
        return;
      }
    }
    final idx = _radios.indexWhere((r) => r.id == radioId);
    if (idx < 0) return;
    _radios[idx] =
        _radios[idx].copyWith(txRadioChannelId: null, txFrequency: hz);
    _saveRadios();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Export / Import
  // ---------------------------------------------------------------------------

  Map<String, dynamic> exportConfig() {
    return {
      'version': 2,
      'radios': _radios.map((r) {
        final j = r.toJson();
        j.remove('inputDeviceId');
        j.remove('outputDeviceId');
        return j;
      }).toList(),
      'intercoms': _intercoms.map((i) {
        final j = i.toJson();
        j.remove('inputDeviceId');
        j.remove('outputDeviceId');
        return j;
      }).toList(),
      'radioChannels': _radioChannels.map((c) => c.toJson()).toList(),
    };
  }

  Future<String?> exportToFile() async {
    try {
      final content = const JsonEncoder.withIndent('  ').convert(exportConfig());
      await FilePicker.saveFile(
        dialogTitle: 'Export RaDIS Configuration',
        fileName: 'radis_config.json',
        bytes: Uint8List.fromList(utf8.encode(content)),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> importFromFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Import RaDIS Configuration',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return null;

      final path = file.path;
      if (path == null) return 'Could not access file path.';

      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final version = json['version'] as int? ?? 1;

      _radios = (json['radios'] as List? ?? [])
          .map((e) => RadioConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      _intercoms = (json['intercoms'] as List? ?? [])
          .map((e) => IntercomConfig.fromJson(e as Map<String, dynamic>))
          .toList();

      if (version >= 2) {
        _radioChannels = (json['radioChannels'] as List? ?? [])
            .map((e) => NetChannel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // version 1: flatten net plans
        final oldNetPlans = (json['netPlans'] as List? ?? [])
            .map((e) => NetPlan.fromJson(e as Map<String, dynamic>))
            .toList();
        _radioChannels = oldNetPlans.expand((p) => p.channels).toList();
        // Migrate channel assignments
        for (int i = 0; i < _radios.length; i++) {
          final r = _radios[i];
          if (r.radioChannelId == null &&
              r.netPlanId != null &&
              r.netChannelIndex != null) {
            try {
              final plan =
                  oldNetPlans.firstWhere((p) => p.id == r.netPlanId);
              final idx = r.netChannelIndex!;
              if (idx < plan.channels.length) {
                _radios[i] = _radios[i]
                    .copyWith(radioChannelId: plan.channels[idx].id);
              }
            } catch (_) {}
          }
        }
      }

      await _saveRadios();
      await _saveIntercoms();
      await _saveRadioChannels();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Map<String, dynamic> _channelsExportMap() => {
        'version': 1,
        'radioChannels': _radioChannels.map((c) => c.toJson()).toList(),
      };

  Future<String?> exportChannelsToFile() async {
    try {
      final content = const JsonEncoder.withIndent('  ').convert(_channelsExportMap());
      await FilePicker.saveFile(
        dialogTitle: 'Export Channel List',
        fileName: 'channels.json',
        bytes: Uint8List.fromList(utf8.encode(content)),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> importChannelsFromFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Import Channel List',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return null;
      final path = file.path;
      if (path == null) return 'Could not access file path.';

      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      _radioChannels = (json['radioChannels'] as List? ?? [])
          .map((e) => NetChannel.fromJson(e as Map<String, dynamic>))
          .toList();

      await _saveRadioChannels();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
