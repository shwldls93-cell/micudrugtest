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

const storageKey = 'icu_infusion_presets_by_department_v2';
const selectedDepartmentKey = 'icu_selected_department_v2';
const legacyStorageKeys = ['icu_infusion_presets_by_department_v1'];
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
        fontFamily: 'Pretendard',
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
  final _scrollController = ScrollController();
  final _landingSectionKey = GlobalKey();
  final _editorSectionKey = GlobalKey();

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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDepartment = readFirstAvailableString(
      prefs,
      selectedDepartmentKey,
      legacySelectedDepartmentKeys,
      ignoreEmpty: true,
    );

    final mergedMap = migratePresetMap(
      currentRaw: prefs.getString(storageKey),
      legacyRaw: readFirstLegacyString(prefs, legacyStorageKeys),
    );

    if (!mounted) return;

    setState(() {
      _presetsByDepartment = mergedMap;
      _selectedDepartmentId =
          savedDepartment != null && mergedMap.containsKey(savedDepartment)
              ? savedDepartment
              : null;
      _selectedPresetId =
          _currentPresets.isNotEmpty ? _currentPresets.first.id : null;
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
    return _currentPresets.isNotEmpty ? _currentPresets.first : null;
  }

  List<DrugPreset> get _presetSearchResults {
    final normalizedQuery = normalizeSearchText(_presetSearchQuery);
    if (normalizedQuery.isEmpty) return const [];

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
  }

  void _clearPresetSearchField() {
    if (_presetSearchController.text.isNotEmpty) {
      _presetSearchController.clear();
    }
  }

  void _selectDepartment(String departmentId) {
    setState(() {
      _selectedDepartmentId = departmentId;
      _selectedPresetId = _presetsByDepartment[departmentId]?.firstOrNull?.id;
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
        _resultDetail = rangeWarning ?? '자동 계산된 펌프 설정값입니다.';
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
      _selectedPresetId = nextList.first.id;
      _doseController.clear();
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
      _selectedPresetId = resetList.first.id;
      _doseController.clear();
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
      body: Container(
        color: snoobiSky,
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: calculatorMaxWidth),
                child: Column(
                  children: [
                    if (_selectedDepartmentId == null)
                      Container(
                        key: _landingSectionKey,
                        child: LandingSection(
                          selectedDepartmentLabel:
                              _currentDepartment?.label ?? '선택 전',
                          onSelectDepartment: _selectDepartment,
                          selectedDepartmentId: _selectedDepartmentId,
                        ),
                      )
                    else
                      CalculatorSection(
                        departmentLabel: _currentDepartment?.label ?? '-',
                        presets: _currentPresets,
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
                        onPresetChanged: _changeSelectedPreset,
                        onPresetSearchChanged: (value) {
                          setState(() => _presetSearchQuery = value);
                        },
                        onPresetSearchSelected: (presetId) {
                          _changeSelectedPreset(presetId);
                        },
                        onClearPresetSearch: () {
                          setState(() => _clearPresetSearchState());
                          _clearPresetSearchField();
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
                        onResetPresets: _resetDepartmentPresets,
                        editor: _buildEditorCard(),
                        onDoseChanged: _autoCalculate,
                        onWeightChanged: _autoCalculate,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorCard() {
    return Container(
      key: _editorSectionKey,
      child: ExpansionTile(
        collapsedShape: roundedBorder(),
        shape: roundedBorder(),
        backgroundColor: const Color(0xF7FFFFFF),
        collapsedBackgroundColor: const Color(0xF0FFFFFF),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '약물 계산식 추가/수정/비고 관리',
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Form(
            key: _editorFormKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isCreatingPreset
                            ? '새 계산식 작성 중'
                            : '수정 대상: ${_selectedPreset?.name ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: snoobiInk,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _startNewPreset,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('새 계산식'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    EditorField(
                      controller: _nameController,
                      label: '약물명',
                      width: 260,
                    ),
                    EditorField(
                      controller: _doseUnitController,
                      label: '목표 용량 단위',
                      width: 260,
                    ),
                    EditorField(
                      controller: _minDoseController,
                      label: '최소 용량 (선택)',
                      width: 220,
                      isOptional: true,
                      isNumeric: true,
                      keyboardType: TextInputType.number,
                    ),
                    EditorField(
                      controller: _maxDoseController,
                      label: '최대 용량 (선택)',
                      width: 220,
                      isOptional: true,
                      isNumeric: true,
                      keyboardType: TextInputType.number,
                    ),
                    EditorField(
                      controller: _drugAmountController,
                      label: '총 약물량',
                      width: 220,
                      isNumeric: true,
                      mustBePositive: true,
                      keyboardType: TextInputType.number,
                    ),
                    EditorField(
                      controller: _drugUnitController,
                      label: '총 약물량 단위',
                      width: 220,
                    ),
                    EditorField(
                      controller: _volumeController,
                      label: '최종 부피 (mL)',
                      width: 220,
                      isNumeric: true,
                      mustBePositive: true,
                      keyboardType: TextInputType.number,
                    ),
                    EditorField(
                      controller: _rateIncrementController,
                      label: '펌프 반올림 단위 (mL/hr)',
                      width: 220,
                      isNumeric: true,
                      mustBePositive: true,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(
                      width: 220,
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
                          setState(() => _selectedTimeUnit = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: editorDecoration(
                    '비고 / Mix 공식 / Loading dose / 특이사항',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _useWeight,
                  title: const Text('체중 기반 계산 사용'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  onChanged: (value) => setState(() => _useWeight = value),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _savePreset,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(_isCreatingPreset ? '새 약물 저장' : '선택 약물 수정'),
                    ),
                    OutlinedButton(
                      onPressed:
                          _isCreatingPreset ? null : _deleteSelectedPreset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                        side: const BorderSide(color: Color(0xFFF04438)),
                      ),
                      child: const Text('선택 약물 삭제'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
