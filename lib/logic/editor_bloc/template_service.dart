import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:docx_template/docx_template.dart';

class TemplateConfig {
  final String id;
  final String title;
  final String header;
  final String footer;
  final String body;

  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double bodyTopMargin;

  const TemplateConfig({
    required this.id,
    required this.title,
    required this.header,
    required this.footer,
    required this.body,
    this.backgroundImagePath,
    this.backgroundOpacity = 0.9,
    this.bodyTopMargin = 160.0,
  });
}

class TemplateService {
  // ---------------------------------------------------------------------------
  // BUILT-IN TEMPLATES
  // ---------------------------------------------------------------------------

  static List<TemplateConfig> builtInTemplates(String scannedText) => [
        TemplateConfig(
          id: 'essay',
          title: 'Essay',
          header: 'Essay Title',
          footer: 'Page {page} | DocEase',
          body: '[Title]\n\nIntroduction:\n$scannedText\n\nConclusion:\n',
        ),
        TemplateConfig(
          id: 'letter',
          title: 'Formal Letter',
          header: 'Formal Letter',
          footer: 'Confidential | DocEase',
          body:
              '[Date]\n\nDear [Recipient],\n\n$scannedText\n\nSincerely,\n[Your Name]',
        ),
        TemplateConfig(
          id: 'report',
          title: 'Report',
          header: '[Report Title] | [Author]',
          footer: 'Page {page} | [Date]',
          body:
              '[Report Title]\n[Author] | [Date]\n\n$scannedText',
        ),
        TemplateConfig(
          id: 'memo',
          title: 'Memo',
          header: 'MEMORANDUM',
          footer: 'Internal Use Only | DocEase',
          body:
              'TO: [Recipient]\nFROM: [Sender]\nDATE: [Date]\nSUBJECT: [Subject]\n\n$scannedText',
        ),
      ];

  // ---------------------------------------------------------------------------
  // GENERATE PDF
  // ---------------------------------------------------------------------------

static Future<File> generatePdf({
  required TemplateConfig template,
  required String fileName,
  String? headerImagePath,
  String? footerImagePath,
  String? backgroundImagePath,
  double backgroundOpacity = 0.9,
  double bodyTopMargin = 160,
}) async {
  final pdf = pw.Document();

  // Pre-load images
  pw.MemoryImage? headerImage;
  pw.MemoryImage? footerImage;
  pw.MemoryImage? backgroundImage;

  if (headerImagePath != null && headerImagePath.isNotEmpty) {
    headerImage =
        pw.MemoryImage(await File(headerImagePath).readAsBytes());
  }
  if (footerImagePath != null && footerImagePath.isNotEmpty) {
    footerImage =
        pw.MemoryImage(await File(footerImagePath).readAsBytes());
  }
  if (backgroundImagePath != null &&
      backgroundImagePath.isNotEmpty) {
    backgroundImage = pw.MemoryImage(
        await File(backgroundImagePath).readAsBytes());
  }

  final chunks = _splitIntoChunks(template.body, 3000);
  final totalPages = chunks.length;
  final isBackgroundMode = backgroundImage != null;

  for (int i = 0; i < chunks.length; i++) {
    final pageNumber = i + 1;
    final headerText =
        template.header.replaceAll('{page}', '$pageNumber');
    final footerText = template.footer
        .replaceAll('{page}', '$pageNumber')
        .replaceAll('{total}', '$totalPages');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) {
          if (isBackgroundMode) {
            // ── Background mode ──────────────────────────
            return pw.Stack(
              children: [
                // Full page background image
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: backgroundOpacity,
                    child: pw.Image(
                      backgroundImage!,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
                // Body text overlay
                pw.Positioned(
                  top: bodyTopMargin,
                  left: 48,
                  right: 48,
                  bottom: 80,
                  child: pw.Text(
                    chunks[i],
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 6,
                    ),
                  ),
                ),
              ],
            );
          }

          // ── Zones mode (header + footer strips) ────────
          return pw.Padding(
            padding: const pw.EdgeInsets.all(48),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.only(bottom: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.center,
                    children: [
                      headerImage != null
                          ? pw.Image(headerImage,
                              height: 28,
                              fit: pw.BoxFit.contain)
                          : pw.Expanded(
                              child: pw.Text(
                                headerText,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey600,
                                  fontWeight:
                                      pw.FontWeight.bold,
                                ),
                              ),
                            ),
                      pw.Text(
                        'Page $pageNumber of $totalPages',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                // Body
                pw.Expanded(
                  child: pw.Text(
                    chunks[i],
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 6,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                // Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.only(top: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: footerImage != null
                      ? pw.Center(
                          child: pw.Image(footerImage,
                              height: 24,
                              fit: pw.BoxFit.contain))
                      : pw.Text(
                          footerText,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey500,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/DocEase/PDF');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final file = File('${folder.path}/$fileName.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

  // ---------------------------------------------------------------------------
  // GENERATE DOCX
  // ---------------------------------------------------------------------------

  static Future<File> generateDocx({
    required TemplateConfig template,
    required String fileName,
  }) async {
    // Build a minimal DOCX in-memory using raw XML
    // since docx_template needs an existing .docx asset
    // we build it from scratch using the xml approach
    final content = _buildDocxXml(
      header: template.header,
      footer: template.footer,
      body: template.body,
    );

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/DocEase/DOCX');
    if (!await folder.exists()) await folder.create(recursive: true);

    final file = File('${folder.path}/$fileName.docx');
    await file.writeAsString(content);
    return file;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static List<String> _splitIntoChunks(String text, int chunkSize) {
    final chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) end = text.length;

      // Try to break at a newline or space
      if (end < text.length) {
        final breakAt = text.lastIndexOf('\n', end);
        if (breakAt > start) end = breakAt;
      }

      chunks.add(text.substring(start, end).trim());
      start = end;
    }
    return chunks.isEmpty ? [''] : chunks;
  }

  static String _buildDocxXml({
    required String header,
    required String footer,
    required String body,
  }) {
    final escapedHeader = _escapeXml(header);
    final escapedFooter = _escapeXml(footer);
    final bodyParagraphs = body
        .split('\n')
        .map((line) =>
            '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(line)}</w:t></w:r></w:p>')
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:rPr><w:b/><w:sz w:val="28"/></w:rPr>
        <w:t>$escapedHeader</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r><w:rPr><w:b/></w:rPr>
        <w:t>────────────────────────────</w:t>
      </w:r>
    </w:p>
    $bodyParagraphs
    <w:p>
      <w:r><w:rPr><w:b/></w:rPr>
        <w:t>────────────────────────────</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:rPr><w:color w:val="808080"/><w:sz w:val="18"/></w:rPr>
        <w:t>$escapedFooter</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>''';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}