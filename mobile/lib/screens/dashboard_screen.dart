import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/coin.dart';
import '../widgets/stock_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'history_screen.dart';
import 'transaction_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.transactions.take(3).toList();
    final firstLoad = state.loading && state.transactions.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Coin(),
            SizedBox(width: 8),
            Text('Gold Manager',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => context.read<AppState>().logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: GoldColors.gold,
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            StockCard(stock: state.stock),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _open(
                        context, const AddTransactionScreen(type: 'purchase')),
                    child: const Text('＋ Buy gold'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _open(
                        context, const AddTransactionScreen(type: 'sale')),
                    child: const Text('－ Sell gold'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Eyebrow('RECENT'),
                TextButton(
                  onPressed: () => _open(context, const HistoryScreen()),
                  child: const Text('All entries →'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (firstLoad)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 44),
                child: Center(
                    child: CircularProgressIndicator(color: GoldColors.gold)),
              )
            else if (state.error != null && state.transactions.isEmpty)
              _ErrorBlock(
                message: state.error!,
                onRetry: () => context.read<AppState>().refresh(),
              )
            else if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 44),
                child: Center(
                  child: Text('No transactions yet',
                      style: TextStyle(color: GoldColors.faint)),
                ),
              )
            else
              ...recent.map(
                (t) => TransactionTile(
                  txn: t,
                  onTap: () => _open(
                      context, TransactionDetailScreen(transactionId: t.id)),
                ),
              ),
            const SizedBox(height: 18),
            _RealizedRow(value: state.stock.realizedProfit),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.6,
          color: GoldColors.muted,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _RealizedRow extends StatelessWidget {
  const _RealizedRow({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: GoldColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GoldColors.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _Eyebrow('REALIZED PROFIT'),
          Text(
            inr(value),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: GoldColors.gain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: GoldColors.loss)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
