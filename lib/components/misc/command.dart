import 'package:flutter/material.dart';

class CommandDialog extends StatefulWidget {
  final List<String> items;
  final void Function(String)? onSelected;

  const CommandDialog({
    super.key,
    required this.items,
    this.onSelected,
  });

  @override
  State<CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<CommandDialog> {
  final TextEditingController _controller = TextEditingController();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _controller.addListener(_filter);
  }

  void _filter() {
    setState(() {
      _filteredItems = widget.items
          .where((item) =>
              item.toLowerCase().contains(_controller.text.toLowerCase()))
          .toList();
    });
  }

  void _selectItem(String item) {
    if (widget.onSelected != null) {
      widget.onSelected!(item);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(maxHeight: 400, maxWidth: 500),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                hintText: 'Search...',
                border: InputBorder.none,
              ),
            ),
            const Divider(),

            // List Items
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(
                      child: Text(
                        "No results found",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: Text(item),
                          onTap: () => _selectItem(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
