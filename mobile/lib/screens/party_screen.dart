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
    final allocations = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => _SettleDialog(heading: heading, bills: openBills),
    );
    if (allocations == null || allocations.isEmpty || !context.mounted) return;

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

class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.heading, required this.bills});

  final String heading;
  final List<GoldTransaction> bills;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  final _controllers = <String, TextEditingController>{};
  final _checked = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final b in widget.bills) {
      _controllers[b.id] = TextEditingController()..addListener(_recalc);
    }
  }

  void _recalc() => setState(() => _error = null);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _amountFor(String id) =>
      double.tryParse(_controllers[id]!.text.trim()) ?? 0;
  double get _total => widget.bills.fold(0, (s, b) => s + _amountFor(b.id));

  void _toggle(GoldTransaction b, bool on) {
    setState(() {
      if (on) {
        _checked.add(b.id);
        _controllers[b.id]!.text = b.amountDue.toStringAsFixed(0);
      } else {
        _checked.remove(b.id);
        _controllers[b.id]!.clear();
      }
    });
  }

  void _submit() {
    final allocations = <Map<String, dynamic>>[];
    for (final b in widget.bills) {
      final amt = _amountFor(b.id);
      if (amt <= 0) continue;
      if (amt > b.amountDue + 0.005) {
        setState(() => _error = 'Bill of ${inr(b.totalAmount)} has only '
            '${inr(b.amountDue)} outstanding');
        return;
      }
      allocations.add({
        'transactionId': b.id,
        'amount': amt,
        'note': 'Party settlement',
      });
    }
    if (allocations.isEmpty) {
      setState(() => _error = 'Enter an amount on at least one bill');
      return;
    }
    Navigator.pop(context, allocations);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GoldColors.surface,
      title: Text(widget.heading, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tick the bills this money covers and adjust the amounts.',
              style: TextStyle(color: GoldColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: widget.bills.map((b) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _checked.contains(b.id),
                            onChanged: (v) => _toggle(b, v ?? false),
                            activeColor: GoldColors.gold,
                            checkColor: GoldColors.goldInk,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${fmtDate(b.date)} · ${grams(b.weightGrams)}',
                                    style: const TextStyle(fontSize: 12)),
                                Text('due ${inr(b.amountDue)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: GoldColors.loss)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: TextField(
                              controller: _controllers[b.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '0',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(color: GoldColors.muted)),
                Text(inr(_total),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style: const TextStyle(color: GoldColors.loss, fontSize: 12)),
            ],
          ],
        ),
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
