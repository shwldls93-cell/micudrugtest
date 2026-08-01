import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const storageKey = 'icu_infusion_presets_by_department_v2';
const selectedDepartmentKey = 'icu_selected_department_v2';
const legacyStorageKeys = [
  'icu_infusion_presets_by_department_v1',
];
const legacySelectedDepartmentKeys = [
  'icu_selected_department_v1',
];

const supportedTimeUnits = {'min', 'hr', 'day'};

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
          background: const Color(0xFFF7F9FB),
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
  final _calculatorSectionKey = GlobalKey();
  final _editorSectionKey = GlobalKey();

  late Map<String, List<DrugPreset>> _presetsByDepartment;
  String? _selectedDepartmentId;
  String? _selectedPresetId;
  String _resultValue = '--';
  String _resultDetail = '약물과 값을 입력하면 계산식이 표시됩니다.';
  bool _resultError = false;
  bool _resultDoseWarning = false;
  bool _useWeight = true;
  bool _isLoading = true;
  String _selectedTimeUnit = 'min';
  String _activeBottomTab = 'home';

  @override
  void initState() {
    super.initState();
    _presetsByDepartment = defaultPresetMap();
    _loadState();
  }

  @override
  void dispose() {
    _doseController.dispose();
    _weightController.dispose();
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

  Future<void> _scrollToSection(GlobalKey sectionKey) async {
    final context = sectionKey.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  void _handleBottomNavTap(String tab) {
    setState(() => _activeBottomTab = tab);

    switch (tab) {
      case 'home':
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
        break;
      case 'presets':
        if (_selectedDepartmentId == null) {
          _showSnackBar('먼저 부서를 선택해 주세요.');
          return;
        }
        _scrollToSection(_editorSectionKey);
        break;
      default:
        break;
    }
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
      _selectedDepartmentId = savedDepartment != null && mergedMap.containsKey(savedDepartment)
          ? savedDepartment
          : null;
      _selectedPresetId = _currentPresets.isNotEmpty ? _currentPresets.first.id : null;
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
          (key, value) => MapEntry(
            key,
            value.map((preset) => preset.toJson()).toList(),
          ),
        ),
      ),
    );
    await removeLegacyKeys(prefs, legacySelectedDepartmentKeys);
    await removeLegacyKeys(prefs, legacyStorageKeys);
  }

  List<DrugPreset> get _currentPresets =>
      _presetsByDepartment[_selectedDepartmentId] ?? const [];

  DepartmentPreset? get _currentDepartment {
    for (final department in defaultDepartments) {
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

  void _resetResult([String? detail]) {
    setState(() {
      _resultValue = '--';
      _resultDetail = detail ?? '약물과 값을 입력하면 계산식이 표시됩니다.';
      _resultError = false;
      _resultDoseWarning = false;
    });
  }

  void _selectDepartment(String departmentId) {
    setState(() {
      _selectedDepartmentId = departmentId;
      _selectedPresetId = _presetsByDepartment[departmentId]?.firstOrNull?.id;
      _doseController.clear();
      _weightController.clear();
      _syncEditorWithSelectedPreset();
      _resetResult();
      _activeBottomTab = 'home';
    });
    _saveState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSection(_calculatorSectionKey);
    });
  }

  void _changeSelectedPreset(String? presetId) {
    setState(() {
      _selectedPresetId = presetId;
      _syncEditorWithSelectedPreset();
      _resetResult();
    });
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
    _selectedTimeUnit = preset.timeUnit;
    _useWeight = preset.useWeight;
  }

  void _calculate() {
    if (!_calculatorFormKey.currentState!.validate()) return;

    final preset = _selectedPreset;
    if (preset == null) {
      setState(() {
        _resultValue = '입력 확인';
        _resultDetail = '먼저 부서를 선택하고 약물을 선택해 주세요.';
        _resultError = true;
        _resultDoseWarning = false;
      });
      return;
    }

    final dose = double.tryParse(_doseController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());

    if (!isFinitePositive(dose)) {
      setState(() {
        _resultValue = '입력 확인';
        _resultDetail = '목표 용량을 0보다 큰 숫자로 입력해 주세요.';
        _resultError = true;
        _resultDoseWarning = false;
      });
      return;
    }

    if (preset.useWeight && !isFinitePositive(weight)) {
      setState(() {
        _resultValue = '입력 확인';
        _resultDetail = '체중 기반 약물이므로 몸무게를 입력해 주세요.';
        _resultError = true;
        _resultDoseWarning = false;
      });
      return;
    }

    final presetError = validatePreset(preset);
    if (presetError != null) {
      setState(() {
        _resultValue = '설정 확인';
        _resultDetail = '선택한 계산식이 안전하지 않아 계산하지 않았습니다: $presetError';
        _resultError = true;
        _resultDoseWarning = false;
      });
      return;
    }

    final targetRangeWarning = validateDoseRange(dose, preset);

    final rate = calculateRate(
      dose: dose,
      weight: weight ?? 0,
      preset: preset,
    );
    if (!rate.isFinite || rate < 0) {
      setState(() {
        _resultValue = '계산 오류';
        _resultDetail = '계산 결과가 유효하지 않아 펌프 속도를 표시하지 않았습니다.';
        _resultError = true;
        _resultDoseWarning = false;
      });
      return;
    }
    final roundedRate = roundCalculatedRate(rate, preset);
    if (roundedRate <= 0 && rate > 0) {
      setState(() {
        _resultValue = '설정 확인';
        _resultDetail =
            '계산된 속도(${formatNumber(rate)} mL/hr)가 펌프 반올림 단위보다 작아 0 mL/hr로 반올림됩니다. '
            '더 낮은 펌프 단위 또는 처방/농도를 확인해 주세요.';
        _resultError = true;
        _resultDoseWarning = false;
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
            : '펌프 반올림 후 예상 용량 ${formatNumber(deliveredDose)} ${preset.doseUnit}: '
                '$deliveredRangeWarning');

    setState(() {
      _resultValue = formatCalculatedRate(roundedRate, preset);
      _resultDetail = rangeWarning != null
          ? '$rangeWarning 주입용량확인'
          : '계산된 주입속도를 infusion pump에 입력해 주세요.';
      _resultError = rangeWarning != null;
      _resultDoseWarning = rangeWarning != null;
    });
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
      _showSnackBar('총 약물량, 최종 부피, 펌프 반올림 단위는 유한한 숫자로 입력해 주세요.');
      return;
    }

    final preset = DrugPreset(
      id: _selectedPreset?.id ?? uniqueId(),
      name: _nameController.text.trim(),
      doseUnit: _doseUnitController.text.trim(),
      minDose: minDose,
      maxDose: maxDose,
      drugAmount: drugAmount,
      drugUnit: _drugUnitController.text.trim(),
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
      _syncEditorWithSelectedPreset();
      _resultValue = '저장 완료';
      _resultDetail = '${_currentDepartment?.label ?? ''} 부서에 ${preset.name} 계산식을 저장했습니다.';
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

    final updated = _currentPresets.where((item) => item.id != preset.id).toList();
    final nextList = updated.isNotEmpty ? updated : defaultPresetMap()[departmentId]!;

    setState(() {
      _presetsByDepartment[departmentId] = nextList;
      _selectedPresetId = nextList.first.id;
      _syncEditorWithSelectedPreset();
      _resetResult('${_currentDepartment?.label ?? ''} 부서 약물 목록을 업데이트했습니다.');
    });

    await _saveState();
  }

  Future<void> _resetDepartmentPresets() async {
    final departmentId = _selectedDepartmentId;
    if (departmentId == null) return;

    final confirmed = await _confirm(
      title: '기본값 복원',
      message: '현재 부서의 약물 목록을 기본값으로 되돌릴까요?',
    );
    if (!confirmed) return;

    final resetList = defaultPresetMap()[departmentId]!;
    setState(() {
      _presetsByDepartment[departmentId] = resetList;
      _selectedPresetId = resetList.first.id;
      _syncEditorWithSelectedPreset();
      _resetResult('${_currentDepartment?.label ?? ''} 부서 기본 약물 계산식으로 복원했습니다.');
    });

    await _saveState();
  }

  Future<bool> _confirm({required String title, required String message}) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      floatingActionButton: _selectedDepartmentId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _calculate,
              backgroundColor: const Color(0xFF0F6784),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text(
                '계산',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SoftBottomNav(
        selectedTab: _activeBottomTab,
        onTap: _handleBottomNavTap,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FBFF),
              Color(0xFFEEF6FB),
              Color(0xFFFFF4F8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    Container(
                      key: _landingSectionKey,
                      child: _LandingSection(
                        selectedDepartmentLabel: _currentDepartment?.label ?? '선택 전',
                        onSelectDepartment: _selectDepartment,
                        selectedDepartmentId: _selectedDepartmentId,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_selectedDepartmentId != null)
                      Container(
                        key: _calculatorSectionKey,
                        child: _CalculatorSection(
                          departmentLabel: _currentDepartment?.displayTitle ?? '-',
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
                          onCalculate: _calculate,
                          onPresetChanged: _changeSelectedPreset,
                          onChangeDepartment: () {
                            setState(() {
                              _selectedDepartmentId = null;
                              _selectedPresetId = null;
                              _resetResult();
                            });
                            _saveState();
                          },
                          onResetPresets: _resetDepartmentPresets,
                          editor: _buildEditorCard(),
                        ),
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
        title: const Text(
          '약물 계산식 추가 / 수정 / 비고 관리',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Form(
            key: _editorFormKey,
            child: Column(
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _EditorField(controller: _nameController, label: '약물명', width: 260),
                    _EditorField(controller: _doseUnitController, label: '목표 용량 단위', width: 260),
                    _EditorField(controller: _minDoseController, label: '최소 용량 (선택)', width: 220, keyboardType: TextInputType.number),
                    _EditorField(controller: _maxDoseController, label: '최대 용량 (선택)', width: 220, keyboardType: TextInputType.number),
                    _EditorField(controller: _drugAmountController, label: '총 약물량', width: 220, keyboardType: TextInputType.number),
                    _EditorField(controller: _drugUnitController, label: '총 약물량 단위', width: 220),
                    _EditorField(controller: _volumeController, label: '최종 부피 (mL)', width: 220, keyboardType: TextInputType.number),
                    _EditorField(controller: _rateIncrementController, label: '펌프 반올림 단위 (mL/hr)', width: 220, keyboardType: TextInputType.number),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
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
                  decoration: editorDecoration('비고 / Mix 공식 / Loading dose / 특이사항'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        value: _useWeight,
                        title: const Text('체중 기반 계산 사용'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        onChanged: (value) => setState(() => _useWeight = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _savePreset,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('약물 저장'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _deleteSelectedPreset,
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

class _LandingSection extends StatelessWidget {
  const _LandingSection({
    required this.selectedDepartmentLabel,
    required this.onSelectDepartment,
    required this.selectedDepartmentId,
  });

  final String selectedDepartmentLabel;
  final ValueChanged<String> onSelectDepartment;
  final String? selectedDepartmentId;

  @override
  Widget build(BuildContext context) {
    return ThemedBoard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CloudHeader(
            titleSize: 44,
            subtitle: '부서 선택 후 바로 약물 속도를 계산할 수 있어요',
          ),
          const SizedBox(height: 20),
          const PickBanner(),
          const SizedBox(height: 18),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: defaultDepartments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final department = defaultDepartments[index];
                return DepartmentCard(
                  department: department,
                  selected: selectedDepartmentId == department.id,
                  onTap: () => onSelectDepartment(department.id),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          SelectedChip(label: selectedDepartmentLabel),
        ],
      ),
    );
  }
}

class _CalculatorSection extends StatelessWidget {
  const _CalculatorSection({
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
    required this.onCalculate,
    required this.onPresetChanged,
    required this.onChangeDepartment,
    required this.onResetPresets,
    required this.editor,
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
  final VoidCallback onCalculate;
  final ValueChanged<String?> onPresetChanged;
  final VoidCallback onChangeDepartment;
  final VoidCallback onResetPresets;
  final Widget editor;

  @override
  Widget build(BuildContext context) {
    final preset = selectedPreset;
    final timeMultiplier = preset == null ? '1' : timeUnitFactorLabel(preset.timeUnit);
    final rangeText = preset == null
        ? '-'
        : '${formatOptionalDose(preset.minDose, preset.doseUnit)} ~ ${formatOptionalDose(preset.maxDose, preset.doseUnit)}';
    final mixLine = preset == null
        ? '-'
        : extractMixLine(preset.note, preset.name);
    final formulaText = preset == null
        ? '-'
        : '목표용량 × ${preset.useWeight ? '체중 × ' : ''}$timeMultiplier × '
            '${formatNumber(preset.volumeMl)} mL ÷ ${formulaDrugAmount(preset)}';

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
            decoration: roundedDecoration(color: const Color(0xFFFFFFFF), radius: 32),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: calculatorFormKey,
                child: Column(
                  children: [
                    CalculatorRow(
                      label: '약물선택',
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPresetId,
                        decoration: rowDecoration(),
                        items: presets
                            .map(
                              (preset) => DropdownMenuItem(
                                value: preset.id,
                                child: Text(
                                  presetDropdownLabel(preset.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) => presets
                            .map(
                              (preset) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  presetDropdownLabel(preset.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onPresetChanged,
                      ),
                      suffix: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Color(0xFF0F6784)),
                    ),
                    const SizedBox(height: 14),
                    CalculatorRow(
                      label: '몸무게',
                      child: TextFormField(
                        controller: weightController,
                        enabled: preset?.useWeight ?? true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: rowDecoration(hint: '몸무게 입력'),
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: rowDecoration(hint: '용량 입력'),
                        validator: (value) => (value == null || value.trim().isEmpty) ? '용량 입력' : null,
                      ),
                      suffix: UnitLabel(preset?.doseUnit ?? '약물단위', compact: true),
                    ),
                    const SizedBox(height: 14),
                    CalculatorRow(
                      label: '주입속도',
                      child: ResultBox(value: resultValue, isWarning: resultDoseWarning),
                      suffix: RateSuffix(showWarning: resultDoseWarning),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: onCalculate,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F6784),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('속도 계산하기'),
                              SizedBox(width: 8),
                              Icon(Icons.calculate_rounded, size: 20),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: onResetPresets,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F6784),
                            side: const BorderSide(color: Color(0xFFB8D8E6)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: const Text('현재 부서 기본값 복원'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    NoteBoard(
                      mixLine: mixLine,
                      rangeText: rangeText,
                      formulaText: formulaText,
                      additionalNote: preset == null ? '' : extractAdditionalNote(preset.note),
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

class ThemedBoard extends StatelessWidget {
  const ThemedBoard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2ECF2), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F6784),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class CloudHeader extends StatelessWidget {
  const CloudHeader({
    required this.titleSize,
    this.subtitle,
    this.footer,
    super.key,
  });

  final double titleSize;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE7F7FC),
            Color(0xFFFFF6FA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2ECF2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PatternBadge(label: 'ICU CALC'),
              const Spacer(),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.favorite_rounded, color: Color(0xFFB85C7A), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TitleStack(fontSize: titleSize),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6B73),
                height: 1.45,
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 18),
            footer!,
          ],
        ],
      ),
    );
  }
}

class TitleStack extends StatelessWidget {
  const TitleStack({required this.fontSize, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlatTitle(text: '스누비', color: const Color(0xFF0F6784), fontSize: fontSize),
        FlatTitle(text: '쫀득 계산기', color: const Color(0xFF293056), fontSize: fontSize - 2),
      ],
    );
  }
}

class FlatTitle extends StatelessWidget {
  const FlatTitle({
    required this.text,
    required this.color,
    required this.fontSize,
    super.key,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.05,
        letterSpacing: -1.1,
      ),
    );
  }
}

class PickBanner extends StatelessWidget {
  const PickBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_hospital_rounded, color: Color(0xFF0F6784), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '오늘 근무 부서를 먼저 선택해 주세요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF293056),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DepartmentCard extends StatelessWidget {
  const DepartmentCard({
    required this.department,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final DepartmentPreset department;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: 154,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF7FD) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected ? const Color(0xFF8FD5F7) : const Color(0xFFE5EDF3),
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F6784),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: selected
                        ? [Color(0xFF8FD5F7), Color(0xFFFFD1DC)]
                        : [Color(0xFFF3F8FB), Color(0xFFFFF1F5)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(department.icon, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(height: 14),
              Text(
                department.label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF163647)),
              ),
              const SizedBox(height: 6),
              Text(
                department.description,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF667085),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFD9F0FB) : const Color(0xFFF2F5F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selected ? '선택됨' : '탭해서 선택',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectedChip extends StatelessWidget {
  const SelectedChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EDF3)),
      ),
      child: Text(
        '현재 선택: $label',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF344054),
        ),
      ),
    );
  }
}

class CurrentDepartmentBox extends StatelessWidget {
  const CurrentDepartmentBox({
    required this.title,
    required this.onTap,
    super.key,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EDF3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('현재 선택 부서', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF667085))),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475467),
              side: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            child: const Text('부서 변경'),
          ),
        ],
      ),
    );
  }
}

