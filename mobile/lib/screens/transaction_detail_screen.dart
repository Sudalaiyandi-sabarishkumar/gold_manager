import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  GoldTransaction? _find(List<GoldTransaction> list) {
    for (final t in list) {
      if (t.id == transactionId) return t;
    }
    return null;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GoldColors.surface,
        title: const Text('Delete entry?'),
        content:
            const Text('This removes the transaction and recomputes stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: GoldColors.loss)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<AppState>().deleteTransaction(transactionId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not delete the entry')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final txn = context
        .select<AppState, GoldTransaction?>((s) => _find(s.transactions));

    if (txn == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Entry not found',
              style: TextStyle(color: GoldColors.faint)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(txn.isSale ? 'Sale' : 'Purchase')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: GoldColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GoldColors.hairline),
            ),
            child: Column(
              children: [
                _Row(
                  label: 'Type',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: txn.isPurchase
                          ? const Color(0x26F5C518)
                          : GoldColors.raise,
                    ),
                    child: Text(
                      txn.isPurchase ? 'BUY' : 'SELL',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color:
                            txn.isPurchase ? GoldColors.gold : GoldColors.muted,
                      ),
                    ),
                  ),
                ),
                _Row(label: 'Date', value: fmtDate(txn.date)),
                _Row(label: 'Weight', value: grams(txn.weightGrams)),
                _Row(label: 'Rate / gram', value: inr2(txn.ratePerGram)),
                _Row(label: 'Total', value: inr(txn.totalAmount)),
                if (txn.balanceAfter != null)
                  _Row(label: 'Stock after', value: grams(txn.balanceAfter!)),
                if (txn.isSale && txn.profit != null)
                  _Row(
                    label: 'Profit vs avg cost',
                    child: Text(
                      signedInr(txn.profit!),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: txn.profit! >= 0
                            ? GoldColors.gain
                            : GoldColors.loss,
                      ),
                    ),
                  ),
                _Row(
                    label: 'Note',
                    value: txn.note.isEmpty ? '—' : txn.note,
                    last: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: GoldColors.loss,
              side: const BorderSide(color: Color(0xFF6A2F2B)),
            ),
            onPressed: () => _confirmDelete(context),
            child: const Text('Delete entry'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.child, this.last = false});

  final String label;
  final String? value;
  final Widget? child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: GoldColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: GoldColors.muted, fontSize: 12)),
          const Spacer(),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: child ??
                  Text(
                    value ?? '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: GoldColors.text,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
