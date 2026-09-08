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
  final _search = TextEditingController();
  String _filter = 'all';
  String _query = '';
  DateTime? _from;
  DateTime? _to;

  bool get _hasFilters =>
      _query.isNotEmpty || _from != null || _to != null || _filter != 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _search.clear();
      _query = '';
      _from = null;
      _to = null;
      _filter = 'all';
    });
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _from = DateTime(d.year, d.month, d.day));
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _to = DateTime(d.year, d.month, d.day, 23, 59, 59));
    }
  }

  List<GoldTransaction> _apply(List<GoldTransaction> all) {
    final q = _query.trim().toLowerCase();
    return all.where((t) {
      if (_filter != 'all' && t.type != _filter) return false;
      if (_from != null && t.date.isBefore(_from!)) return false;
      if (_to != null && t.date.isAfter(_to!)) return false;
      if (q.isNotEmpty &&
          !t.party.toLowerCase().contains(q) &&
          !t.note.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _apply(context.watch<AppState>().transactions);

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
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_hasFilters)
            TextButton(onPressed: _clearAll, child: const Text('Clear')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search name or note',
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: 'From',
                    value: _from,
                    onTap: _pickFrom,
                    onClear: _from == null
                        ? null
                        : () => setState(() => _from = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateChip(
                    label: 'To',
                    value: _to,
                    onTap: _pickTo,
                    onClear:
                        _to == null ? null : () => setState(() => _to = null),
                  ),
                ),
              ],
            ),
          ),
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
                      _hasFilters
                          ? 'Nothing matches those filters'
                          : 'No transactions yet',
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

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: GoldColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GoldColors.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 1,
                          color: GoldColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'Any' : fmtDate(value!),
                    style: TextStyle(
                      fontSize: 13,
                      color: value == null ? GoldColors.faint : GoldColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child:
                    const Icon(Icons.close, size: 15, color: GoldColors.muted),
              )
            else
              const Icon(Icons.calendar_today,
                  size: 14, color: GoldColors.muted),
          ],
        ),
      ),
    );
  }
}
