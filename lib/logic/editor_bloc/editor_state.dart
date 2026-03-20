import 'package:flutter/material.dart';
import '../../services/print_view.dart';

enum SaveFormat { txt, docx, pdf }

enum SaveStatus { idle, saving, success, error, conflict } 

class EditorState {
  final String currentFileName;
  final String text;

  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  final TextAlign alignment;
  final double fontSize;
  final String fontFamily;

  final PaperSize pageSize;

  final bool isPrintView;
  final bool isHTMLView;
  final bool showToolbar;

  final bool hasUnsavedChanges;

  // Save sheet
  final SaveFormat selectedSaveFormat;
  final SaveStatus saveStatus;
  final String? saveError;

  final String? conflictFileName;
  final String? suggestedFileName;

  EditorState({
    required this.currentFileName,
    this.text = "",
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.alignment = TextAlign.left,
    this.fontSize = 12.0,
    this.fontFamily = 'Arial',
    this.pageSize = PaperSize.a4,
    this.isPrintView = false,
    this.isHTMLView = false,
    this.showToolbar = true,
    this.hasUnsavedChanges = false,
    this.selectedSaveFormat = SaveFormat.txt,
    this.saveStatus = SaveStatus.idle,
    this.saveError,
    this.conflictFileName,
    this.suggestedFileName,
  });

  EditorState copyWith({
    String? currentFileName,
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    TextAlign? alignment,
    double? fontSize,
    String? fontFamily,
    PaperSize? pageSize,
    bool? isPrintView,
    bool? isHTMLView,
    bool? showToolbar,
    bool? hasUnsavedChanges,
    SaveFormat? selectedSaveFormat,
    SaveStatus? saveStatus,
    String? saveError,
    String? conflictFileName,
    String? suggestedFileName,
  }) {
    return EditorState(
      currentFileName: currentFileName ?? this.currentFileName,
      text: text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      alignment: alignment ?? this.alignment,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      pageSize: pageSize ?? this.pageSize,
      isPrintView: isPrintView ?? this.isPrintView,
      isHTMLView: isHTMLView ?? this.isHTMLView,
      showToolbar: showToolbar ?? this.showToolbar,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      selectedSaveFormat: selectedSaveFormat ?? this.selectedSaveFormat,
      saveStatus: saveStatus ?? this.saveStatus,
      saveError: saveError ?? this.saveError,
      conflictFileName: conflictFileName ?? this.conflictFileName,
      suggestedFileName: suggestedFileName ?? this.suggestedFileName,
    );
  }
}