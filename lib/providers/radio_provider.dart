import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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

  Future<void> load(int defaultSiteId, int defaultAppId) async {
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
    // Clear any radio assignments to this plan
    for (int i = 0; i < _radios.length; i++) {
      if (_radios[i].netPlanId == id) {
        _radios[i] = _radios[i].copyWith(netPlanId: null, netChannelIndex: null);
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
    if (idx >= 0) {
      final radio = _radios[idx];
      double? newFreq;
      RadioModulationType? newMod;
      int? newCrypto;
      int? newCryptoKey;

      if (netPlanId != null && channelIndex != null) {
        final plan = _netPlans.firstWhere((n) => n.id == netPlanId,
            orElse: () => throw Exception('Plan not found'));
        if (channelIndex < plan.channels.length) {
          final ch = plan.channels[channelIndex];
          newFreq = ch.frequency;
          newMod = ch.modulationType;
          newCrypto = ch.cryptoSystem;
          newCryptoKey = ch.cryptoKeyId;
        }
      }

      _radios[idx] = radio.copyWith(
        netPlanId: netPlanId,
        netChannelIndex: channelIndex,
        frequency: newFreq,
        modulationType: newMod,
        cryptoSystem: newCrypto,
        cryptoKeyId: newCryptoKey,
      );
      _saveRadios();
      notifyListeners();
    }
  }

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
}
