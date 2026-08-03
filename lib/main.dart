import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/default_presets.dart' as preset_data;
import 'models/drug_preset.dart';
import 'services/pump_calculator.dart';
import 'services/preset_storage.dart';
import 'utils/pump_calculator_text.dart';
import 'widgets/pump_calculator/calculator_section.dart';
import 'widgets/pump_calculator/landing_section.dart';
import 'widgets/pump_calculator/layout_constants.dart';
import 'widgets/pump_calculator/shared_widgets.dart';

const storageKey = 'icu_infusion_presets_by_department_v3';
const selectedDepartmentKey = 'icu_selected_department_v2';
const legacyStorageKeys = [
  'icu_infusion_presets_by_department_v2',
  'icu_infusion_presets_by_department_v1',
];
const legacySelectedDepartmentKeys = ['icu_selected_department_v1'];

void main() {
  runApp(const JjonddeukCalculatorApp());
}

class JjonddeukCalculatorApp extends StatelessWidget {
  const JjonddeukCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '스누비 쫀득 계산기',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6784),
          primary: const Color(0xFF0F6784),
          secondary: const Color(0xFFFFD9E4),
          surface: const Color(0xFFFFFFFF),
        ),
      ),
      home: const PumpCalculatorPage(),
    );
  }
}

class PumpCalculatorPage extends StatefulWidget {
  const PumpCalculatorPage({super.key});

  @override
  State<PumpCalculatorPage> createState() => _PumpCalculatorPageState();
}

class _PumpCalculatorPageState extends State<PumpCalculatorPage> {
  final _doseController = TextEditingController();
  final _weightController = TextEditingController();
  final _presetSearchController = TextEditingController();

  final _nameController = TextEditingController();
  final _doseUnitController = TextEditingController();
  final _minDoseController = TextEditingController();
  final _maxDoseController = TextEditingController();
  final _drugAmountController = TextEditingController();
  final _drugUnitController = TextEditingController();
  final _volumeController = TextEditingController();
  final _rateIncrementController = TextEditingController();
  final _noteController = TextEditingController();

  final _calculatorFormKey = GlobalKey<FormState>();
  final _editorFormKey = GlobalKey<FormState>();

  late Map<String, List<DrugPreset>> _presetsByDepartment;
  String? _selectedDepartmentId;
  String? _selectedPresetId;
  String _resultValue = '--';
  String _resultDetail = '';
  bool _resultError = false;
  bool _resultDoseWarning = false;
  bool _useWeight = true;
  bool _isLoading = true;
  String _selectedTimeUnit = 'min';
  String _presetSearchQuery = '';
  bool _isPresetSearchOpen = false;
  bool _isCreatingPreset = false;

  @override
  void initState() {
    super.initState();
    _presetsByDepartment = preset_data.defaultPresetMap();
    _loadState();
  }

