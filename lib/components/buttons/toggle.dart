import 'package:flutter/material.dart';

enum ToggleVariant { defaultStyle, outline }
enum ToggleSize { sm, md, lg }

class Toggle extends StatefulWidget {
  final bool initialState;
  final ToggleVariant variant;
  final ToggleSize size;
  final VoidCallback? onPressed;
  final Widget child;
  final bool disabled;

  const Toggle({
    super.key,
    required this.child,
    this.initialState = false,
    this.variant = ToggleVariant.defaultStyle,
    this.size = ToggleSize.md,
    this.onPressed,
    this.disabled = false,
  });

  @override
  State<Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<Toggle> {
  late bool _isOn;

  @override
  void initState() {
    super.initState();
    _isOn = widget.initialState;
  }

  void _toggle() {
    if (widget.disabled) return;
    setState(() {
      _isOn = !_isOn;
    });
    widget.onPressed?.call();
  }

  EdgeInsets _paddingForSize() {
    switch (widget.size) {
      case ToggleSize.sm:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      case ToggleSize.lg:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case ToggleSize.md:
      default:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    Color background;
    Color foreground;
    BoxBorder? border;

    if (_isOn) {
      background = colorScheme.secondaryContainer;
      foreground = colorScheme.onSecondaryContainer;
    } else {
      switch (widget.variant) {
        case ToggleVariant.outline:
          background = Colors.transparent;
          border = Border.all(color: colorScheme.outline);
          foreground = colorScheme.onSurface;
          break;
        case ToggleVariant.defaultStyle:
        default:
          background = Colors.transparent;
          foreground = colorScheme.onSurface;
      }
    }

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: _paddingForSize(),
        decoration: BoxDecoration(
          color: widget.disabled ? colorScheme.surfaceVariant : background,
          border: border,
          borderRadius: BorderRadius.circular(6),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: widget.disabled ? colorScheme.onSurface.withOpacity(0.4) : foreground,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
