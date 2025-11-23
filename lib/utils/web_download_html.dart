// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Salva um arquivo CSV no navegador (somente Web)
Future<bool> saveCsvWeb(String filename, String content) async {
  try {
    final blob = html.Blob([content], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';

    // Adiciona ao DOM para compatibilidade
    html.document.body?.append(anchor);

    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    print("Erro ao salvar CSV no navegador: $e");
    return false;
  }
}
