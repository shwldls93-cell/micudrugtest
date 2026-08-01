import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:micudrugtest/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

DrugPreset preset({
  String id = 'test-id',
  String name = 'Test infusion',
  String doseUnit = 'mcg/kg/hr',
  double drugAmount = 400,
  String drugUnit = 'mcg',
  double volumeMl = 100,
  String timeUnit = 'hr',
  bool useWeight = true,
  double? minDose,
  double? maxDose,
  double rateIncrementMlPerHr = 0.1,
}) {
  return DrugPreset(
    id: id,
    name: name,
    doseUnit: doseUnit,
    drugAmount: drugAmount,
    drugUnit: drugUnit,
    volumeMl: volumeMl,
    timeUnit: timeUnit,
    useWeight: useWeight,
    minDose: minDose,
    maxDose: maxDose,
    note: 'Test only',
    rateIncrementMlPerHr: rateIncrementMlPerHr,
  );
}

Map<String, dynamic> encodedPresetMap(Map<String, List<DrugPreset>> map) {
  return map.map(
    (departmentId, presets) => MapEntry(
      departmentId,
      presets.map((item) => item.toJson()).toList(),
    ),
  );
}

void main() {
  group('weight, time, concentration, and unit safety', () {
    test('all shipped presets have a valid, dimensionally compatible configuration', () {
      for (final entry in defaultPresetMap().entries) {
        for (final item in entry.value) {
          expect(validatePreset(item), isNull, reason: '${entry.key}: ${item.name}');
        }
      }
    });

    test('converts mg concentration to a mcg prescription before calculating', () {
      final adrenaline = defaultPresetMap()['eicu2']!
          .firstWhere((item) => item.name == 'Adrenaline');

      final rate = calculateRate(dose: 0.1, weight: 70, preset: adrenaline);

      expect(rate, closeTo(5.25, 0.000001));
      expect(roundCalculatedRate(rate, adrenaline), closeTo(5.3, 0.000001));
      expect(formulaDrugAmount(adrenaline), '4000 mcg');
    });

    test('applies kg, minute, hour, and day factors in the correct direction', () {
      final minutePreset = preset(
        drugAmount: 2000,
        volumeMl: 40,
        timeUnit: 'min',
      );
      final dailyPreset = preset(
        doseUnit: 'mg/day',
        drugAmount: 200,
        drugUnit: 'mg',
        volumeMl: 200,
        timeUnit: 'day',
        useWeight: false,
      );

      expect(
        calculateRate(dose: 0.1, weight: 70, preset: minutePreset),
        closeTo(8.4, 0.000001),
      );
      expect(
        calculateRate(dose: 200, weight: 0, preset: dailyPreset),
        closeTo(200 / 24, 0.000001),
      );
    });

    test('does not require weight for a non-weight-based prescription', () {
      final nonWeightPreset = preset(
        doseUnit: 'mg/hr',
        drugAmount: 50,
        drugUnit: 'mg',
        volumeMl: 250,
        useWeight: false,
      );

      expect(calculateRate(dose: 5, weight: 0, preset: nonWeightPreset), 25);
    });

    test('rejects incompatible units instead of treating numeric values as interchangeable', () {
      final incompatible = preset(drugUnit: 'IU');

      expect(validatePreset(incompatible), contains('호환되지'));
      expect(
        () => calculateRate(dose: 0.1, weight: 70, preset: incompatible),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('dose limits and pump rounding', () {
    test('warns below and above configured dose limits, but not at a boundary', () {
      final limited = preset(minDose: 0.2, maxDose: 1.0);

      expect(validateDoseRange(0.199, limited), contains('최소'));
      expect(validateDoseRange(0.2, limited), isNull);
      expect(validateDoseRange(1.0, limited), isNull);
      expect(validateDoseRange(1.001, limited), contains('최대'));
    });

    test('uses an explicit pump increment instead of medication-name-specific rounding', () {
      final tenthMlPump = preset(name: 'Heparin', rateIncrementMlPerHr: 0.1);
      final halfMlPump = preset(rateIncrementMlPerHr: 0.5);

      expect(roundCalculatedRate(8.75, tenthMlPump), closeTo(8.8, 0.000001));
      expect(formatCalculatedRate(8.8, tenthMlPump), '8.8');
      expect(roundCalculatedRate(8.75, halfMlPump), 9.0);
      expect(formatCalculatedRate(9.0, halfMlPump), '9.0');
    });

    test('can detect when rounding a valid target produces an out-of-range delivered dose', () {
      final limited = preset(
        doseUnit: 'mg/hr',
        drugAmount: 100,
        drugUnit: 'mg',
        volumeMl: 100,
        useWeight: false,
        maxDose: 0.8,
        rateIncrementMlPerHr: 1,
      );
      final unroundedRate = calculateRate(dose: 0.76, weight: 0, preset: limited);
      final roundedRate = roundCalculatedRate(unroundedRate, limited);
      final deliveredDose = calculateDoseFromRate(
        rateMlPerHr: roundedRate,
        weight: 0,
        preset: limited,
      );

      expect(validateDoseRange(0.76, limited), isNull);
      expect(roundedRate, 1.0);
      expect(deliveredDose, 1.0);
      expect(validateDoseRange(deliveredDose, limited), contains('최대'));
    });

    test('makes a rate that rounds to zero visible to the caller', () {
      final item = preset(rateIncrementMlPerHr: 0.1);

      expect(roundCalculatedRate(0.04, item), 0.0);
    });
  });

  group('invalid input and unsafe configuration rejection', () {
    test('rejects non-finite or non-positive amounts, volumes, doses, and weights', () {
      expect(validatePreset(preset(drugAmount: 0)), isNotNull);
      expect(validatePreset(preset(volumeMl: double.infinity)), isNotNull);
      expect(validatePreset(preset(minDose: double.nan)), isNotNull);
      expect(
        () => calculateRate(dose: double.nan, weight: 70, preset: preset()),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => calculateRate(dose: 0.1, weight: 0, preset: preset()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects invalid time units and inverted limits rather than silently treating them as hourly', () {
      expect(validatePreset(preset(timeUnit: 'week')), contains('시간 기준'));
      expect(validatePreset(preset(doseUnit: 'mcg/kg/min', timeUnit: 'hr')), contains('일치하지'));
      expect(validatePreset(preset(minDose: 2, maxDose: 1)), contains('최소 용량'));
      expect(() => timeUnitRateFactor('week'), throwsA(isA<ArgumentError>()));
    });
  });

  group('preset editing, identity, and persistence migration', () {
    test('upserts a validated edited preset by ID without creating a duplicate', () {
      final original = preset(id: 'editable', name: 'Original');
      final edited = preset(id: 'editable', name: 'Edited', rateIncrementMlPerHr: 0.25);

      final updated = upsertPreset([original], edited);

      expect(updated, hasLength(1));
      expect(updated.single.name, 'Edited');
      expect(updated.single.rateIncrementMlPerHr, 0.25);
    });

    test('deduplicates persisted IDs while preserving preset content and rounding configuration', () {
      final first = preset(id: 'duplicate', rateIncrementMlPerHr: 0.5);
      final second = preset(id: 'duplicate', name: 'Other preset');
      final repaired = ensureUniquePresetIds([first, second]);

      expect(repaired.map((item) => item.id).toSet(), hasLength(2));
      expect(repaired.first.id, 'duplicate');
      expect(repaired.first.rateIncrementMlPerHr, 0.5);
      expect(repaired.last.name, 'Other preset');
    });

    test('round-trips edited preset data, including the pump increment', () {
      final original = preset(rateIncrementMlPerHr: 0.25, minDose: 0.1, maxDose: 1.2);
      final restored = DrugPreset.fromJson(original.toJson());

      expect(restored.rateIncrementMlPerHr, 0.25);
      expect(restored.minDose, 0.1);
      expect(restored.maxDose, 1.2);
      expect(validatePreset(restored), isNull);
    });

    test('uses valid legacy data when the current saved map is malformed', () {
      final legacyPreset = preset(id: 'legacy-safe', name: 'Legacy safe preset');
      final legacyMap = defaultPresetMap();
      legacyMap['micu'] = [legacyPreset];

      final migrated = migratePresetMap(
        currentRaw: '{not valid JSON}',
        legacyRaw: jsonEncode(encodedPresetMap(legacyMap)),
      );

      expect(migrated['micu']!.single.name, 'Legacy safe preset');
      expect(migrated['micu']!.single.id, 'legacy-safe');
    });

    test('drops malformed records without retaining an unsafe preset', () {
      final valid = preset(id: 'valid');
      final rawMap = encodedPresetMap(defaultPresetMap());
      rawMap['micu'] = [
        valid.toJson(),
        {
          'id': 'unsafe',
          'name': 'Unsafe preset',
          'doseUnit': 'mcg/kg/hr',
          'drugAmount': 0,
          'drugUnit': 'mcg',
          'volumeMl': 100,
          'timeUnit': 'hr',
          'useWeight': true,
          'note': 'Unsafe concentration',
        },
      ];

      final migrated = migratePresetMap(currentRaw: jsonEncode(rawMap));

      expect(migrated['micu']!.map((item) => item.id), contains('valid'));
      expect(migrated['micu']!.map(validatePreset), everyElement(isNull));
    });

    test('falls back to a non-empty legacy string when the current value is blank', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: '',
        legacyStorageKeys.first: 'legacy-map',
      });
      final preferences = await SharedPreferences.getInstance();

      expect(
        readFirstAvailableString(
          preferences,
          storageKey,
          legacyStorageKeys,
          ignoreEmpty: true,
        ),
        'legacy-map',
      );
    });
  });
}
