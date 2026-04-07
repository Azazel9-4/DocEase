// docx_generator.dart
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../services/media_scanner_service.dart';

/// Generate a DOCX file by parsing the Quill Document structure directly.
Future<File?> generateDocx({
  required quill.Document document,
  required String savePath,
  required String pageSize,
  String fontFamily = "Calibri",
  int fontSize = 24, 
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  String headerText = "",
  String footerText = "",
  String? backgroundImagePath,
  double marginCm = 2.54,
  double bodyTopMargin = 160.0, 
}) async {
  try {
    final int marginTwips = (marginCm * 567).round();
    final int headerFooterMarginTwips = (marginTwips / 2).round(); // The 0.5 inch gap from the edge!
    
    final bool hasBackground = backgroundImagePath != null && backgroundImagePath.isNotEmpty;
    final int topMarginTwips = hasBackground ? (bodyTopMargin * 15).round() : marginTwips;

    int pageWidth  = 11907;
    int pageHeight = 16840;

    switch (pageSize.toLowerCase()) {
      case "letter":
      case "short":
        pageWidth  = 12241;
        pageHeight = 15842;
        break;
      case "legal":
      case "long":
        pageWidth  = 12241;
        pageHeight = 20162;
        break;
    }

    final List<String> xmlParagraphs =[];
    for (final node in document.root.children) {
      if (node is quill.Line) {
        xmlParagraphs.add(_buildXmlParagraph(node, fontFamily, fontSize));
      } else if (node is quill.Block) {
        for (final line in node.children) {
          if (line is quill.Line) {
            xmlParagraphs.add(_buildXmlParagraph(line, fontFamily, fontSize));
          }
        }
      }
    }

    final archive = Archive();
    String relsXml = _wordRelsBase;
    String contentTypesXml = _contentTypesBase;
    String sectPrRefs = "";

    // ── Background Image ────────────────────────────────────────────────────
    if (hasBackground) {
      final bgFile = File(backgroundImagePath);
      if (await bgFile.exists()) {
        final bytes = await bgFile.readAsBytes();
        String ext = backgroundImagePath.split('.').last.toLowerCase();
        if (ext == 'jpg') ext = 'jpeg';

        archive.addFile(ArchiveFile('word/media/bg_image.$ext', bytes.length, bytes));
        relsXml +=
            '<Relationship Id="rIdBg" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            'Target="media/bg_image.$ext"/>';
        contentTypesXml +=
            '<Override PartName="/word/headerBg.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>';

        final int pageWidthEmu  = pageWidth  * 635;
        final int pageHeightEmu = pageHeight * 635;

        final bgHeaderXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:p>
    <w:pPr><w:jc w:val="left"/></w:pPr>
    <w:r>
      <w:rPr/>
      <w:drawing>
        <wp:anchor distT="0" distB="0" distL="0" distR="0"
                  simplePos="0" relativeHeight="251658240" behindDoc="1"
                  locked="0" layoutInCell="1" allowOverlap="0">
          <wp:simplePos x="0" y="0"/>
          <wp:positionH relativeFrom="page"><wp:posOffset>0</wp:posOffset></wp:positionH>
          <wp:positionV relativeFrom="page"><wp:posOffset>0</wp:posOffset></wp:positionV>
          <wp:extent cx="$pageWidthEmu" cy="$pageHeightEmu"/>
          <wp:effectExtent l="0" t="0" r="0" b="0"/>
          <wp:wrapNone/>
          <wp:docPr id="1" name="BackgroundImage"/>
          <wp:cNvGraphicFramePr>
            <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="0"/>
          </wp:cNvGraphicFramePr>
          <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
            <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:nvPicPr>
                  <pic:cNvPr id="0" name="BackgroundImage"/>
                  <pic:cNvPicPr><a:picLocks noChangeAspect="0"/></pic:cNvPicPr>
                </pic:nvPicPr>
                <pic:blipFill>
                  <a:blip r:embed="rIdBg"/>
                  <a:stretch><a:fillRect/></a:stretch>
                </pic:blipFill>
                <pic:spPr>
                  <a:xfrm><a:off x="0" y="0"/><a:ext cx="$pageWidthEmu" cy="$pageHeightEmu"/></a:xfrm>
                  <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                </pic:spPr>
              </pic:pic>
            </a:graphicData>
          </a:graphic>
        </wp:anchor>
      </w:drawing>
    </w:r>
  </w:p>
</w:hdr>''';

        final bgHeaderBytes = utf8.encode(bgHeaderXml);
        archive.addFile(ArchiveFile('word/headerBg.xml', bgHeaderBytes.length, bgHeaderBytes));

        final bgHeaderRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdBg"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    Target="media/bg_image.$ext"/>
</Relationships>''';
        final bgHeaderRelsBytes = utf8.encode(bgHeaderRels);
        archive.addFile(ArchiveFile(
          'word/_rels/headerBg.xml.rels', bgHeaderRelsBytes.length, bgHeaderRelsBytes,
        ));
        relsXml +=
            '<Relationship Id="rIdBgHeader" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" '
            'Target="headerBg.xml"/>';
        sectPrRefs += '<w:headerReference w:type="default" r:id="rIdBgHeader"/>';
      }
    }

    // ── Header text (Only if NO background image) ────────────────────────────
    if (headerText.isNotEmpty && !hasBackground) {
      final headerBytes = utf8.encode(_buildHeader(headerText));
      archive.addFile(ArchiveFile('word/header1.xml', headerBytes.length, headerBytes));
      relsXml +=
          '<Relationship Id="rIdHeader" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" '
          'Target="header1.xml"/>';
      contentTypesXml +=
          '<Override PartName="/word/header1.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>';
      sectPrRefs += '<w:headerReference w:type="default" r:id="rIdHeader"/>';
    }

    // ── Footer text (Only if NO background image) ────────────────────────────
    if (footerText.isNotEmpty && !hasBackground) {
      final footerBytes = utf8.encode(_buildFooter(footerText));
      archive.addFile(ArchiveFile('word/footer1.xml', footerBytes.length, footerBytes));
      relsXml +=
          '<Relationship Id="rIdFooter" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" '
          'Target="footer1.xml"/>';
      contentTypesXml +=
          '<Override PartName="/word/footer1.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>';
      sectPrRefs += '<w:footerReference w:type="default" r:id="rIdFooter"/>';
    }

    relsXml += '</Relationships>';
    contentTypesXml += '</Types>';

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    ${xmlParagraphs.join('\n')}
    <w:sectPr>
      $sectPrRefs
      <w:pgSz w:w="$pageWidth" w:h="$pageHeight"/>
      <!-- w:header and w:footer push the bounds dynamically based on text height -->
      <w:pgMar w:top="$topMarginTwips" w:right="$marginTwips" w:bottom="$marginTwips" w:left="$marginTwips" w:header="$headerFooterMarginTwips" w:footer="$headerFooterMarginTwips"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final contentTypesBytes = utf8.encode(contentTypesXml);
    final relsRelsBytes     = utf8.encode(_relsRels);
    final wordRelsBytes     = utf8.encode(relsXml);
    final documentBytes     = utf8.encode(documentXml);

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));
    archive.addFile(ArchiveFile('_rels/.rels',                  relsRelsBytes.length,  relsRelsBytes));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', wordRelsBytes.length,  wordRelsBytes));
    archive.addFile(ArchiveFile('word/document.xml',            documentBytes.length,  documentBytes));

    final docxBytes = ZipEncoder().encode(archive);
    final file = File(savePath);
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    await file.writeAsBytes(docxBytes!);
    await MediaScannerService.scanFile(file.path);
    return file;
  } catch (e) {
    throw Exception("Failed to generate DOCX: $e");
  }
}

