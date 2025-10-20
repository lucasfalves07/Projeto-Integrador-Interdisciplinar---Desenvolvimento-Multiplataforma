import 'package:flutter/material.dart';

class NavigationMenu extends StatefulWidget {
  final List<NavigationMenuItem> items;

  const NavigationMenu({super.key, required this.items});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  int? _openIndex;

  void _toggleMenu(int index) {
    setState(() {
      _openIndex = _openIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isOpen = _openIndex == index;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                if (item.onTap != null) item.onTap!();
                if (item.subItems.isNotEmpty) _toggleMenu(index);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isOpen
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                      : Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    if (item.subItems.isNotEmpty)
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, size: 16),
                      ),
                  ],
                ),
              ),
            ),
            if (isOpen && item.subItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.subItems.map((subItem) {
                    return InkWell(
                      onTap: subItem.onTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          subItem.label,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class NavigationMenuItem {
  final String label;
  final VoidCallback? onTap;
  final List<NavigationSubItem> subItems;

  NavigationMenuItem({
    required this.label,
    this.onTap,
    this.subItems = const [],
  });
}

class NavigationSubItem {
  final String label;
  final VoidCallback? onTap;

  NavigationSubItem({required this.label, this.onTap});
}
