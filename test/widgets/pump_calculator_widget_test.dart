import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micudrugtest/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('department entry requires an explicit medication selection', (
    tester,
  ) async {
    await _openMicu(tester);

    expect(find.byKey(const Key('medication-required-banner')), findsOneWidget);
    expect(find.byKey(const Key('selected-medication-card')), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('weight-field'))).enabled,
      isFalse,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('dose-field'))).enabled,
      isFalse,
    );
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('changing medication clears dose but keeps patient weight', (
    tester,
  ) async {
    await _openMicu(tester);
    await _selectMedication(tester, 'propofol 400mg');

    final weightInput = _editableTextInside(const Key('weight-field'));
    final doseInput = _editableTextInside(const Key('dose-field'));
    await tester.enterText(weightInput, '70');
    await tester.enterText(doseInput, '10');
    await tester.pump();

    expect(tester.widget<EditableText>(weightInput).controller.text, '70');
    expect(tester.widget<EditableText>(doseInput).controller.text, '10');

    await _selectMedication(tester, 'remifentanil 1mg');

    expect(tester.widget<EditableText>(weightInput).controller.text, '70');
    expect(tester.widget<EditableText>(doseInput).controller.text, isEmpty);
    expect(find.text('--'), findsOneWidget);
    expect(find.textContaining('처방 용량을 다시 입력'), findsOneWidget);
  });

  testWidgets('MICU 1 g/50 mL propofol calculates 2.1 mL/hr at 70 kg', (
    tester,
  ) async {
    await _openMicu(tester);
    await _selectMedication(tester, 'propofol 1g/50mL');

    await tester.enterText(
      _editableTextInside(const Key('weight-field')),
      '70',
    );
    await tester.enterText(
      _editableTextInside(const Key('dose-field')),
      '10',
    );
    await tester.pumpAndSettle();

    expect(find.text('2.1'), findsOneWidget);
    expect(find.textContaining('1 g / 50 mL'), findsWidgets);
    expect(find.textContaining('펌프 단위 0.1 mL/hr'), findsOneWidget);
  });

  testWidgets('invalid and non-positive inputs show immediate reasons', (
    tester,
  ) async {
    await _openMicu(tester);
    await _selectMedication(tester, 'propofol 400mg');

    final weightInput = _editableTextInside(const Key('weight-field'));
    final doseInput = _editableTextInside(const Key('dose-field'));
    await tester.enterText(weightInput, '70');
    await tester.enterText(doseInput, '570abc');
    await tester.pumpAndSettle();

    expect(find.text('숫자만 입력해 주세요.'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);

    await tester.enterText(doseInput, '0');
    await tester.pumpAndSettle();
    expect(find.text('0보다 큰 숫자를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('dose-range warning is placed directly with the result', (
    tester,
  ) async {
    await _openMicu(tester);
    await _selectMedication(tester, 'propofol 400mg');

    await tester.enterText(
      _editableTextInside(const Key('weight-field')),
      '70',
    );
    await tester.enterText(_editableTextInside(const Key('dose-field')), '5');
    await tester.pumpAndSettle();

    final warning = find.byKey(const Key('result-status-banner'));
    final details = find.byKey(const Key('calculation-details-tile'));
    expect(warning, findsOneWidget);
    expect(find.textContaining('권장 범위 밖입니다'), findsOneWidget);
    expect(tester.getTopLeft(warning).dy, lessThan(tester.getTopLeft(details).dy));
  });

  testWidgets('new patient clears weight dose result and medication', (
    tester,
  ) async {
    await _openMicu(tester);
    await _selectMedication(tester, 'propofol 400mg');

    final weightInput = _editableTextInside(const Key('weight-field'));
    final doseInput = _editableTextInside(const Key('dose-field'));
    await tester.enterText(weightInput, '70');
    await tester.enterText(doseInput, '10');
    await tester.pumpAndSettle();
    expect(find.text('4.2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-patient-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('medication-required-banner')), findsOneWidget);
    expect(tester.widget<EditableText>(weightInput).controller.text, isEmpty);
    expect(tester.widget<EditableText>(doseInput).controller.text, isEmpty);
    expect(find.text('--'), findsOneWidget);
    expect(find.textContaining('새 환자 입력을 시작'), findsOneWidget);
  });

  testWidgets('settings are separated and explain local-only storage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _openMicu(tester);
    await tester.ensureVisible(find.byKey(const Key('open-settings-button')));
    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('약물 설정 관리'), findsWidgets);
    expect(find.textContaining('현재 기기에만 저장'), findsOneWidget);
    expect(find.byKey(const Key('reset-presets-button')), findsOneWidget);
    expect(find.text('새 계산식'), findsOneWidget);
  });

  testWidgets('calculator rows do not overflow at 320 logical pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _openMicu(tester);
    await _selectMedication(tester, 'propofol 1g/50mL');
    await tester.enterText(
      _editableTextInside(const Key('weight-field')),
      '70',
    );
    await tester.enterText(
      _editableTextInside(const Key('dose-field')),
      '10',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('2.1'), findsOneWidget);
  });

  testWidgets('landing cards include department descriptions', (tester) async {
    await tester.pumpWidget(const JjonddeukCalculatorApp());
    await tester.pumpAndSettle();

    expect(find.text('계산할 부서를 선택해 주세요'), findsOneWidget);
    expect(find.text('내과계 중환자실'), findsOneWidget);
    expect(find.text('외과계 중환자실'), findsOneWidget);
    expect(find.text('응급 중환자실2'), findsOneWidget);
    expect(find.text('신경계 중환자실'), findsOneWidget);
  });
}

Future<void> _openMicu(WidgetTester tester) async {
  await tester.pumpWidget(const JjonddeukCalculatorApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('MICU'));
  await tester.pumpAndSettle();
}

Future<void> _selectMedication(WidgetTester tester, String query) async {
  final searchField = find.byKey(const Key('preset-search-field'));
  await tester.enterText(searchField, query);
  await tester.pumpAndSettle();

  final result = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
              'preset-search-result-',
            ),
  );
  expect(result, findsOneWidget);
  await tester.ensureVisible(result);
  await tester.tap(result);
  await tester.pumpAndSettle();
}

Finder _editableTextInside(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
}
