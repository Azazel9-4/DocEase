// lib/logic/editor_bloc/editor_event.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../services/print_view.dart';
import 'editor_state.dart';

abstract class EditorEvent {
  const EditorEvent();
}

// ─────────────────────────────────────────────────────────────
// DOCUMENT / CONTENT
// ─────────────────────────────────────────────────────────────

class LoadInitialText extends EditorEvent {
  final String text;
  final String? fileName;
  const LoadInitialText({required this.text, this.fileName});
}

class LoadJsonProject extends EditorEvent {
  final String jsonString;
  final String sourceFilePath;
  const LoadJsonProject({
    required this.jsonString,
    required this.sourceFilePath,
  });
}

class UpdateDocument extends EditorEvent {
  final quill.Document document;
  const UpdateDocument(this.document);
}

class MarkSaved extends EditorEvent {
  const MarkSaved();
}

// ─────────────────────────────────────────────────────────────
// VIEW / DISPLAY
// ─────────────────────────────────────────────────────────────

class ChangePageSize extends EditorEvent {
  final PaperSize size;
  const ChangePageSize(this.size);
}

class TogglePrintView extends EditorEvent {
  const TogglePrintView();
}

class ToggleHTMLView extends EditorEvent {
  const ToggleHTMLView();
}

class ToggleToolbar extends EditorEvent {
  const ToggleToolbar();
}

// ─────────────────────────────────────────────────────────────
// FILE NAME
// ─────────────────────────────────────────────────────────────

class ChangeFileName extends EditorEvent {
  final String newName;
  const ChangeFileName(this.newName);
}

// ─────────────────────────────────────────────────────────────
// SAVE FORMAT SELECTION
// ─────────────────────────────────────────────────────────────

class SelectSaveFormat extends EditorEvent {
  final SaveFormat format;
  const SelectSaveFormat(this.format);
}

// ─────────────────────────────────────────────────────────────
// SAVE FLOW
// ─────────────────────────────────────────────────────────────

class RequestSave extends EditorEvent {
  const RequestSave();
}

class ResolveConflict extends EditorEvent {
  final bool replace;
  const ResolveConflict({required this.replace});
}

class SaveCompleted extends EditorEvent {
  const SaveCompleted();
}

class SaveFailed extends EditorEvent {
  final String error;
  const SaveFailed(this.error);
}

// ─────────────────────────────────────────────────────────────
// HEADER / FOOTER / BACKGROUND
// ─────────────────────────────────────────────────────────────

class SetHeaderFooter extends EditorEvent {
  final String header;
  final String footer;
  final bool locked;
  final String? headerImagePath;
  final String? footerImagePath;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double bodyTopMargin;
  final double bgScale;
  final double bgOffsetX;
  final double bgOffsetY;
  final double marginCm; // ← ADD THIS
  final bool showHeaderFooter;
  final PaperSize paperSize;


  const SetHeaderFooter({
    required this.header,
    required this.footer,
    required this.locked,
    this.headerImagePath,
    this.footerImagePath,
    this.backgroundImagePath,
    this.backgroundOpacity = 0.9,
    this.bodyTopMargin = 160,
    this.bgScale = 1.0,
    this.bgOffsetX = 0.0,
    this.bgOffsetY = 0.0,
    this.marginCm = 2.54, // ← ADD THIS
    this.showHeaderFooter = true,
    this.paperSize = PaperSize.a4,

  });
}

// ─────────────────────────────────────────────────────────────
// FORMATTING
// ─────────────────────────────────────────────────────────────

class ChangeAlignment extends EditorEvent {
  final TextAlign alignment;
  const ChangeAlignment(this.alignment);
}

class ChangeFontSize extends EditorEvent {
  final double fontSize;
  const ChangeFontSize(this.fontSize);
}

class ChangeFontFamily extends EditorEvent {
  final String fontFamily;
  const ChangeFontFamily(this.fontFamily);
}

class ToggleBold extends EditorEvent {
  const ToggleBold();
}

class ToggleItalic extends EditorEvent {
  const ToggleItalic();
}

class ToggleUnderline extends EditorEvent {
  const ToggleUnderline();
}

/// Change the page margin (in centimetres).
/// This is the single source of truth — PrintView, DOCX, and PDF
/// all derive their margin values from this.
class ChangeMargin extends EditorEvent {
  final double marginCm;
  const ChangeMargin(this.marginCm);
}