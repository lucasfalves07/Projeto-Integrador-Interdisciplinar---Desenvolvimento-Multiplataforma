import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final Widget? header;
  final Widget? footer;
  final Widget? child;
  final String? title;
  final String? description;

  const CustomDrawer({
    super.key,
    this.header,
    this.footer,
    this.child,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle indicator
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (header != null) header!,
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    title!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    description!,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              if (footer != null) footer!,
            ],
          ),
        );
      },
    );
  }
}

void showCustomDrawer({
  required BuildContext context,
  Widget? header,
  Widget? footer,
  Widget? child,
  String? title,
  String? description,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CustomDrawer(
      header: header,
      footer: footer,
      child: child,
      title: title,
      description: description,
    ),
  );
}
