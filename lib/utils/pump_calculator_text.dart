String normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[\s()/_-]+'), '');
}

String presetDropdownLabel(String presetName) {
  return presetName.trim().replaceAllMapped(
        RegExp(r'([A-Za-z가-힣])\('),
        (match) => '${match.group(1)} (',
      );
}

String selectedPresetLabel(String presetName) {
  final normalized = presetDropdownLabel(presetName).trim();
  return normalized.replaceFirst(RegExp(r'\s*\([^()]+\)\s*$'), '').trim();
}

String? selectedPresetDetail(String presetName) {
  final normalized = presetDropdownLabel(presetName).trim();
  final match = RegExp(r'\(([^()]+)\)\s*$').firstMatch(normalized);
  final detail = match?.group(1)?.trim();

  if (detail == null || detail.isEmpty) {
    return null;
  }

  return detail;
}

String mixDrugLabel(String drugName) {
  final trimmed = drugName.trim();

  if (RegExp(r'^[A-Za-z가-힣]+\([^()]+\)$').hasMatch(trimmed)) {
    return trimmed.substring(0, trimmed.indexOf('(')).trim();
  }

  return presetDropdownLabel(trimmed).trim();
}

String extractMixLine(String note, String drugName) {
  if (note.trim().isEmpty) return '-';
  final lines = note.split('\n');

  String attachDrugName(String mixBody) {
    final normalizedDrugName = mixDrugLabel(drugName);
    final normalizedMixBody = mixBody.trim();

    if (normalizedDrugName.isEmpty || normalizedMixBody.isEmpty) {
      return normalizedMixBody;
    }

    if (normalizedMixBody.toLowerCase().startsWith(
          normalizedDrugName.toLowerCase(),
        )) {
      return normalizedMixBody;
    }

    return '$normalizedDrugName $normalizedMixBody';
  }

  for (final line in lines) {
    if (line.toLowerCase().contains('mix')) {
      final mixBody = line.replaceFirst(
        RegExp(r'^mix\s*', caseSensitive: false),
        '',
      );
      return attachDrugName(mixBody);
    }
  }
  return attachDrugName(lines.first);
}

String extractAdditionalNote(String note) {
  if (note.trim().isEmpty) return '';

  final allLines = note
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final hasExplicitMixLine = allLines.any(
    (line) => line.toLowerCase().startsWith('mix'),
  );
  final extraLines = allLines
      .skip(hasExplicitMixLine ? 0 : 1)
      .where((line) => !line.toLowerCase().startsWith('mix'))
      .where((line) => !RegExp(r'^min\s', caseSensitive: false).hasMatch(line))
      .toList();

  return extraLines.join('\n');
}