class CalculatorRow extends StatelessWidget {
  const CalculatorRow({
    required this.label,
    required this.child,
    required this.suffix,
    super.key,
  });

  final String label;
  final Widget child;
  final Widget suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabelPill(text: label),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: child),
              const SizedBox(width: 12),
              suffix,
            ],
          ),
        ],
      ),
    );
  }
}

class LabelPill extends StatelessWidget {
  const LabelPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F6784)),
        ),
      ),
    );
  }
}

class UnitLabel extends StatelessWidget {
  const UnitLabel(this.text, {this.emphasized = false, this.compact = false, super.key});

  final String text;
  final bool emphasized;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 136 : 110,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 16 : (emphasized ? 30 : 24),
            fontWeight: FontWeight.w900,
            color: const Color(0xFF163647),
          ),
        ),
      ),
    );
  }
}

class RateSuffix extends StatelessWidget {
  const RateSuffix({required this.showWarning, super.key});

  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UnitLabel('cc/hr', emphasized: true),
          if (showWarning)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '주입용량확인',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC12828),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ResultBox extends StatelessWidget {
  const ResultBox({required this.value, required this.isWarning, super.key});

  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E4EA)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isWarning ? const Color(0xFFC12828) : const Color(0xFF101828),
          ),
        ),
      ),
    );
  }
}

