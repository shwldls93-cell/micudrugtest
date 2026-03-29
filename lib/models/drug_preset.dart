class DepartmentPreset {
  DepartmentPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.presets,
  });

  final String id;
  final String label;
  final String icon;
  final String description;
  final List<DrugPreset> presets;

  String get displayTitle => label;
}

class DrugPreset {
  DrugPreset({
    required this.id,
    required this.name,
    required this.doseUnit,
    required this.drugAmount,
    required this.drugUnit,
    required this.volumeMl,
    required this.timeUnit,
    required this.useWeight,
    required this.note,
    this.minDose,
    this.maxDose,
  });

  final String id;
  final String name;
  final String doseUnit;
  final double? minDose;
  final double? maxDose;
  final double drugAmount;
  final String drugUnit;
  final double volumeMl;
  final String timeUnit;
  final bool useWeight;
  final String note;

  DrugPreset copy() {
    return DrugPreset(
      id: id,
      name: name,
      doseUnit: doseUnit,
      minDose: minDose,
      maxDose: maxDose,
      drugAmount: drugAmount,
      drugUnit: drugUnit,
      volumeMl: volumeMl,
      timeUnit: timeUnit,
      useWeight: useWeight,
      note: note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'doseUnit': doseUnit,
      'minDose': minDose,
      'maxDose': maxDose,
      'drugAmount': drugAmount,
      'drugUnit': drugUnit,
      'volumeMl': volumeMl,
      'timeUnit': timeUnit,
      'useWeight': useWeight,
      'note': note,
    };
  }

  factory DrugPreset.fromJson(Map<String, dynamic> json) {
    return DrugPreset(
      id: (json['id'] as String?) ?? uniqueId(),
      name: (json['name'] as String?) ?? '',
      doseUnit: (json['doseUnit'] as String?) ?? '',
      minDose: (json['minDose'] as num?)?.toDouble(),
      maxDose: (json['maxDose'] as num?)?.toDouble(),
      drugAmount: ((json['drugAmount'] as num?) ?? 0).toDouble(),
      drugUnit: (json['drugUnit'] as String?) ?? '',
      volumeMl: ((json['volumeMl'] as num?) ?? 0).toDouble(),
      timeUnit: (json['timeUnit'] as String?) ?? 'min',
      useWeight: (json['useWeight'] as bool?) ?? true,
      note: (json['note'] as String?) ?? '',
    );
  }
}

int _uniqueIdCounter = 0;

String uniqueId() {
  _uniqueIdCounter += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_uniqueIdCounter';
}
