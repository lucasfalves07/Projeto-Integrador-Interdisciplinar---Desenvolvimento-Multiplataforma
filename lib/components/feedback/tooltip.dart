import 'package:flutter/material.dart';

class CustomTooltip extends StatefulWidget {
  final Widget trigger;
  final String message;
  final EdgeInsets padding;
  final Duration showDuration;
  final Duration waitDuration;
  final double sideOffset;

  const CustomTooltip({
    super.key,
    required this.trigger,
    required this.message,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.showDuration = const Duration(seconds: 2),
    this.waitDuration = const Duration(milliseconds: 500),
    this.sideOffset = 8.0,
  });

  @override
  State<CustomTooltip> createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<CustomTooltip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showTooltip() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(widget.showDuration, _hideTooltip);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy - widget.sideOffset,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, -size.height - widget.sideOffset),
          child: Material(
            color: Colors.transparent,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 6,
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ],
                ),
                padding: widget.padding,
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTapDown: (_) => _showTooltip(),
        onTapUp: (_) => _hideTooltip(),
        onLongPress: _showTooltip,
        onLongPressEnd: (_) => _hideTooltip(),
        child: widget.trigger,
      ),
    );
  }
}
