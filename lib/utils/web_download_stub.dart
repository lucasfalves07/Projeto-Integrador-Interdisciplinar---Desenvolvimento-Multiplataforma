/// Fallback para plataformas que não suportam APIs Web (mobile/desktop).
/// Sempre retorna false para sinalizar que a exportação deve ser tratada
/// de outra forma ou ignorada.
Future<bool> saveCsvWeb(String filename, String content) async {
  return false;
}
