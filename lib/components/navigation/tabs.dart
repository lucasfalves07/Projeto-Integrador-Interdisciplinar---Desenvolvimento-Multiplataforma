import 'package:flutter/material.dart';

/// Tabs raiz (equivalente a <Tabs>)
class CustomTabs extends StatelessWidget {
  final List<String> tabs;
  final List<Widget> children;
  final int initialIndex;

  const CustomTabs({
    super.key,
    required this.tabs,
    required this.children,
    this.initialIndex = 0,
  }) : assert(tabs.length == children.length, "O nÃºmero de tabs deve ser igual ao de conteÃºdos.");

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Column(
        children: [
          // TabsList
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  ),
                ],
              ),
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor: Theme.of(context).hintColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),

          // TabsContent
          Expanded(
            child: TabBarView(children: children),
          ),
        ],
      ),
    );
  }
}
