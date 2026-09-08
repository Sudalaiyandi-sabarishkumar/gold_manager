import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key, this.initialKind = 'cash'});

  final String initialKind;

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _form = GlobalKey<FormState>();
  final _party = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();

  late String _kind = widget.initialKind;
  String _unit = 'day';
  bool _countStartDay = false;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isGold => _kind == 'gold';

  @override
  void initState() {
    super.initState();
    _applyKindDefaults();
    _principal.addListener(_recalc);
    _rate.addListener(_recalc);
    _ref.addListener(_recalc);
  }

  void _recalc() => setState(() {});

  void _applyKindDefaults() {
    if (_isGold) {
      _rate.text = '1.5';
      _ref.text = '100';
      _unit = 'month';
    } else {
      _rate.text = '100';
      _ref.text = '100000';
      _unit = 'day';
    }
  }

  @override
  void dispose() {
    _party.dispose();
    _principal.dispose();
    _rate.dispose();
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _p => double.tryParse(_principal.text.trim()) ?? 0;
  double get _r => double.tryParse(_rate.text.trim()) ?? 0;
  double get _refv => double.tryParse(_ref.text.trim()) ?? 0;
  double get _perPeriod => (_refv > 0) ? _p / _refv * _r : 0;

  String _fmt(num n) => _isGold ? grams(n) : inr(n);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      await appState.createLoan({
        'kind': _kind,
        'party': appState.canonicalParty(_party.text),
        'date': _date.toIso8601String(),
        'principal': _p,
        'interestRate': _r,
        'interestRefAmount': _refv,
        'interestUnit': _unit,
        'countStartDay': _countStartDay,
        'note': _note.text.trim(),
      });
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                '${_isGold ? 'Gold' : 'Cash'} loan of ${_fmt(_p)} recorded')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('New loan')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash loan')),
                  ButtonSegment(value: 'gold', label: Text('Gold loan')),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _applyKindDefaults();
                }),
                style: SegmentedButton.styleFrom(
                  backgroundColor: GoldColors.surface2,
                  foregroundColor: GoldColors.muted,
                  selectedBackgroundColor: GoldColors.gold,
                  selectedForegroundColor: GoldColors.goldInk,
                  side: const BorderSide(color: GoldColors.hairline),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _Label('BORROWER'),
            const SizedBox(height: 6),
            Autocomplete<String>(
              optionsBuilder: (value) {
                final names = context.read<AppState>().partyNames;
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return names;
                return names.where((n) => n.toLowerCase().contains(q));
              },
              onSelected: (v) => _party.text = v,
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'type or pick a name',
                    suffixIcon:
                        Icon(Icons.arrow_drop_down, color: GoldColors.muted),
                  ),
                  onChanged: (v) => _party.text = v,
                );
              },
            ),
            const SizedBox(height: 16),
            const _Label('DATE GIVEN'),
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
            _Label(_isGold ? 'PRINCIPAL (G)' : 'PRINCIPAL (₹)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _principal,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0'),
              validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0
                  ? 'Enter an amount'
                  : null,
            ),
            const SizedBox(height: 16),
            const _Label('INTEREST'),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _rate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(suffixText: _isGold ? 'g' : '₹'),
                    validator: (v) =>
                        (double.tryParse((v ?? '').trim()) ?? -1) < 0
                            ? '?'
                            : null,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('per', style: TextStyle(color: GoldColors.muted)),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'day', label: Text('day')),
                      ButtonSegment(value: 'month', label: Text('month')),
                    ],
                    selected: {_unit},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _unit = s.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: GoldColors.surface2,
                      foregroundColor: GoldColors.muted,
                      selectedBackgroundColor: GoldColors.gold,
                      selectedForegroundColor: GoldColors.goldInk,
                      side: const BorderSide(color: GoldColors.hairline),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('per every ',
                    style: TextStyle(color: GoldColors.muted, fontSize: 13)),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _ref,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        suffixText: _isGold ? 'g' : '₹', isDense: true),
                    validator: (v) =>
                        (double.tryParse((v ?? '').trim()) ?? 0) <= 0
                            ? '?'
                            : null,
                  ),
                ),
                const Text('  of principal',
                    style: TextStyle(color: GoldColors.muted, fontSize: 13)),
              ],
            ),
            if (_p > 0 && _perPeriod > 0) ...[
              const SizedBox(height: 8),
              Text(
                '≈ ${_fmt(_perPeriod)} interest per $_unit on this loan',
                style: const TextStyle(color: GoldColors.gain, fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: GoldColors.gold,
              title: const Text('Count the day it was given',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'On = the start date is a full period',
                style: TextStyle(fontSize: 11, color: GoldColors.faint),
              ),
              value: _countStartDay,
              onChanged: (v) => setState(() => _countStartDay = v),
            ),
            const SizedBox(height: 10),
            const _Label('NOTE'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'optional'),
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
                  : const Text('Record loan'),
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
