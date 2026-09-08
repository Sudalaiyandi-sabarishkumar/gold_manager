import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_manager/theme.dart';
import 'package:gold_manager/utils/format.dart';

void main() {
  test('inr formats in the Indian grouping system', () {
    expect(inr(5086856), '₹50,86,856');
  });

  test('grams keeps two decimals', () {
    expect(grams(860), '860.00 g');
  });

  test('signedInr uses + / − prefixes', () {
    expect(signedInr(40756), '+₹40,756');
    expect(signedInr(-1200), '−₹1,200');
  });

  testWidgets('gold theme applies a dark scaffold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGoldTheme(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final ctx = tester.element(find.byType(Scaffold));
    expect(Theme.of(ctx).scaffoldBackgroundColor, GoldColors.bg);
  });
}
