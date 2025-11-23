/// Exporta a implementação correta dependendo da plataforma:
/// - Web → usa web_download_html.dart
/// - Mobile/Desktop → usa web_download_stub.dart
export 'web_download_stub.dart'
    if (dart.library.html) 'web_download_html.dart';
