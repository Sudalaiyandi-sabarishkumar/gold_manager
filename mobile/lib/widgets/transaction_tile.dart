import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../theme.dart';
import '../utils/format.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.txn,
    this.onTap,
    this.showBalance = false,
  });

  final GoldTransaction txn;
  final VoidCallback? onTap;

  /// History shows "bal <grams>"; the dashboard shows the date instead.
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GoldColors.hairline)),
        ),
        child: Row(
          children: [
            _TypeChip(purchase: txn.isPurchase),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${grams(txn.weightGrams)} @ ${inr(txn.ratePerGram)}',
                    style:
                        const TextStyle(fontSize: 13, color: GoldColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showBalance && txn.balanceAfter != null
                        ? 'bal ${grams(txn.balanceAfter!)}'
                        : fmtDate(txn.date),
                    style:
                        const TextStyle(fontSize: 11, color: GoldColors.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  inr(txn.totalAmount),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (txn.isSale && txn.profit != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    signedInr(txn.profit!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          txn.profit! >= 0 ? GoldColors.gain : GoldColors.loss,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.purchase});
  final bool purchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: purchase ? const Color(0x26F5C518) : GoldColors.raise,
      ),
      child: Text(
        purchase ? 'BUY' : 'SELL',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: purchase ? GoldColors.gold : GoldColors.muted,
        ),
      ),
    );
  }
}
