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
          const _Eyebrow('CURRENT STOCK'),
          const SizedBox(height: 8),
          Text(
            grams(stock.weightGrams),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              height: 1,
              color: GoldColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'avg cost ${inr2(stock.avgCostPerGram)} / g',
            style: const TextStyle(color: GoldColors.muted, fontSize: 13),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Eyebrow('STOCK VALUE'),
              Text(
                inr(stock.stockValue),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.6,
        color: GoldColors.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
