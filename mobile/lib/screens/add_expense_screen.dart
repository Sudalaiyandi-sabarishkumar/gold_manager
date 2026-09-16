import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Records cash taken out of hand for anything outside the gold ledger —
/// personal use, shop rent, and the like.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_recalc);
  }

  void _recalc() => setState(() {});

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _amt => double.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save(double cashInHand) async {
    if (!_form.currentState!.validate()) return;
    if (_amt > cashInHand) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await context.read<AppState>().addExpense(
            date: _date,
            amount: _amt,
            note: _note.text.trim(),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Recorded ${inr(_amt)} taken out')),
      );
    } on ApiException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reach the server')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashInHand =
        context.select<AppState, double>((s) => s.stock.cashInHand);
    final over = _amt > cashInHand;

    return Scaffold(
      appBar: AppBar(title: const Text('Take out cash')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _Label('DATE'),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmtDate(_date)),
                    const Icon(Icons.calendar_today,
                        size: 16, color: GoldColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('AMOUNT (₹)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0',
                helperText: 'Cash in hand ${inr(cashInHand)}',
                helperStyle: const TextStyle(color: GoldColors.faint),
                errorText: over ? 'Only ${inr(cashInHand)} in hand' : null,
              ),
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (d == null || d <= 0) return 'Enter an amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('REASON'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'personal use, shop rent, …',
              ),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: (_saving || over) ? null : () => _save(cashInHand),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GoldColors.goldInk,
                      ),
                    )
                  : const Text('Take out cash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          color: GoldColors.muted,
          fontWeight: FontWeight.w600,
        ),
      );
}
