// lib/logic/editor_bloc/editor_state.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../services/print_view.dart';

enum SaveFormat { json, txt, docx, pdf }
enum SaveStatus { idle, saving, success, error, conflict }

class EditorState {
  final String currentFileName;
  final quill.Document document;

  final bool showHeaderFooter;
  final PaperSize pageSize;
  final bool isPrintView;
  final bool isHTMLView;
  final bool showToolbar;
  final bool hasUnsavedChanges;

  final TextAlign alignment;
  final double fontSize;
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  // Save
  final SaveFormat selectedSaveFormat;
  final SaveStatus saveStatus;
  final String? saveError;
  final String? conflictFileName;
  final String? suggestedFileName;

  // JSON project tracking
  final String? projectFilePath;
  final bool isJsonProject;

  // Header / Footer / Background
  final String headerText;
  final String footerText;
  final bool isHeaderFooterLocked;
  final String? headerImagePath;
  final String? footerImagePath;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double bodyTopMargin;
  final double bgScale;
  final double bgOffsetX;
  final double bgOffsetY;

  /// Page margin in centimetres — single source of truth shared by
  /// PrintView, the DOCX generator, and the PDF generator.
  /// Default 2.54 cm matches MS Word's "Normal" margin preset.
  final double marginCm;

  String get text => document.toPlainText();

  EditorState({
    required this.currentFileName,
    quill.Document? document,
    this.showHeaderFooter = true,
    this.pageSize = PaperSize.a4,
    this.isPrintView = false,
    this.isHTMLView = false,
    this.showToolbar = true,
    this.hasUnsavedChanges = false,
    this.alignment = TextAlign.left,
    this.fontSize = 14.0,
    this.fontFamily = 'Arial',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.selectedSaveFormat = SaveFormat.json,
    this.saveStatus = SaveStatus.idle,
    this.saveError,
    this.conflictFileName,
    this.suggestedFileName,
    this.projectFilePath,
    this.isJsonProject = false,
    this.headerText = '',
    this.footerText = '',
    this.isHeaderFooterLocked = false,
    this.headerImagePath,
    this.footerImagePath,
    this.backgroundImagePath,
    this.backgroundOpacity = 0.9,
    this.bodyTopMargin = 160,
    this.bgScale = 1.0,
    this.bgOffsetX = 0.0,
    this.bgOffsetY = 0.0,
    this.marginCm = 2.54,
  }) : document = document ?? quill.Document();

  // ─────────────────────────────────────────────────────────────
  // SERIALIZATION
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson(quill.QuillController controller) {
    return {
      'version': 1,
      'currentFileName': currentFileName,
      'lastSaved': DateTime.now().toIso8601String(),
      'quillDelta': controller.document.toDelta().toJson(),
      'pageSize': pageSize.name,
      'backgroundImagePath': backgroundImagePath,
      'backgroundOpacity': backgroundOpacity,
      'bodyTopMargin': bodyTopMargin,
      'bgScale': bgScale,
      'bgOffsetX': bgOffsetX,
      'bgOffsetY': bgOffsetY,
      'headerText': headerText,
      'footerText': footerText,
      'isHeaderFooterLocked': isHeaderFooterLocked,
      'headerImagePath': headerImagePath,
      'footerImagePath': footerImagePath,
      'alignment': alignment.name,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderline': isUnderline,
      'marginCm': marginCm,
    };
  }

