import 'package:flutter/material.dart';

/// FunÃ§Ã£o para exibir toast (SnackBar) no Flutter
void showToast(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction ?? () {},
            )
          : null,
    ),
  );
}
