import 'package:flutter/material.dart';
import '../../services/print_view.dart';
import 'editor_state.dart'; 

abstract class EditorEvent {}

class LoadInitialText extends EditorEvent {
  final String text;
  final String? fileName;
  LoadInitialText(this.text, this.fileName);
}

class UpdateText extends EditorEvent {
  final String fullText;
  UpdateText(this.fullText);
}

// Formatting
class ToggleBold extends EditorEvent {}
class ToggleItalic extends EditorEvent {}
class ToggleUnderline extends EditorEvent {}

class ChangeAlignment extends EditorEvent {
  final TextAlign alignment;
  ChangeAlignment(this.alignment);
}

class ChangeFontSize extends EditorEvent {
  final double size;
  ChangeFontSize(this.size);
}

class ChangeFontFamily extends EditorEvent {
  final String font;
  ChangeFontFamily(this.font);
}

class ChangePageSize extends EditorEvent {
  final PaperSize size;
  ChangePageSize(this.size);
}

// View
class TogglePrintView extends EditorEvent {}
class ToggleHTMLView extends EditorEvent {}
class ToggleToolbar extends EditorEvent {}

// File
class ChangeFileName extends EditorEvent {
  final String newName;
  ChangeFileName(this.newName);
}

class MarkSaved extends EditorEvent {}

// Save
class SelectSaveFormat extends EditorEvent {
  final SaveFormat format;
  SelectSaveFormat(this.format);
}

class RequestSave extends EditorEvent {}

class SaveCompleted extends EditorEvent {}

class SaveFailed extends EditorEvent {
  final String error;
  SaveFailed(this.error);
}

class ResolveConflict extends EditorEvent {
  final bool replace; // true = overwrite, false = keep both
  ResolveConflict({required this.replace});
}