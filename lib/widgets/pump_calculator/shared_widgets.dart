import 'package:flutter/material.dart';

import 'layout_constants.dart';

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
              const _PatternBadge(label: 'ICU CALC'),
              const Spacer(),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFB85C7A),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TitleStack(fontSize: titleSize),
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
                const Text(
                  '현재 선택 부서',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
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
              const SizedBox(width: 6),
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F6784),
          ),
        ),
      ),
    );
  }
}

class UnitLabel extends StatelessWidget {
  const UnitLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return CalculatorSuffixSlot(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: calculatorUnitFontSize,
            fontWeight: FontWeight.w900,
            color: Color(0xFF163647),
          ),
        ),
      ),
    );
  }
}

class CalculatorSuffixSlot extends StatelessWidget {
  const CalculatorSuffixSlot({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: calculatorSuffixWidth,
      child: Center(child: child),
    );
  }
}

class RateSuffix extends StatelessWidget {
  const RateSuffix({required this.showWarning, super.key});

  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: calculatorSuffixWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UnitLabel('cc/hr'),
          if (showWarning)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '주입용량확인',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
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
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
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
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color:
                isWarning ? const Color(0xFFC12828) : const Color(0xFF101828),
          ),
        ),
      ),
    );
  }
}

class EditorField extends StatelessWidget {
  const EditorField({
    required this.controller,
    required this.label,
    required this.width,
    this.isOptional = false,
    this.isNumeric = false,
    this.keyboardType,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final bool isOptional;
  final bool isNumeric;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null) return isOptional ? null : '$label 입력';
          if (value.trim().isEmpty) return isOptional ? null : '$label 입력';
          if (isNumeric && double.tryParse(value.trim()) == null) {
            return '숫자만 입력해 주세요.';
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
    focusedBorder:
        roundedInputBorder(color: const Color(0xFF8FD5F7), radius: 18),
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
          ],
        ),
      ),
    );
  }
}

class _TitleStack extends StatelessWidget {
  const _TitleStack({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FlatTitle(
          text: '스누비',
          color: const Color(0xFF0F6784),
          fontSize: fontSize,
        ),
        _FlatTitle(
          text: '쫀득 계산기',
          color: const Color(0xFF293056),
          fontSize: fontSize - 2,
        ),
      ],
    );
  }
}

class _FlatTitle extends StatelessWidget {
  const _FlatTitle({
    required this.text,
    required this.color,
    required this.fontSize,
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

class _PatternBadge extends StatelessWidget {
  const _PatternBadge({required this.label});

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
