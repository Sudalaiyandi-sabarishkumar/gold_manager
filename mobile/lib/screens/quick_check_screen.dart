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
///
/// `carryRate` is the excess's cost basis — it is built **only from
/// purchases**; a sale changes `netQtyGrams` but never touches `carryRate`,
/// even when the sale pushes the position into demand (it just keeps
/// showing the last purchase-based rate). It only reads as "no rate" (0)
/// when no purchase has happened yet. While extending an existing excess,
/// purchases blend into a weighted-average cost; while covering a demand
/// (fully or partially), a purchase instead resets `carryRate` straight to
/// its own price, since it's the latest purchase.
///
/// `saleRate` is the mirror image: it is built **only from sales**,
/// blending while extending an existing demand, and reset to the latest
/// sale's own price whenever a sale starts a fresh demand or (fully/
/// partially) covers an excess. Purchases never touch it.
///
/// `safePrice` is the breakeven price for the current position — `carryRate`
/// rounded UP while in excess (so "sell above" stays a genuinely safe
/// threshold), or `saleRate` rounded DOWN while in demand (so "buy below"
/// stays genuinely safe), 0 when balanced or when there's nothing to base
/// it on yet. `profit` uses this exact rounded value too, not the raw
/// unrounded `carryRate`/`saleRate` — so the profit figure always matches
/// what you'd actually get by acting on the displayed safe price.
class QuickCheckResult {
  const QuickCheckResult({
    required this.transactions,
    required this.netQtyGrams,
    required this.carryRate,
    required this.saleRate,
    required this.safePrice,
    required this.purchasesTotal,
    required this.salesTotal,
    required this.profit,
  });

  final List<GoldTransaction> transactions;
  final double netQtyGrams;
  final double carryRate;
  final double saleRate;
  final double safePrice;
  final double purchasesTotal;
  final double salesTotal;
  final double profit;

  int get txnCount => transactions.length;
  bool get isExcess => netQtyGrams > 0;
  bool get isDemand => netQtyGrams < 0;
  bool get isBalanced => netQtyGrams == 0;

  static QuickCheckResult compute(
    List<GoldTransaction> all, {
    double seedNetQtyGrams = 0,
    double seedCarryRate = 0,
    double seedSaleRate = 0,
    double seedPurchasesTotal = 0,
    double seedSalesTotal = 0,
  }) {
    final tradeable = all.where((t) => t.isPurchase || t.isSale).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double netQty = seedNetQtyGrams;
    double carryRate = seedCarryRate;
    double saleRate = seedSaleRate;
    double purchasesTotal = seedPurchasesTotal;
    double salesTotal = seedSalesTotal;

    for (final t in tradeable) {
      final before = netQty;
      if (t.isSale) {
        salesTotal += t.totalAmount;
        if (before < 0) {
          // Extending an existing demand: blend into the weighted-average
          // sale price that created it.
          final newWeight = before - t.weightGrams;
          saleRate = (before.abs() * saleRate + t.weightGrams * t.ratePerGram) /
              (before.abs() + t.weightGrams);
          netQty = newWeight;
        } else {
          // before >= 0: starting fresh, or (partially or fully) covering an
          // excess. Any sale here resets saleRate to its own price.
          saleRate = t.ratePerGram;
          netQty = before - t.weightGrams;
        }
        // A sale never touches carryRate — see class doc.
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
        // A purchase never touches saleRate — see class doc.
      }
    }

    // The rate actually applied to close the remaining position: the
    // purchase-based cost basis while in excess (you'd sell it), or the
    // sale-based rate while in demand (you'd buy it back relative to what
    // you already received for it). Rounded UP for excess and DOWN for
    // demand so it stays a genuinely safe threshold — and profit is
    // computed from this SAME rounded value, not the raw point value,
    // so the two figures always agree with each other.
    final double safePrice;
    if (netQty > 0) {
      safePrice = carryRate.ceilToDouble();
    } else if (netQty < 0) {
      safePrice = saleRate.floorToDouble();
    } else {
      safePrice = 0.0;
    }
    final profit = salesTotal - purchasesTotal + (netQty * safePrice);

    return QuickCheckResult(
      transactions: tradeable,
      netQtyGrams: netQty,
      carryRate: carryRate,
      saleRate: saleRate,
      safePrice: safePrice,
      purchasesTotal: purchasesTotal,
      salesTotal: salesTotal,
      profit: profit,
    );
  }
}

class QuickCheckScreen extends StatefulWidget {
  const QuickCheckScreen({super.key});

  @override
  State<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends State<QuickCheckScreen> {
  final _manualRate = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manualRate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _manualRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final result = QuickCheckResult.compute(
      state.transactions,
      seedNetQtyGrams: settings.quickCheckSeedNetQtyGrams,
      seedCarryRate: settings.quickCheckSeedCarryRate,
      seedSaleRate: settings.quickCheckSeedSaleRate,
      seedPurchasesTotal: settings.quickCheckSeedPurchasesTotal,
      seedSalesTotal: settings.quickCheckSeedSalesTotal,
    );

    final statusLabel =
        result.isExcess ? 'Excess' : (result.isDemand ? 'Demand' : 'Balanced');
    final statusColor = result.isExcess
        ? GoldColors.gain
        : (result.isDemand ? GoldColors.loss : GoldColors.muted);
    final hasSafePrice = result.safePrice != 0;
    final newestFirst = result.transactions.reversed.toList();

    final manualRate = double.tryParse(_manualRate.text.trim());
    final usingManualRate = manualRate != null && manualRate > 0;
    final displayedProfit = usingManualRate
        ? result.salesTotal -
            result.purchasesTotal +
            (result.netQtyGrams * manualRate)
        : result.profit;

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
                Text(
                  result.isExcess
                      ? 'SAFE TO SELL ABOVE'
                      : (result.isDemand
                          ? 'SAFE TO BUY BELOW'
                          : 'SAFE PRICE'),
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: GoldColors.muted,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  hasSafePrice ? '${inr(result.safePrice)} / g' : '—',
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
                  // cash excess). Uses safePrice so excess is valued at
                  // carryRate and demand at saleRate, matching "SAFE ...
                  // BELOW/ABOVE" and "PROFIT" above.
                  hasSafePrice
                      ? signedInr(-(result.safePrice * result.netQtyGrams))
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
                Row(
                  children: [
                    const Text('PROFIT',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: GoldColors.muted,
                            fontWeight: FontWeight.w600)),
                    if (usingManualRate) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: GoldColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'MANUAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: GoldColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  signedInr(displayedProfit),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: displayedProfit >= 0
                        ? GoldColors.gain
                        : GoldColors.loss,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualRate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Simulate at rate/g (optional)',
                    hintText: 'Leave blank to use the safe price',
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
