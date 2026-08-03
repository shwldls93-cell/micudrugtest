import 'package:flutter/material.dart';

import '../../data/default_presets.dart' as preset_data;
import '../../models/drug_preset.dart';
import 'shared_widgets.dart';

class LandingSection extends StatelessWidget {
  const LandingSection({
    required this.onSelectDepartment,
    required this.selectedDepartmentId,
    super.key,
  });

  final ValueChanged<String> onSelectDepartment;
  final String? selectedDepartmentId;

  @override
  Widget build(BuildContext context) {
    return _LandingSectionBody(
      onSelectDepartment: onSelectDepartment,
      selectedDepartmentId: selectedDepartmentId,
    );
  }
}

class _LandingSectionBody extends StatelessWidget {
  const _LandingSectionBody({
    required this.onSelectDepartment,
    required this.selectedDepartmentId,
  });

  final ValueChanged<String> onSelectDepartment;
  final String? selectedDepartmentId;

  @override
  Widget build(BuildContext context) {
    return ThemedBoard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CloudHeader(titleSize: 52),
          const SizedBox(height: 14),
          const _PickBanner(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final useSingleColumn = constraints.maxWidth < 360;
              return GridView.count(
                crossAxisCount: useSingleColumn ? 1 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: useSingleColumn ? 12 : 18,
                crossAxisSpacing: 18,
                childAspectRatio: useSingleColumn ? 2.65 : 1.35,
                children: [
                  for (final department in preset_data.defaultDepartments)
                    DepartmentCard(
                      department: department,
                      selected: selectedDepartmentId == department.id,
                      useHorizontalLayout: useSingleColumn,
                      onTap: () => onSelectDepartment(department.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class DepartmentCard extends StatelessWidget {
  const DepartmentCard({
    required this.department,
    required this.selected,
    required this.useHorizontalLayout,
    required this.onTap,
    super.key,
  });

  final DepartmentPreset department;
  final bool selected;
  final bool useHorizontalLayout;
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
            padding: useHorizontalLayout
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : const EdgeInsets.fromLTRB(10, 18, 10, 14),
            child: useHorizontalLayout
                ? Row(
                    children: [
                      Text(
                        department.icon,
                        style: const TextStyle(fontSize: 27),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _DepartmentCardText(
                          department: department,
                          selected: selected,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        department.icon,
                        style: const TextStyle(fontSize: 25),
                      ),
                      const SizedBox(height: 5),
                      _DepartmentCardText(
                        department: department,
                        selected: selected,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentCardText extends StatelessWidget {
  const _DepartmentCardText({
    required this.department,
    required this.selected,
    required this.textAlign,
  });

  final DepartmentPreset department;
  final bool selected;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlign == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          department.label,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 20,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: selected ? const Color(0xFF0F6784) : snoobiInk,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          department.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF52606D),
          ),
        ),
      ],
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
              TextSpan(text: '계산할 부서를 선택해 주세요'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
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
