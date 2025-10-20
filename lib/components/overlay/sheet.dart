import 'package:flutter/material.dart';

enum SheetSide { top, bottom, left, right }

class AppSheet extends StatefulWidget {
  final Widget child;
  final bool isOpen;
  final SheetSide side;
  final VoidCallback? onClose;

  const AppSheet({
    super.key,
    required this.child,
    this.isOpen = false,
    this.side = SheetSide.right,
    this.onClose,
  });

  @override
  State<AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<AppSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = _getAnimation(widget.side);

    if (widget.isOpen) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AppSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isOpen && !_controller.isCompleted) {
      _controller.forward();
    } else if (!widget.isOpen && _controller.isCompleted) {
      _controller.reverse();
    }
  }

  Animation<Offset> _getAnimation(SheetSide side) {
    switch (side) {
      case SheetSide.top:
        return Tween(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      case SheetSide.bottom:
        return Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      case SheetSide.left:
        return Tween(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      case SheetSide.right:
      default:
        return Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen && !_controller.isAnimating) return const SizedBox.shrink();

    return Stack(
      children: [
        // Overlay
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withOpacity(0.6),
          ),
        ),

        // Sheet Content
        SlideTransition(
          position: _offsetAnimation,
          child: Align(
            alignment: _getAlignment(widget.side),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              width: widget.side == SheetSide.left || widget.side == SheetSide.right
                  ? MediaQuery.of(context).size.width * 0.75
                  : double.infinity,
              height: widget.side == SheetSide.top || widget.side == SheetSide.bottom
                  ? MediaQuery.of(context).size.height * 0.75
                  : double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Stack(
                children: [
                  widget.child,
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onClose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Alignment _getAlignment(SheetSide side) {
    switch (side) {
      case SheetSide.top:
        return Alignment.topCenter;
      case SheetSide.bottom:
        return Alignment.bottomCenter;
      case SheetSide.left:
        return Alignment.centerLeft;
      case SheetSide.right:
      default:
        return Alignment.centerRight;
    }
  }
}

// Header
class SheetHeader extends StatelessWidget {
  final Widget child;

  const SheetHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }
}

// Footer
class SheetFooter extends StatelessWidget {
  final Widget child;

  const SheetFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: child,
    );
  }
}

// Title
class SheetTitle extends StatelessWidget {
  final String text;

  const SheetTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

// Description
class SheetDescription extends StatelessWidget {
  final String text;

  const SheetDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).hintColor,
          ),
    );
  }
}
