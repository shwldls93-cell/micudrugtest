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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CloudHeader(titleSize: 62),
          const SizedBox(height: 20),
          const _PickBanner(),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 1.35,
            children: [
              for (final department in preset_data.defaultDepartments)
                DepartmentCard(
                  department: department,
                  selected: selectedDepartmentId == department.id,
                  onTap: () => onSelectDepartment(department.id),
                ),
            ],
          ),
          const SizedBox(height: 22),
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
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: ScallopedCard(
            selected: selected,
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  department.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: selected ? const Color(0xFF0F6784) : snoobiInk,
                  ),
                ),
              ),
            ),
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
        color: snoobiPaper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: snoobiInk, width: 1.3),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, color: snoobiInk),
      ),
    );
  }
}

class _PickBanner extends StatelessWidget {
  const _PickBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: snoobiCream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: snoobiInk, width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '당신의 부서를 '),
                  TextSpan(
                    text: 'pick',
                    style: TextStyle(color: snoobiRed),
                  ),
                  TextSpan(text: ' 해주세요!'),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: snoobiInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
