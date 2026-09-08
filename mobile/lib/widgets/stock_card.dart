import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../theme.dart';
import '../utils/format.dart';

class StockCard extends StatelessWidget {
  const StockCard({super.key, required this.stock});

  final StockSummary stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GoldColors.hairline),
        gradient: const RadialGradient(
          center: Alignment(-1, -1),
          radius: 1.6,
          colors: [Color(0xFF251D10), Color(0xFF120F0A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('IN HAND'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Figure(
                  label: 'Gold',
                  value: grams(stock.weightGrams),
                ),
              ),
              Container(width: 1, height: 34, color: GoldColors.hairline),
              const SizedBox(width: 14),
              Expanded(
                child: _Figure(
                  label: 'Cash',
                  value: inr(stock.cashInHand),
                  alignEnd: true,
                  danger: stock.cashInHand < 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'avg cost ${inr2(stock.avgCostPerGram)} / g  ·  stock value ${inr(stock.stockValue)}',
            style: const TextStyle(color: GoldColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: GoldColors.muted)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1,
              color: danger ? GoldColors.loss : GoldColors.text,
            ),
          ),
        ),
      ],
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
