import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final Color? color;
  final ShapeBorder? shape;

  const CustomCard({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.elevation = 2,
    this.color,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.all(8),
      elevation: elevation,
      color: color ?? Theme.of(context).cardColor,
      shape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class CardHeader extends StatelessWidget {
  final Widget child;
  const CardHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  final String text;
  const CardTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class CardDescription extends StatelessWidget {
  final String text;
  const CardDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
    );
  }
}

class CardContent extends StatelessWidget {
  final Widget child;
  const CardContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class CardFooter extends StatelessWidget {
  final Widget child;
  const CardFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: child,
    );
  }
}
