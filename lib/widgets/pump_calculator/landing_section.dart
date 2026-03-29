import 'package:flutter/material.dart';

import '../../data/default_presets.dart' as preset_data;
import '../../models/drug_preset.dart';
import 'shared_widgets.dart';

class LandingSection extends StatelessWidget {
  const LandingSection({
    required this.selectedDepartmentLabel,
    required this.onSelectDepartment,
    required this.selectedDepartmentId,
    super.key,
  });

  final String selectedDepartmentLabel;
  final ValueChanged<String> onSelectDepartment;
  final String? selectedDepartmentId;

  @override
  Widget build(BuildContext context) {
    return _LandingSectionBody(
      selectedDepartmentLabel: selectedDepartmentLabel,
      onSelectDepartment: onSelectDepartment,
      selectedDepartmentId: selectedDepartmentId,
    );
  }
}

class _LandingSectionBody extends StatelessWidget {
  const _LandingSectionBody({
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
          const CloudHeader(
            titleSize: 44,
            subtitle: '부서 선택 후 바로 약물 속도를 계산할 수 있어요',
          ),
          const SizedBox(height: 20),
          const _PickBanner(),
          const SizedBox(height: 18),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preset_data.defaultDepartments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final department = preset_data.defaultDepartments[index];
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
              color:
                  selected ? const Color(0xFF8FD5F7) : const Color(0xFFE5EDF3),
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
                        ? [const Color(0xFF8FD5F7), const Color(0xFFFFD1DC)]
                        : [const Color(0xFFF3F8FB), const Color(0xFFFFF1F5)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child:
                    Text(department.icon, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(height: 14),
              Text(
                department.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163647),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFD9F0FB)
                      : const Color(0xFFF2F5F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selected ? '선택됨' : '탭해서 선택',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
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
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF344054),
        ),
      ),
    );
  }
}

class _PickBanner extends StatelessWidget {
  const _PickBanner();

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
          Icon(
            Icons.local_hospital_rounded,
            color: Color(0xFF0F6784),
            size: 18,
          ),
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
