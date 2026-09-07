import 'dart:convert';
import 'dart:io';
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
  static const _netPlansKey = 'net_plans';

  List<RadioConfig> _radios = [];
  List<IntercomConfig> _intercoms = [];
  List<NetPlan> _netPlans = [];

  List<RadioConfig> get radios => List.unmodifiable(_radios);
  List<IntercomConfig> get intercoms => List.unmodifiable(_intercoms);
  List<NetPlan> get netPlans => List.unmodifiable(_netPlans);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final radiosJson = prefs.getString(_radiosKey);
    if (radiosJson != null) {
      try {
        final list = jsonDecode(radiosJson) as List;
        _radios = list
            .map((e) => RadioConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final intercomsJson = prefs.getString(_intercomsKey);
    if (intercomsJson != null) {
      try {
        final list = jsonDecode(intercomsJson) as List;
        _intercoms = list
            .map((e) => IntercomConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final netPlansJson = prefs.getString(_netPlansKey);
    if (netPlansJson != null) {
      try {
        final list = jsonDecode(netPlansJson) as List;
        _netPlans = list
            .map((e) => NetPlan.fromJson(e as Map<String, dynamic>))
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

  Future<void> _saveNetPlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _netPlansKey, jsonEncode(_netPlans.map((n) => n.toJson()).toList()));
  }

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

  void addNetPlan() {
    _netPlans.add(NetPlan(name: 'Net Plan ${_netPlans.length + 1}'));
    _saveNetPlans();
    notifyListeners();
  }

  void removeNetPlan(String id) {
    _netPlans.removeWhere((n) => n.id == id);
    for (int i = 0; i < _radios.length; i++) {
      if (_radios[i].netPlanId == id) {
        _radios[i] = _applyNetAssignment(_radios[i], netPlanId: null, netChannelIndex: null);
      }
    }
    _saveNetPlans();
    _saveRadios();
    notifyListeners();
  }

  void updateNetPlan(NetPlan updated) {
    final idx = _netPlans.indexWhere((n) => n.id == updated.id);
    if (idx >= 0) {
      _netPlans[idx] = updated;
      _saveNetPlans();
      notifyListeners();
    }
  }

  void assignRadioToChannel(String radioId, String? netPlanId, int? channelIndex) {
    final idx = _radios.indexWhere((r) => r.id == radioId);
    if (idx < 0) return;
    final radio = _radios[idx];

    if (netPlanId == null || channelIndex == null) {
      _radios[idx] = _applyNetAssignment(radio, netPlanId: null, netChannelIndex: null);
    } else {
      try {
        final plan = _netPlans.firstWhere((n) => n.id == netPlanId);
        if (channelIndex < plan.channels.length) {
          final ch = plan.channels[channelIndex];
          _radios[idx] = _applyNetAssignment(radio,
              netPlanId: netPlanId,
              netChannelIndex: channelIndex,
              frequency: ch.frequency,
              modulationType: ch.modulationType,
              cryptoSystem: ch.cryptoSystem,
              cryptoKeyId: ch.cryptoKeyId);
        }
      } catch (_) {}
    }
    _saveRadios();
    notifyListeners();
  }

  /// Updates the radio's frequency and auto-selects a matching net channel if
  /// one exists, otherwise clears the net assignment (manual tune).
  void updateRadioFrequency(String radioId, double hz) {
    for (final plan in _netPlans) {
      for (var i = 0; i < plan.channels.length; i++) {
        if ((plan.channels[i].frequency - hz).abs() < 1.0) {
          assignRadioToChannel(radioId, plan.id, i);
          return;
        }
      }
    }
    final idx = _radios.indexWhere((r) => r.id == radioId);
    if (idx < 0) return;
    _radios[idx] = _applyNetAssignment(_radios[idx],
        netPlanId: null, netChannelIndex: null, frequency: hz);
    _saveRadios();
    notifyListeners();
  }

  /// Builds a copy of [r] with net assignment fields set explicitly (supports
  /// null to clear), preserving all other fields unchanged.
  RadioConfig _applyNetAssignment(
    RadioConfig r, {
    required String? netPlanId,
    required int? netChannelIndex,
    double? frequency,
    RadioModulationType? modulationType,
    int? cryptoSystem,
    int? cryptoKeyId,
  }) =>
      RadioConfig(
        id: r.id,
        name: r.name,
        enabled: r.enabled,
        frequency: frequency ?? r.frequency,
        bandwidth: r.bandwidth,
        modulationType: modulationType ?? r.modulationType,
        powerWatts: r.powerWatts,
        cryptoSystem: cryptoSystem ?? r.cryptoSystem,
        cryptoKeyId: cryptoKeyId ?? r.cryptoKeyId,
        inputDeviceId: r.inputDeviceId,
        outputDeviceId: r.outputDeviceId,
        inputGain: r.inputGain,
        outputVolume: r.outputVolume,
        squelch: r.squelch,
        sidetoneVolume: r.sidetoneVolume,
        outputPan: r.outputPan,
        pttBindingIds: List<String>.from(r.pttBindingIds),
        triggerMode: r.triggerMode,
        voxThreshold: r.voxThreshold,
        voxHangTime: r.voxHangTime,
        netPlanId: netPlanId,
        netChannelIndex: netChannelIndex,
        exerciseId: r.exerciseId,
        entityId: r.entityId,
        radioNumber: r.radioNumber,
        disLocalAddress: r.disLocalAddress,
        disPort: r.disPort,
        disUseMulticast: r.disUseMulticast,
        disMulticastGroup: r.disMulticastGroup,
        disUnicastAddress: r.disUnicastAddress,
        disNetworkInterface: r.disNetworkInterface,
        disProtocolVersion: r.disProtocolVersion,
      );

  NetPlan? getNetPlan(String? id) {
    if (id == null) return null;
    try {
      return _netPlans.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  void importNetPlan(NetPlan plan) {
    _netPlans.add(plan);
    _saveNetPlans();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Export / Import
  // ---------------------------------------------------------------------------

  /// Serialise radios, intercoms and net plans to a JSON map.
  /// Audio device IDs are stripped (they are machine-specific).
  Map<String, dynamic> exportConfig() {
    return {
      'version': 1,
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
      'netPlans': _netPlans.map((n) => n.toJson()).toList(),
    };
  }

  /// Export config to a user-chosen file via system save dialog.
  /// Returns an error string on failure, or null on success / cancellation.
  Future<String?> exportToFile() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export RaDIS Configuration',
        fileName: 'radis_config.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return null;
      final file = File(path);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(exportConfig()));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Import config from a user-chosen file via system open dialog.
  /// Replaces current radios, intercoms and net plans.
  /// Returns an error string on failure, or null on success / cancellation.
  Future<String?> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import RaDIS Configuration',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) return 'Could not access file path.';

      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final version = json['version'] as int? ?? 1;
      if (version != 1) return 'Unsupported config version: $version';

      _radios = (json['radios'] as List? ?? [])
          .map((e) => RadioConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      _intercoms = (json['intercoms'] as List? ?? [])
          .map((e) => IntercomConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      _netPlans = (json['netPlans'] as List? ?? [])
          .map((e) => NetPlan.fromJson(e as Map<String, dynamic>))
          .toList();

      await _saveRadios();
      await _saveIntercoms();
      await _saveNetPlans();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