  static (EditorState, quill.QuillController) fromJson(
    Map<String, dynamic> json,
    String sourceFilePath,
  ) {
    final deltaJson = json['quillDelta'] as List<dynamic>? ?? [];
    final document = deltaJson.isEmpty
        ? quill.Document()
        : quill.Document.fromJson(deltaJson);

    final controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final pageSizeName = json['pageSize'] as String? ?? 'a4';
    final pageSize = PaperSize.values.firstWhere(
      (e) => e.name == pageSizeName,
      orElse: () => PaperSize.a4,
    );

    final alignName = json['alignment'] as String? ?? 'left';
    final alignment = switch (alignName) {
      'center'  => TextAlign.center,
      'right'   => TextAlign.right,
      'justify' => TextAlign.justify,
      _         => TextAlign.left,
    };

    final restoredState = EditorState(
      currentFileName:
          json['currentFileName'] as String? ?? 'Untitled Document',
      pageSize: pageSize,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      backgroundOpacity:
          (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.9,
      bodyTopMargin: (json['bodyTopMargin'] as num?)?.toDouble() ?? 160,
      bgScale: (json['bgScale'] as num?)?.toDouble() ?? 1.0,
      bgOffsetX: (json['bgOffsetX'] as num?)?.toDouble() ?? 0.0,
      bgOffsetY: (json['bgOffsetY'] as num?)?.toDouble() ?? 0.0,
      headerText: json['headerText'] as String? ?? '',
      footerText: json['footerText'] as String? ?? '',
      isHeaderFooterLocked:
          json['isHeaderFooterLocked'] as bool? ?? false,
      headerImagePath: json['headerImagePath'] as String?,
      footerImagePath: json['footerImagePath'] as String?,
      alignment: alignment,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      fontFamily: json['fontFamily'] as String? ?? 'Arial',
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isUnderline: json['isUnderline'] as bool? ?? false,
      // Default to 2.54 for old projects that don't have this field yet
      marginCm: (json['marginCm'] as num?)?.toDouble() ?? 2.54,
      isJsonProject: true,
      projectFilePath: sourceFilePath,
      hasUnsavedChanges: false,
      selectedSaveFormat: SaveFormat.json,
      saveStatus: SaveStatus.idle,
    );

    return (restoredState, controller);
  }

  // ─────────────────────────────────────────────────────────────
  // COPYWITH
  // ─────────────────────────────────────────────────────────────

  EditorState copyWith({
    String? currentFileName,
    quill.Document? document,
    bool? showHeaderFooter,
    PaperSize? pageSize,
    bool? isPrintView,
    bool? isHTMLView,
    bool? showToolbar,
    bool? hasUnsavedChanges,
    TextAlign? alignment,
    double? fontSize,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    SaveFormat? selectedSaveFormat,
    SaveStatus? saveStatus,
    String? saveError,
    String? conflictFileName,
    String? suggestedFileName,
    String? projectFilePath,
    bool? isJsonProject,
    String? headerText,
    String? footerText,
    bool? isHeaderFooterLocked,
    String? headerImagePath,
    String? footerImagePath,
    String? backgroundImagePath,
    double? backgroundOpacity,
    double? bodyTopMargin,
    double? bgScale,
    double? bgOffsetX,
    double? bgOffsetY,
    double? marginCm,
  }) {
    return EditorState(
      currentFileName: currentFileName ?? this.currentFileName,
      document: document ?? this.document,
      showHeaderFooter: showHeaderFooter ?? this.showHeaderFooter,
      pageSize: pageSize ?? this.pageSize,
      isPrintView: isPrintView ?? this.isPrintView,
      isHTMLView: isHTMLView ?? this.isHTMLView,
      showToolbar: showToolbar ?? this.showToolbar,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      alignment: alignment ?? this.alignment,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      selectedSaveFormat: selectedSaveFormat ?? this.selectedSaveFormat,
      saveStatus: saveStatus ?? this.saveStatus,
      saveError: saveError ?? this.saveError,
      conflictFileName: conflictFileName ?? this.conflictFileName,
      suggestedFileName: suggestedFileName ?? this.suggestedFileName,
      projectFilePath: projectFilePath ?? this.projectFilePath,
      isJsonProject: isJsonProject ?? this.isJsonProject,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      isHeaderFooterLocked: isHeaderFooterLocked ?? this.isHeaderFooterLocked,
      headerImagePath: headerImagePath ?? this.headerImagePath,
      footerImagePath: footerImagePath ?? this.footerImagePath,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      bodyTopMargin: bodyTopMargin ?? this.bodyTopMargin,
      bgScale: bgScale ?? this.bgScale,
      bgOffsetX: bgOffsetX ?? this.bgOffsetX,
      bgOffsetY: bgOffsetY ?? this.bgOffsetY,
      marginCm: marginCm ?? this.marginCm,
    );
  }
}