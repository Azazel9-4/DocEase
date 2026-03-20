abstract class DocumentEvent {}

class TextChanged extends DocumentEvent {
  final String text;
  TextChanged(this.text);
}

class ToggleBold extends DocumentEvent {}
class ToggleItalic extends DocumentEvent {}
class ChangeFontSize extends DocumentEvent {
  final double size;
  ChangeFontSize(this.size);
}