import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_manager/theme.dart';
import 'package:gold_manager/utils/csv_export.dart';
import 'package:gold_manager/utils/format.dart';

void main() {
  test('csvField quotes only when it needs to', () {
    expect(csvField('Ravi Jewellers'), 'Ravi Jewellers');
    expect(csvField('Ravi, Jewellers'), '"Ravi, Jewellers"');
    expect(csvField('He said "hi"'), '"He said ""hi"""');
    expect(csvField('line1\nline2'), '"line1\nline2"');
    expect(csvField(null), '');
  });

  test('buildCsv writes a header row and CRLF-terminated data rows', () {
    final csv = buildCsv(
      ['Date', 'Party', 'Note'],
      [
        ['2026-09-01', 'Kumar, Jewellery', 'bill "S-118"'],
      ],
    );
    expect(csv,
        'Date,Party,Note\r\n2026-09-01,"Kumar, Jewellery","bill ""S-118"""\r\n');
  });

  test('csvDate formats as yyyy-MM-dd', () {
    expect(csvDate(DateTime(2026, 9, 1)), '2026-09-01');
  });

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
