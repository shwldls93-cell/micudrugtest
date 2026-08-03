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
    this.rateIncrementMlPerHr = 0.1,
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
  final double rateIncrementMlPerHr;

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
      rateIncrementMlPerHr: rateIncrementMlPerHr,
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
      'rateIncrementMlPerHr': rateIncrementMlPerHr,
    };
  }

  factory DrugPreset.fromJson(Map<String, dynamic> json) {
    return DrugPreset(
      id: json['id'] is String && (json['id'] as String).trim().isNotEmpty
          ? json['id'] as String
          : uniqueId(),
      name: (json['name'] as String?) ?? '',
      doseUnit: (json['doseUnit'] as String?) ?? '',
      minDose: (json['minDose'] as num?)?.toDouble(),
      maxDose: (json['maxDose'] as num?)?.toDouble(),
      drugAmount: ((json['drugAmount'] as num?) ?? 0).toDouble(),
      drugUnit: (json['drugUnit'] as String?) ?? '',
      volumeMl: ((json['volumeMl'] as num?) ?? 0).toDouble(),
      timeUnit: (json['timeUnit'] as String?) ?? '',
      useWeight: (json['useWeight'] as bool?) ?? true,
      note: (json['note'] as String?) ?? '',
      rateIncrementMlPerHr:
          ((json['rateIncrementMlPerHr'] as num?) ?? 0.1).toDouble(),
    );
  }

  static DrugPreset? tryFromJson(Map<String, dynamic> json) {
    const requiredStringFields = [
      'name',
      'doseUnit',
      'drugUnit',
      'timeUnit',
      'note',
    ];
    if (requiredStringFields.any((field) => json[field] is! String) ||
        json['drugAmount'] is! num ||
        json['volumeMl'] is! num ||
        json['useWeight'] is! bool ||
        (json['id'] != null && json['id'] is! String) ||
        (json['minDose'] != null && json['minDose'] is! num) ||
        (json['maxDose'] != null && json['maxDose'] is! num) ||
        (json['rateIncrementMlPerHr'] != null &&
            json['rateIncrementMlPerHr'] is! num)) {
      return null;
    }

    return DrugPreset.fromJson(json);
  }
}

int _uniqueIdCounter = 0;

String uniqueId() {
  _uniqueIdCounter += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_uniqueIdCounter';
}
