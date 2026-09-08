import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/payment_status_chip.dart';

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
        const SnackBar(content: Text('Could not delete the entry')),
      );
    }
  }

  Future<void> _addPayment(BuildContext context, GoldTransaction txn) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _AddPaymentDialog(due: txn.amountDue),
    );
    if (amount == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().addPayment(txn.id, amount: amount);
      messenger.showSnackBar(
        SnackBar(content: Text('Payment recorded · ${inr(amount)}')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not record the payment')),
      );
    }
  }

  Future<void> _deletePayment(
    BuildContext context,
    GoldTransaction txn,
    Payment p,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GoldColors.surface,
        title: const Text('Remove this payment?'),
        content: Text('${inr(p.amount)} on ${fmtDate(p.date)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Remove', style: TextStyle(color: GoldColors.loss)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().deletePayment(txn.id, p.id);
      messenger.showSnackBar(const SnackBar(content: Text('Payment removed')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not remove the payment')),
      );
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
          _Card(
            children: [
              _KvRow(
                label: 'Type',
                child: _Badge(
                  text: txn.isPurchase ? 'BUY' : 'SELL',
                  fg: txn.isPurchase ? GoldColors.gold : GoldColors.muted,
                  bg: txn.isPurchase
                      ? const Color(0x26F5C518)
                      : GoldColors.raise,
                ),
              ),
              _KvRow(label: 'Date', value: fmtDate(txn.date)),
              _KvRow(
                label: txn.partyRole,
                value: txn.party.isEmpty ? '—' : txn.party,
              ),
              _KvRow(label: 'Weight', value: grams(txn.weightGrams)),
              _KvRow(label: 'Rate / gram', value: inr2(txn.ratePerGram)),
              _KvRow(label: 'Total', value: inr(txn.totalAmount)),
              if (txn.balanceAfter != null)
                _KvRow(label: 'Stock after', value: grams(txn.balanceAfter!)),
              if (txn.isSale && txn.profit != null)
                _KvRow(
                  label: 'Profit vs avg cost',
                  child: Text(
                    signedInr(txn.profit!),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color:
                          txn.profit! >= 0 ? GoldColors.gain : GoldColors.loss,
                    ),
                  ),
                ),
              _KvRow(
                label: 'Note',
                value: txn.note.isEmpty ? '—' : txn.note,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const _SectionLabel('SETTLEMENT'),
              const SizedBox(width: 8),
              PaymentStatusChip(status: txn.paymentStatus),
            ],
          ),
          const SizedBox(height: 8),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniStat(
                          label: txn.isSale ? 'Received' : 'Paid',
                          value: inr(txn.amountPaid),
                          color: GoldColors.gain,
                        ),
                        _MiniStat(
                          label: txn.isSale ? 'Buyer owes' : 'We owe',
                          value: inr(txn.amountDue),
                          color: txn.amountDue > 0.005
                              ? GoldColors.loss
                              : GoldColors.faint,
                          alignEnd: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: txn.totalAmount <= 0
                            ? 0
                            : (txn.amountPaid / txn.totalAmount)
                                .clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: GoldColors.raise,
                        valueColor:
                            const AlwaysStoppedAnimation(GoldColors.gain),
                      ),
                    ),
                  ],
                ),
              ),
              if (txn.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No payments recorded',
                        style:
                            TextStyle(color: GoldColors.faint, fontSize: 12)),
                  ),
                )
              else
                ...txn.payments.map(
                  (p) => _PaymentRow(
                    payment: p,
                    onDelete: () => _deletePayment(context, txn, p),
                  ),
                ),
              if (!txn.isSettled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: OutlinedButton.icon(
                    onPressed: () => _addPayment(context, txn),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      txn.isSale ? 'Record a receipt' : 'Record a payment',
                    ),
                  ),
                ),
            ],
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

class _AddPaymentDialog extends StatefulWidget {
  const _AddPaymentDialog({required this.due});
  final double due;

  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.due.toStringAsFixed(0));
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_amount.text.trim()) ?? 0;
    if (v <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (v > widget.due + 0.005) {
      setState(() => _error = 'Only ${inr(widget.due)} outstanding');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GoldColors.surface,
      title: const Text('Record payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outstanding ${inr(widget.due)}',
              style: const TextStyle(color: GoldColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onDelete});
  final Payment payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GoldColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inr(payment.amount),
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  payment.note.isEmpty
                      ? fmtDate(payment.date)
                      : '${fmtDate(payment.date)} · ${payment.note}',
                  style: const TextStyle(fontSize: 11, color: GoldColors.faint),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: GoldColors.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GoldColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GoldColors.hairline),
      ),
      child: Column(children: children),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow(
      {required this.label, this.value, this.child, this.last = false});
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.fg, required this.bg});
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(6), color: bg),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: fg,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.4,
          color: GoldColors.goldDeep,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: GoldColors.muted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
