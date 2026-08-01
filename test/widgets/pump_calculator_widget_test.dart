import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micudrugtest/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('changing medication clears dose but keeps patient weight', (
    tester,
  ) async {
    await tester.pumpWidget(const JjonddeukCalculatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('MICU'));
    await tester.pumpAndSettle();

    final searchField = find.byKey(const Key('preset-search-field'));
    Finder searchResult() => find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                    'preset-search-result-',
                  ),
        );

    await tester.enterText(searchField, 'propofol');
    await tester.pumpAndSettle();
    expect(find.textContaining('propofol 400'), findsWidgets);
    await tester.ensureVisible(searchResult());
    await tester.tap(searchResult());
    await tester.pumpAndSettle();

    final weightField = find.byKey(const Key('weight-field'));
    final doseField = find.byKey(const Key('dose-field'));
    final weightInput = find.descendant(
      of: weightField,
      matching: find.byType(EditableText),
    );
    final doseInput = find.descendant(
      of: doseField,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<TextFormField>(weightField).enabled, isTrue);
    await tester.ensureVisible(weightField);
    await tester.pumpAndSettle();
    await tester.enterText(weightInput, '70');
    await tester.pump();
    expect(tester.widget<EditableText>(weightInput).controller.text, '70');
    await tester.enterText(doseInput, '10');
    await tester.pump();
    expect(tester.widget<EditableText>(weightInput).controller.text, '70');
    expect(tester.widget<EditableText>(doseInput).controller.text, '10');

    await tester.enterText(searchField, 'remifentanil');
    await tester.pumpAndSettle();
    expect(find.textContaining('remifentanil 1mg'), findsWidgets);
    expect(searchResult(), findsOneWidget);
    await tester.ensureVisible(searchResult());
    await tester.tap(searchResult());
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(weightInput).controller.text, '70');
    expect(tester.widget<EditableText>(doseInput).controller.text, isEmpty);
    expect(find.text('--'), findsOneWidget);
    expect(find.textContaining('처방 용량을 다시 입력'), findsOneWidget);
  });

  testWidgets('preset editor actions do not overflow on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const JjonddeukCalculatorApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('MICU'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('약물 계산식 추가/수정/비고 관리'));
    await tester.tap(find.text('약물 계산식 추가/수정/비고 관리'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('새 계산식'), findsOneWidget);
    expect(find.text('선택 약물 수정'), findsOneWidget);
    expect(find.text('선택 약물 삭제'), findsOneWidget);
  });
}
