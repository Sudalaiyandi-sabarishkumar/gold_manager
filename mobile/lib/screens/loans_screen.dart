import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/loan.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'add_loan_screen.dart';
import 'loan_detail_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _search = TextEditingController();
  String _status = 'open';
  String _kind = 'all';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Loan> _apply(List<Loan> all) {
    final q = _query.trim().toLowerCase();
    return all.where((l) {
      if (_status != 'all' && l.status != _status) return false;
      if (_kind != 'all' && l.kind != _kind) return false;
      if (q.isNotEmpty &&
          !l.party.toLowerCase().contains(q) &&
          !l.note.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final loans = _apply(context.watch<AppState>().loans);

    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GoldColors.gold,
        foregroundColor: GoldColors.goldInk,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddLoanScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New loan'),
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
                hintText: 'Search borrower or note',
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'open', label: Text('Open')),
                      ButtonSegment(value: 'repaid', label: Text('Repaid')),
                      ButtonSegment(value: 'all', label: Text('All')),
                    ],
                    selected: {_status},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _status = s.first),
                    style: _segStyle,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'cash', label: Text('Cash')),
                      ButtonSegment(value: 'gold', label: Text('Gold')),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                    style: _segStyle,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loans.isEmpty
                ? const Center(
                    child: Text('No loans here',
                        style: TextStyle(color: GoldColors.faint)),
                  )
                : RefreshIndicator(
                    color: GoldColors.gold,
                    onRefresh: () => context.read<AppState>().refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: loans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _LoanRow(loan: loans[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  ButtonStyle get _segStyle => SegmentedButton.styleFrom(
        backgroundColor: GoldColors.surface2,
        foregroundColor: GoldColors.muted,
        selectedBackgroundColor: GoldColors.gold,
        selectedForegroundColor: GoldColors.goldInk,
        side: const BorderSide(color: GoldColors.hairline),
        visualDensity: VisualDensity.compact,
      );
}

class _LoanRow extends StatelessWidget {
  const _LoanRow({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final open = loan.isOpen;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LoanDetailScreen(loanId: loan.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GoldColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GoldColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: loan.isGold ? const Color(0x26F5C518) : GoldColors.raise,
              ),
              child: Text(
                loan.isGold ? 'GOLD' : 'CASH',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: loan.isGold ? GoldColors.gold : GoldColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.party.isEmpty ? 'Unnamed' : loan.party,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${loan.amount(loan.principal)} · ${fmtDate(loan.date)}',
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
                  open ? loan.amount(loan.outstanding) : 'repaid',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: open ? GoldColors.loss : GoldColors.gain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  open
                      ? '${loan.daysElapsed}d · +${loan.amount2(loan.accruedInterest)}'
                      : '',
                  style: const TextStyle(fontSize: 10, color: GoldColors.faint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