class NoteBoard extends StatelessWidget {
  const NoteBoard({
    required this.mixLine,
    required this.rangeText,
    required this.formulaText,
    required this.additionalNote,
    required this.resultDetail,
    required this.resultError,
    super.key,
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
          _InfoLine(icon: '📝', label: 'Mix', value: mixLine),
          const SizedBox(height: 14),
          _InfoLine(icon: '⚖️', label: 'Range', value: rangeText),
          const SizedBox(height: 14),
          _InfoLine(icon: '🧮', label: '공식', value: formulaText),
          if (hasAdditionalNote) ...[
            const SizedBox(height: 18),
            Text(
              additionalNote,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475467),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            resultDetail,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: resultError ? const Color(0xFFC12828) : const Color(0xFF475467),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(icon, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    required this.width,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if ((label == '최소 용량 (선택)' || label == '최대 용량 (선택)') || value == null) return null;
          if (value.trim().isEmpty) return '$label 입력';
          if (label == '총 약물량' ||
              label == '최종 부피 (mL)' ||
              label == '펌프 반올림 단위 (mL/hr)') {
            final parsed = double.tryParse(value.trim());
            if (!isFinitePositive(parsed)) return '$label은 0보다 큰 유한한 숫자여야 합니다.';
          }
          return null;
        },
        decoration: editorDecoration(label),
      ),
    );
  }
}

InputDecoration rowDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFFFFFFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: roundedInputBorder(),
    enabledBorder: roundedInputBorder(),
    focusedBorder: roundedInputBorder(color: const Color(0xFF8FD5F7)),
  );
}

InputDecoration editorDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFFFFFFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: roundedInputBorder(radius: 18),
    enabledBorder: roundedInputBorder(radius: 18),
    focusedBorder: roundedInputBorder(color: const Color(0xFF8FD5F7), radius: 18),
  );
}

OutlineInputBorder roundedInputBorder({
  Color color = const Color(0xFFD0D5DD),
  double radius = 14,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}

RoundedRectangleBorder roundedBorder([double radius = 28]) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: const BorderSide(color: Color(0xFFE4E7EC), width: 1.5),
  );
}

BoxDecoration roundedDecoration({required Color color, double radius = 28}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE4E7EC), width: 1.5),
  );
}

