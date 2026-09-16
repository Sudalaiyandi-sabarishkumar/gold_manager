import 'package:flutter/material.dart';

/// The AVS mark used in the wordmark and on the login screen.
class Coin extends StatelessWidget {
  const Coin({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/avs.jpeg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