// ── Alignment resolution ─────────────────────────────────────────────────────
String _resolveAlignment(quill.Line line) {
  quill.Leaf? lastLeaf;
  for (final child in line.children) {
    if (child is quill.Leaf) lastLeaf = child;
  }
  final leafAlign = lastLeaf?.style.attributes['align']?.value as String?;
  if (leafAlign != null) {
    return _alignToWord(leafAlign);
  }

  final lineAlign = line.style.attributes['align']?.value as String?;
  if (lineAlign != null) {
    return _alignToWord(lineAlign);
  }

  return 'left'; 
}

String _alignToWord(String quillAlign) {
  switch (quillAlign) {
    case 'center':  return 'center';
    case 'right':   return 'right';
    case 'justify': return 'both';
    default:        return 'left';
  }
}

// ── Paragraph builder ────────────────────────────────────────────────────────
String _buildXmlParagraph(quill.Line line, String defaultFont, int defaultSize) {
  final String align = _resolveAlignment(line);

  String pPrExtra = "";
  final indentAttr = line.style.attributes[quill.Attribute.indent.key];
  if (indentAttr?.value != null) {
    final int level = (indentAttr!.value as num).toInt();
    pPrExtra = '<w:ind w:left="${level * 720}"/>';
  }

  final List<String> runs =[];

  for (final child in line.children) {
    if (child is quill.Leaf) {
      final text = _escapeXml(child.toPlainText().replaceAll('\n', ''));
      if (text.isEmpty) continue;

      final attrs = child.style.attributes;

      final bool bold      = attrs['bold']?.value      == true;
      final bool italic    = attrs['italic']?.value    == true;
      final bool underline = attrs['underline']?.value == true;
      final bool strike    = attrs['strike']?.value    == true;

      final dynamic sizeVal = attrs['size']?.value;
      int halfPt = defaultSize;
      if (sizeVal is num) {
        halfPt = (sizeVal * 2).toInt();
      } else if (sizeVal is String) {
        switch (sizeVal) {
          case 'small': halfPt = 20; break; 
          case 'large': halfPt = 28; break; 
          case 'huge':  halfPt = 36; break; 
        }
      }

      final dynamic fontVal = attrs['font']?.value;
      final String font =
          (fontVal is String && fontVal.isNotEmpty) ? fontVal : defaultFont;

      String colorXml = "";
      final dynamic colorVal = attrs['color']?.value;
      if (colorVal is String && colorVal.isNotEmpty) {
        final hex = colorVal.replaceAll('#', '');
        if (hex.length == 6) colorXml = '<w:color w:val="$hex"/>';
      }

      String highlightXml = "";
      final dynamic bgVal = attrs['background']?.value;
      if (bgVal is String && bgVal.isNotEmpty) {
        final hex = bgVal.replaceAll('#', '');
        if (hex.length == 6) {
          highlightXml = '<w:shd w:val="clear" w:color="auto" w:fill="$hex"/>';
        }
      }

      runs.add('''<w:r>
        <w:rPr>
          <w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font"/>
          <w:sz w:val="$halfPt"/>
          <w:szCs w:val="$halfPt"/>
          ${bold      ? '<w:b/><w:bCs/>'        : ''}
          ${italic    ? '<w:i/><w:iCs/>'        : ''}
          ${underline ? '<w:u w:val="single"/>' : ''}
          ${strike    ? '<w:strike/>'           : ''}
          $colorXml
          $highlightXml
        </w:rPr>
        <w:t xml:space="preserve">$text</w:t>
      </w:r>''');
    }
  }

    final String paragraphProps = '<w:pPr><w:jc w:val="$align"/>$pPrExtra<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>';

  if (runs.isEmpty) {
    return '<w:p>$paragraphProps<w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>';
  }
  return '<w:p>$paragraphProps${runs.join('\n')}</w:p>';
}

