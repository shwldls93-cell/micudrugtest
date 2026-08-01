import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/default_presets.dart' as preset_data;
import '../models/drug_preset.dart';
import 'pump_calculator.dart';

Map<String, List<DrugPreset>> migratePresetMap({
  String? currentRaw,
  String? legacyRaw,
}) {
  final current = _decodePresetSource(currentRaw);
  final legacy = _decodePresetSource(legacyRaw);
  final merged = <String, List<DrugPreset>>{};

  for (final department in preset_data.defaultDepartments) {
    merged[department.id] =
        _decodeDepartmentPresets(current?[department.id], department.id) ??
            _decodeDepartmentPresets(legacy?[department.id], department.id) ??
            department.presets.map((preset) => preset.copy()).toList();
  }

  return merged;
}

Map<String, dynamic>? _decodePresetSource(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  try {
    final decodedValue = jsonDecode(raw);
    if (decodedValue is! Map) return null;
    return Map<String, dynamic>.from(decodedValue);
  } catch (_) {
    return null;
  }
}

List<DrugPreset>? _decodeDepartmentPresets(
  dynamic rawPresets,
  String departmentId,
) {
  if (rawPresets is! List) return null;

  var parsedPresets = <DrugPreset>[];
  for (final rawPreset in rawPresets) {
    if (rawPreset is! Map) continue;
    final json = Map<String, dynamic>.from(rawPreset);
    _migrateLegacyRateIncrement(json);
    final preset = DrugPreset.tryFromJson(json);
    if (preset != null) parsedPresets.add(preset);
  }

  if (departmentId == 'micu') {
    if (preset_data.shouldReplaceLegacyMicuPresets(parsedPresets)) {
      parsedPresets = <DrugPreset>[];
    } else {
      parsedPresets = preset_data.replaceLegacyMicuPropofolLabel(parsedPresets);
      if (preset_data.shouldReplaceLegacyMicuRocuroniumPreset(parsedPresets)) {
        parsedPresets = preset_data.replaceLegacyMicuRocuroniumPreset(
          parsedPresets,
        );
      }
      if (preset_data.shouldReplaceLegacyMicuKetaminePreset(parsedPresets)) {
        parsedPresets = preset_data.replaceLegacyMicuKetaminePreset(
          parsedPresets,
        );
      }
    }
  }
  if (departmentId == 'eicu2' &&
      preset_data.shouldReplaceLegacyEicu2Presets(parsedPresets)) {
    parsedPresets = preset_data.replaceLegacyEicu2Presets(parsedPresets);
  }
  if (departmentId == 'ncu' &&
      preset_data.shouldReplaceLegacyNcuMgso4Presets(parsedPresets)) {
    parsedPresets = preset_data.replaceLegacyNcuMgso4Presets(parsedPresets);
  }

  parsedPresets =
      parsedPresets.where((preset) => validatePreset(preset) == null).toList();
  return parsedPresets.isEmpty
      ? null
      : preset_data.ensureUniquePresetIds(parsedPresets);
}

void _migrateLegacyRateIncrement(Map<String, dynamic> json) {
  if (json.containsKey('rateIncrementMlPerHr')) return;

  final name = json['name'];
  json['rateIncrementMlPerHr'] =
      name is String && name.trim().toLowerCase().startsWith('heparin')
          ? 1.0
          : 0.1;
}

List<DrugPreset> upsertPreset(List<DrugPreset> existing, DrugPreset edited) {
  final error = validatePreset(edited);
  if (error != null) throw CalculationInputException(error);

  final updated = [...existing];
  final index = updated.indexWhere((item) => item.id == edited.id);
  if (index >= 0) {
    updated[index] = edited;
  } else {
    updated.add(edited);
  }
  return preset_data.ensureUniquePresetIds(updated);
}

String? readFirstAvailableString(
  SharedPreferences prefs,
  String primaryKey,
  List<String> legacyKeys, {
  bool ignoreEmpty = false,
}) {
  final primaryValue = prefs.getString(primaryKey);
  if (primaryValue != null && (!ignoreEmpty || primaryValue.isNotEmpty)) {
    return primaryValue;
  }

  for (final legacyKey in legacyKeys) {
    final legacyValue = prefs.getString(legacyKey);
    if (legacyValue != null && (!ignoreEmpty || legacyValue.isNotEmpty)) {
      return legacyValue;
    }
  }
  return null;
}

String? readFirstLegacyString(
  SharedPreferences prefs,
  List<String> legacyKeys,
) {
  for (final legacyKey in legacyKeys) {
    final value = prefs.getString(legacyKey);
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

Future<void> removeLegacyKeys(
  SharedPreferences prefs,
  List<String> legacyKeys,
) async {
  for (final legacyKey in legacyKeys) {
    await prefs.remove(legacyKey);
  }
}
