import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/coin.dart';
import '../widgets/stock_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'expenses_screen.dart';
import 'history_screen.dart';
import 'loans_screen.dart';
import 'outstanding_screen.dart';
import 'quick_check_screen.dart';
import 'settings_screen.dart';
import 'transaction_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _shrink(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ShrinkConfirmDialog(),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await context.read<AppState>().shrinkTransactions();
      final deleted = (res['deletedCount'] as num?)?.toInt() ?? 0;
      final remaining = (res['remainingCount'] as num?)?.toInt() ?? 0;
      final msg = deleted == 0
          ? (res['message'] as String? ?? 'Nothing to shrink yet.')
          : 'Removed $deleted, kept $remaining.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not shrink transactions')),
      );
    }
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
            Text('AVS',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Loans',
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
            onPressed: () => _open(context, const LoansScreen()),
          ),
          IconButton(
            tooltip: 'Quick check',
            icon: const Icon(Icons.fact_check_outlined, size: 20),
            onPressed: () => _open(context, const QuickCheckScreen()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            color: GoldColors.surface,
            onSelected: (v) {
              if (v == 'expenses') _open(context, const ExpensesScreen());
              if (v == 'settings') _open(context, const SettingsScreen());
              if (v == 'shrink') _shrink(context);
              if (v == 'logout') context.read<AppState>().logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'expenses', child: Text('Miscellaneous')),
              PopupMenuItem(value: 'settings', child: Text('Opening balances')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'shrink', child: Text('Shrink')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: GoldColors.gold,
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            StockCard(stock: state.stock),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MoneyCard(
                    label: 'RECEIVABLE',
                    caption: 'buyers owe you',
                    value: state.stock.totalReceivable,
                    color: GoldColors.gain,
                    onTap: () => _open(
                      context,
                      const OutstandingScreen(initialSide: 'receivable'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyCard(
                    label: 'PAYABLE',
                    caption: 'you owe sellers',
                    value: state.stock.totalPayable,
                    color: GoldColors.loss,
                    onTap: () => _open(
                      context,
                      const OutstandingScreen(initialSide: 'payable'),
                    ),
                  ),
                ),
              ],
            ),
            if (state.stock.loanCashOutstanding > 0.5 ||
                state.stock.loanGoldOutstandingGrams > 0.0005) ...[
              const SizedBox(height: 10),
              _LoansOutRow(
                stock: state.stock,
                onTap: () => _open(context, const LoansScreen()),
              ),
            ],
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
            if (state.stock.interestEarnedCash > 0.5 ||
                state.stock.interestEarnedGoldGrams > 0.0005) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'LOAN INTEREST EARNED',
                value: _interestEarnedText(state.stock),
              ),
            ],
            if (state.stock.totalExpenses > 0.5) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'MISCELLANEOUS TAKEN OUT',
                value: inr(state.stock.totalExpenses),
                color: GoldColors.loss,
                onTap: () => _open(context, const ExpensesScreen()),
              ),
            ],
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

String _interestEarnedText(dynamic stock) {
  final parts = <String>[];
  if (stock.interestEarnedCash > 0.5) parts.add(inr(stock.interestEarnedCash));
  if (stock.interestEarnedGoldGrams > 0.0005) {
    parts.add(grams(stock.interestEarnedGoldGrams));
  }
  return parts.join('  +  ');
}

class _RealizedRow extends StatelessWidget {
  const _RealizedRow({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) =>
      _SummaryRow(label: 'REALIZED PROFIT', value: inr(value));
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color = GoldColors.gain,
    this.onTap,
  });
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: GoldColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GoldColors.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Eyebrow(label),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoansOutRow extends StatelessWidget {
  const _LoansOutRow({required this.stock, required this.onTap});
  final dynamic stock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[];
    if (stock.loanCashOutstanding > 0.5) {
      bits.add(inr(stock.loanCashOutstanding));
    }
    if (stock.loanGoldOutstandingGrams > 0.0005) {
      bits.add(grams(stock.loanGoldOutstandingGrams));
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: GoldColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GoldColors.hairline),
        ),
        child: Row(
          children: [
            const _Eyebrow('LOANS OUT'),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bits.join('  +  '),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: GoldColors.loss,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: GoldColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ShrinkConfirmDialog extends StatefulWidget {
  const _ShrinkConfirmDialog();

  @override
  State<_ShrinkConfirmDialog> createState() => _ShrinkConfirmDialogState();
}

class _ShrinkConfirmDialogState extends State<_ShrinkConfirmDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final ok = v.trim().toLowerCase() == 'confirm';
    if (ok != _matches) setState(() => _matches = ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GoldColors.surface,
      title: const Text('Shrink transaction history?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes every fully-paid purchase/sale entry '
              'up through today. Pending (unpaid or partially paid) entries '
              'are never deleted — the oldest one stops the deletion there. '
              'In hand, receivable, payable and Quick Check stay exactly the '
              'same — only the entry list gets shorter.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration:
                  const InputDecoration(labelText: 'Type CONFIRM to proceed'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Shrink', style: TextStyle(color: GoldColors.loss)),
        ),
      ],
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

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.caption,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final double value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: GoldColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GoldColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                letterSpacing: 1.4,
                color: GoldColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                inr(value),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    caption,
                    style: const TextStyle(
                        fontSize: 10.5, color: GoldColors.faint),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 14, color: GoldColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
