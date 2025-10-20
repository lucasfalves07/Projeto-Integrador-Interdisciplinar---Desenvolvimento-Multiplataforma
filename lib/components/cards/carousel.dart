import 'package:flutter/material.dart';

class Carousel extends StatefulWidget {
  final List<Widget> items;
  final Axis orientation;

  const Carousel({
    super.key,
    required this.items,
    this.orientation = Axis.horizontal,
  });

  @override
  State<Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<Carousel> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  void scrollPrev() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void scrollNext() {
    if (_currentPage < widget.items.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: widget.orientation,
          itemCount: widget.items.length,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemBuilder: (context, index) {
            return widget.items[index];
          },
        ),

        // BotÃ£o anterior
        Positioned(
          left: 8,
          child: IconButton(
            onPressed: _currentPage > 0 ? scrollPrev : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_left),
          ),
        ),

        // BotÃ£o prÃ³ximo
        Positioned(
          right: 8,
          child: IconButton(
            onPressed: _currentPage < widget.items.length - 1 ? scrollNext : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_right),
          ),
        ),
      ],
    );
  }
}
