import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout_constants.dart';

const snoobiSky = Color(0xFFAEDCEF);
const snoobiPaper = Color(0xFFFFFEFA);
const snoobiInk = Color(0xFF171717);
const snoobiCream = Color(0xFFFFF8B9);
const snoobiBlue = Color(0xFFAED9EC);
const snoobiPink = Color(0xFFFFA7D4);
const snoobiRed = Color(0xFFE75D55);

class SnoobiAsset {
  const SnoobiAsset._();

  static const dogMegaphone = 'app_assets/snoobi/dog_megaphone.png';
  static const catMagnifier = 'app_assets/snoobi/cat_magnifier.png';
  static const star = 'app_assets/snoobi/star.png';
  static const bubbles = 'app_assets/snoobi/bubbles.png';
  static const bubbleSingle = 'app_assets/snoobi/bubble_single.png';
}

class ThemedBoard extends StatelessWidget {
  const ThemedBoard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: snoobiPaper,
        border: Border.all(color: snoobiInk, width: 2.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
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
    final compact = titleSize < 40;
    final height = compact ? 178.0 : 300.0;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _CloudPainter())),
          Positioned(
              left: compact ? 18 : 28,
              top: compact ? 18 : 34,
            child: Image.asset(
              SnoobiAsset.catMagnifier,
              width: compact ? 56 : 96,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
              right: compact ? 14 : 26,
              top: compact ? 28 : 70,
            child: Image.asset(
              SnoobiAsset.dogMegaphone,
              width: compact ? 56 : 96,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
              left: compact ? 106 : 142,
              top: compact ? 48 : 124,
            child: _DecorationAsset(
              path: SnoobiAsset.star,
              size: compact ? 16 : 28,
            ),
          ),
          Positioned(
              right: compact ? 62 : 46,
              top: compact ? 30 : 86,
            child: _DecorationAsset(
              path: SnoobiAsset.star,
              size: compact ? 15 : 25,
            ),
          ),
          Positioned(
              left: compact ? 10 : 18,
              top: compact ? 72 : 112,
            child: _DecorationAsset(
              path: SnoobiAsset.bubbleSingle,
              size: compact ? 24 : 40,
              opacity: 0.9,
            ),
          ),
          Positioned(
            right: compact ? 0 : -4,
            bottom: compact ? -4 : 18,
            child: _DecorationAsset(
              path: SnoobiAsset.bubbles,
              size: compact ? 44 : 72,
              opacity: 0.92,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
              top: compact ? 20 : 54,
            child: Center(child: _TitleStack(fontSize: titleSize)),
          ),
          if (subtitle != null)
            Positioned(
              left: 34,
              right: 34,
              bottom: footer == null ? 10 : (compact ? 62 : 56),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF535353),
                ),
              ),
            ),
          if (footer != null)
            Positioned(
              left: compact ? 12 : 22,
              right: compact ? 12 : 22,
              bottom: compact ? 14 : 26,
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class HandDrawnDivider extends StatelessWidget {
  const HandDrawnDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      width: double.infinity,
      color: snoobiInk,
      margin: const EdgeInsets.symmetric(vertical: 14),
    );
  }
}

class ScallopedCard extends StatelessWidget {
  const ScallopedCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.selected = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScallopedPainter(
        color: selected ? const Color(0xFFFFF39D) : snoobiCream,
      ),
      child: Padding(padding: padding, child: child),
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
    return Material(
      color: snoobiCream,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: snoobiInk, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$title 선택중',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: snoobiInk,
                  ),
                ),
              ),
              const Icon(Icons.swap_horiz_rounded, size: 18, color: snoobiInk),
            ],
          ),
        ),
      ),
    );
  }
}

class CalculatorRow extends StatelessWidget {
  const CalculatorRow({
    required this.label,
    required this.child,
    this.suffix,
    super.key,
  });

