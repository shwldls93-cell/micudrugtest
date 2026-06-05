import 'package:flutter_test/flutter_test.dart';
import 'package:micudrugtest/data/default_presets.dart';
import 'package:micudrugtest/models/drug_preset.dart';
import 'package:micudrugtest/services/pump_calculator.dart';
import 'package:micudrugtest/utils/pump_calculator_text.dart';

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
        timeUnit: 'hr',
        useWeight: true,
        note: '',
        minDose: 0.02,
        maxDose: 0.3,
      );

      final rate = calculateRate(
        dose: 0.1,
        weight: 60,
        preset: preset,
      );

      expect(rate, closeTo(6.0, 0.000001));
    });

    test('prefers the dose unit suffix over stale timeUnit data', () {
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

      expect(resolveDoseTimeUnitId(preset), 'min');
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

      final rate = calculateRate(
        dose: 1,
        weight: 0,
        preset: preset,
      );

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
      final precedex =
          presets.firstWhere((preset) => preset.name == 'precedex');

      expect(presets, hasLength(24));
      expect(precedex.doseUnit, 'mcg/kg/hr');
      expect(precedex.maxDose, 1.5);
      expect(
        presets.any((preset) => preset.name == 'norepinephrine (central)'),
        isTrue,
      );
      expect(
        presets.any((preset) => preset.name == 'Labesin'),
        isTrue,
      );
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
          final rate = calculateRate(
            dose: dose,
            weight: 60,
            preset: preset,
          );
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

    test('simplifies selected preset labels', () {
      expect(
        selectedPresetLabel('precedex(dexmedetomidine)'),
        'precedex',
      );
      expect(
        selectedPresetLabel('norepinephrine (central)'),
        'norepinephrine',
      );
    });

    test('extracts preset helper details for the dropdown list', () {
      expect(
        selectedPresetDetail('precedex(dexmedetomidine)'),
        'dexmedetomidine',
      );
      expect(
        selectedPresetDetail('norepinephrine (central)'),
        'central',
      );
      expect(selectedPresetDetail('propofol'), isNull);
    });
  });
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
