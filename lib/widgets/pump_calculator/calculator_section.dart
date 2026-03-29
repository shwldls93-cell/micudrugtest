import 'package:flutter/material.dart';

import '../../models/drug_preset.dart';
import '../../services/pump_calculator.dart';
import '../../utils/pump_calculator_text.dart';
import 'shared_widgets.dart';

class CalculatorSection extends StatelessWidget {
  const CalculatorSection({
    required this.departmentLabel,
    required this.presets,
    required this.selectedPresetId,
    required this.selectedPreset,
    required this.doseController,
    required this.weightController,
    required this.resultValue,
    required this.resultDetail,
    required this.resultError,
    required this.resultDoseWarning,
    required this.calculatorFormKey,
    required this.presetSearchController,
    required this.presetSearchQuery,
    required this.presetSearchResults,
    required this.onPresetChanged,
    required this.onPresetSearchChanged,
    required this.onPresetSearchSelected,
    required this.onClearPresetSearch,
    required this.onChangeDepartment,
    required this.onResetPresets,
    required this.editor,
    required this.onDoseChanged,
    required this.onWeightChanged,
    super.key,
  });

  final String departmentLabel;
  final List<DrugPreset> presets;
  final String? selectedPresetId;
  final DrugPreset? selectedPreset;
  final TextEditingController doseController;
  final TextEditingController weightController;
  final String resultValue;
  final String resultDetail;
  final bool resultError;
  final bool resultDoseWarning;
  final GlobalKey<FormState> calculatorFormKey;
  final TextEditingController presetSearchController;
  final String presetSearchQuery;
  final List<DrugPreset> presetSearchResults;
  final ValueChanged<String?> onPresetChanged;
  final ValueChanged<String> onPresetSearchChanged;
  final ValueChanged<String> onPresetSearchSelected;
  final VoidCallback onClearPresetSearch;
  final VoidCallback onChangeDepartment;
  final VoidCallback onResetPresets;
  final Widget editor;
  final VoidCallback onDoseChanged;
  final VoidCallback onWeightChanged;

