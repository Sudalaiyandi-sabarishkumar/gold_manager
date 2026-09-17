import 'package:flutter_test/flutter_test.dart';
import 'package:gold_manager/models/transaction.dart';
import 'package:gold_manager/screens/quick_check_screen.dart';

GoldTransaction _txn(String type, DateTime date, double weight, double rate) {
  return GoldTransaction(
    id: '${date.millisecondsSinceEpoch}-$type-$weight',
    type: type,
    date: date,
    party: '',
    weightGrams: weight,
    ratePerGram: rate,
    totalAmount: weight * rate,
    note: '',
    amountPaid: weight * rate,
    amountDue: 0,
    paymentStatus: 'paid',
    payments: const [],
  );
}

void main() {
  final d1 = DateTime(2026, 1, 1);
  final d2 = DateTime(2026, 1, 2);
  final d3 = DateTime(2026, 1, 3);

  test('scenario 1: exact cancel keeps the purchase rate, not the sale rate',
      () {
    final result = QuickCheckResult.compute([
      _txn('purchase', d1, 50, 14000),
      _txn('sale', d2, 50, 14020),
    ]);
    expect(result.netQtyGrams, 0);
    expect(result.carryRate, 14000);
    expect(result.profit, 1000); // 701000 - 700000 + 0*14000
  });

  test('scenario 2: fresh start after an exact cancel', () {
    final result = QuickCheckResult.compute([
      _txn('purchase', d1, 50, 14000),
      _txn('sale', d2, 50, 14020),
      _txn('purchase', d3, 50, 14015),
    ]);
    expect(result.netQtyGrams, 50);
    expect(result.carryRate, 14015);
    expect(result.profit, closeTo(1000, 1e-9));
  });

  test(
      'scenario 3: a partial sale shrinks the position without touching the '
      'rate, only purchases blend into it', () {
    final result = QuickCheckResult.compute([
      _txn('purchase', d1, 50, 14000),
      _txn('sale', d2, 40, 14020),
      _txn('purchase', d3, 20, 14015),
    ]);
    expect(result.netQtyGrams, 30);
    expect(result.carryRate, closeTo((10 * 14000 + 20 * 14015) / 30, 1e-9));
  });

  test(
      'oversell into demand keeps the last purchase rate, not blank, '
      'because a purchase happened earlier this cycle', () {
    final result = QuickCheckResult.compute([
      _txn('purchase', d1, 50, 14000),
      _txn('sale', d2, 70, 14020),
    ]);
    expect(result.netQtyGrams, -20);
    expect(result.isDemand, true);
    expect(result.carryRate, 14000); // kept, not zeroed, from the purchase
  });

  test(
      'a purchase that only partially covers a demand still resets the rate '
      'to its own price, not the stale rate', () {
    final result = QuickCheckResult.compute([
      _txn('purchase', d1, 100, 15000),
      _txn('sale', d2, 50, 15020),
      _txn('purchase', d3, 50, 15030), // blends: (50*15000+50*15030)/100
      _txn('sale', DateTime(2026, 1, 4), 100, 15020),
      _txn('sale', DateTime(2026, 1, 5), 100, 15020), // now net -100
      _txn('purchase', DateTime(2026, 1, 6), 50, 15030), // covers to -50
    ]);
    expect(result.netQtyGrams, -50);
    expect(result.carryRate, 15030); // latest purchase's own rate, not 15015
  });

  test('safePrice is the purchase rate (sell above it) while in excess', () {
    final result = QuickCheckResult.compute([
      _txn('purchase', d1, 50, 14000),
      _txn('sale', d2, 20, 14020),
    ]);
    expect(result.isExcess, true);
    expect(result.safePrice, result.carryRate);
    expect(result.safePrice, 14000);
  });

  test(
      'safePrice mirrors carryRate but from sales while in demand: blends '
      'while extending, resets on any sale that starts fresh or covers an '
      'excess', () {
    // Mirror of the "partial cover resets to latest rate" purchase test,
    // with purchase/sale roles swapped.
    final result = QuickCheckResult.compute([
      _txn('sale', d1, 100, 15000),
      _txn('purchase', d2, 50, 15020),
      _txn('sale', d3, 50, 15030), // blends: (50*15000+50*15030)/100
      _txn('purchase', DateTime(2026, 1, 4), 100, 15020),
      _txn('purchase', DateTime(2026, 1, 5), 100, 15020), // now net +100
      _txn('sale', DateTime(2026, 1, 6), 50, 15030), // covers to +50
    ]);
    expect(result.netQtyGrams, 50);
    expect(result.isExcess, true);
    // saleRate tracked throughout even though the final state is excess.
    expect(result.saleRate, 15030);
  });

  test('safePrice is blank (0) in demand until a sale has actually happened',
      () {
    final result = QuickCheckResult.compute([]);
    expect(result.isBalanced, true);
    expect(result.safePrice, 0);
  });

  test('safePrice tracks the sale side while in demand', () {
    final result = QuickCheckResult.compute([
      _txn('sale', d1, 50, 14000),
      _txn('purchase', d2, 20, 14020),
    ]);
    expect(result.isDemand, true);
    expect(result.safePrice, result.saleRate);
    expect(result.safePrice, 14000);
  });

  test('replays the full history regardless of how many entries there are',
      () {
    final txns = <GoldTransaction>[];
    var day = DateTime(2026, 1, 1);
    for (var i = 0; i < 25; i++) {
      txns.add(_txn('purchase', day, 10, 100));
      day = day.add(const Duration(days: 1));
    }
    txns.add(_txn('sale', day, 5, 200));

    final result = QuickCheckResult.compute(txns);
    expect(result.txnCount, 26);
    expect(result.netQtyGrams, 245); // 25*10 - 5
    expect(result.carryRate, 100); // last blend point stays at the purchase rate
  });
}
