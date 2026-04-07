// pdf_generator.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../services/media_scanner_service.dart';

Future<void> generatePDF({
  required quill.Document document,
  required String pageSize,
  required String fontFamily,
  required double fontSize,
  required String savePath,
  required String headerText,
  required String footerText,
  required double bodyTopMargin,
  String? backgroundImagePath,
  double backgroundOpacity = 0.9,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  double marginCm = 2.54,
  bool showHeaderFooter = true, // <-- NEW: Sync this with your app state
}) async {
  final pdf = pw.Document();

  // 1. Determine Page Format
  PdfPageFormat pdfPageFormat;
  switch (pageSize.toLowerCase()) {
    case "long":
    case "legal":
      pdfPageFormat = PdfPageFormat.legal;
      break;
    case "short":
    case "letter":
      pdfPageFormat = PdfPageFormat.letter;
      break;
    case "a4":
    default:
      pdfPageFormat = PdfPageFormat.a4;
  }

  // 2. Convert margin: cm → PDF points (1 cm = 28.3465 pt)
  final double marginPt = marginCm * 28.3465;

  // 3. Load Background Image
  pw.MemoryImage? bgImage;
  if (backgroundImagePath != null && backgroundImagePath.isNotEmpty) {
    final bgFile = File(backgroundImagePath);
    if (await bgFile.exists()) {
      bgImage = pw.MemoryImage(await bgFile.readAsBytes());
    }
  }

  // 4. Define PageTheme
  // Set Top/Bottom to 0 so we can perfectly control the dynamic height in the header/footer!
  final theme = pw.PageTheme(
    pageFormat: pdfPageFormat,
    margin: pw.EdgeInsets.only(
      left: marginPt, 
      right: marginPt, 
      top: 0, 
      bottom: 0,
    ),
    buildBackground: (pw.Context context) {
      if (bgImage == null) return pw.SizedBox.shrink();
      return pw.FullPage(
        ignoreMargins: true,
        child: pw.Opacity(
          opacity: backgroundOpacity,
          child: pw.Image(bgImage, fit: pw.BoxFit.cover),
        ),
      );
    },
  );

  // 5. Use MultiPage with deep Quill node parsing
  pdf.addPage(
    pw.MultiPage(
      pageTheme: theme,
      header: (pw.Context context) {
        // EXACT PARITY WITH PRINT_VIEW:
        // 1. If background image exists, use the custom bodyTopMargin
        if (bgImage != null) {
           return pw.SizedBox(height: bodyTopMargin);
        }
        // 2. If headers are hidden, just return the exact margin (no 160 bug!)
        if (!showHeaderFooter) {
           return pw.SizedBox(height: marginPt);
        }
        
        // 3. Standard Header
        return pw.Container(
          alignment: pw.Alignment.centerLeft,
          padding: pw.EdgeInsets.only(
            top: marginPt / 2, 
            bottom: 20, // Buffer distance between header and body text
          ),
          child: headerText.isNotEmpty 
            ? pw.Text(headerText, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            : pw.SizedBox(height: 10), // Empty buffer so layout doesn't collapse
        );
      },
      footer: (pw.Context context) {
        // 1. Fallback to standard margin if hidden or background is used
        if (bgImage != null || !showHeaderFooter) {
          return pw.SizedBox(height: marginPt);
        }

        // 2. Standard Footer
        return pw.Container(
          alignment: pw.Alignment.center, 
          padding: pw.EdgeInsets.only(
            top: 20, // Buffer between body and footer
            bottom: marginPt / 2,
          ),
          child: footerText.isNotEmpty 
            ? pw.Text(footerText, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            : pw.SizedBox(height: 10),
        );
      },
      build: (pw.Context context) {
        List<pw.Widget> widgets =[];

        for (final node in document.root.children) {
          if (node is quill.Line) {
            widgets.add(_buildLineWidget(node, fontSize, fontFamily));
          } else if (node is quill.Block) {
            for (final line in node.children) {
              if (line is quill.Line) {
                widgets.add(_buildLineWidget(line, fontSize, fontFamily));
              }
            }
          }
        }
        return widgets;
      },
    ),
  );

  // 6. Save
  final file = File(savePath);
  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }
  await file.writeAsBytes(await pdf.save());
  await MediaScannerService.scanFile(file.path);
}

pw.Widget _buildLineWidget(quill.Line line, double fontSize, String fontFamily) {
  pw.TextAlign lineAlign = pw.TextAlign.left;
  final alignAttr = line.style.attributes[quill.Attribute.align.key];

  if (alignAttr != null) {
    if (alignAttr.value == 'center') lineAlign = pw.TextAlign.center;
    else if (alignAttr.value == 'right') lineAlign = pw.TextAlign.right;
    else if (alignAttr.value == 'justify') lineAlign = pw.TextAlign.justify;
  }

  List<pw.InlineSpan> spans =[];

  for (final leaf in line.children) {
    if (leaf is quill.Leaf) {
      final inlineStyles = leaf.style.attributes;

      final bool isSpanBold      = inlineStyles['bold']?.value      == true;
      final bool isSpanItalic    = inlineStyles['italic']?.value    == true;
      final bool isSpanUnderline = inlineStyles['underline']?.value == true;

      // Inline font size override
      final dynamic sizeVal = inlineStyles['size']?.value;
      double spanFontSize = fontSize;
      if (sizeVal is num) {
        spanFontSize = sizeVal.toDouble();
      } else if (sizeVal is String) {
        switch (sizeVal) {
          case 'small': spanFontSize = fontSize * 0.75; break;
          case 'large': spanFontSize = fontSize * 1.17; break;
          case 'huge':  spanFontSize = fontSize * 1.5;  break;
        }
      }

      final String textValue = leaf.toPlainText().replaceAll('\n', '');

      if (textValue.isNotEmpty) {
        spans.add(
          pw.TextSpan(
            text: textValue,
            style: pw.TextStyle(
              fontSize: spanFontSize,
              font: _getFontVariant(fontFamily, isSpanBold, isSpanItalic),
              decoration: isSpanUnderline
                  ? pw.TextDecoration.underline
                  : pw.TextDecoration.none,
            ),
          ),
        );
      }
    }
  }

  if (spans.isEmpty) {
    return pw.SizedBox(height: fontSize);
  }

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(bottom: 0), // <-- FIX: Ensures true 1.0 Line Spacing!
    child: pw.RichText(
      textAlign: lineAlign,
      text: pw.TextSpan(children: spans),
    ),
  );
}

pw.Font _getFontVariant(String family, bool bold, bool italic) {
  switch (family.toLowerCase()) {
    case 'courier':
      if (bold && italic) return pw.Font.courierBoldOblique();
      if (bold)           return pw.Font.courierBold();
      if (italic)         return pw.Font.courierOblique();
      return pw.Font.courier();
    case 'times':
      if (bold && italic) return pw.Font.timesBoldItalic();
      if (bold)           return pw.Font.timesBold();
      if (italic)         return pw.Font.timesItalic();
      return pw.Font.times();
    case 'helvetica':
    default:
      if (bold && italic) return pw.Font.helveticaBoldOblique();
      if (bold)           return pw.Font.helveticaBold();
      if (italic)         return pw.Font.helveticaOblique();
      return pw.Font.helvetica();
  }
}