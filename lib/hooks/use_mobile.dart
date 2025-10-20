import 'package:flutter/widgets.dart';

/// Hook para saber se a tela Ã© "mobile"
/// baseado no breakpoint de 768px.
bool useIsMobile(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width < 768;
}