  @override
  Widget build(BuildContext context) {
    final preset = selectedPreset;
    final timeMultiplier =
        preset == null ? '1' : timeUnitFactorLabelForPreset(preset);
    final rangeText = preset == null
        ? '-'
        : '${formatOptionalDose(preset.minDose, preset.doseUnit)} ~ ${formatOptionalDose(preset.maxDose, preset.doseUnit)}';
    final mixLine =
        preset == null ? '-' : extractMixLine(preset.note, preset.name);
    final formulaText = preset == null
        ? '-'
        : '목표용량 × ${preset.useWeight ? '체중 × ' : ''}$timeMultiplier × ${formatNumber(preset.volumeMl)} ÷ ${formatNumber(preset.drugAmount)}';

    return ThemedBoard(
      child: Column(
        children: [
          CloudHeader(
            titleSize: 34,
            subtitle: '입력값만 넣으면 infusion pump 속도를 바로 확인할 수 있어요',
            footer: CurrentDepartmentBox(
              title: departmentLabel,
              onTap: onChangeDepartment,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration:
                roundedDecoration(color: const Color(0xFFFFFFFF), radius: 32),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: calculatorFormKey,
                child: Column(
                  children: [
                    CalculatorRow(
                      label: '약물선택',
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(selectedPresetId),
                        initialValue: selectedPresetId,
                        isExpanded: true,
                        icon: const SizedBox.shrink(),
                        decoration: rowDecoration(),
                        items: presets
                            .map(
                              (preset) => DropdownMenuItem(
                                value: preset.id,
                                child: _PresetDropdownLabel(
                                  text: presetDropdownLabel(preset.name),
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) => presets
                            .map(
                              (preset) => _PresetDropdownLabel(
                                text: presetDropdownLabel(preset.name),
                                scaleToFit: true,
                              ),
                            )
                            .toList(),
                        onChanged: onPresetChanged,
                      ),
                      suffix: const CalculatorSuffixSlot(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28,
                          color: Color(0xFF0F6784),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: presetSearchController,
                      textInputAction: TextInputAction.search,
                      onChanged: onPresetSearchChanged,
                      onSubmitted: (_) {
                        if (presetSearchResults.isNotEmpty) {
                          onPresetSearchSelected(presetSearchResults.first.id);
                        }
                      },
                      decoration: rowDecoration(hint: '검색해서 바로 약물 찾기').copyWith(
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF0F6784),
                        ),
                        suffixIcon: presetSearchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: onClearPresetSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    if (presetSearchQuery.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _PresetSearchResults(
                        results: presetSearchResults,
                        selectedPresetId: selectedPresetId,
                        onSelected: onPresetSearchSelected,
                      ),
                    ],
                    const SizedBox(height: 14),
                    CalculatorRow(
                      label: '몸무게',
                      child: TextFormField(
                        controller: weightController,
                        enabled: preset?.useWeight ?? true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: rowDecoration(hint: '몸무게 입력'),
                        onChanged: (_) => onWeightChanged(),
                      ),
                      suffix: const UnitLabel('kg'),
                    ),
                    if (!(preset?.useWeight ?? true))
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '체중 불필요 약물입니다.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    CalculatorRow(
                      label: '주입용량',
                      child: TextFormField(
                        controller: doseController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: rowDecoration(hint: '용량 입력'),
                        onChanged: (_) => onDoseChanged(),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? '용량 입력'
                                : double.tryParse(value.trim()) == null
                                    ? '숫자 입력'
                                    : null,
                      ),
                      suffix: UnitLabel(preset?.doseUnit ?? '약물단위'),
                    ),
                    const SizedBox(height: 14),
                    CalculatorRow(
                      label: '주입속도',
                      child: ResultBox(
                        value: resultValue,
                        isWarning: resultDoseWarning,
                      ),
                      suffix: RateSuffix(showWarning: resultDoseWarning),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: onResetPresets,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F6784),
                          side: const BorderSide(color: Color(0xFFB8D8E6)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('현재 부서 기본값 복원'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _NoteBoard(
                      mixLine: mixLine,
                      rangeText: rangeText,
                      formulaText: formulaText,
                      additionalNote: preset == null
                          ? ''
                          : extractAdditionalNote(preset.note),
                      resultDetail: resultDetail,
                      resultError: resultError,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          editor,
        ],
      ),
    );
  }
}

class _PresetDropdownLabel extends StatelessWidget {
  const _PresetDropdownLabel({
    required this.text,
    this.scaleToFit = false,
  });

  final String text;
  final bool scaleToFit;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: scaleToFit ? TextOverflow.visible : TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: scaleToFit
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: label,
            )
          : label,
    );
  }
}

class _PresetSearchResults extends StatelessWidget {
  const _PresetSearchResults({
    required this.results,
    required this.selectedPresetId,
    required this.onSelected,
  });

  final List<DrugPreset> results;
  final String? selectedPresetId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleResults = results.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            results.isEmpty ? '검색 결과가 없어요' : '검색 결과 ${results.length}개',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475467),
            ),
          ),
          if (results.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              '약물명이나 약물 구분어로 다시 검색해 보세요.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667085),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            for (final preset in visibleResults) ...[
              _PresetSearchResultTile(
                preset: preset,
                selected: preset.id == selectedPresetId,
                onTap: () => onSelected(preset.id),
              ),
              if (preset != visibleResults.last) const SizedBox(height: 8),
            ],
            if (results.length > visibleResults.length) ...[
              const SizedBox(height: 10),
              Text(
                '외 ${results.length - visibleResults.length}개 더 있어요. 검색어를 조금 더 입력해 보세요.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF667085),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PresetSearchResultTile extends StatelessWidget {
  const _PresetSearchResultTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final DrugPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF7FD) : const Color(0xFFF9FBFD),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF163647),
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0F6784),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteBoard extends StatelessWidget {
  const _NoteBoard({
    required this.mixLine,
    required this.rangeText,
    required this.formulaText,
    required this.additionalNote,
    required this.resultDetail,
    required this.resultError,
  });

  final String mixLine;
  final String rangeText;
  final String formulaText;
  final String additionalNote;
  final String resultDetail;
  final bool resultError;

  @override
  Widget build(BuildContext context) {
    final hasAdditionalNote = additionalNote.trim().isNotEmpty;
    final hasResultDetail = resultDetail.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: '혼합', value: mixLine, maxLines: 2),
          const SizedBox(height: 14),
          _InfoLine(label: '범위', value: rangeText),
          const SizedBox(height: 14),
          _InfoLine(label: '계산', value: formulaText),
          if (hasAdditionalNote) ...[
            const SizedBox(height: 18),
            Text(
              additionalNote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475467),
              ),
            ),
          ],
          if (hasResultDetail) ...[
            const SizedBox(height: 14),
            Text(
              resultDetail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: resultError
                    ? const Color(0xFFC12828)
                    : const Color(0xFF475467),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ],
    );
  }
}
