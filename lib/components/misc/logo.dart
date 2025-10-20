import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final String asset;
  const LogoWidget({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24), // equivalente ao padding do CSS
      child: Image.asset(
        asset,
        height: 96, // 6em
      ),
    );
  }
}