// ── Header / Footer builders ─────────────────────────────────────────────────

// Replaces newlines with <w:br/> tags so multi-line text wraps correctly in Word
String _escapeAndWrapXml(String text) {
  if (text.isEmpty) return '';
  final escaped = _escapeXml(text);
  return escaped.replaceAll('\n', '</w:t><w:br/><w:t xml:space="preserve">');
}

String _buildHeader(String text) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr><w:jc w:val="left"/></w:pPr> <!-- Left Aligned to match Flutter -->
    <w:r>
      <w:rPr><w:color w:val="707070"/><w:sz w:val="20"/></w:rPr>
      <w:t xml:space="preserve">${_escapeAndWrapXml(text)}</w:t>
    </w:r>
  </w:p>
</w:hdr>''';

String _buildFooter(String text) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr><w:jc w:val="center"/></w:pPr> <!-- Center Aligned -->
    <w:r>
      <w:rPr><w:color w:val="707070"/><w:sz w:val="20"/></w:rPr>
      <w:t xml:space="preserve">${_escapeAndWrapXml(text)}</w:t>
    </w:r>
  </w:p>
</w:ftr>''';

String _escapeXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

// ── OOXML boilerplate ────────────────────────────────────────────────────────
const String _contentTypesBase = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels"  ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml"   ContentType="application/xml"/>
  <Default Extension="png"   ContentType="image/png"/>
  <Default Extension="jpeg"  ContentType="image/jpeg"/>
  <Default Extension="jpg"   ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
''';

const String _wordRelsBase = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
''';

const String _relsRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>
</Relationships>
''';