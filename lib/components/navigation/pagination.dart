import 'package:flutter/material.dart';

class Pagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageChanged;

  const Pagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: const NavigationBarThemeData(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PaginationPrevious(
            enabled: currentPage > 1,
            onPressed: () => onPageChanged?.call(currentPage - 1),
          ),
          const SizedBox(width: 8),
          PaginationContent(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: onPageChanged,
          ),
          const SizedBox(width: 8),
          PaginationNext(
            enabled: currentPage < totalPages,
            onPressed: () => onPageChanged?.call(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class PaginationContent extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageChanged;

  const PaginationContent({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];

    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 || i == totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
        items.add(PaginationItem(
          page: i,
          isActive: i == currentPage,
          onPressed: () => onPageChanged?.call(i),
        ));
      } else if (i == currentPage - 2 || i == currentPage + 2) {
        items.add(const PaginationEllipsis());
      }
    }

    return Row(children: items);
  }
}

class PaginationItem extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback? onPressed;

  const PaginationItem({
    super.key,
    required this.page,
    this.isActive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PaginationLink(
      label: page.toString(),
      isActive: isActive,
      onPressed: onPressed,
    );
  }
}

class PaginationLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  const PaginationLink({
    super.key,
    required this.label,
    this.isActive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: isActive ? Colors.grey.shade200 : null,
        foregroundColor: isActive ? Colors.black : Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class PaginationPrevious extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const PaginationPrevious({super.key, this.enabled = true, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.chevron_left, size: 16),
      label: const Text("Previous"),
    );
  }
}

class PaginationNext extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const PaginationNext({super.key, this.enabled = true, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.chevron_right, size: 16),
      label: const Text("Next"),
    );
  }
}

class PaginationEllipsis extends StatelessWidget {
  const PaginationEllipsis({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.more_horiz, size: 18),
    );
  }
}
