import 'package:flutter/material.dart';

import '../../models/drug_preset.dart';
import '../../services/pump_calculator.dart';
import '../../utils/pump_calculator_text.dart';
import 'shared_widgets.dart';

class CalculatorSection extends StatelessWidget {
  const CalculatorSection({
    required this.departmentLabel,
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
    required this.showPresetSearchResults,
    required this.onPresetSearchTap,
    required this.onPresetSearchChanged,
    required this.onPresetSearchSelected,
    required this.onClearPresetSearch,
    required this.onChangeDepartment,
    required this.onStartNewPatient,
    required this.onOpenSettings,
    required this.onDoseChanged,
    required this.onWeightChanged,
    super.key,
  });

  final String departmentLabel;
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
  final bool showPresetSearchResults;
  final VoidCallback onPresetSearchTap;
  final ValueChanged<String> onPresetSearchChanged;
  final ValueChanged<String> onPresetSearchSelected;
  final VoidCallback onClearPresetSearch;
  final VoidCallback onChangeDepartment;
  final VoidCallback onStartNewPatient;
  final VoidCallback onOpenSettings;
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
        : '처방용량 × ${preset.useWeight ? '체중 × ' : ''}$timeMultiplier × '
            '${formatNumber(preset.volumeMl)} mL ÷ ${formulaDrugAmount(preset)}';