  @override
  void dispose() {
    _doseController.dispose();
    _weightController.dispose();
    _presetSearchController.dispose();
    _nameController.dispose();
    _doseUnitController.dispose();
    _minDoseController.dispose();
    _maxDoseController.dispose();
    _drugAmountController.dispose();
    _drugUnitController.dispose();
    _volumeController.dispose();
    _rateIncrementController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final currentRaw = prefs.getString(storageKey);
    final legacyRaw = readFirstLegacyString(prefs, legacyStorageKeys);
    final savedDepartment = readFirstAvailableString(
      prefs,
      selectedDepartmentKey,
      legacySelectedDepartmentKeys,
      ignoreEmpty: true,
    );

    final mergedMap = migratePresetMap(
      currentRaw: currentRaw,
      legacyRaw: legacyRaw,
      addMissingMicuPropofol1g50Ml:
          currentRaw == null || currentRaw.trim().isEmpty,
    );

    if (!mounted) return;

    setState(() {
      _presetsByDepartment = mergedMap;
      _selectedDepartmentId =
          savedDepartment != null && mergedMap.containsKey(savedDepartment)
              ? savedDepartment
              : null;
      _selectedPresetId = null;
      _syncEditorWithSelectedPreset();
      _isLoading = false;
    });

    await _saveState();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedDepartmentKey, _selectedDepartmentId ?? '');
    await prefs.setString(
      storageKey,
      jsonEncode(
        _presetsByDepartment.map(
          (key, value) =>
              MapEntry(key, value.map((preset) => preset.toJson()).toList()),
        ),
      ),
    );
    await removeLegacyKeys(prefs, legacySelectedDepartmentKeys);
    await removeLegacyKeys(prefs, legacyStorageKeys);
  }

  List<DrugPreset> get _currentPresets =>
      _presetsByDepartment[_selectedDepartmentId] ?? const [];

  DepartmentPreset? get _currentDepartment {
    for (final department in preset_data.defaultDepartments) {
      if (department.id == _selectedDepartmentId) return department;
    }
    return null;
  }

  DrugPreset? get _selectedPreset {
    for (final preset in _currentPresets) {
      if (preset.id == _selectedPresetId) return preset;
    }
    return null;
  }

  List<DrugPreset> get _presetSearchResults {
    final normalizedQuery = normalizeSearchText(_presetSearchQuery);
    if (normalizedQuery.isEmpty) return _currentPresets;

    final prefixMatches = <DrugPreset>[];
    final containsMatches = <DrugPreset>[];

    for (final preset in _currentPresets) {
      final searchTerms = <String>[
        normalizeSearchText(preset.name),
        normalizeSearchText(presetDropdownLabel(preset.name)),
        normalizeSearchText(mixDrugLabel(preset.name)),
      ];

      if (searchTerms.any((term) => term.startsWith(normalizedQuery))) {
        prefixMatches.add(preset);
      } else if (searchTerms.any((term) => term.contains(normalizedQuery))) {
        containsMatches.add(preset);
      }
    }

    return [...prefixMatches, ...containsMatches];
  }

  void _applyDefaultResult([String? detail]) {
    _resultValue = '--';
    _resultDetail = detail ?? '';
    _resultError = false;
    _resultDoseWarning = false;
  }

  void _resetResult([String? detail]) {
    setState(() {
      _applyDefaultResult(detail);
    });
  }

  void _clearPresetSearchState() {
    _presetSearchQuery = '';
    _isPresetSearchOpen = false;
  }

  void _clearPresetSearchField() {
    if (_presetSearchController.text.isNotEmpty) {
      _presetSearchController.clear();
    }
  }

  void _selectDepartment(String departmentId) {
    setState(() {
      _selectedDepartmentId = departmentId;
      _selectedPresetId = null;
      _clearPresetSearchState();
      _doseController.clear();
      _weightController.clear();
      _isCreatingPreset = false;
      _syncEditorWithSelectedPreset();
      _applyDefaultResult();
    });
    _clearPresetSearchField();
    _saveState();
  }

  void _changeSelectedPreset(String? presetId) {
    setState(() {
      _selectedPresetId = presetId;
      _clearPresetSearchState();
      _doseController.clear();
      _isCreatingPreset = false;
      _syncEditorWithSelectedPreset();
      _applyDefaultResult('약물이 변경되어 처방 용량을 다시 입력해 주세요.');
    });
    _clearPresetSearchField();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _startNewPatient() {
    setState(() {
      _selectedPresetId = null;
      _doseController.clear();
      _weightController.clear();
      _clearPresetSearchState();
      _isCreatingPreset = false;
      _syncEditorWithSelectedPreset();
      _applyDefaultResult('새 환자 입력을 시작합니다. 약물을 선택해 주세요.');
    });
    _clearPresetSearchField();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _syncEditorWithSelectedPreset() {
    final preset = _selectedPreset;
    if (preset == null) {
      _nameController.clear();
      _doseUnitController.clear();
      _minDoseController.clear();
      _maxDoseController.clear();
      _drugAmountController.clear();
      _drugUnitController.clear();
      _volumeController.clear();
      _rateIncrementController.clear();
      _noteController.clear();
      _selectedTimeUnit = 'min';
      _useWeight = true;
      return;
    }

    _nameController.text = preset.name;
    _doseUnitController.text = preset.doseUnit;
    _minDoseController.text = preset.minDose?.toString() ?? '';
    _maxDoseController.text = preset.maxDose?.toString() ?? '';
    _drugAmountController.text = preset.drugAmount.toString();
    _drugUnitController.text = preset.drugUnit;
    _volumeController.text = preset.volumeMl.toString();
    _rateIncrementController.text = preset.rateIncrementMlPerHr.toString();
    _noteController.text = preset.note;
    _selectedTimeUnit = resolveDoseTimeUnitId(preset);
    _useWeight = preset.useWeight;
  }

  void _startNewPreset() {
    setState(() {
      _isCreatingPreset = true;
      _nameController.clear();
      _doseUnitController.clear();
      _minDoseController.clear();
      _maxDoseController.clear();
      _drugAmountController.clear();
      _drugUnitController.clear();
      _volumeController.clear();
      _rateIncrementController.text = '0.1';
      _noteController.clear();
      _selectedTimeUnit = 'min';
      _useWeight = true;
    });
  }

  void _autoCalculate() {
    final preset = _selectedPreset;
    if (preset == null) {
      _resetResult();
      return;
    }

    final dose = double.tryParse(_doseController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());

    if (!isFinitePositive(dose) ||
        (preset.useWeight && !isFinitePositive(weight))) {
      _resetResult();
      return;
    }
    final validDose = dose!;

    try {
      final presetError = validatePreset(preset);
      if (presetError != null) {
        throw CalculationInputException(presetError);
      }
      final targetRangeWarning = validateDoseRange(validDose, preset);
      final rate = calculateRate(
        dose: validDose,
        weight: weight ?? 0,
        preset: preset,
      );
      final roundedRate = roundCalculatedRate(rate, preset);
      if (roundedRate <= 0 && rate > 0) {
        setState(() {
          _resultValue = '설정 확인';
          _resultDetail =
              '계산값 ${formatNumber(rate)} mL/hr가 펌프 반올림 단위보다 작아 0 mL/hr가 됩니다. 농도와 펌프 단위를 확인해 주세요.';
          _resultError = true;
          _resultDoseWarning = true;
        });
        return;
      }
      final deliveredDose = calculateDoseFromRate(
        rateMlPerHr: roundedRate,
        weight: weight ?? 0,
        preset: preset,
      );
      final deliveredRangeWarning = validateDoseRange(deliveredDose, preset);
      final rangeWarning = targetRangeWarning ??
          (deliveredRangeWarning == null
              ? null
              : '펌프 반올림 후 예상 용량 ${formatNumber(deliveredDose)} ${preset.doseUnit}: $deliveredRangeWarning');

      setState(() {
        _resultValue = formatCalculatedRate(roundedRate, preset);
        _resultDetail = rangeWarning == null
            ? '원계산 ${formatNumber(rate)} mL/hr를 펌프 단위 '
                '${formatNumber(preset.rateIncrementMlPerHr)} mL/hr로 반올림한 결과입니다.'
            : '권장 범위 밖입니다. $rangeWarning 처방과 약물 설정을 다시 확인해 주세요.';
        _resultError = rangeWarning != null;
        _resultDoseWarning = rangeWarning != null;
      });
    } on CalculationInputException catch (error) {
      setState(() {
        _resultValue = '단위 확인';
        _resultDetail = error.message;
        _resultError = true;
        _resultDoseWarning = false;
      });
    }
  }

  Future<void> _savePreset() async {
    if (!_editorFormKey.currentState!.validate()) return;
    if (_selectedDepartmentId == null) return;

    final minDose = _minDoseController.text.trim().isEmpty
        ? null
        : double.tryParse(_minDoseController.text.trim());
    final maxDose = _maxDoseController.text.trim().isEmpty
        ? null
        : double.tryParse(_maxDoseController.text.trim());

    if ((_minDoseController.text.trim().isNotEmpty && minDose == null) ||
        (_maxDoseController.text.trim().isNotEmpty && maxDose == null)) {
      _showSnackBar('최소/최대 용량은 유한한 숫자로 입력해 주세요.');
      return;
    }

    final drugAmount = double.tryParse(_drugAmountController.text.trim());
    final volumeMl = double.tryParse(_volumeController.text.trim());
    final rateIncrement = double.tryParse(_rateIncrementController.text.trim());
    if (drugAmount == null || volumeMl == null || rateIncrement == null) {
      _showSnackBar('총 약물량, 최종 부피, 펌프 반올림 단위를 확인해 주세요.');
      return;
    }

    final normalizedDoseUnit = normalizeDoseUnitLabel(
      _doseUnitController.text.trim(),
      _selectedTimeUnit,
    );
    final normalizedDrugUnit = normalizeAmountUnitLabel(
      _drugUnitController.text.trim(),
    );

    final preset = DrugPreset(
      id: _isCreatingPreset ? uniqueId() : (_selectedPreset?.id ?? uniqueId()),
      name: _nameController.text.trim(),
      doseUnit: normalizedDoseUnit,
      minDose: minDose,
      maxDose: maxDose,
      drugAmount: drugAmount,
      drugUnit: normalizedDrugUnit,
      volumeMl: volumeMl,
      timeUnit: _selectedTimeUnit,
      useWeight: _useWeight,
      note: _noteController.text.trim(),
      rateIncrementMlPerHr: rateIncrement,
    );

    final presetError = validatePreset(preset);
    if (presetError != null) {
      _showSnackBar('저장하지 않았습니다: $presetError');
      return;
    }
    final updated = upsertPreset(_currentPresets, preset);

    setState(() {
      _presetsByDepartment[_selectedDepartmentId!] = updated;
      _selectedPresetId = preset.id;
      _isCreatingPreset = false;
      _syncEditorWithSelectedPreset();
      _resultValue = '저장 완료';
      _resultDetail =
          '${_currentDepartment?.label ?? ''} 부서에 ${preset.name} 계산식을 저장했습니다.';
      _resultError = false;
      _resultDoseWarning = false;
    });

    await _saveState();
  }

  Future<void> _deleteSelectedPreset() async {
    final preset = _selectedPreset;
    final departmentId = _selectedDepartmentId;
    if (preset == null || departmentId == null) return;

    final confirmed = await _confirm(
      title: '약물 삭제',
      message: '${preset.name} 계산식을 삭제할까요?',
    );
    if (!confirmed) return;

    final updated =
        _currentPresets.where((item) => item.id != preset.id).toList();
    final nextList = updated.isNotEmpty
        ? updated
        : preset_data.defaultPresetMap()[departmentId]!;

    setState(() {
      _presetsByDepartment[departmentId] = nextList;
      _selectedPresetId = null;
      _doseController.clear();
      _weightController.clear();
      _isCreatingPreset = false;
      _syncEditorWithSelectedPreset();
      _applyDefaultResult(
        '${_currentDepartment?.label ?? ''} 부서 약물 목록을 업데이트했습니다.',
      );
    });

    await _saveState();
  }

  Future<void> _resetDepartmentPresets() async {
    final departmentId = _selectedDepartmentId;
    if (departmentId == null) return;

    final confirmed = await _confirm(
      title: '기본값 복원',
      message: '현재 부서에서 수정하거나 추가한 계산식이 모두 사라집니다. 기본값으로 되돌릴까요?',
    );
    if (!confirmed) return;

    final resetList = preset_data.defaultPresetMap()[departmentId]!;
    setState(() {
      _presetsByDepartment[departmentId] = resetList;
      _selectedPresetId = null;
      _doseController.clear();
      _weightController.clear();
      _isCreatingPreset = false;
      _syncEditorWithSelectedPreset();
      _applyDefaultResult(
        '${_currentDepartment?.label ?? ''} 부서 기본 약물 계산식으로 복원했습니다.',
      );
    });

    await _saveState();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: snoobiSky,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: calculatorMaxWidth),
              child: _selectedDepartmentId == null
                  ? LandingSection(onSelectDepartment: _selectDepartment)
                  : CalculatorSection(
                        departmentLabel: _currentDepartment?.label ?? '-',
                        selectedPresetId: _selectedPresetId,
                        selectedPreset: _selectedPreset,
                        doseController: _doseController,
                        weightController: _weightController,
                        resultValue: _resultValue,
                        resultDetail: _resultDetail,
                        resultError: _resultError,
                        resultDoseWarning: _resultDoseWarning,
                        calculatorFormKey: _calculatorFormKey,
                        presetSearchController: _presetSearchController,
                        presetSearchQuery: _presetSearchQuery,
                        presetSearchResults: _presetSearchResults,
                        showPresetSearchResults: _isPresetSearchOpen,
                        onPresetSearchTap: () {
                          setState(() => _isPresetSearchOpen = true);
                        },
                        onPresetSearchChanged: (value) {
                          setState(() {
                            _presetSearchQuery = value;
                            _isPresetSearchOpen = true;
                          });
                        },
                        onPresetSearchSelected: (presetId) {
                          _changeSelectedPreset(presetId);
                        },
                        onClearPresetSearch: () {
                          setState(() => _clearPresetSearchState());
                          _clearPresetSearchField();
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        onChangeDepartment: () {
                          setState(() {
                            _selectedDepartmentId = null;
                            _selectedPresetId = null;
                            _doseController.clear();
                            _weightController.clear();
                            _isCreatingPreset = false;
                            _clearPresetSearchState();
                            _applyDefaultResult();
                          });
                          _clearPresetSearchField();
                          _saveState();
                        },
                        onStartNewPatient: _startNewPatient,
                        onOpenSettings: _showPresetManager,
                        onDoseChanged: _autoCalculate,
                        onWeightChanged: _autoCalculate,
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPresetManager() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: snoobiPaper,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => FractionallySizedBox(
          heightFactor: 0.94,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '약물 설정 관리',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: snoobiInk,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '설정 닫기',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: _buildPresetManagerContent(
                    sheetContext: sheetContext,
                    refreshSheet: refreshSheet,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetManagerContent({
    required BuildContext sheetContext,
    required StateSetter refreshSheet,
  }) {
    void refreshBoth(VoidCallback update) {
      setState(update);
      refreshSheet(() {});
    }

    return Form(
      key: _editorFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: roundedDecoration(color: const Color(0xFFE8F7FF)),
            child: const Text(
              '수정·추가한 계산식은 이 브라우저의 현재 기기에만 저장됩니다. '
              '브라우저 데이터를 삭제하면 사라질 수 있어요.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: snoobiInk,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('reset-presets-button'),
                onPressed: () async {
                  await _resetDepartmentPresets();
                  if (sheetContext.mounted) refreshSheet(() {});
                },
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('부서 기본값 복원'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _startNewPreset();
                  refreshSheet(() {});
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('새 계산식'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isCreatingPreset
                ? '새 계산식 작성 중'
                : _selectedPreset == null
                    ? '수정할 약물을 계산 화면에서 먼저 선택해 주세요.'
                    : '수정 대상: ${_selectedPreset!.name}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: snoobiInk,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              EditorField(
                controller: _nameController,
                label: '약물명',
                width: 280,
              ),
              EditorField(
                controller: _doseUnitController,
                label: '목표 용량 단위',
                width: 280,
              ),
              EditorField(
                controller: _minDoseController,
                label: '최소 용량 (선택)',
                width: 240,
                isOptional: true,
                isNumeric: true,
                keyboardType: TextInputType.number,
              ),
              EditorField(
                controller: _maxDoseController,
                label: '최대 용량 (선택)',
                width: 240,
                isOptional: true,
                isNumeric: true,
                keyboardType: TextInputType.number,
              ),
              EditorField(
                controller: _drugAmountController,
                label: '총 약물량',
                width: 240,
                isNumeric: true,
                mustBePositive: true,
                keyboardType: TextInputType.number,
              ),
              EditorField(
                controller: _drugUnitController,
                label: '총 약물량 단위',
                width: 240,
              ),
              EditorField(
                controller: _volumeController,
                label: '최종 부피 (mL)',
                width: 240,
                isNumeric: true,
                mustBePositive: true,
                keyboardType: TextInputType.number,
              ),
              EditorField(
                controller: _rateIncrementController,
                label: '펌프 반올림 단위 (mL/hr)',
                width: 240,
                isNumeric: true,
                mustBePositive: true,
                keyboardType: TextInputType.number,
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selectedTimeUnit),
                  initialValue: _selectedTimeUnit,
                  decoration: editorDecoration('시간 기준'),
                  items: const [
                    DropdownMenuItem(value: 'min', child: Text('분당 처방')),
                    DropdownMenuItem(value: 'hr', child: Text('시간당 처방')),
                    DropdownMenuItem(value: 'day', child: Text('일당 처방')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    refreshBoth(() => _selectedTimeUnit = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            maxLines: 5,
            decoration: editorDecoration(
              '비고 / Mix 공식 / Loading dose / 특이사항',
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _useWeight,
            title: const Text('체중 기반 계산 사용'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            onChanged: (value) => refreshBoth(() => _useWeight = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: (_isCreatingPreset || _selectedPreset != null)
                    ? () async {
                        await _savePreset();
                        if (sheetContext.mounted) refreshSheet(() {});
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  _isCreatingPreset ? '새 약물 저장' : '선택 약물 수정',
                ),
              ),
              OutlinedButton(
                onPressed: (!_isCreatingPreset && _selectedPreset != null)
                    ? () async {
                        await _deleteSelectedPreset();
                        if (sheetContext.mounted) refreshSheet(() {});
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                  side: const BorderSide(color: Color(0xFFF04438)),
                  minimumSize: const Size(140, 48),
                ),
                child: const Text('선택 약물 삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
