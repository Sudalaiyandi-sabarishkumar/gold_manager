import 'package:flutter/material.dart';

import '../theme.dart';

/// The little gold coin used in the wordmark and on the login screen.
class Coin extends StatelessWidget {
  const Coin({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFE488), GoldColors.gold, Color(0xFFA9791A)],
          stops: [0.0, 0.46, 1.0],
        ),
      ),
      child: size >= 40
          ? Text(
              'Au',
              style: TextStyle(
                color: const Color(0xFF3A2B05),
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
              ),
            )
          : null,
    );
  }
}
