import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/csv_export.dart';
import '../utils/format.dart';
import 'add_expense_screen.dart';

/// Miscellaneous cash withdrawals — money taken out of hand for anything
/// outside the gold ledger.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Expense> _apply(List<Expense> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((e) => e.note.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _export(List<Expense> rows) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = buildCsv(
        ['Date', 'Amount', 'Note'],
        rows
            .map((e) => [csvDate(e.date), e.amount.toStringAsFixed(2), e.note])
            .toList(),
      );
      await shareCsv(label: 'expenses', csv: csv);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not export the file')),
        );
      }
    }
  }

  Future<void> _delete(Expense e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GoldColors.surface,
        title: const Text('Delete this entry?'),
        content: Text('${inr(e.amount)} on ${fmtDate(e.date)}'
            '${e.note.isEmpty ? '' : ' · ${e.note}'}'),
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().deleteExpense(e.id);
      messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the entry')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _apply(context.watch<AppState>().expenses);
    final total = rows.fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miscellaneous'),
        actions: [
          IconButton(
            tooltip: 'Download CSV',
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: rows.isEmpty ? null : () => _export(rows),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GoldColors.gold,
        foregroundColor: GoldColors.goldInk,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddExpenseScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Take out cash'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search reason',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total taken out',
                    style: TextStyle(color: GoldColors.muted, fontSize: 12)),
                Text(
                  inr(total),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GoldColors.loss,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'Nothing taken out yet' : 'No matches',
                      style: const TextStyle(color: GoldColors.faint),
                    ),
                  )
                : RefreshIndicator(
                    color: GoldColors.gold,
                    onRefresh: () => context.read<AppState>().refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ExpenseRow(
                        expense: rows[i],
                        onDelete: () => _delete(rows[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onDelete});
  final Expense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: GoldColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GoldColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.note.isEmpty ? 'Miscellaneous' : expense.note,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(fmtDate(expense.date),
                    style:
                        const TextStyle(fontSize: 11, color: GoldColors.faint)),
              ],
            ),
          ),
          Text(
            '−${inr(expense.amount)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: GoldColors.loss,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: GoldColors.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