    return ThemedBoard(
      child: Column(
        children: [
          CloudHeader(
            titleSize: 28,
            footer: CurrentDepartmentBox(
              title: departmentLabel,
              onTap: onChangeDepartment,
            ),
          ),
          const HandDrawnDivider(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '환자가 바뀌면 이전 체중을 지워 주세요.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const Key('new-patient-button'),
                onPressed: onStartNewPatient,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: snoobiInk,
                  side: const BorderSide(color: snoobiInk, width: 1.4),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('새 환자 시작'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Form(
            key: calculatorFormKey,
            child: Column(
              children: [
                Semantics(
                  textField: true,
                  label: '약물 검색 및 선택',
                  child: TextField(
                    key: const Key('preset-search-field'),
                    controller: presetSearchController,
                    onTap: onPresetSearchTap,
                    textInputAction: TextInputAction.search,
                    onChanged: onPresetSearchChanged,
                    onSubmitted: (_) {
                      if (presetSearchResults.isNotEmpty) {
                        onPresetSearchSelected(presetSearchResults.first.id);
                      }
                    },
                    decoration: rowDecoration(
                      hint: '약물명을 검색하거나 눌러서 목록 열기',
                    ).copyWith(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: snoobiInk,
                      ),
                      suffixIcon: showPresetSearchResults ||
                              presetSearchQuery.trim().isNotEmpty
                          ? IconButton(
                              tooltip: '약물 목록 닫기',
                              onPressed: onClearPresetSearch,
                              icon: const Icon(Icons.close_rounded),
                            )
                          : const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: snoobiInk,
                            ),
                    ),
                  ),
                ),
                if (showPresetSearchResults) ...[
                  const SizedBox(height: 10),
                  _PresetSearchResults(
                    results: presetSearchResults,
                    selectedPresetId: selectedPresetId,
                    onSelected: onPresetSearchSelected,
                  ),
                ],
                const SizedBox(height: 12),
                if (preset == null)
                  const _MedicationRequiredBanner()
                else
                  _SelectedMedicationCard(preset: preset),
                const SizedBox(height: 8),
                CalculatorRow(
                  label: '몸무게',
                  child: TextFormField(
                    key: const Key('weight-field'),
                    controller: weightController,
                    enabled: preset?.useWeight ?? false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: rowDecoration(hint: '몸무게 입력'),
                    validator: preset?.useWeight ?? false
                        ? (value) => _validatePositiveNumber(value, '몸무게')
                        : null,
                    onChanged: (_) => onWeightChanged(),
                  ),
                  suffix: const UnitLabel('kg'),
                ),
                if (preset != null && !preset.useWeight)
                  const Padding(
                    padding: EdgeInsets.only(top: 2, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '체중을 사용하지 않는 약물입니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                  ),
                CalculatorRow(
                  label: '처방용량',
                  child: TextFormField(
                    key: const Key('dose-field'),
                    controller: doseController,
                    enabled: preset != null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: rowDecoration(hint: '처방용량 입력'),
                    validator: preset == null
                        ? null
                        : (value) => _validatePositiveNumber(value, '처방용량'),
                    onChanged: (_) => onDoseChanged(),
                  ),
                  suffix: UnitLabel(preset?.doseUnit ?? '-'),
                ),
                CalculatorRow(
                  label: '주입속도',
                  child: ResultBox(
                    value: resultValue,
                    isWarning: resultDoseWarning || resultError,
                  ),
                  suffix: RateSuffix(showWarning: resultDoseWarning),
                ),
                if (resultDetail.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ResultStatusBanner(
                    key: const Key('result-status-banner'),
                    message: resultDetail,
                    isWarning: resultDoseWarning || resultError,
                  ),
                ],
                if (preset != null) ...[
                  const HandDrawnDivider(),
                  _NoteBoard(
                    mixLine: mixLine,
                    rangeText: rangeText,
                    formulaText: formulaText,
                    additionalNote: extractAdditionalNote(preset.note),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('open-settings-button'),
              onPressed: onOpenSettings,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: snoobiInk,
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('약물 설정 관리'),
            ),
          ),
        ],
      ),
    );
  }
}

String? _validatePositiveNumber(String? value, String label) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '$label을 입력해 주세요.';
  final parsed = double.tryParse(text);
  if (parsed == null || !parsed.isFinite) return '숫자만 입력해 주세요.';
  if (parsed <= 0) return '0보다 큰 숫자를 입력해 주세요.';
  return null;
}

class _MedicationRequiredBanner extends StatelessWidget {
  const _MedicationRequiredBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '약물이 선택되지 않았습니다',
      child: Container(
        key: const Key('medication-required-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: roundedDecoration(color: snoobiCream),
        child: const Row(
          children: [
            Icon(Icons.touch_app_rounded, size: 21, color: snoobiInk),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '약물을 먼저 선택해 주세요. 선택 전에는 계산할 수 없습니다.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  color: snoobiInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMedicationCard extends StatelessWidget {
  const _SelectedMedicationCard({required this.preset});

  final DrugPreset preset;

  @override
  Widget build(BuildContext context) {
    final summary = reservoirSummary(
      drugAmount: preset.drugAmount,
      drugUnit: preset.drugUnit,
      volumeMl: preset.volumeMl,
      doseUnit: preset.doseUnit,
    );

    return Semantics(
      container: true,
      label: '선택 약물 ${preset.name}, $summary',
      child: Container(
        key: const Key('selected-medication-card'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: roundedDecoration(color: const Color(0xFFE8F7FF)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '선택 약물',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF52606D),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              presetDropdownLabel(preset.name),
              style: const TextStyle(
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w900,
                color: snoobiInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w800,
                color: snoobiInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultStatusBanner extends StatelessWidget {
  const ResultStatusBanner({
    required this.message,
    required this.isWarning,
    super.key,
  });

  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? const Color(0xFFC12828) : const Color(0xFF0F6784);
    final background =
        isWarning ? const Color(0xFFFFE9E7) : const Color(0xFFE8F7FF);

    return Semantics(
      liveRegion: true,
      label: isWarning ? '계산 경고: $message' : '계산 안내: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              size: 21,
              color: color,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
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
        color: snoobiPaper,
        border: Border.all(color: snoobiInk, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            results.isEmpty ? '검색 결과가 없어요' : '검색 결과 ${results.length}개',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: snoobiInk,
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
      key: ValueKey('preset-search-result-${preset.id}'),
      color: selected ? const Color(0xFFE8F7FF) : const Color(0xFFFFFCDA),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presetDropdownLabel(preset.name),
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: snoobiInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservoirSummary(
                        drugAmount: preset.drugAmount,
                        drugUnit: preset.drugUnit,
                        volumeMl: preset.volumeMl,
                        doseUnit: preset.doseUnit,
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF52606D),
                      ),
                    ),
                  ],
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
  });

  final String mixLine;
  final String rangeText;
  final String formulaText;
  final String additionalNote;

  @override
  Widget build(BuildContext context) {
    final hasAdditionalNote = additionalNote.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      child: ScallopedCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(label: 'Mix', value: mixLine),
            const SizedBox(height: 12),
            _InfoLine(label: 'Range', value: rangeText),
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('calculation-details-tile'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 2),
                title: const Text(
                  '계산 근거 및 주석 보기',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: snoobiInk,
                  ),
                ),
                children: [
                  _InfoLine(label: '공식', value: formulaText),
                  if (hasAdditionalNote) ...[
                    const SizedBox(height: 12),
                    _InfoLine(label: '주석', value: additionalNote),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            fontSize: 17,
            height: 1,
            fontWeight: FontWeight.w900,
            color: snoobiInk,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w900,
              color: snoobiInk,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w800,
              color: snoobiInk,
            ),
          ),
        ),
      ],
    );
  }
}
