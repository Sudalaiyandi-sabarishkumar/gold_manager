import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().transactions;
    final rows = _filter == 'all'
        ? all
        : all.where((t) => t.type == _filter).toList(growable: false);

    // Group by calendar day, preserving the newest-first order.
    final order = <String>[];
    final groups = <String, List<GoldTransaction>>{};
    for (final t in rows) {
      final key = fmtDate(t.date);
      if (!groups.containsKey(key)) {
        groups[key] = <GoldTransaction>[];
        order.add(key);
      }
      groups[key]!.add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'purchase', label: Text('Buy')),
                  ButtonSegment(value: 'sale', label: Text('Sell')),
                ],
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _filter = s.first),
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
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      _filter == 'all'
                          ? 'No transactions yet'
                          : 'No $_filter entries yet',
                      style: const TextStyle(color: GoldColors.faint),
                    ),
                  )
                : RefreshIndicator(
                    color: GoldColors.gold,
                    onRefresh: () => context.read<AppState>().refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: order.length,
                      itemBuilder: (context, i) {
                        final key = order[i];
                        final items = groups[key]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 14, bottom: 2),
                              child: Text(
                                key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  color: GoldColors.goldDeep,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...items.map(
                              (t) => TransactionTile(
                                txn: t,
                                showBalance: true,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TransactionDetailScreen(
                                        transactionId: t.id),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