  final String label;
  final Widget child;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label 영역',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useStackedLayout = constraints.maxWidth < 350;
            final inputRow = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: child),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  suffix!,
                ],
              ],
            );

            if (useStackedLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 112, child: LabelPill(text: label)),
                  const SizedBox(height: 7),
                  inputRow,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 104, child: LabelPill(text: label)),
                const SizedBox(width: 10),
                Expanded(child: inputRow),
              ],
            );
          },
        ),
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: snoobiCream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: snoobiInk, width: 1.4),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: snoobiInk,
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
      child: Text(
        text.replaceAll('/', '/\u200B'),
        maxLines: 2,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: calculatorUnitFontSize,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: snoobiInk,
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
          const UnitLabel('mL/hr'),
          if (showWarning)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                '범위 확인',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
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
    return Semantics(
      liveRegion: true,
      label: isWarning ? '주의가 필요한 계산 결과 $value mL/hr' : '계산된 주입속도 $value mL/hr',
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isWarning ? const Color(0xFFC12828) : snoobiInk,
            width: 1.7,
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isWarning ? const Color(0xFFC12828) : snoobiInk,
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
    this.mustBePositive = false,
    this.keyboardType,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final bool isOptional;
  final bool isNumeric;
  final bool mustBePositive;
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
          if (isNumeric) {
            final parsed = double.tryParse(value.trim());
            if (parsed == null || !parsed.isFinite) {
              return '유한한 숫자만 입력해 주세요.';
            }
            if (mustBePositive && parsed <= 0) {
              return '0보다 큰 숫자를 입력해 주세요.';
            }
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
    fillColor: Colors.white,
    isDense: true,
    hintStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: Color(0xFF555555),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: roundedInputBorder(),
    enabledBorder: roundedInputBorder(),
    focusedBorder: roundedInputBorder(color: snoobiBlue, width: 2.2),
  );
}

InputDecoration editorDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: roundedInputBorder(radius: 10),
    enabledBorder: roundedInputBorder(radius: 10),
    focusedBorder: roundedInputBorder(
      color: snoobiBlue,
      radius: 10,
      width: 2.2,
    ),
  );
}

OutlineInputBorder roundedInputBorder({
  Color color = snoobiInk,
  double radius = 0,
  double width = 1.6,
}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );
}

RoundedRectangleBorder roundedBorder([double radius = 12]) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: const BorderSide(color: snoobiInk, width: 1.5),
  );
}

BoxDecoration roundedDecoration({required Color color, double radius = 12}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: snoobiInk, width: 1.5),
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
          color: snoobiPaper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: snoobiInk, width: 1.4),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _OutlinedText(text: '스누비', color: snoobiCream, fontSize: fontSize),
        _OutlinedText(text: '쫀득', color: snoobiBlue, fontSize: fontSize - 5),
        _OutlinedText(text: '계산기', color: snoobiPink, fontSize: fontSize - 8),
      ],
    );
  }
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 0.98,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.2
              ..strokeJoin = StrokeJoin.round
              ..color = snoobiInk,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
            height: 0.98,
          ),
        ),
      ],
    );
  }
}

class _DecorationAsset extends StatelessWidget {
  const _DecorationAsset({
    required this.path,
    required this.size,
    this.opacity = 1,
  });

  final String path;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(path, width: size, height: size, fit: BoxFit.contain),
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
    final color = selected ? snoobiInk : const Color(0xFF8A8A8A);

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

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = snoobiSky;
    final paper = Paint()..color = snoobiPaper;
    final stroke = Paint()
      ..color = snoobiInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRect(Offset.zero & size, sky);

    final cloud = Path()
      ..moveTo(0, size.height * 0.22)
      ..cubicTo(
        size.width * 0.10,
        size.height * 0.22,
        size.width * 0.10,
        size.height * 0.42,
        size.width * 0.23,
        size.height * 0.39,
      )
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.30,
        size.width * 0.40,
        size.height * 0.36,
        size.width * 0.48,
        size.height * 0.43,
      )
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.24,
        size.width * 0.70,
        size.height * 0.43,
        size.width * 0.78,
        size.height * 0.31,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.15,
        size.width * 0.94,
        size.height * 0.14,
        size.width,
        size.height * 0.07,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(cloud, paper);
    canvas.drawPath(cloud, stroke);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => false;
}

class _ScallopedPainter extends CustomPainter {
  const _ScallopedPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = snoobiInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _buildPath(Size size) {
    const step = 15.0;
    const depth = 4.5;
    final path = Path()..moveTo(depth, depth);

    var x = depth;
    while (x < size.width - depth) {
      final next = math.min(x + step, size.width - depth);
      path.quadraticBezierTo((x + next) / 2, -depth, next, depth);
      x = next;
    }

    var y = depth;
    while (y < size.height - depth) {
      final next = math.min(y + step, size.height - depth);
      path.quadraticBezierTo(
        size.width + depth,
        (y + next) / 2,
        size.width - depth,
        next,
      );
      y = next;
    }

    x = size.width - depth;
    while (x > depth) {
      final next = math.max(x - step, depth);
      path.quadraticBezierTo(
        (x + next) / 2,
        size.height + depth,
        next,
        size.height - depth,
      );
      x = next;
    }

    y = size.height - depth;
    while (y > depth) {
      final next = math.max(y - step, depth);
      path.quadraticBezierTo(-depth, (y + next) / 2, depth, next);
      y = next;
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ScallopedPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
