import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/loan.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  Loan? _find(List<Loan> list) {
    for (final l in list) {
      if (l.id == loanId) return l;
    }
    return null;
  }

  Future<void> _repay(BuildContext context, Loan loan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RepayDialog(loan: loan),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().repayLoan(loan.id, result);
      messenger
          .showSnackBar(const SnackBar(content: Text('Repayment recorded')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not record the repayment')),
      );
    }
  }

  Future<void> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
    Future<void> Function() run,
    String done,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GoldColors.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: GoldColors.loss)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await run();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Something went wrong')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = context.select<AppState, Loan?>((s) => _find(s.loans));
    if (loan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child:
              Text('Loan not found', style: TextStyle(color: GoldColors.faint)),
        ),
      );
    }

    final navigator = Navigator.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${loan.isGold ? 'Gold' : 'Cash'} loan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _Card(children: [
            _KvRow(
              label: 'Kind',
              child: _Badge(text: loan.isGold ? 'GOLD' : 'CASH'),
            ),
            _KvRow(
                label: 'Borrower',
                value: loan.party.isEmpty ? '—' : loan.party),
            _KvRow(label: 'Given on', value: fmtDate(loan.date)),
            _KvRow(label: 'Principal', value: loan.amount(loan.principal)),
            _KvRow(label: 'Interest', value: loan.rateLabel),
            _KvRow(
              label: 'Start day counts',
              value: loan.countStartDay ? 'Yes' : 'No',
            ),
            _KvRow(
              label: 'Note',
              value: loan.note.isEmpty ? '—' : loan.note,
              last: true,
            ),
          ]),
          const SizedBox(height: 20),
          if (loan.isOpen) ...[
            const _SectionLabel('OUTSTANDING'),
            const SizedBox(height: 8),
            _Card(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Mini(
                            label: '${loan.daysElapsed} days elapsed',
                            value: loan.amount(loan.principal),
                            sub: 'principal'),
                        _Mini(
                          label: 'interest so far',
                          value: loan.amount2(loan.accruedInterest),
                          sub: 'accrued',
                          color: GoldColors.gain,
                          alignEnd: true,
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('They owe you',
                            style: TextStyle(color: GoldColors.muted)),
                        Text(
                          loan.amount(loan.outstanding),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: GoldColors.loss,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _repay(context, loan),
              child: const Text('Record repayment'),
            ),
          ] else ...[
            const _SectionLabel('REPAID'),
            const SizedBox(height: 8),
            _Card(children: [
              _KvRow(label: 'Repaid on', value: fmtDate(loan.repayment!.date)),
              _KvRow(
                label: 'Principal returned',
                value: loan.amount(loan.repayment!.principalReturned),
              ),
              _KvRow(
                label: 'Interest received',
                child: Text(
                  loan.amount2(loan.repayment!.interestPaid),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: GoldColors.gain,
                  ),
                ),
              ),
              _KvRow(
                label: 'Note',
                value:
                    loan.repayment!.note.isEmpty ? '—' : loan.repayment!.note,
                last: true,
              ),
            ]),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _confirm(
                context,
                'Reopen this loan?',
                'It goes back to outstanding and interest resumes accruing.',
                'Reopen',
                () => context.read<AppState>().reopenLoan(loan.id),
                'Loan reopened',
              ),
              child: const Text('Reopen'),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: GoldColors.loss,
              side: const BorderSide(color: Color(0xFF6A2F2B)),
            ),
            onPressed: () => _confirm(
              context,
              'Delete this loan?',
              'This removes it entirely and recomputes your balances.',
              'Delete',
              () async {
                await context.read<AppState>().deleteLoan(loan.id);
                navigator.pop();
              },
              'Loan deleted',
            ),
            child: const Text('Delete loan'),
          ),
        ],
      ),
    );
  }
}

class _RepayDialog extends StatefulWidget {
  const _RepayDialog({required this.loan});
  final Loan loan;

  @override
  State<_RepayDialog> createState() => _RepayDialogState();
}

class _RepayDialogState extends State<_RepayDialog> {
  late final TextEditingController _principal = TextEditingController(
      text: widget.loan.principal.toStringAsFixed(widget.loan.isGold ? 3 : 0));
  late final TextEditingController _interest = TextEditingController(
      text: widget.loan.accruedInterest
          .toStringAsFixed(widget.loan.isGold ? 3 : 0));
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _principal.dispose();
    _interest.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.loan.date,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final unit = l.isGold ? 'g' : '₹';
    return AlertDialog(
      backgroundColor: GoldColors.surface,
      title: const Text('Record repayment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Repaid on'),
            trailing:
                TextButton(onPressed: _pickDate, child: Text(fmtDate(_date))),
          ),
          TextField(
            controller: _principal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Principal returned', suffixText: unit),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _interest,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Interest received', suffixText: unit),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, <String, dynamic>{
              'date': _date.toIso8601String(),
              'principalReturned': double.tryParse(_principal.text.trim()) ?? 0,
              'interestPaid': double.tryParse(_interest.text.trim()) ?? 0,
            });
          },
          child: const Text('Record'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: GoldColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GoldColors.hairline),
        ),
        child: Column(children: children),
      );
}

class _KvRow extends StatelessWidget {
  const _KvRow(
      {required this.label, this.value, this.child, this.last = false});
  final String label;
  final String? value;
  final Widget? child;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: const Color(0x26F5C518),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: GoldColors.gold,
          ),
        ),
      );
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

class _Mini extends StatelessWidget {
  const _Mini({
    required this.label,
    required this.value,
    required this.sub,
    this.color = GoldColors.text,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: GoldColors.muted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color)),
          Text(sub,
              style: const TextStyle(fontSize: 10, color: GoldColors.faint)),
        ],
      );
}
