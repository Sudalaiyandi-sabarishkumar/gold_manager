import 'package:flutter/material.dart';

import '../theme.dart';

/// Small pill showing 'PAID' / 'PART' / 'DUE' for a transaction's settlement.
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.status});

  final String status; // 'paid' | 'partial' | 'unpaid'

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final String label;
    switch (status) {
      case 'paid':
        fg = GoldColors.gain;
        label = 'PAID';
      case 'partial':
        fg = GoldColors.gold;
        label = 'PART';
      default:
        fg = GoldColors.loss;
        label = 'DUE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: fg,
        ),
      ),
    );
  }
}
