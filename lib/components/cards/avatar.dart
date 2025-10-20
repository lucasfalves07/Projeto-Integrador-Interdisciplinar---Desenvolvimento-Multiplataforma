import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackText;
  final double size;

  const Avatar({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.size = 40, // equivalente ao h-10 w-10
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Text(
              fallbackText != null && fallbackText!.isNotEmpty
                  ? fallbackText![0].toUpperCase()
                  : "?",
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
