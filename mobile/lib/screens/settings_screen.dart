import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _cash;
  late final TextEditingController _gold;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _cash = TextEditingController(text: s.openingCash.toStringAsFixed(0));
    _gold = TextEditingController(text: s.openingGoldGrams.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _cash.dispose();
    _gold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await context.read<AppState>().updateSettings(
            openingCash: double.parse(_cash.text.trim()),
            openingGoldGrams: double.parse(_gold.text.trim()),
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Opening balances updated')),
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
    final stock = context.watch<AppState>().stock;

    return Scaffold(
      appBar: AppBar(title: const Text('Opening balances')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text(
              'What you started with, before any transaction or loan. '
              'Everything else is computed from here.',
              style: TextStyle(color: GoldColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const _Label('OPENING CASH (₹)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cash,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
              validator: (v) => (double.tryParse((v ?? '').trim()) ?? -1) < 0
                  ? 'Enter an amount'
                  : null,
            ),
            const SizedBox(height: 16),
            const _Label('OPENING GOLD (G)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _gold,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
              validator: (v) => (double.tryParse((v ?? '').trim()) ?? -1) < 0
                  ? 'Enter a weight'
                  : null,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GoldColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GoldColors.hairline),
              ),
              child: Column(
                children: [
                  _row('Cash in hand now', inr(stock.cashInHand)),
                  const SizedBox(height: 6),
                  _row('Gold in stock now', grams(stock.weightGrams)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GoldColors.goldInk,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(color: GoldColors.muted, fontSize: 12)),
          Text(v,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: GoldColors.text)),
        ],
      );
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
