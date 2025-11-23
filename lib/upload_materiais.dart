import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final dir = Directory('assets/materiais');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
    print('📁 Pasta criada: ${dir.path}');
  }

  final materiais = {
    'matematica_basica.pdf': 'https://edisciplinas.usp.br/pluginfile.php/6323544/mod_resource/content/1/Apostila%20de%20Matem%C3%A1tica%20B%C3%A1sica.pdf',
    'portugues_gramatica.pdf': 'https://educapes.capes.gov.br/bitstream/capes/589596/2/Apostila%20de%20Gram%C3%A1tica.pdf',
    'historia_geral.pdf': 'https://educapes.capes.gov.br/bitstream/capes/587892/2/Apostila%20de%20Hist%C3%B3ria%20Geral.pdf',
    'biologia_introducao.pdf': 'https://educapes.capes.gov.br/bitstream/capes/589616/2/Apostila%20de%20Biologia.pdf',
  };

  print('📥 Baixando ${materiais.length} PDFs...');

  for (final entry in materiais.entries) {
    final filePath = '${dir.path}/${entry.key}';
    try {
      final response = await http.get(Uri.parse(entry.value));
      if (response.statusCode == 200) {
        await File(filePath).writeAsBytes(response.bodyBytes);
        print('✅ Baixado: ${entry.key}');
      } else {
        print('⚠️ Falha ao baixar ${entry.key} (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Erro ao baixar ${entry.key}: $e');
    }
  }

  print('\n🎉 Todos os arquivos foram baixados com sucesso!');
}
