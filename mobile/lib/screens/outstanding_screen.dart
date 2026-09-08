import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/outstanding.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key, this.initialSide = 'receivable'});

  final String initialSide; // 'receivable' | 'payable'

  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  late String _side = widget.initialSide;

  @override
  Widget build(BuildContext context) {
    final report = OutstandingReport.fromTransactions(
      context.watch<AppState>().transactions,
    );
    final isReceivable = _side == 'receivable';
    final parties = isReceivable ? report.receivables : report.payables;
    final total = isReceivable ? report.totalReceivable : report.totalPayable;

    return Scaffold(
      appBar: AppBar(title: const Text('Outstanding')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'receivable', label: Text('Receivable')),
                  ButtonSegment(value: 'payable', label: Text('Payable')),
                ],
                selected: {_side},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _side = s.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: GoldColors.surface2,
                  foregroundColor: GoldColors.muted,
                  selectedBackgroundColor: GoldColors.gold,
                  selectedForegroundColor: GoldColors.goldInk,
                  side: const BorderSide(color: GoldColors.hairline),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isReceivable ? 'Buyers owe you' : 'You owe sellers',
                  style: const TextStyle(color: GoldColors.muted, fontSize: 12),
                ),
                Text(
                  inr(total),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isReceivable ? GoldColors.gain : GoldColors.loss,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: parties.isEmpty
                ? const Center(
                    child: Text('Nothing outstanding',
                        style: TextStyle(color: GoldColors.faint)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: parties.length,
                    itemBuilder: (context, i) => _PartyCard(party: parties[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.party});
  final OutstandingParty party;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: GoldColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GoldColors.hairline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          title: Text(
            party.party,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${party.count} ${party.count == 1 ? 'bill' : 'bills'}',
            style: const TextStyle(color: GoldColors.faint, fontSize: 11),
          ),
          trailing: Text(
            inr(party.totalDue),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: GoldColors.loss,
            ),
          ),
          children: party.transactions
              .map(
                (t) => TransactionTile(
                  txn: t,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TransactionDetailScreen(transactionId: t.id),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
