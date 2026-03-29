import '../models/drug_preset.dart';

enum DoseAmountUnit { mcg, mg, g, iu }

enum DoseTimeUnit { min, hr, day }

class CalculationInputException implements Exception {
  CalculationInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DoseSpecification {
  const DoseSpecification({
    required this.amountUnit,
    required this.timeUnit,
  });

  final DoseAmountUnit amountUnit;
  final DoseTimeUnit timeUnit;
}

double calculateRate({
  required double dose,
  required double weight,
  required DrugPreset preset,
}) {
  final doseSpec = resolveDoseSpecification(preset);
  final drugAmountUnit = parseDrugAmountUnit(preset.drugUnit);

  if (drugAmountUnit == null) {
    throw CalculationInputException(
      '총 약물량 단위는 mg, mcg, g, iu만 지원해요.',
    );
  }

  final normalizedDrugAmount = convertDrugAmountToDoseUnit(
    amount: preset.drugAmount,
    from: drugAmountUnit,
    to: doseSpec.amountUnit,
  );
  final timeMultiplier = doseTimeRateFactor(doseSpec.timeUnit);
  final weightFactor = preset.useWeight ? weight : 1.0;

  return (dose * weightFactor * timeMultiplier * preset.volumeMl) /
      normalizedDrugAmount;
}

double roundCalculatedRate(double value, DrugPreset preset) {
  if (preset.name.toLowerCase() == 'heparin') {
    return value.roundToDouble();
  }

  return (value * 10).round() / 10;
}

String formatCalculatedRate(double value, DrugPreset preset) {
  if (preset.name.toLowerCase() == 'heparin') {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

String? validateDoseRange(double dose, DrugPreset preset) {
  if (preset.minDose != null && dose < preset.minDose!) {
    return '입력 용량이 최소 권장 용량(${formatOptionalDose(preset.minDose, preset.doseUnit)})보다 낮습니다.';
  }
  if (preset.maxDose != null && dose > preset.maxDose!) {
    return '입력 용량이 최대 권장 용량(${formatOptionalDose(preset.maxDose, preset.doseUnit)})보다 높습니다.';
  }
  return null;
}

String formatNumber(num value) {
  final text = value.toStringAsFixed(2);
  if (text.endsWith('.00')) return text.substring(0, text.length - 3);
  if (text.endsWith('0')) return text.substring(0, text.length - 1);
  return text;
}

String formatOptionalDose(double? value, String unit) {
  if (value == null) return '-';
  return '${formatNumber(value)} $unit';
}

DoseSpecification resolveDoseSpecification(DrugPreset preset) {
  final amountUnit = parseDoseAmountUnit(preset.doseUnit);
  if (amountUnit == null) {
    throw CalculationInputException(
      '목표 용량 단위는 mg, mcg, g, iu 형식만 지원해요. 예: mcg/kg/min',
    );
  }

  final timeUnit =
      inferDoseTimeUnit(preset.doseUnit) ?? doseTimeUnitFromId(preset.timeUnit);

  return DoseSpecification(
    amountUnit: amountUnit,
    timeUnit: timeUnit,
  );
}

bool canConvertAmountUnits(DoseAmountUnit from, DoseAmountUnit to) {
  if (from == to) return true;

  final massUnits = {
    DoseAmountUnit.mcg,
    DoseAmountUnit.mg,
    DoseAmountUnit.g,
  };
  final isMassUnit = massUnits.contains(from) && massUnits.contains(to);

  return isMassUnit;
}

double convertDrugAmountToDoseUnit({
  required double amount,
  required DoseAmountUnit from,
  required DoseAmountUnit to,
}) {
  if (!canConvertAmountUnits(from, to)) {
    throw CalculationInputException(
      '목표 용량 단위와 총 약물량 단위가 서로 맞지 않아요.',
    );
  }

  if (from == to) return amount;

  const amountInMcgFactor = {
    DoseAmountUnit.mcg: 1.0,
    DoseAmountUnit.mg: 1000.0,
    DoseAmountUnit.g: 1000000.0,
  };

  if (amountInMcgFactor.containsKey(from) &&
      amountInMcgFactor.containsKey(to)) {
    final amountInMcg = amount * amountInMcgFactor[from]!;
    return amountInMcg / amountInMcgFactor[to]!;
  }

  return amount;
}

DoseAmountUnit? parseDoseAmountUnit(String doseUnitLabel) {
  final normalized = normalizeDoseUnitLabel(doseUnitLabel);
  if (normalized.isEmpty) return null;

  final amountToken = normalized.split('/').first;
  switch (amountToken) {
    case 'mcg':
      return DoseAmountUnit.mcg;
    case 'mg':
      return DoseAmountUnit.mg;
    case 'g':
      return DoseAmountUnit.g;
    case 'iu':
      return DoseAmountUnit.iu;
    default:
      return null;
  }
}

DoseAmountUnit? parseDrugAmountUnit(String drugUnitLabel) {
  switch (normalizeAmountUnitLabel(drugUnitLabel)) {
    case 'mcg':
      return DoseAmountUnit.mcg;
    case 'mg':
      return DoseAmountUnit.mg;
    case 'g':
      return DoseAmountUnit.g;
    case 'iu':
      return DoseAmountUnit.iu;
    default:
      return null;
  }
}

DoseTimeUnit? inferDoseTimeUnit(String doseUnitLabel) {
  final normalized = normalizeDoseUnitLabel(doseUnitLabel);
  if (normalized.isEmpty || !normalized.contains('/')) return null;

  final timeToken = normalized.split('/').last;
  switch (timeToken) {
    case 'min':
      return DoseTimeUnit.min;
    case 'hr':
      return DoseTimeUnit.hr;
    case 'day':
      return DoseTimeUnit.day;
    default:
      return null;
  }
}

String resolveDoseTimeUnitId(DrugPreset preset) {
  return doseTimeUnitId(resolveDoseSpecification(preset).timeUnit);
}

double doseTimeRateFactor(DoseTimeUnit timeUnit) {
  switch (timeUnit) {
    case DoseTimeUnit.min:
      return 60.0;
    case DoseTimeUnit.day:
      return 1 / 24;
    case DoseTimeUnit.hr:
      return 1.0;
  }
}

String timeUnitFactorLabel(String timeUnitId) {
  switch (doseTimeUnitFromId(timeUnitId)) {
    case DoseTimeUnit.min:
      return '60';
    case DoseTimeUnit.day:
      return '1/24';
    case DoseTimeUnit.hr:
      return '1';
  }
}

String timeUnitFactorLabelForPreset(DrugPreset preset) {
  return timeUnitFactorLabel(resolveDoseTimeUnitId(preset));
}

String timeUnitDescription(String timeUnitId) {
  switch (doseTimeUnitFromId(timeUnitId)) {
    case DoseTimeUnit.min:
      return '분당 × 60';
    case DoseTimeUnit.day:
      return '일당 × 1/24';
    case DoseTimeUnit.hr:
      return '시간당 × 1';
  }
}

DoseTimeUnit doseTimeUnitFromId(String timeUnitId) {
  switch (timeUnitId) {
    case 'min':
      return DoseTimeUnit.min;
    case 'day':
      return DoseTimeUnit.day;
    case 'hr':
    default:
      return DoseTimeUnit.hr;
  }
}

String doseTimeUnitId(DoseTimeUnit timeUnit) {
  switch (timeUnit) {
    case DoseTimeUnit.min:
      return 'min';
    case DoseTimeUnit.day:
      return 'day';
    case DoseTimeUnit.hr:
      return 'hr';
  }
}

String normalizeAmountUnitLabel(String value) {
  var normalized = value.trim().toLowerCase();
  normalized = normalized.replaceAll('μ', 'u').replaceAll('µ', 'u');

  switch (normalized) {
    case 'ug':
      return 'mcg';
    case 'mcg':
    case 'mg':
    case 'g':
    case 'iu':
      return normalized;
    default:
      return normalized;
  }
}

String normalizeDoseUnitLabel(String value, [String? selectedTimeUnitId]) {
  var normalized = value.trim().toLowerCase();
  normalized = normalized.replaceAll('μ', 'u').replaceAll('µ', 'u');
  normalized = normalized.replaceAll(RegExp(r'\s+'), '');
  normalized = normalized.replaceAll('ug', 'mcg');
  normalized = normalized.replaceFirst(RegExp(r'/h$'), '/hr');
  normalized = normalized.replaceFirst(RegExp(r'/d$'), '/day');
  normalized = normalized.replaceFirst(RegExp(r'/m$'), '/min');

  if (selectedTimeUnitId != null &&
      RegExp(r'/(min|hr|day)$').hasMatch(normalized)) {
    normalized = normalized.replaceFirst(
      RegExp(r'/(min|hr|day)$'),
      '/${doseTimeUnitId(doseTimeUnitFromId(selectedTimeUnitId))}',
    );
  }

  return normalized;
}