class PatternBadge extends StatelessWidget {
  const PatternBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E9F2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F6784),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class PawPatternBackground extends StatelessWidget {
  const PawPatternBackground({super.key});

  @override
  Widget build(BuildContext context) {
    const paws = ['🐾', '·', '🐾', '·', '🐾', '·', '🐾', '·'];

    return Align(
      alignment: Alignment.topCenter,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 22,
        runSpacing: 16,
        children: [
          for (var i = 0; i < 18; i++)
            Transform.translate(
              offset: Offset(i.isOdd ? 10 : 0, i % 3 == 0 ? 6 : 0),
              child: Text(
                paws[i % paws.length],
                style: TextStyle(
                  fontSize: paws[i % paws.length] == '🐾' ? 22 : 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF98A2B3).withOpacity(
                    paws[i % paws.length] == '🐾' ? 0.14 : 0.18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SoftBottomNav extends StatelessWidget {
  const SoftBottomNav({
    required this.selectedTab,
    required this.onTap,
    super.key,
  });

  final String selectedTab;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE5EDF3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F6784),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: selectedTab == 'home',
              onTap: () => onTap('home'),
            ),
            const SizedBox(width: 120),
            _BottomNavItem(
              icon: Icons.bookmark_border_rounded,
              label: 'Presets',
              selected: selectedTab == 'presets',
              onTap: () => onTap('presets'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0F6784) : const Color(0xFF98A2B3);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MedicationUnit {
  mcg('mcg', 1),
  mg('mg', 1000),
  g('g', 1000000),
  iu('IU', null),
  unit('units', null);

  const MedicationUnit(this.label, this.microgramFactor);

  final String label;
  final double? microgramFactor;

  bool get isMass => microgramFactor != null;
}

bool isFinitePositive(double? value) => value != null && value.isFinite && value > 0;

bool isFiniteNonNegative(double? value) => value != null && value.isFinite && value >= 0;

MedicationUnit? medicationUnitFromText(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('μ', 'u').replaceAll('µ', 'u');
  switch (normalized) {
    case 'mcg':
    case 'ug':
    case 'microgram':
    case 'micrograms':
      return MedicationUnit.mcg;
    case 'mg':
    case 'milligram':
    case 'milligrams':
      return MedicationUnit.mg;
    case 'g':
    case 'gram':
    case 'grams':
      return MedicationUnit.g;
    case 'iu':
      return MedicationUnit.iu;
    case 'unit':
    case 'units':
      return MedicationUnit.unit;
    default:
      return null;
  }
}

MedicationUnit? doseMedicationUnit(String doseUnit) {
  return medicationUnitFromText(doseUnit.split('/').first);
}

String? timeUnitFromDoseUnit(String doseUnit) {
  final parts = doseUnit.trim().toLowerCase().split('/');
  if (parts.length < 2) return null;
  switch (parts.last.trim()) {
    case 'min':
    case 'minute':
    case 'minutes':
      return 'min';
    case 'hr':
    case 'hour':
    case 'hours':
      return 'hr';
    case 'day':
    case 'days':
      return 'day';
    default:
      return null;
  }
}

double? convertMedicationAmount(
  double amount, {
  required MedicationUnit from,
  required MedicationUnit to,
}) {
  if (!amount.isFinite) return null;
  if (from == to) return amount;
  if (!from.isMass || !to.isMass) return null;
  return amount * from.microgramFactor! / to.microgramFactor!;
}

String? validatePreset(DrugPreset preset) {
  if (preset.name.trim().isEmpty) return '약물명이 비어 있습니다.';
  if (preset.doseUnit.trim().isEmpty) return '목표 용량 단위가 비어 있습니다.';
  if (!isFinitePositive(preset.drugAmount)) return '총 약물량은 0보다 큰 유한한 숫자여야 합니다.';
  if (!isFinitePositive(preset.volumeMl)) return '최종 부피는 0보다 큰 유한한 숫자여야 합니다.';
  if (!supportedTimeUnits.contains(preset.timeUnit)) return '시간 기준은 min, hr, day 중 하나여야 합니다.';
  final doseTimeUnit = timeUnitFromDoseUnit(preset.doseUnit);
  if (doseTimeUnit == null) return '목표 용량 단위에 min, hr, day 시간 기준을 포함해야 합니다.';
  if (doseTimeUnit != preset.timeUnit) {
    return '목표 용량 단위의 시간 기준과 선택한 시간 기준이 일치하지 않습니다.';
  }
  if (preset.minDose != null && !isFiniteNonNegative(preset.minDose)) {
    return '최소 용량은 0 이상의 유한한 숫자여야 합니다.';
  }
  if (preset.maxDose != null && !isFiniteNonNegative(preset.maxDose)) {
    return '최대 용량은 0 이상의 유한한 숫자여야 합니다.';
  }
  if (preset.minDose != null && preset.maxDose != null && preset.minDose! > preset.maxDose!) {
    return '최소 용량은 최대 용량보다 클 수 없습니다.';
  }
  if (!isFinitePositive(preset.rateIncrementMlPerHr)) {
    return '펌프 반올림 단위는 0보다 큰 유한한 숫자여야 합니다.';
  }

  final drugUnit = medicationUnitFromText(preset.drugUnit);
  final doseUnit = doseMedicationUnit(preset.doseUnit);
  if (drugUnit == null || doseUnit == null) {
    return '총 약물량과 목표 용량의 단위를 인식할 수 없습니다.';
  }
  if (convertMedicationAmount(preset.drugAmount, from: drugUnit, to: doseUnit) == null) {
    return '총 약물량과 목표 용량의 단위가 호환되지 않습니다.';
  }
  return null;
}

double calculateRate({
  required double dose,
  required double weight,
  required DrugPreset preset,
}) {
  final presetError = validatePreset(preset);
  if (presetError != null) throw ArgumentError.value(preset, 'preset', presetError);
  if (!isFinitePositive(dose)) {
    throw ArgumentError.value(dose, 'dose', 'Dose must be a finite number greater than zero.');
  }
  if (preset.useWeight && !isFinitePositive(weight)) {
    throw ArgumentError.value(weight, 'weight', 'Weight must be a finite number greater than zero.');
  }

  final drugUnit = medicationUnitFromText(preset.drugUnit)!;
  final doseUnit = doseMedicationUnit(preset.doseUnit)!;
  final normalizedDrugAmount =
      convertMedicationAmount(preset.drugAmount, from: drugUnit, to: doseUnit)!;
  final timeMultiplier = timeUnitRateFactor(preset.timeUnit);
  final weightFactor = preset.useWeight ? weight : 1.0;
  final rate = (dose * weightFactor * timeMultiplier * preset.volumeMl) / normalizedDrugAmount;
  if (!rate.isFinite || rate < 0) {
    throw StateError('Calculated infusion rate is not finite.');
  }
  return rate;
}

double calculateDoseFromRate({
  required double rateMlPerHr,
  required double weight,
  required DrugPreset preset,
}) {
  final presetError = validatePreset(preset);
  if (presetError != null) throw ArgumentError.value(preset, 'preset', presetError);
  if (!isFiniteNonNegative(rateMlPerHr)) {
    throw ArgumentError.value(rateMlPerHr, 'rateMlPerHr', 'Rate must be finite and non-negative.');
  }
  if (preset.useWeight && !isFinitePositive(weight)) {
    throw ArgumentError.value(weight, 'weight', 'Weight must be a finite number greater than zero.');
  }

  final drugUnit = medicationUnitFromText(preset.drugUnit)!;
  final doseUnit = doseMedicationUnit(preset.doseUnit)!;
  final normalizedDrugAmount =
      convertMedicationAmount(preset.drugAmount, from: drugUnit, to: doseUnit)!;
  final denominator = (preset.useWeight ? weight : 1.0) *
      timeUnitRateFactor(preset.timeUnit) *
      preset.volumeMl;
  final dose = rateMlPerHr * normalizedDrugAmount / denominator;
  if (!dose.isFinite || dose < 0) {
    throw StateError('Calculated dose is not finite.');
  }
  return dose;
}

double roundCalculatedRate(double value, DrugPreset preset) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, 'value', 'Rate must be a finite non-negative number.');
  }
  final increment = preset.rateIncrementMlPerHr;
  if (!isFinitePositive(increment)) {
    throw ArgumentError.value(increment, 'rateIncrementMlPerHr', 'Increment must be finite and positive.');
  }
  return (value / increment).round() * increment;
}

String formatCalculatedRate(double value, DrugPreset preset) {
  if (!value.isFinite || value < 0) return '--';
  final increment = preset.rateIncrementMlPerHr;
  if (!isFinitePositive(increment)) return '--';

  var digits = 0;
  var scaled = increment;
  while (digits < 3 && (scaled - scaled.round()).abs() > 0.000001) {
    scaled *= 10;
    digits += 1;
  }
  return value.toStringAsFixed(digits);
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
  final text = value.toStringAsFixed(2);
  if (text.endsWith('.00')) return text.substring(0, text.length - 3);
  if (text.endsWith('0')) return text.substring(0, text.length - 1);
  return text;
}

String formatOptionalDose(double? value, String unit) {
  if (value == null) return '-';
  return '${formatNumber(value)} $unit';
}

String formulaDrugAmount(DrugPreset preset) {
  final sourceUnit = medicationUnitFromText(preset.drugUnit);
  final targetUnit = doseMedicationUnit(preset.doseUnit);
  if (sourceUnit == null || targetUnit == null) {
    return '${formatNumber(preset.drugAmount)} ${preset.drugUnit}';
  }
  final converted = convertMedicationAmount(
    preset.drugAmount,
    from: sourceUnit,
    to: targetUnit,
  );
  if (converted == null) return '${formatNumber(preset.drugAmount)} ${preset.drugUnit}';
  return '${formatNumber(converted)} ${targetUnit.label}';
}

String presetDropdownLabel(String presetName) {
  final withoutDose = presetName.replaceAll(
    RegExp(r'\s+\d+(?:\.\d+)?\s*(?:mg|mcg|iu)(?=\s*\(|$)', caseSensitive: false),
    '',
  );
  return withoutDose.replaceAllMapped(
    RegExp(r'([A-Za-z가-힣])\('),
    (match) => '${match.group(1)} (',
  );
}

String extractMixLine(String note, String drugName) {
  if (note.trim().isEmpty) return '-';
  final lines = note.split('\n');
  for (final line in lines) {
    if (line.toLowerCase().contains('mix')) {
      final mixBody = line.replaceFirst(RegExp(r'^mix\s*', caseSensitive: false), '');
      return '$drugName: $mixBody';
    }
  }
  return lines.first;
}

String extractAdditionalNote(String note) {
  if (note.trim().isEmpty) return '';

  final extraLines = note
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !line.toLowerCase().startsWith('mix'))
      .where((line) => !RegExp(r'^min\s', caseSensitive: false).hasMatch(line))
      .toList();

  return extraLines.join('\n');
}

Map<String, List<DrugPreset>> defaultPresetMap() {
  return {
    for (final department in defaultDepartments)
      department.id: department.presets.map((preset) => preset.copy()).toList(),
  };
}

Map<String, List<DrugPreset>> migratePresetMap({
  String? currentRaw,
  String? legacyRaw,
}) {
  return _decodePresetMap(currentRaw) ?? _decodePresetMap(legacyRaw) ?? defaultPresetMap();
}

Map<String, List<DrugPreset>>? _decodePresetMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  try {
    final decodedValue = jsonDecode(raw);
    if (decodedValue is! Map) return null;
    final decoded = Map<String, dynamic>.from(decodedValue);
    final mergedMap = <String, List<DrugPreset>>{};

    for (final department in defaultDepartments) {
      final rawPresets = decoded[department.id];
      if (rawPresets is! List) {
        mergedMap[department.id] = department.presets.map((preset) => preset.copy()).toList();
        continue;
      }

      final parsedPresets = <DrugPreset>[];
      for (final rawPreset in rawPresets) {
        if (rawPreset is! Map) continue;
        final preset = DrugPreset.tryFromJson(Map<String, dynamic>.from(rawPreset));
        if (preset != null) parsedPresets.add(preset);
      }

      if (department.id == 'micu' && shouldReplaceLegacyMicuPresets(parsedPresets)) {
        parsedPresets.clear();
      }
      mergedMap[department.id] = parsedPresets.isEmpty
          ? department.presets.map((preset) => preset.copy()).toList()
          : ensureUniquePresetIds(parsedPresets);
    }
    return mergedMap;
  } catch (_) {
    return null;
  }
}

List<DrugPreset> ensureUniquePresetIds(List<DrugPreset> presets) {
  final seenIds = <String>{};

  return presets.map((preset) {
    var nextId = preset.id;
    if (nextId.isEmpty || seenIds.contains(nextId)) {
      nextId = uniqueId();
    }
    seenIds.add(nextId);

    return DrugPreset(
      id: nextId,
      name: preset.name,
      doseUnit: preset.doseUnit,
      minDose: preset.minDose,
      maxDose: preset.maxDose,
      drugAmount: preset.drugAmount,
      drugUnit: preset.drugUnit,
      volumeMl: preset.volumeMl,
      timeUnit: preset.timeUnit,
      useWeight: preset.useWeight,
      note: preset.note,
      rateIncrementMlPerHr: preset.rateIncrementMlPerHr,
    );
  }).toList();
}

List<DrugPreset> upsertPreset(List<DrugPreset> existing, DrugPreset edited) {
  final presetError = validatePreset(edited);
  if (presetError != null) {
    throw ArgumentError.value(edited, 'edited', presetError);
  }

  final updated = [...existing];
  final index = updated.indexWhere((item) => item.id == edited.id);
  if (index >= 0) {
    updated[index] = edited;
  } else {
    updated.add(edited);
  }
  return ensureUniquePresetIds(updated);
}

double timeUnitRateFactor(String timeUnit) {
  switch (timeUnit) {
    case 'min':
      return 60.0;
    case 'day':
      return 1 / 24;
    case 'hr':
      return 1.0;
    default:
      throw ArgumentError.value(timeUnit, 'timeUnit', 'Unsupported time unit.');
  }
}

String timeUnitFactorLabel(String timeUnit) {
  switch (timeUnit) {
    case 'min':
      return '60';
    case 'day':
      return '1/24';
    case 'hr':
      return '1';
    default:
      return '?';
  }
}

String timeUnitDescription(String timeUnit) {
  switch (timeUnit) {
    case 'min':
      return '분당 × 60';
    case 'day':
      return '일당 × 1/24';
    case 'hr':
      return '시간당 × 1';
    default:
      return '지원하지 않는 시간 기준';
  }
}

bool shouldReplaceLegacyMicuPresets(List<DrugPreset> presets) {
  if (presets.isEmpty) return false;

  final names = presets.map((preset) => preset.name.toLowerCase()).toSet();
  const preExampleNames = {'noradrenaline', 'vasopressin', 'dobutamine'};
  const previousMicuNames = {
    'remifentanil (1 mg)',
    'remifentanil (2 mg)',
    'propofol (200 mg)',
    'propofol (400 mg)',
    'sufentanil (50 mcg)',
    'sufentanil (200 mcg)',
    'rocuronium (50 mg)',
    'rocuronium (250 mg)',
    'ketamine (250 mg)',
    'ketamine (500 mg)',
    'midazolam',
    'morphine (10 mg)',
    'morphine (50 mg)',
    'norphin (central) (4 mg)',
    'norphin (central) (12 mg)',
    'norphin (pph) (4 mg)',
    'norphin (pph) (6 mg)',
  };
  const correctedNames = {
    'precedex',
    'remifentanil 1mg',
    'propofol 200mg',
    'sufentanil 50mcg',
    'rocuronium 50mg',
    'ketamine 250mg',
    'midazolam 15mg',
    'morphine 10mg',
    'norphin 4mg (central)',
    'norphin 4mg(pph)',
    'vasopressin 20iu',
    'epinephrine 1mg',
    'nicardipine 10mg',
    'diltiazem 50mg',
    'amiodarone 150mg',
    'lidocaine 400mg',
    'isoproterenol 0.2mg',
    'milrinone 10mg',
    'novastan 10mg',
    'pantoprazole 40mg',
    'cortisol 100mg',
  };

  return (names.any(preExampleNames.contains) || names.any(previousMicuNames.contains)) &&
      !names.any(correctedNames.contains);
}

DrugPreset buildDrugPreset({
  required String name,
  required String doseUnit,
  required double drugAmount,
  required String drugUnit,
  required double volumeMl,
  required String timeUnit,
  required bool useWeight,
  required String note,
  double? minDose,
  double? maxDose,
}) {
  return DrugPreset(
    id: uniqueId(),
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

List<DrugPreset> buildDrugPresetVariants({
  required String name,
  required String doseUnit,
  required List<double> drugAmounts,
  required List<String> amountLabels,
  required String drugUnit,
  required String diluent,
  required double volumeMl,
  required String timeUnit,
  required bool useWeight,
  required String note,
  double? minDose,
  double? maxDose,
}) {
  return [
    for (var i = 0; i < drugAmounts.length; i++)
      buildDrugPreset(
        name: amountLabels.length > 1 ? '$name (${amountLabels[i]})' : name,
        doseUnit: doseUnit,
        drugAmount: drugAmounts[i],
        drugUnit: drugUnit,
        volumeMl: volumeMl,
        timeUnit: timeUnit,
        useWeight: useWeight,
        minDose: minDose,
        maxDose: maxDose,
        note: 'Mix ${amountLabels[i]} + $diluent ${formatNumber(volumeMl)} mL\n$note',
      ),
  ];
}

List<DrugPreset> defaultMicuPresets() {
  return [
    buildDrugPreset(
      name: 'precedex',
      doseUnit: 'mcg/kg/hr',
      drugAmount: 400,
      drugUnit: 'mcg',
      volumeMl: 100,
      timeUnit: 'hr',
      useWeight: true,
      minDose: 0.1,
      maxDose: 1.0,
      note: 'Mix 400 mcg + NS 100 mL\nmin 0.1, max 1.0',
    ),
    buildDrugPreset(
      name: 'remifentanil 1mg',
      doseUnit: 'mcg/kg/min',
      drugAmount: 2000,
      drugUnit: 'mcg',
      volumeMl: 40,
      timeUnit: 'min',
      useWeight: true,
      minDose: 0.01,
      maxDose: 0.1,
      note: 'Mix 2 mg + 5DW 40 mL\n1 vial 1 mg 기준 / 총량 2 mg\nmin 0.01, max 0.1',
    ),
    buildDrugPreset(
      name: 'propofol 200mg',
      doseUnit: 'mcg/kg/min',
      drugAmount: 400000,
      drugUnit: 'mcg',
      volumeMl: 40,
      timeUnit: 'min',
      useWeight: true,
      minDose: 10,
      maxDose: 40,
      note: '원액사용 / 총량 400 mg (200 mg vial × 2) / 계산용 총부피 40 mL\nmin 10, max 40, 단독 route 사용, 12hr line change, 원액사용',
    ),
    buildDrugPreset(
      name: 'sufentanil 50mcg',
      doseUnit: 'mcg/kg/hr',
      drugAmount: 200,
      drugUnit: 'mcg',
      volumeMl: 40,
      timeUnit: 'hr',
      useWeight: true,
      minDose: 0.2,
      maxDose: 1,
      note: 'Mix 200 mcg + 5DW 40 mL\n1 vial 50 mcg 기준 / 총량 200 mcg\nmin 0.2, max 1',
    ),
    buildDrugPreset(
      name: 'rocuronium 50mg',
      doseUnit: 'mcg/kg/hr',
      drugAmount: 250000,
      drugUnit: 'mcg',
      volumeMl: 50,
      timeUnit: 'hr',
      useWeight: true,
      minDose: 0.2,
      maxDose: 1,
      note: 'Mix 250 mg + 5DW 50 mL\n1 vial 50 mg 기준 / 총량 250 mg\nmin 0.2, max 1',
    ),
    buildDrugPreset(
      name: 'ketamine 250mg',
      doseUnit: 'mcg/kg/hr',
      drugAmount: 500000,
      drugUnit: 'mcg',
      volumeMl: 250,
      timeUnit: 'hr',
      useWeight: true,
      minDose: 0.2,
      maxDose: 4,
      note: 'Mix 500 mg + 5DW 250 mL\n1 vial 250 mg 기준 / 총량 500 mg\nmin 0.2, max 4',
    ),
    buildDrugPreset(
      name: 'midazolam 15mg',
      doseUnit: 'mg/hr',
      drugAmount: 45,
      drugUnit: 'mg',
      volumeMl: 45,
      timeUnit: 'hr',
      useWeight: false,
      minDose: 0.2,
      note: 'Mix 45 mg + 5DW 45 mL\n1 vial 15 mg 기준 / 총량 45 mg\nmin 0.2, max none',
    ),
    buildDrugPreset(
      name: 'morphine 10mg',
      doseUnit: 'mg/hr',
      drugAmount: 50,
      drugUnit: 'mg',
      volumeMl: 50,
      timeUnit: 'hr',
      useWeight: false,
      minDose: 1,
      note: 'Mix 50 mg + 5DW 50 mL\n1 vial 10 mg 기준 / 총량 50 mg\nmin 1, max none',
    ),
    buildDrugPreset(
      name: 'norphin 4mg (central)',
      doseUnit: 'mcg/min',
      drugAmount: 12000,
      drugUnit: 'mcg',
      volumeMl: 200,
      timeUnit: 'min',
      useWeight: false,
      minDose: 2,
      maxDose: 64,
      note: 'Mix 12 mg + 5DW 200 mL\n1 vial 4 mg 기준 / 총량 12 mg\nmin 2, max 64',
    ),
    buildDrugPreset(
      name: 'norphin 4mg(pph)',
      doseUnit: 'mcg/min',
      drugAmount: 6000,
      drugUnit: 'mcg',
      volumeMl: 200,
      timeUnit: 'min',
      useWeight: false,
      minDose: 2,
      maxDose: 64,
      note: 'Mix 6 mg + 5DW 200 mL\n1 vial 4 mg 기준 / 총량 6 mg\nmin 2, max 64',
    ),
    buildDrugPreset(
      name: 'vasopressin 20iu',
      doseUnit: 'iu/min',
      drugAmount: 40,
      drugUnit: 'iu',
      volumeMl: 100,
      timeUnit: 'min',
      useWeight: false,
      minDose: 0.02,
      maxDose: 0.1,
      note: 'Mix 40 IU + 5DW 100 mL\n1 vial 20 IU 기준 / 총량 40 IU\nmin 0.02, max 0.1',
    ),
    buildDrugPreset(
      name: 'epinephrine 1mg',
      doseUnit: 'mcg/kg/min',
      drugAmount: 10000,
      drugUnit: 'mcg',
      volumeMl: 100,
      timeUnit: 'min',
      useWeight: true,
      minDose: 0.02,
      maxDose: 0.7,
      note: 'Mix 10 mg + 5DW 100 mL\n1 vial 1 mg 기준 / 총량 10 mg\nmin 0.02, max 0.7',
    ),
    buildDrugPreset(
      name: 'dopamine',
      doseUnit: 'mcg/kg/min',
      drugAmount: 400000,
      drugUnit: 'mcg',
      volumeMl: 200,
      timeUnit: 'min',
      useWeight: true,
      minDose: 3,
      maxDose: 20,
      note: 'Mix 400 mg + 5DW 200 mL\nmin 3, max 20',
    ),
    buildDrugPreset(
      name: 'dobutamine',
      doseUnit: 'mcg/kg/min',
      drugAmount: 500000,
      drugUnit: 'mcg',
      volumeMl: 250,
      timeUnit: 'min',
      useWeight: true,
      minDose: 3,
      maxDose: 20,
      note: 'Mix 500 mg + 5DW 250 mL\nmin 3, max 20',
    ),
    buildDrugPreset(
      name: 'nicardipine 10mg',
      doseUnit: 'mg/hr',
      drugAmount: 50,
      drugUnit: 'mg',
      volumeMl: 250,
      timeUnit: 'hr',
      useWeight: false,
      minDose: 1,
      maxDose: 15,
      note: 'Mix 50 mg + 5DW 250 mL\n1 vial 10 mg 기준 / 총량 50 mg\nmin 1, max 15',
    ),
    buildDrugPreset(
      name: 'nitroglycerin',
      doseUnit: 'mcg/min',
      drugAmount: 50000,
      drugUnit: 'mcg',
      volumeMl: 250,
      timeUnit: 'min',
      useWeight: false,
      minDose: 10,
      maxDose: 200,
      note: 'Mix 50 mg + 5DW 250 mL\nmin 10, max 200',
    ),
    buildDrugPreset(
      name: 'esmolol',
      doseUnit: 'mcg/kg/min',
      drugAmount: 2500000,
      drugUnit: 'mcg',
      volumeMl: 250,
      timeUnit: 'min',
      useWeight: true,
      minDose: 50,
      maxDose: 300,
      note: 'Mix 2500 mg + 5DW 250 mL\nmin 50, max 300, 250-500mcg/kg loading (1min 이상)',
    ),
    buildDrugPreset(
      name: 'diltiazem 50mg',
      doseUnit: 'mg/hr',
      drugAmount: 100,
      drugUnit: 'mg',
      volumeMl: 100,
      timeUnit: 'hr',
      useWeight: false,
      minDose: 5,
      maxDose: 50,
      note: 'Mix 100 mg + 5DW 100 mL\n1 vial 50 mg 기준 / 총량 100 mg\nmin 5, max 50',
    ),
    buildDrugPreset(
      name: 'amiodarone 150mg',
      doseUnit: 'mg/min',
      drugAmount: 900,
      drugUnit: 'mg',
      volumeMl: 500,
      timeUnit: 'min',
      useWeight: false,
      note: 'Mix 900 mg + 5DW 500 mL\n1 vial 150 mg 기준 / 총량 900 mg\n1mg/min 6hr, 0.5mg/min 18hr, 150-300mg loading (10min 이상)',
    ),
    buildDrugPreset(
      name: 'lidocaine 400mg',
      doseUnit: 'mg/min',
      drugAmount: 1600,
      drugUnit: 'mg',
      volumeMl: 200,
      timeUnit: 'min',
      useWeight: false,
      minDose: 0.5,
      maxDose: 4,
      note: 'Mix 1600 mg + 5DW 200 mL\n1 vial 400 mg 기준 / 총량 1600 mg\nmin 0.5, max 4',
    ),
    buildDrugPreset(
      name: 'isoproterenol 0.2mg',
      doseUnit: 'mcg/min',
      drugAmount: 1000,
      drugUnit: 'mcg',
      volumeMl: 500,
      timeUnit: 'min',
      useWeight: false,
      minDose: 0.5,
      maxDose: 5,
      note: 'Mix 1 mg + 5DW 500 mL\n1 vial 0.2 mg 기준 / 총량 1 mg\nmin 0.5, max 5',
    ),
    buildDrugPreset(
      name: 'milrinone 10mg',
      doseUnit: 'mcg/kg/min',
      drugAmount: 50000,
      drugUnit: 'mcg',
      volumeMl: 200,
      timeUnit: 'min',
      useWeight: true,
      minDose: 0.25,
      maxDose: 0.75,
      note: 'Mix 50 mg + 5DW 200 mL\n1 vial 10 mg 기준 / 총량 50 mg\nmin 0.25, max 0.75, 50mcg/kg loading (10min)',
    ),
    buildDrugPreset(
      name: 'heparin',
      doseUnit: 'iu/kg/hr',
      drugAmount: 25000,
      drugUnit: 'iu',
      volumeMl: 500,
      timeUnit: 'hr',
      useWeight: true,
      minDose: 12,
      note: 'Mix 25000 IU + 5DW 500 mL\nmin 12, max 1000iu/hr',
    ),
    buildDrugPreset(
      name: 'novastan 10mg',
      doseUnit: 'mcg/kg/min',
      drugAmount: 20000,
      drugUnit: 'mcg',
      volumeMl: 100,
      timeUnit: 'min',
      useWeight: true,
      minDose: 0.5,
      maxDose: 10,
      note: 'Mix 20 mg + 5DW 100 mL\n1 vial 10 mg 기준 / 총량 20 mg\nmin 0.5, max 10',
    ),
    buildDrugPreset(
      name: 'pantoprazole 40mg',
      doseUnit: 'mg/hr',
      drugAmount: 80,
      drugUnit: 'mg',
      volumeMl: 80,
      timeUnit: 'hr',
      useWeight: false,
      note: 'Mix 80 mg + NS 80 mL\n1 vial 40 mg 기준 / 총량 80 mg\n8mg/hr 고정',
    ),
    buildDrugPreset(
      name: 'cortisol 100mg',
      doseUnit: 'mg/day',
      drugAmount: 200,
      drugUnit: 'mg',
      volumeMl: 200,
      timeUnit: 'day',
      useWeight: false,
      note: 'Mix 200 mg + 5DW 200 mL\n1 vial 100 mg 기준 / 총량 200 mg\n200mg/day 일반적으로 사용',
    ),
  ];
}

final List<DepartmentPreset> defaultDepartments = [
      DepartmentPreset(
        id: 'micu',
        label: 'MICU',
        icon: '🫁',
        description: '내과계 중환자실',
        presets: defaultMicuPresets(),
      ),
      DepartmentPreset(
        id: 'sicu',
        label: 'SICU',
        icon: '🩺',
        description: '외과계 중환자실',
        presets: [
          DrugPreset(
            id: uniqueId(),
            name: 'Fentanyl',
            doseUnit: 'mcg/hr',
            minDose: 25,
            maxDose: 200,
            drugAmount: 1000,
            drugUnit: 'mcg',
            volumeMl: 50,
            timeUnit: 'hr',
            useWeight: false,
            note: 'Mix 1000 mcg + NS 50 mL\n진정 점수와 호흡수 함께 확인',
          ),
          DrugPreset(
            id: uniqueId(),
            name: 'Nicardipine',
            doseUnit: 'mg/hr',
            minDose: 1,
            maxDose: 15,
            drugAmount: 20,
            drugUnit: 'mg',
            volumeMl: 100,
            timeUnit: 'hr',
            useWeight: false,
            note: 'Mix 20 mg + NS 100 mL\n혈압 변화 빠르므로 단계적 증량',
          ),
          DrugPreset(
            id: uniqueId(),
            name: 'Heparin',
            doseUnit: 'units/hr',
            minDose: 500,
            maxDose: 2000,
            drugAmount: 25000,
            drugUnit: 'units',
            volumeMl: 50,
            timeUnit: 'hr',
            useWeight: false,
            note: 'Mix 25000 units + NS 50 mL\nPTT 또는 anti-Xa 프로토콜 확인',
          ),
        ],
      ),
      DepartmentPreset(
        id: 'eicu2',
        label: 'EICU2',
        icon: '⚡',
        description: '응급 중환자실2',
        presets: [
          DrugPreset(
            id: uniqueId(),
            name: 'Adrenaline',
            doseUnit: 'mcg/kg/min',
            minDose: 0.01,
            maxDose: 0.5,
            drugAmount: 4,
            drugUnit: 'mg',
            volumeMl: 50,
            timeUnit: 'min',
            useWeight: true,
            note: 'Mix 4 mg + D5W 50 mL\n부정맥 및 말초허혈 주의',
          ),
          DrugPreset(
            id: uniqueId(),
            name: 'Amiodarone',
            doseUnit: 'mg/hr',
            minDose: 0.5,
            maxDose: 1,
            drugAmount: 150,
            drugUnit: 'mg',
            volumeMl: 100,
            timeUnit: 'hr',
            useWeight: false,
            note: 'Loading dose 후 유지주입으로 전환\nQT prolongation 확인',
          ),
          DrugPreset(
            id: uniqueId(),
            name: 'Dopamine',
            doseUnit: 'mcg/kg/min',
            minDose: 2,
            maxDose: 20,
            drugAmount: 200,
            drugUnit: 'mg',
            volumeMl: 50,
            timeUnit: 'min',
            useWeight: true,
            note: 'Mix 200 mg + NS 50 mL\n빈맥과 혈압 반응 모니터링',
          ),
        ],
      ),
      DepartmentPreset(
        id: 'ncu',
        label: 'NCU',
        icon: '🧠',
        description: '신경계 중환자실',
        presets: [
          DrugPreset(
            id: uniqueId(),
            name: 'Nimodipine',
            doseUnit: 'mg/hr',
            minDose: 1,
            maxDose: 2,
            drugAmount: 10,
            drugUnit: 'mg',
            volumeMl: 50,
            timeUnit: 'hr',
            useWeight: false,
            note: '저혈압 시 감량 고려\n혈압 유지 목표 확인',
          ),
          DrugPreset(
            id: uniqueId(),
            name: 'Propofol',
            doseUnit: 'mg/kg/hr',
            minDose: 0.3,
            maxDose: 3,
            drugAmount: 500,
            drugUnit: 'mg',
            volumeMl: 50,
            timeUnit: 'hr',
            useWeight: true,
            note: '중성지방, 혈압, 진정 점수 모니터링\n장시간 고용량 사용 주의',
          ),
          DrugPreset(
            id: uniqueId(),
            name: 'Midazolam',
            doseUnit: 'mg/hr',
            minDose: 1,
            maxDose: 10,
            drugAmount: 50,
            drugUnit: 'mg',
            volumeMl: 50,
            timeUnit: 'hr',
            useWeight: false,
            note: 'Loading dose 여부는 상황에 따라 판단\n호흡억제 및 진정 깊이 평가',
          ),
        ],
      ),
    ];

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

  String get displayTitle => '$label $description';
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
      rateIncrementMlPerHr: ((json['rateIncrementMlPerHr'] as num?) ?? 0.1).toDouble(),
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
        (json['rateIncrementMlPerHr'] != null && json['rateIncrementMlPerHr'] is! num)) {
      return null;
    }

    final preset = DrugPreset.fromJson(json);
    return validatePreset(preset) == null ? preset : null;
  }
}

int _uniqueIdCounter = 0;

String uniqueId() {
  _uniqueIdCounter += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_uniqueIdCounter';
}

String? readFirstAvailableString(
  SharedPreferences prefs,
  String primaryKey,
  List<String> legacyKeys,
  {bool ignoreEmpty = false},
) {
  final primaryValue = prefs.getString(primaryKey);
  if (primaryValue != null && (!ignoreEmpty || primaryValue.isNotEmpty)) return primaryValue;

  for (final legacyKey in legacyKeys) {
    final legacyValue = prefs.getString(legacyKey);
    if (legacyValue != null && (!ignoreEmpty || legacyValue.isNotEmpty)) return legacyValue;
  }

  return null;
}

String? readFirstLegacyString(SharedPreferences prefs, List<String> legacyKeys) {
  for (final legacyKey in legacyKeys) {
    final value = prefs.getString(legacyKey);
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

Future<void> removeLegacyKeys(
  SharedPreferences prefs,
  List<String> legacyKeys,
) async {
  for (final legacyKey in legacyKeys) {
    await prefs.remove(legacyKey);
  }
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
