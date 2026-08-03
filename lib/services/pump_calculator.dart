import '../models/drug_preset.dart';

enum DoseAmountUnit { mcg, mg, g, iu }

enum DoseTimeUnit { min, hr, day }

const supportedTimeUnitIds = {'min', 'hr', 'day'};

class CalculationInputException implements Exception {
  CalculationInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DoseSpecification {
  const DoseSpecification({required this.amountUnit, required this.timeUnit});

  final DoseAmountUnit amountUnit;
  final DoseTimeUnit timeUnit;
}

bool isFinitePositive(double? value) =>
    value != null && value.isFinite && value > 0;

bool isFiniteNonNegative(double? value) =>
    value != null && value.isFinite && value >= 0;

String? validatePreset(DrugPreset preset) {
  if (preset.name.trim().isEmpty) return '약물명이 비어 있습니다.';
  if (preset.doseUnit.trim().isEmpty) return '목표 용량 단위가 비어 있습니다.';
  if (!isFinitePositive(preset.drugAmount)) {
    return '총 약물량은 0보다 큰 유한한 숫자여야 합니다.';
  }
  if (!isFinitePositive(preset.volumeMl)) {
    return '최종 부피는 0보다 큰 유한한 숫자여야 합니다.';
  }
  if (!isFinitePositive(preset.rateIncrementMlPerHr)) {
    return '펌프 반올림 단위는 0보다 큰 유한한 숫자여야 합니다.';
  }
  if (_rateIncrementDecimalPlaces(preset.rateIncrementMlPerHr) == null) {
    return '펌프 반올림 단위는 소수점 6자리 이내로 입력해야 합니다.';
  }
  if (!supportedTimeUnitIds.contains(preset.timeUnit)) {
    return '시간 기준은 min, hr, day 중 하나여야 합니다.';
  }
  if (preset.minDose != null && !isFiniteNonNegative(preset.minDose)) {
    return '최소 용량은 0 이상의 유한한 숫자여야 합니다.';
  }
  if (preset.maxDose != null && !isFiniteNonNegative(preset.maxDose)) {
    return '최대 용량은 0 이상의 유한한 숫자여야 합니다.';
  }
  if (preset.minDose != null &&
      preset.maxDose != null &&
      preset.minDose! > preset.maxDose!) {
    return '최소 용량은 최대 용량보다 클 수 없습니다.';
  }

  final doseAmountUnit = parseDoseAmountUnit(preset.doseUnit);
  final drugAmountUnit = parseDrugAmountUnit(preset.drugUnit);
  if (doseAmountUnit == null || drugAmountUnit == null) {
    return '총 약물량과 목표 용량의 단위를 인식할 수 없습니다.';
  }
  if (!canConvertAmountUnits(drugAmountUnit, doseAmountUnit)) {
    return '총 약물량과 목표 용량의 단위가 호환되지 않습니다.';
  }

  final doseTimeUnit = inferDoseTimeUnit(preset.doseUnit);
  if (doseTimeUnit == null) {
    return '목표 용량 단위에 min, hr, day 시간 기준을 포함해야 합니다.';
  }
  if (doseTimeUnitId(doseTimeUnit) != preset.timeUnit) {
    return '목표 용량 단위의 시간 기준과 선택한 시간 기준이 일치하지 않습니다.';
  }

  final normalizedDoseUnit = normalizeDoseUnitLabel(preset.doseUnit);
  final hasWeightToken = normalizedDoseUnit.contains('/kg/');
  if (hasWeightToken != preset.useWeight) {
    return '목표 용량 단위의 kg 기준과 체중 기반 설정이 일치하지 않습니다.';
  }
  return null;
}

double calculateRate({
  required double dose,
  required double weight,
  required DrugPreset preset,
}) {
  final presetError = validatePreset(preset);
  if (presetError != null) throw CalculationInputException(presetError);
  if (!isFinitePositive(dose)) {
    throw CalculationInputException('목표 용량은 0보다 큰 유한한 숫자여야 합니다.');
  }
  if (preset.useWeight && !isFinitePositive(weight)) {
    throw CalculationInputException('체중은 0보다 큰 유한한 숫자여야 합니다.');
  }

  final doseSpec = resolveDoseSpecification(preset);
  final drugAmountUnit = parseDrugAmountUnit(preset.drugUnit)!;
  final normalizedDrugAmount = convertDrugAmountToDoseUnit(
    amount: preset.drugAmount,
    from: drugAmountUnit,
    to: doseSpec.amountUnit,
  );
  final timeMultiplier = doseTimeRateFactor(doseSpec.timeUnit);
  final weightFactor = preset.useWeight ? weight : 1.0;
  final rate = (dose * weightFactor * timeMultiplier * preset.volumeMl) /
      normalizedDrugAmount;
  if (!rate.isFinite || rate < 0) {
    throw CalculationInputException('계산 결과가 유효하지 않습니다.');
  }
  return rate;
}

double calculateDoseFromRate({
  required double rateMlPerHr,
  required double weight,
  required DrugPreset preset,
}) {
  final presetError = validatePreset(preset);
  if (presetError != null) throw CalculationInputException(presetError);
  if (!isFiniteNonNegative(rateMlPerHr)) {
    throw CalculationInputException('주입속도는 0 이상의 유한한 숫자여야 합니다.');
  }
  if (preset.useWeight && !isFinitePositive(weight)) {
    throw CalculationInputException('체중은 0보다 큰 유한한 숫자여야 합니다.');
  }

  final doseSpec = resolveDoseSpecification(preset);
  final drugAmountUnit = parseDrugAmountUnit(preset.drugUnit)!;
  final normalizedDrugAmount = convertDrugAmountToDoseUnit(
    amount: preset.drugAmount,
    from: drugAmountUnit,
    to: doseSpec.amountUnit,
  );
  final denominator = (preset.useWeight ? weight : 1.0) *
      doseTimeRateFactor(doseSpec.timeUnit) *
      preset.volumeMl;
  final dose = rateMlPerHr * normalizedDrugAmount / denominator;
  if (!dose.isFinite || dose < 0) {
    throw CalculationInputException('역산된 용량이 유효하지 않습니다.');
  }
  return dose;
}

double roundCalculatedRate(double value, DrugPreset preset) {
  if (!isFiniteNonNegative(value)) {
    throw CalculationInputException('주입속도는 0 이상의 유한한 숫자여야 합니다.');
  }
  if (!isFinitePositive(preset.rateIncrementMlPerHr)) {
    throw CalculationInputException('펌프 반올림 단위가 올바르지 않습니다.');
  }
  return (value / preset.rateIncrementMlPerHr).round() *
      preset.rateIncrementMlPerHr;
}

String formatCalculatedRate(double value, DrugPreset preset) {
  if (!isFiniteNonNegative(value) ||
      !isFinitePositive(preset.rateIncrementMlPerHr)) {
    return '--';
  }

  final digits = _rateIncrementDecimalPlaces(preset.rateIncrementMlPerHr);
  if (digits == null) return '--';
  return value.toStringAsFixed(digits);
}

int? _rateIncrementDecimalPlaces(double value) {
  for (var digits = 0; digits <= 6; digits += 1) {
    final rounded = double.parse(value.toStringAsFixed(digits));
    if ((value - rounded).abs() <= 0.000000001) return digits;
  }
  return null;
}

String? validateDoseRange(double dose, DrugPreset preset) {
  if (!dose.isFinite) return '입력 용량은 유한한 숫자여야 합니다.';
  if (preset.minDose != null && dose < preset.minDose!) {
    return '입력 용량이 최소 권장 용량(${formatOptionalDose(preset.minDose, preset.doseUnit)})보다 낮습니다.';
  }
  if (preset.maxDose != null && dose > preset.maxDose!) {
    return '입력 용량이 최대 권장 용량(${formatOptionalDose(preset.maxDose, preset.doseUnit)})보다 높습니다.';
  }
  return null;
}

String formatNumber(num value) {
  if (!value.isFinite) return '--';
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

  final timeUnit = inferDoseTimeUnit(preset.doseUnit);
  if (timeUnit == null) {
    throw CalculationInputException('목표 용량 단위에 min, hr, day 시간 기준을 포함해 주세요.');
  }
  if (!supportedTimeUnitIds.contains(preset.timeUnit) ||
      doseTimeUnitId(timeUnit) != preset.timeUnit) {
    throw CalculationInputException('목표 용량 단위와 선택한 시간 기준이 일치하지 않아요.');
  }

  return DoseSpecification(amountUnit: amountUnit, timeUnit: timeUnit);
}

bool canConvertAmountUnits(DoseAmountUnit from, DoseAmountUnit to) {
  if (from == to) return true;

  const massUnits = {DoseAmountUnit.mcg, DoseAmountUnit.mg, DoseAmountUnit.g};
  return massUnits.contains(from) && massUnits.contains(to);
}

double convertDrugAmountToDoseUnit({
  required double amount,
  required DoseAmountUnit from,
  required DoseAmountUnit to,
}) {
  if (!amount.isFinite) {
    throw CalculationInputException('총 약물량은 유한한 숫자여야 합니다.');
  }
  if (!canConvertAmountUnits(from, to)) {
    throw CalculationInputException('목표 용량 단위와 총 약물량 단위가 서로 맞지 않아요.');
  }
  if (from == to) return amount;

  const amountInMcgFactor = {
    DoseAmountUnit.mcg: 1.0,
    DoseAmountUnit.mg: 1000.0,
    DoseAmountUnit.g: 1000000.0,
  };
  final amountInMcg = amount * amountInMcgFactor[from]!;
  return amountInMcg / amountInMcgFactor[to]!;
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
    case 'unit':
    case 'units':
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

DoseTimeUnit doseTimeUnitFromId(String timeUnitId) {
  switch (timeUnitId) {
    case 'min':
      return DoseTimeUnit.min;
    case 'day':
      return DoseTimeUnit.day;
    case 'hr':
      return DoseTimeUnit.hr;
    default:
      throw CalculationInputException('지원하지 않는 시간 기준이에요.');
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
    case 'unit':
    case 'units':
      return 'iu';
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

String formulaDrugAmount(DrugPreset preset) {
  final sourceUnit = parseDrugAmountUnit(preset.drugUnit);
  final targetUnit = parseDoseAmountUnit(preset.doseUnit);
  if (sourceUnit == null || targetUnit == null) {
    return '${formatNumber(preset.drugAmount)} ${preset.drugUnit}';
  }

  try {
    final converted = convertDrugAmountToDoseUnit(
      amount: preset.drugAmount,
      from: sourceUnit,
      to: targetUnit,
    );
    return '${formatNumber(converted)} ${doseAmountUnitLabel(targetUnit)}';
  } on CalculationInputException {
    return '${formatNumber(preset.drugAmount)} ${preset.drugUnit}';
  }
}

String doseAmountUnitLabel(DoseAmountUnit unit) {
  switch (unit) {
    case DoseAmountUnit.mcg:
      return 'mcg';
    case DoseAmountUnit.mg:
      return 'mg';
    case DoseAmountUnit.g:
      return 'g';
    case DoseAmountUnit.iu:
      return 'IU';
  }
}
