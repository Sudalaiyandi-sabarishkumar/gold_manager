import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, required this.type});

  final String type; // 'purchase' | 'sale'
  bool get isSale => type == 'sale';

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _rate = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  double get _w => double.tryParse(_weight.text.trim()) ?? 0;
  double get _r => double.tryParse(_rate.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _weight.addListener(_recalc);
    _rate.addListener(_recalc);
  }

  void _recalc() => setState(() {});

  @override
  void dispose() {
    _weight.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(double available) async {
    if (!_form.currentState!.validate()) return;
    if (widget.isSale && _w > available) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await context.read<AppState>().addTransaction(
            type: widget.type,
            date: _date,
            weightGrams: _w,
            ratePerGram: _r,
            note: _note.text.trim(),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${widget.isSale ? 'Sale' : 'Purchase'} saved · '
            '${widget.isSale ? '−' : '+'}${grams(_w)}',
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not reach the server')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = context.select<AppState, ({double weight, double avg})>(
      (s) => (weight: s.stock.weightGrams, avg: s.stock.avgCostPerGram),
    );
    final over = widget.isSale && _w > pool.weight;
    final total = _w * _r;
    final estProfit = (_r - pool.avg) * _w;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isSale ? 'Sell gold' : 'Buy gold')),
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
            const _Label('WEIGHT (G)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                helperText:
                    widget.isSale ? 'In stock ${grams(pool.weight)}' : null,
                helperStyle: const TextStyle(color: GoldColors.faint),
                errorText: over ? 'Only ${grams(pool.weight)} available' : null,
              ),
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (d == null || d <= 0) return 'Enter a weight';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('RATE / GRAM'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _rate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (d == null || d <= 0) return 'Enter a rate';
                return null;
              },
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('TOTAL'),
                Text(
                  total > 0 ? inr(total) : '—',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (widget.isSale) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Label('EST. PROFIT VS AVG COST'),
                  Text(
                    (_w > 0 && _r > 0) ? signedInr(estProfit) : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: estProfit >= 0 ? GoldColors.gain : GoldColors.loss,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const _Label('NOTE'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    widget.isSale ? 'buyer, invoice no.' : 'supplier, bill no.',
              ),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: (_saving || over) ? null : () => _save(pool.weight),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GoldColors.goldInk,
                      ),
                    )
                  : Text(widget.isSale ? 'Save sale' : 'Save purchase'),
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
