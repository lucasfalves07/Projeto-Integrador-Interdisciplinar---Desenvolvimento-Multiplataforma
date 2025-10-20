import 'toaster.dart';

/// Re-exporta o que importa
typedef UseToast = ToastController;

/// Atalho para criar um toast rapidamente
void toast(ToastController controller, {
  required String title,
  String? description,
  bool destructive = false,
}) {
  controller.show(
    ToastEntry(
      id: DateTime.now().toIso8601String(),
      title: title,
      description: description,
      variant: destructive ? ToastVariant.destructive : ToastVariant.normal,
    ),
  );
}
