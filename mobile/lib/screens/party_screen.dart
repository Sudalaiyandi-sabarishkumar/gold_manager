import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

/// One person's account: their sales (receivable) and purchases (payable),
/// with a single place to record what they paid across several bills.
class PartyScreen extends StatelessWidget {
  const PartyScreen({super.key, required this.partyName});

  final String partyName;

  bool _isThisParty(GoldTransaction t) =>
      t.party.trim().toLowerCase() == partyName.trim().toLowerCase();

  Future<void> _settle(
    BuildContext context,
    String heading,
    List<GoldTransaction> openBills,
  ) async {
    final totalDue = openBills.fold<double>(0, (s, b) => s + b.amountDue);
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(heading: heading, totalDue: totalDue),
    );
    if (amount == null || amount <= 0 || !context.mounted) return;

    // Oldest bill first: fill each one fully before spilling into the next.
    final oldestFirst = [...openBills]
      ..sort((a, b) => a.date.compareTo(b.date));
    final allocations = <Map<String, dynamic>>[];
    var remaining = amount;
    for (final bill in oldestFirst) {
      if (remaining <= 0.005) break;
      final take = remaining < bill.amountDue ? remaining : bill.amountDue;
      if (take <= 0.005) continue;
      allocations.add({
        'transactionId': bill.id,
        'amount': take,
        'note': 'Party settlement',
      });
      remaining -= take;
    }
    if (allocations.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().settleParty(allocations);
      final total = allocations.fold<double>(
        0,
        (s, a) => s + (a['amount'] as num).toDouble(),
      );
      messenger.showSnackBar(
        SnackBar(
            content: Text('Recorded ${inr(total)} across '
                '${allocations.length} ${allocations.length == 1 ? 'bill' : 'bills'}')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not record the payment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = context
        .watch<AppState>()
        .transactions
        .where(_isThisParty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final sales = mine.where((t) => t.isSale).toList();
    final purchases = mine.where((t) => t.isPurchase).toList();
    final receivable = sales.fold<double>(0, (s, t) => s + t.amountDue);
    final payable = purchases.fold<double>(0, (s, t) => s + t.amountDue);

    return Scaffold(
      appBar: AppBar(title: Text(partyName)),
      body: mine.isEmpty
          ? const Center(
              child: Text('No transactions with this party',
                  style: TextStyle(color: GoldColors.faint)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (sales.isNotEmpty)
                  _Section(
                    title: 'RECEIVABLE',
                    caption: 'they owe you',
                    total: receivable,
                    totalColor: GoldColors.gain,
                    bills: sales,
                    actionLabel: 'Record receipt',
                    onAction: receivable <= 0.005
                        ? null
                        : () => _settle(
                              context,
                              'Receipt from $partyName',
                              sales.where((t) => t.amountDue > 0.005).toList(),
                            ),
                  ),
                if (purchases.isNotEmpty)
                  _Section(
                    title: 'PAYABLE',
                    caption: 'you owe them',
                    total: payable,
                    totalColor: GoldColors.loss,
                    bills: purchases,
                    actionLabel: 'Record payment',
                    onAction: payable <= 0.005
                        ? null
                        : () => _settle(
                              context,
                              'Payment to $partyName',
                              purchases
                                  .where((t) => t.amountDue > 0.005)
                                  .toList(),
                            ),
                  ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.caption,
    required this.total,
    required this.totalColor,
    required this.bills,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String caption;
  final double total;
  final Color totalColor;
  final List<GoldTransaction> bills;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: GoldColors.goldDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '  $caption',
                  style: const TextStyle(fontSize: 11, color: GoldColors.faint),
                ),
              ]),
            ),
            Text(
              inr(total),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: total > 0.005 ? totalColor : GoldColors.faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...bills.map(
          (t) => TransactionTile(
            txn: t,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TransactionDetailScreen(transactionId: t.id),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

/// Asks for a single total amount; [PartyScreen._settle] spreads it across
/// that party's open bills, oldest first.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.heading, required this.totalDue});

  final String heading;
  final double totalDue;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.totalDue.toStringAsFixed(0));
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
    if (v > widget.totalDue + 0.005) {
      setState(() => _error = 'Only ${inr(widget.totalDue)} outstanding');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GoldColors.surface,
      title: Text(widget.heading, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outstanding ${inr(widget.totalDue)}',
              style: const TextStyle(color: GoldColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          const Text(
            'Applied to the oldest bill first, then the next.',
            style: TextStyle(color: GoldColors.faint, fontSize: 11),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Amount', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Record')),
      ],
    );
  }
}
