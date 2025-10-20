/// Helper para concatenar strings de estilo/classe.
/// No Flutter, como usamos Widgets em vez de classes CSS,
/// essa funÃ§Ã£o sÃ³ serve para unir strings caso vocÃª queira
/// reaproveitar em logs, debug ou algo parecido.
String cn(List<String?> inputs) {
  return inputs.where((input) => input != null && input.isNotEmpty).join(" ");
}
