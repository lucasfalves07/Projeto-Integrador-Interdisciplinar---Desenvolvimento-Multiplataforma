// ✅ lib/utils/export_boletim_pdf.dart — Versão Final Premium (Web + Mobile + Desktop)
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;

// Imports específicos por plataforma
import 'dart:io' show File; // Apenas mobile/desktop
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:open_filex/open_filex.dart';
import 'dart:html' as html; // Apenas Web

class ExportBoletimPDF {
  static Future<void> gerarPDF({
    required String alunoNome,
    required String alunoRA,
    required String turmaNome,
    required Map<String, Map<String, double>> mediasPorDisciplinaBim,
    required Map<String, double> mediaFinalPorDisciplina,
    required Map<String, String> statusPorDisciplina,
    required Map<String, String> disciplinasNomes,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // ================== CABEÇALHO ==================
          pw.Container(
            alignment: pw.Alignment.centerLeft,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Escola Poliedro",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  "Boletim Escolar",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ),
          pw.Divider(color: PdfColors.blue900, thickness: 1.5),
          pw.SizedBox(height: 10),

          // ================== DADOS DO ALUNO ==================
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey400),
              borderRadius: pw.BorderRadius.circular(6),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Nome do Aluno: $alunoNome",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text("RA: $alunoRA", style: const pw.TextStyle(fontSize: 11)),
                pw.Text("Turma: $turmaNome",
                    style: const pw.TextStyle(fontSize: 11)),
                pw.Text("Emitido em: ${df.format(DateTime.now())}",
                    style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // ================== TÍTULO TABELA ==================
          pw.Text(
            "Desempenho por Disciplina e Bimestre",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 10),

          // ================== TABELA ==================
          _tabelaBoletim(
            mediasPorDisciplinaBim,
            mediaFinalPorDisciplina,
            statusPorDisciplina,
            disciplinasNomes,
          ),

          pw.SizedBox(height: 24),

          // ================== LEGENDA ==================
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Legenda de Status:",
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.blueGrey800),
                ),
                pw.SizedBox(height: 4),
                pw.Bullet(
                    text: "Aprovado — média ≥ 7,0",
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Bullet(
                    text: "Recuperação — média entre 5,0 e 6,9",
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Bullet(
                    text: "Reprovado — média < 5,0",
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _salvarEAbrir(bytes, alunoNome);
  }

  // ============================================================
  // 🔹 Tabela formatada do boletim
  // ============================================================
  static pw.Widget _tabelaBoletim(
    Map<String, Map<String, double>> mediasPorDisciplinaBim,
    Map<String, double> mediaFinalPorDisciplina,
    Map<String, String> statusPorDisciplina,
    Map<String, String> disciplinasNomes,
  ) {
    const bimestres = [
      '1º Bim',
      '2º Bim',
      '3º Bim',
      '4º Bim',
    ];

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.7),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerHeight: 25,
      cellHeight: 26,
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FixedColumnWidth(90),
        1: const pw.FixedColumnWidth(50),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(50),
        4: const pw.FixedColumnWidth(50),
        5: const pw.FixedColumnWidth(60),
        6: const pw.FixedColumnWidth(60),
      },
      headers: [
        'Disciplina',
        ...bimestres,
        'Média',
        'Status',
      ],
      data: disciplinasNomes.keys.map((discId) {
        final nome = disciplinasNomes[discId] ?? discId;
        final medias = mediasPorDisciplinaBim[discId] ?? {};
        final mediaFinal = mediaFinalPorDisciplina[discId] ?? 0.0;
        final status = statusPorDisciplina[discId] ?? "-";

        PdfColor statusColor;
        switch (status) {
          case 'Aprovado':
            statusColor = PdfColors.green800;
            break;
          case 'Recuperação':
            statusColor = PdfColors.orange700;
            break;
          default:
            statusColor = PdfColors.red800;
        }

        return [
          nome,
          medias['1º Bimestre']?.toStringAsFixed(1) ?? "-",
          medias['2º Bimestre']?.toStringAsFixed(1) ?? "-",
          medias['3º Bimestre']?.toStringAsFixed(1) ?? "-",
          medias['4º Bimestre']?.toStringAsFixed(1) ?? "-",
          mediaFinal.toStringAsFixed(1),
          pw.Text(
            status,
            style: pw.TextStyle(
              color: statusColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ];
      }).toList(),
    );
  }

  // ============================================================
  // 🔹 Salvar e abrir o PDF (Web + Mobile + Desktop)
  // ============================================================
  static Future<void> _salvarEAbrir(Uint8List bytes, String alunoNome) async {
    final safeName = alunoNome
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .substring(0, alunoNome.length.clamp(0, 25));

    if (kIsWeb) {
      // 🌐 Web — faz download automático
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = "Boletim_$safeName.pdf"
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // 📱 Mobile / Desktop
      final dir = await path_provider.getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Boletim_$safeName.pdf");
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    }
  }
}
