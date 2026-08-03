import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:micudrugtest/data/default_presets.dart';
import 'package:micudrugtest/models/drug_preset.dart';
import 'package:micudrugtest/services/pump_calculator.dart';
import 'package:micudrugtest/services/preset_storage.dart';
import 'package:micudrugtest/utils/pump_calculator_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('pump calculator', () {
    test('converts mg reservoir amounts for mcg dose units', () {
      final preset = DrugPreset(
        id: 'norepi',
        name: 'norepinephrine',
        doseUnit: 'mcg/kg/min',
        drugAmount: 12,
        drugUnit: 'mg',
        volumeMl: 200,
        timeUnit: 'min',
        useWeight: true,
        note: '',
        minDose: 0.02,
        maxDose: 0.3,
      );

      final rate = calculateRate(dose: 0.1, weight: 60, preset: preset);

      expect(rate, closeTo(6.0, 0.000001));
    });

    test('rejects a stale timeUnit that conflicts with the dose suffix', () {
      final preset = DrugPreset(
        id: 'mismatch',
        name: 'example',
        doseUnit: 'mg/min',
        drugAmount: 900,
        drugUnit: 'mg',
        volumeMl: 500,
        timeUnit: 'hr',
        useWeight: false,
        note: '',
      );

      expect(validatePreset(preset), contains('일치하지'));
      expect(
        () => calculateRate(dose: 1, weight: 0, preset: preset),
        throwsA(isA<CalculationInputException>()),
      );
    });

    test('supports gram based presets', () {
      final preset = DrugPreset(
        id: 'mgso4',
        name: 'MgSO4',
        doseUnit: 'g/day',
        drugAmount: 2,
        drugUnit: 'g',
        volumeMl: 20,
        timeUnit: 'day',
        useWeight: false,
        note: '',
      );

      final rate = calculateRate(dose: 1, weight: 0, preset: preset);

      expect(rate, closeTo(20 / 48, 0.000001));
    });

    test('uses the updated NCU MgSO4 preset values', () {
      final preset = buildNcuMgso4Preset();

      expect(preset.name, 'MgSO4');
      expect(preset.doseUnit, 'mcg/kg/hr');
      expect(preset.drugAmount, 6);
      expect(preset.drugUnit, 'g');
      expect(preset.volumeMl, 60);
      expect(preset.timeUnit, 'hr');
      expect(preset.useWeight, isTrue);
      expect(preset.note, contains('Initial 0.1 g/hr'));
    });

    test('replaces legacy NCU MgSO4 entries with the updated preset', () {
      final migrated = replaceLegacyNcuMgso4Presets([
        DrugPreset(
          id: 'legacy-sah',
          name: 'MgSO4 (SAH)',
          doseUnit: 'g/day',
          drugAmount: 2,
          drugUnit: 'g',
          volumeMl: 20,
          timeUnit: 'day',
          useWeight: false,
          note: '',
        ),
        DrugPreset(
          id: 'legacy-ttm',
          name: 'MgSO4 (TTM)',
          doseUnit: 'g/hr',
          drugAmount: 2,
          drugUnit: 'g',
          volumeMl: 50,
          timeUnit: 'hr',
          useWeight: false,
          note: '',
        ),
      ]);

      expect(migrated, hasLength(1));
      expect(migrated.single.name, 'MgSO4');
      expect(migrated.single.doseUnit, 'mcg/kg/hr');
    });

    test('uses the updated MICU rocuronium preset values', () {
      final preset = defaultMicuPresets().firstWhere(
        (preset) => preset.name == 'rocuronium 50mg',
      );

      expect(preset.doseUnit, 'mg/kg/hr');
      expect(preset.drugAmount, 250);
      expect(preset.drugUnit, 'mg');
      expect(preset.volumeMl, 50);
      expect(preset.timeUnit, 'hr');
      expect(preset.useWeight, isTrue);
      expect(preset.minDose, 0.2);
      expect(preset.maxDose, 1);
    });

    test('migrates legacy MICU rocuronium preset units', () {
      final migrated = replaceLegacyMicuRocuroniumPreset([
        DrugPreset(
          id: 'legacy-rocuronium',
          name: 'rocuronium 50mg',
          doseUnit: 'mcg/kg/hr',
          drugAmount: 250000,
          drugUnit: 'mcg',
          volumeMl: 50,
          timeUnit: 'hr',
          useWeight: true,
          minDose: 0.2,
          maxDose: 1,
          note: 'old note',
        ),
      ]);

      expect(migrated, hasLength(1));
      expect(migrated.single.id, 'legacy-rocuronium');
      expect(migrated.single.doseUnit, 'mg/kg/hr');
      expect(migrated.single.drugAmount, 250);
      expect(migrated.single.drugUnit, 'mg');
      expect(migrated.single.minDose, 0.2);
      expect(migrated.single.maxDose, 1);
    });

    test('uses the updated MICU ketamine preset values', () {
      final preset = defaultMicuPresets().firstWhere(
        (preset) => preset.name == 'ketamine 250mg',
      );

      expect(preset.doseUnit, 'mg/kg/hr');
      expect(preset.drugAmount, 500);
      expect(preset.drugUnit, 'mg');
      expect(preset.volumeMl, 250);
      expect(preset.timeUnit, 'hr');
      expect(preset.useWeight, isTrue);
      expect(preset.minDose, 0.2);
      expect(preset.maxDose, 4);
    });

    test('migrates legacy MICU ketamine preset units', () {
      final migrated = replaceLegacyMicuKetaminePreset([
        DrugPreset(
          id: 'legacy-ketamine',
          name: 'ketamine 250mg',
          doseUnit: 'mcg/kg/hr',
          drugAmount: 500000,
          drugUnit: 'mcg',
          volumeMl: 250,
          timeUnit: 'hr',
          useWeight: true,
          minDose: 0.2,
          maxDose: 4,
          note: 'old note',
        ),
      ]);

      expect(migrated, hasLength(1));
      expect(migrated.single.id, 'legacy-ketamine');
      expect(migrated.single.doseUnit, 'mg/kg/hr');
      expect(migrated.single.drugAmount, 500);
      expect(migrated.single.drugUnit, 'mg');
      expect(migrated.single.minDose, 0.2);
      expect(migrated.single.maxDose, 4);
    });

    test('uses the updated EICU2 preset list', () {
      final presets = defaultEicu2Presets();
      final precedex = presets.firstWhere(
        (preset) => preset.name == 'precedex',
      );

      expect(presets, hasLength(24));
      expect(precedex.doseUnit, 'mcg/kg/hr');
      expect(precedex.maxDose, 1.5);
      expect(
        presets.any((preset) => preset.name == 'norepinephrine (central)'),
        isTrue,
      );
      expect(presets.any((preset) => preset.name == 'Labesin'), isTrue);
    });

    test('replaces legacy EICU2 presets with the updated preset list', () {
      final migrated = replaceLegacyEicu2Presets([
        DrugPreset(
          id: 'legacy-adrenaline',
          name: 'Adrenaline',
          doseUnit: 'mcg/kg/min',
          drugAmount: 4,
          drugUnit: 'mg',
          volumeMl: 50,
          timeUnit: 'min',
          useWeight: true,
          note: '',
        ),
        DrugPreset(
          id: 'legacy-amiodarone',
          name: 'Amiodarone',
          doseUnit: 'mg/hr',
          drugAmount: 150,
          drugUnit: 'mg',
          volumeMl: 100,
          timeUnit: 'hr',
          useWeight: false,
          note: '',
        ),
        DrugPreset(
          id: 'legacy-dopamine',
          name: 'Dopamine',
          doseUnit: 'mcg/kg/min',
          drugAmount: 200,
          drugUnit: 'mg',
          volumeMl: 50,
          timeUnit: 'min',
          useWeight: true,
          note: '',
        ),
      ]);

      expect(migrated, hasLength(24));
      expect(migrated.any((preset) => preset.name == 'Adrenaline'), isFalse);
      expect(
        migrated.any((preset) => preset.name == 'norepinephrine (central)'),
        isTrue,
      );
    });

    test('all default presets have calculable dosage settings', () {
      for (final department in defaultDepartments) {
        final seenIds = <String>{};

        for (final preset in department.presets) {
          final label = '${department.label} / ${preset.name}';
          final doseAmountUnit = parseDoseAmountUnit(preset.doseUnit);
          final drugAmountUnit = parseDrugAmountUnit(preset.drugUnit);

          expect(preset.id.trim(), isNotEmpty, reason: label);
          expect(seenIds.add(preset.id), isTrue, reason: '$label duplicate id');
          expect(preset.name.trim(), isNotEmpty, reason: label);
          expect(preset.drugAmount, greaterThan(0), reason: label);
          expect(preset.volumeMl, greaterThan(0), reason: label);
          expect(validatePreset(preset), isNull, reason: label);
          expect(doseAmountUnit, isNotNull, reason: label);
          expect(drugAmountUnit, isNotNull, reason: label);
          expect(
            canConvertAmountUnits(drugAmountUnit!, doseAmountUnit!),
            isTrue,
            reason: '$label unit mismatch',
          );
          expect(
            preset.useWeight,
            normalizeDoseUnitLabel(preset.doseUnit).contains('/kg/'),
            reason: '$label useWeight mismatch',
          );

          if (preset.minDose != null && preset.maxDose != null) {
            expect(
              preset.minDose! <= preset.maxDose!,
              isTrue,
              reason: '$label invalid range',
            );
          }

          final dose = _representativeDose(preset);
          final rate = calculateRate(dose: dose, weight: 60, preset: preset);
          expect(rate.isFinite, isTrue, reason: label);
          expect(rate, greaterThan(0), reason: label);
          expect(
            formatCalculatedRate(roundCalculatedRate(rate, preset), preset),
            isNotEmpty,
            reason: label,
          );
          expect(validateDoseRange(dose, preset), isNull, reason: label);
        }
      }
    });

    test('warns when the dose exceeds the preset maximum', () {
      final preset = DrugPreset(
        id: 'range',
        name: 'test',
        doseUnit: 'mg/hr',
        drugAmount: 50,
        drugUnit: 'mg',
        volumeMl: 50,
        timeUnit: 'hr',
        useWeight: false,
        note: '',
        minDose: 1,
        maxDose: 5,
      );

      final warning = validateDoseRange(7, preset);

      expect(warning, contains('최대 권장 용량'));
    });

    test('normalizes dose labels to the selected time unit', () {
      final normalized = normalizeDoseUnitLabel(' mcg / kg / min ', 'hr');

      expect(normalized, 'mcg/kg/hr');
    });

    test('formats reservoir summaries in clinically readable mass units', () {
      expect(formatReservoirAmount(400000, 'mcg'), '400 mg');
      expect(formatReservoirAmount(1000000, 'mcg'), '1 g');
      expect(
        reservoirSummary(
          drugAmount: 1,
          drugUnit: 'g',
          volumeMl: 50,
          doseUnit: 'mcg/kg/min',
        ),
        '1 g / 50 mL · mcg/kg/min',
      );
    });

    test('labels and calculates the MICU 400 mg propofol preset correctly', () {
      final propofol = defaultMicuPresets().firstWhere(
        (preset) => preset.name == 'propofol 400mg',
      );

      expect(presetDropdownLabel(propofol.name), 'propofol 400mg');
      expect(propofol.drugAmount, 400000);
      expect(propofol.drugUnit, 'mcg');
      expect(propofol.volumeMl, 40);
      expect(
        calculateRate(dose: 10, weight: 70, preset: propofol),
        closeTo(4.2, 0.000001),
      );
    });

    test('labels and calculates the MICU 1 g/50 mL propofol correctly', () {
      final propofol = defaultMicuPresets().firstWhere(
        (preset) => preset.name == 'propofol 1g/50mL',
      );

      expect(presetDropdownLabel(propofol.name), 'propofol 1g/50mL');
      expect(propofol.drugAmount, 1);
      expect(propofol.drugUnit, 'g');
      expect(propofol.volumeMl, 50);
      expect(propofol.doseUnit, 'mcg/kg/min');
      expect(propofol.minDose, 10);
      expect(propofol.maxDose, 40);
      expect(validatePreset(propofol), isNull);
      expect(
        calculateRate(dose: 10, weight: 70, preset: propofol),
        closeTo(2.1, 0.000001),
      );
    });

    test(
      'uses explicit pump increments and detects post-rounding dose warnings',
      () {
        final preset = DrugPreset(
          id: 'rounding',
          name: 'rounding test',
          doseUnit: 'mg/hr',
          drugAmount: 100,
          drugUnit: 'mg',
          volumeMl: 100,
          timeUnit: 'hr',
          useWeight: false,
          note: '',
          maxDose: 0.8,
          rateIncrementMlPerHr: 1,
        );

        final rawRate = calculateRate(dose: 0.76, weight: 0, preset: preset);
        final roundedRate = roundCalculatedRate(rawRate, preset);
        final deliveredDose = calculateDoseFromRate(
          rateMlPerHr: roundedRate,
          weight: 0,
          preset: preset,
        );

        expect(validateDoseRange(0.76, preset), isNull);
        expect(roundedRate, 1);
        expect(deliveredDose, 1);
        expect(validateDoseRange(deliveredDose, preset), contains('최대'));
      },
    );

    test('preserves display precision for sub-milliliter pump increments', () {
      final preset = _testPreset(rateIncrementMlPerHr: 0.0001);

      final rounded = roundCalculatedRate(0.00036, preset);

      expect(rounded, closeTo(0.0004, 0.000000001));
      expect(formatCalculatedRate(rounded, preset), '0.0004');
      expect(
        validatePreset(_testPreset(rateIncrementMlPerHr: 0.0000001)),
        contains('소수점 6자리'),
      );
    });

    test('rejects non-finite inputs and unsafe preset concentrations', () {
      final invalidPreset = DrugPreset(
        id: 'invalid',
        name: 'invalid',
        doseUnit: 'mcg/kg/min',
        drugAmount: 0,
        drugUnit: 'mcg',
        volumeMl: 50,
        timeUnit: 'min',
        useWeight: true,
        note: '',
      );
      final validPreset = DrugPreset(
        id: 'valid',
        name: 'valid',
        doseUnit: 'mcg/kg/min',
        drugAmount: 1000,
        drugUnit: 'mcg',
        volumeMl: 50,
        timeUnit: 'min',
        useWeight: true,
        note: '',
      );

      expect(validatePreset(invalidPreset), isNotNull);
      expect(
        () => calculateRate(dose: double.nan, weight: 70, preset: validPreset),
        throwsA(isA<CalculationInputException>()),
      );
      expect(
        () => calculateRate(
          dose: 1,
          weight: double.infinity,
          preset: validPreset,
        ),
        throwsA(isA<CalculationInputException>()),
      );
    });

    test('repairs duplicate IDs while preserving pump increments', () {
      final first = _testPreset(id: 'duplicate', rateIncrementMlPerHr: 0.5);
      final second = _testPreset(id: 'duplicate', name: 'other');

      final repaired = ensureUniquePresetIds([first, second]);

      expect(repaired.map((item) => item.id).toSet(), hasLength(2));
      expect(repaired.first.rateIncrementMlPerHr, 0.5);
      expect(repaired.last.name, 'other');
    });

    test('upserts an edited preset without creating a duplicate', () {
      final original = _testPreset(id: 'editable', name: 'original');
      final edited = _testPreset(
        id: 'editable',
        name: 'edited',
        rateIncrementMlPerHr: 0.25,
      );

      final updated = upsertPreset([original], edited);

      expect(updated, hasLength(1));
      expect(updated.single.name, 'edited');
      expect(updated.single.rateIncrementMlPerHr, 0.25);
    });

    test('falls back to valid legacy JSON when current JSON is malformed', () {
      final legacyMap = defaultPresetMap();
      legacyMap['micu'] = [_testPreset(id: 'legacy-safe', name: 'legacy safe')];

      final migrated = migratePresetMap(
        currentRaw: '{not valid JSON}',
        legacyRaw: jsonEncode(_encodedPresetMap(legacyMap)),
      );

      expect(migrated['micu']!.single.id, 'legacy-safe');
      expect(migrated['micu']!.single.name, 'legacy safe');
    });

    test('recovers missing departments from legacy JSON independently', () {
      final currentMicu = _testPreset(id: 'current-micu', name: 'current MICU');
      final legacyNcu = _testPreset(id: 'legacy-ncu', name: 'legacy NCU');

      final migrated = migratePresetMap(
        currentRaw: jsonEncode({
          'micu': [currentMicu.toJson()],
        }),
        legacyRaw: jsonEncode({
          'ncu': [legacyNcu.toJson()],
        }),
      );

      expect(migrated['micu']!.single.id, 'current-micu');
      expect(migrated['ncu']!.single.id, 'legacy-ncu');
    });

    test('preserves the legacy heparin whole-mL pump increment', () {
      final legacyHeparin = _testPreset(id: 'heparin', name: 'heparin').toJson()
        ..remove('rateIncrementMlPerHr');

      final migrated = migratePresetMap(
        currentRaw: jsonEncode({
          'micu': [legacyHeparin],
        }),
      );

      expect(migrated['micu']!.single.rateIncrementMlPerHr, 1.0);
    });

    test('drops malformed saved records and keeps valid presets', () {
      final rawMap = _encodedPresetMap(defaultPresetMap());
      rawMap['micu'] = [
        _testPreset(id: 'valid').toJson(),
        {
          'id': 'unsafe',
          'name': 'unsafe',
          'doseUnit': 'mcg/kg/min',
          'drugAmount': 0,
          'drugUnit': 'mcg',
          'volumeMl': 50,
          'timeUnit': 'min',
          'useWeight': true,
          'note': '',
        },
      ];

      final migrated = migratePresetMap(currentRaw: jsonEncode(rawMap));

      expect(migrated['micu']!.map((item) => item.id), contains('valid'));
      expect(migrated['micu']!.map(validatePreset), everyElement(isNull));
    });

    test('migrates the legacy MICU propofol label only for a 400 mg mix', () {
      final legacyMap = defaultPresetMap();
      final legacyPropofol = defaultMicuPresets().firstWhere(
        (preset) => preset.name == 'propofol 400mg',
      );
      legacyMap['micu'] = [
        DrugPreset(
          id: legacyPropofol.id,
          name: 'propofol 200mg',
          doseUnit: legacyPropofol.doseUnit,
          minDose: legacyPropofol.minDose,
          maxDose: legacyPropofol.maxDose,
          drugAmount: legacyPropofol.drugAmount,
          drugUnit: legacyPropofol.drugUnit,
          volumeMl: legacyPropofol.volumeMl,
          timeUnit: legacyPropofol.timeUnit,
          useWeight: legacyPropofol.useWeight,
          note: legacyPropofol.note,
        ),
      ];

      final migrated = migratePresetMap(
        currentRaw: jsonEncode(_encodedPresetMap(legacyMap)),
      );

      expect(migrated['micu']!.single.name, 'propofol 400mg');
    });

    test('adds the new MICU propofol once during the v2-to-v3 migration', () {
      final oldMicuPresets = defaultMicuPresets()
          .where((preset) => preset.name != 'propofol 1g/50mL')
          .toList();

      final migrated = migratePresetMap(
        legacyRaw: jsonEncode({
          'micu': oldMicuPresets.map((preset) => preset.toJson()).toList(),
        }),
        addMissingMicuPropofol1g50Ml: true,
      );

      expect(
        migrated['micu']!
            .where((preset) => preset.name == 'propofol 1g/50mL'),
        hasLength(1),
      );
      expect(
        migrated['micu']!.where((preset) => preset.name == 'propofol 400mg'),
        hasLength(1),
      );
    });

    test('does not duplicate an equivalent custom 1 g/50 mL propofol', () {
      final equivalent = DrugPreset(
        id: 'custom-propofol',
        name: 'Propofol custom 1 g',
        doseUnit: 'mcg/kg/min',
        drugAmount: 1000,
        drugUnit: 'mg',
        volumeMl: 50,
        timeUnit: 'min',
        useWeight: true,
        minDose: 10,
        maxDose: 40,
        note: 'custom',
      );

      final migrated = migratePresetMap(
        legacyRaw: jsonEncode({
          'micu': [equivalent.toJson()],
        }),
        addMissingMicuPropofol1g50Ml: true,
      );

      expect(migrated['micu'], hasLength(1));
      expect(migrated['micu']!.single.id, 'custom-propofol');
    });

    test(
      'uses non-empty legacy preferences when the current value is blank',
      () async {
        SharedPreferences.setMockInitialValues({
          'current': '',
          'legacy': 'legacy-map',
        });
        final preferences = await SharedPreferences.getInstance();

        expect(
          readFirstAvailableString(
              preferences,
              'current',
              const [
                'legacy',
              ],
              ignoreEmpty: true),
          'legacy-map',
        );
      },
    );
  });
}

DrugPreset _testPreset({
  String id = 'test',
  String name = 'test preset',
  double rateIncrementMlPerHr = 0.1,
}) {
  return DrugPreset(
    id: id,
    name: name,
    doseUnit: 'mcg/kg/hr',
    drugAmount: 400,
    drugUnit: 'mcg',
    volumeMl: 100,
    timeUnit: 'hr',
    useWeight: true,
    note: 'test',
    rateIncrementMlPerHr: rateIncrementMlPerHr,
  );
}

Map<String, dynamic> _encodedPresetMap(Map<String, List<DrugPreset>> map) {
  return map.map(
    (departmentId, presets) => MapEntry(
      departmentId,
      presets.map((preset) => preset.toJson()).toList(),
    ),
  );
}

double _representativeDose(DrugPreset preset) {
  if (preset.minDose != null && preset.maxDose != null) {
    return (preset.minDose! + preset.maxDose!) / 2;
  }
  if (preset.minDose != null && preset.minDose! > 0) {
    return preset.minDose!;
  }
  if (preset.maxDose != null && preset.maxDose! > 0) {
    return preset.maxDose!;
  }
  return 1;
}
