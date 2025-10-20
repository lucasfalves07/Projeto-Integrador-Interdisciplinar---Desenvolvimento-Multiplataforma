import 'package:flutter/material.dart';

enum SidebarState { expanded, collapsed }

class SidebarProvider extends InheritedWidget {
  final SidebarState state;
  final bool isMobile;
  final bool open;
  final ValueChanged<bool> setOpen;
  final VoidCallback toggleSidebar;

  const SidebarProvider({
    super.key,
    required this.state,
    required this.open,
    required this.isMobile,
    required this.setOpen,
    required this.toggleSidebar,
    required Widget child,
  }) : super(child: child);

  static SidebarProvider of(BuildContext context) {
    final SidebarProvider? result =
        context.dependOnInheritedWidgetOfExactType<SidebarProvider>();
    assert(result != null, 'No SidebarProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(SidebarProvider oldWidget) {
    return state != oldWidget.state || open != oldWidget.open;
  }
}

class Sidebar extends StatefulWidget {
  final Widget child;
  final double width;
  final SidebarState initialState;
  final bool collapsible;
  final bool isMobile;

  const Sidebar({
    super.key,
    required this.child,
    this.width = 250,
    this.initialState = SidebarState.expanded,
    this.collapsible = true,
    this.isMobile = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late SidebarState _state;
  late bool _open;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _open = widget.initialState == SidebarState.expanded;
  }

  void _setOpen(bool open) {
    setState(() {
      _open = open;
      _state = open ? SidebarState.expanded : SidebarState.collapsed;
    });
  }

  void _toggleSidebar() {
    _setOpen(!_open);
  }

  @override
  Widget build(BuildContext context) {
    return SidebarProvider(
      state: _state,
      open: _open,
      isMobile: widget.isMobile,
      setOpen: _setOpen,
      toggleSidebar: _toggleSidebar,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _open ? widget.width : (widget.collapsible ? 60 : widget.width),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Expanded(child: widget.child),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.background,
            ),
          )
        ],
      ),
    );
  }
}

/// Trigger para abrir/fechar
class SidebarTrigger extends StatelessWidget {
  const SidebarTrigger({super.key});

  @override
  Widget build(BuildContext context) {
    final sidebar = SidebarProvider.of(context);

    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: sidebar.toggleSidebar,
    );
  }
}

/// CabeÃ§alho
class SidebarHeader extends StatelessWidget {
  final Widget child;
  const SidebarHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

/// RodapÃ©
class SidebarFooter extends StatelessWidget {
  final Widget child;
  const SidebarFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

/// ConteÃºdo
class SidebarContent extends StatelessWidget {
  final List<Widget> children;
  const SidebarContent({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: children,
      ),
    );
  }
}

/// Grupo de itens
class SidebarGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const SidebarGroup({super.key, required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Item do menu
class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const SidebarMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sidebar = SidebarProvider.of(context);

    return ListTile(
      dense: true,
      leading: Icon(icon,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).iconTheme.color),
      title: sidebar.state == SidebarState.expanded
          ? Text(
              label,
              style: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            )
          : null,
      onTap: onTap,
      minLeadingWidth: 20,
    );
  }
}
