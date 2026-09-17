import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';

const int kQuickCheckBaseLimitGrams = 500;

/// Result of replaying every purchase/sale transaction, oldest first.
///
/// `netQtyGrams` is a running signed weight (+ve = bought more than sold so
/// far = excess on hand; -ve = sold more than bought = demand/short).
/// `carryRate` is the reference price of that position — it is built **only
/// from purchases**; a sale changes `netQtyGrams` but never touches
/// `carryRate`, even when the sale pushes the position into demand (it just
/// keeps showing the last purchase-based rate). It only reads as "no rate"
/// (0) when no purchase has happened yet. While extending an existing
/// excess, purchases blend into a weighted-average cost; while covering a
/// demand (fully or partially), a purchase instead resets `carryRate`
/// straight to its own price, since it's the latest purchase.
class QuickCheckResult {
  const QuickCheckResult({
    required this.transactions,
    required this.netQtyGrams,
    required this.carryRate,
    required this.purchasesTotal,
    required this.salesTotal,
    required this.profit,
  });

  final List<GoldTransaction> transactions;
  final double netQtyGrams;
  final double carryRate;
  final double purchasesTotal;
  final double salesTotal;
  final double profit;

  int get txnCount => transactions.length;
  bool get isExcess => netQtyGrams > 0;
  bool get isDemand => netQtyGrams < 0;
  bool get isBalanced => netQtyGrams == 0;

  static QuickCheckResult compute(List<GoldTransaction> all) {
    final tradeable = all.where((t) => t.isPurchase || t.isSale).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double netQty = 0;
    double carryRate = 0;
    double purchasesTotal = 0;
    double salesTotal = 0;

    for (final t in tradeable) {
      final before = netQty;
      if (t.isSale) {
        salesTotal += t.totalAmount;
        netQty = before - t.weightGrams;
        // A sale never touches carryRate, no matter the outcome: it stays at
        // the last purchase-based rate (or 0/unset if no purchase has
        // happened yet), even if this sale pushes into demand.
      } else {
        purchasesTotal += t.totalAmount;
        if (before > 0) {
          // Extending an existing long: blend into the weighted-average cost.
          final newWeight = before + t.weightGrams;
          carryRate =
              (before * carryRate + t.weightGrams * t.ratePerGram) /
                  newWeight;
          netQty = newWeight;
        } else {
          // before <= 0: starting fresh, or (partially or fully) covering a
          // short. Any purchase here resets the rate to this purchase's own
          // price, whether or not it flips the position back to positive.
          carryRate = t.ratePerGram;
          netQty = before + t.weightGrams;
        }
      }
    }

    final profit = salesTotal - purchasesTotal + (netQty * carryRate);

    return QuickCheckResult(
      transactions: tradeable,
      netQtyGrams: netQty,
      carryRate: carryRate,
      purchasesTotal: purchasesTotal,
      salesTotal: salesTotal,
      profit: profit,
    );
  }
}

class QuickCheckScreen extends StatelessWidget {
  const QuickCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<AppState>().transactions;
    final result = QuickCheckResult.compute(transactions);

    final statusLabel =
        result.isExcess ? 'Excess' : (result.isDemand ? 'Demand' : 'Balanced');
    final statusColor = result.isExcess
        ? GoldColors.gain
        : (result.isDemand ? GoldColors.loss : GoldColors.muted);
    final hasRate = result.carryRate != 0;
    final newestFirst = result.transactions.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Quick check')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GoldColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GoldColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BASE LIMIT',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: GoldColors.muted,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(grams(kQuickCheckBaseLimitGrams),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('EXCESS / DEMAND WEIGHT',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: GoldColors.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${result.isDemand ? '−' : '+'}${grams(result.netQtyGrams.abs())}',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
                const SizedBox(height: 20),
                const Text('LAST PURCHASED AMOUNT',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: GoldColors.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  hasRate ? '${inr2(result.carryRate)} / g' : '—',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                const Text('EXCESS / DEMAND AMOUNT',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: GoldColors.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  // Inverted vs. the gold quantity: gold excess means cash
                  // was spent to buy it (a cash demand), and gold demand
                  // means more cash came in from selling than was spent (a
                  // cash excess).
                  hasRate
                      ? signedInr(-(result.carryRate * result.netQtyGrams))
                      : '—',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: result.isExcess
                          ? GoldColors.loss
                          : (result.isDemand
                              ? GoldColors.gain
                              : GoldColors.muted)),
                ),
                const SizedBox(height: 20),
                const Text('PROFIT',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: GoldColors.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  signedInr(result.profit),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: result.profit >= 0
                        ? GoldColors.gain
                        : GoldColors.loss,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${result.txnCount} purchase/sale entries',
                  style: const TextStyle(
                      fontSize: 12, color: GoldColors.faint),
                ),
              ],
            ),
          ),
          if (newestFirst.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'ENTRIES',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: GoldColors.muted,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...newestFirst.map(
              (t) => TransactionTile(
                txn: t,
                showBalance: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
