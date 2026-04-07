import 'package:flutter/material.dart';

class CursorPosition {
  final int pageIndex;
  final int localPosition;

  const CursorPosition({
    required this.pageIndex,
    required this.localPosition,
  });
}

class StyledText {
  String text;
  bool bold;
  bool italic;
  bool underline;
  TextAlign alignment;
  double fontSize;
  String fontFamily;

  StyledText(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = TextAlign.left,
    this.fontSize = 14,
    this.fontFamily = 'Arial',
  });

  StyledText copyWith({
    String? text,
    bool? bold,
    bool? italic,
    bool? underline,
    double? fontSize,
    String? fontFamily,
  }) {
    return StyledText(
      text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

// ---------------------------------------------------------------------------
// Paper layout constants — mirrors Word's default margins
// ---------------------------------------------------------------------------
class PaperLayout {
  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final double headerHeight;
  final double footerHeight;
  final double headerSpacing; // gap between header and body
  final double footerSpacing; // gap between body and footer

  const PaperLayout({
    required this.pageWidth,
    required this.pageHeight,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.headerHeight,
    required this.footerHeight,
    required this.headerSpacing,
    required this.footerSpacing,
  });

  double get bodyWidth => pageWidth - marginLeft - marginRight;

  double get bodyHeight =>
      pageHeight -
      marginTop -
      marginBottom -
      headerHeight -
      footerHeight -
      headerSpacing -
      footerSpacing;

  double get bodyTopOffset =>
      marginTop + headerHeight + headerSpacing;

  // A4: 210mm x 297mm at 96dpi ≈ 794 x 1123px
  static const PaperLayout a4 = PaperLayout(
    pageWidth: 794,
    pageHeight: 1123,
    marginTop: 72,      // ~19mm
    marginBottom: 72,
    marginLeft: 72,
    marginRight: 72,
    headerHeight: 36,
    footerHeight: 36,
    headerSpacing: 12,
    footerSpacing: 12,
  );

  // Short (Letter): 8.5in x 11in at 96dpi = 816 x 1056px
  static const PaperLayout short = PaperLayout(
    pageWidth: 816,
    pageHeight: 1056,
    marginTop: 72,
    marginBottom: 72,
    marginLeft: 72,
    marginRight: 72,
    headerHeight: 36,
    footerHeight: 36,
    headerSpacing: 12,
    footerSpacing: 12,
  );

  // Long (Legal): 8.5in x 14in at 96dpi = 816 x 1344px
  static const PaperLayout long = PaperLayout(
    pageWidth: 816,
    pageHeight: 1344,
    marginTop: 72,
    marginBottom: 72,
    marginLeft: 72,
    marginRight: 72,
    headerHeight: 36,
    footerHeight: 36,
    headerSpacing: 12,
    footerSpacing: 12,
  );
}

// ---------------------------------------------------------------------------
// PaginationManager
// ---------------------------------------------------------------------------
class PaginationManager extends ChangeNotifier {
  String _documentText = '';
  final List<List<StyledText>> _pages = [];
  int _globalCursorPosition = 0;

  // Current layout — defaults to A4, updated when paper size changes
  PaperLayout _layout = PaperLayout.a4;

  // Current text style metrics — updated when font changes
  double _fontSize = 12;
  String _fontFamily = 'Arial';
  bool _isBold = false;
  bool _isItalic = false;
  double _lineHeight = 1.8;

  PaginationManager();

  // ==============================
  // Getters
  // ==============================

  String get fullText => _documentText;
  List<List<StyledText>> get pages => List.unmodifiable(_pages);
  int get globalCursorPosition => _globalCursorPosition;
  PaperLayout get layout => _layout;

  // ==============================
  // Configuration
  // ==============================

  void setLayout(PaperLayout layout) {
    _layout = layout;
    _paginateByHeight();
    notifyListeners();
  }

  void setTextStyle({
    double? fontSize,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    double? lineHeight,
  }) {
    _fontSize = fontSize ?? _fontSize;
    _fontFamily = fontFamily ?? _fontFamily;
    _isBold = isBold ?? _isBold;
    _isItalic = isItalic ?? _isItalic;
    _lineHeight = lineHeight ?? _lineHeight;
    _paginateByHeight();
    notifyListeners();
  }

  // ==============================
  // Initialization
  // ==============================

  void initialize() {
    _documentText = '';
    _globalCursorPosition = 0;
    _pages
      ..clear()
      ..add([StyledText('')]);
    notifyListeners();
  }

  void loadInitialText(String text) {
    _documentText = text;
    _globalCursorPosition = 0;
    _paginateByHeight();
    notifyListeners();
  }

  // ==============================
  // Updates
  // ==============================

  void updateContent(String newText) {
    _documentText = newText;
    _globalCursorPosition =
        _globalCursorPosition.clamp(0, _documentText.length);
    _paginateByHeight();
    notifyListeners();
  }

  void setGlobalCursorPosition(int position) {
    _globalCursorPosition =
        position.clamp(0, _documentText.length);
    notifyListeners();
  }

  void updateFromPages(
    List<List<StyledText>> newPages, {
    required int editingPageIndex,
    required int localCursorOffset,
  }) {
    _pages
      ..clear()
      ..addAll(newPages);

    _documentText = newPages
        .expand((page) => page)
        .map((e) => e.text)
        .join();

    _globalCursorPosition =
        getGlobalFromLocal(editingPageIndex, localCursorOffset);

    notifyListeners();
  }

  // ==============================
  // Cursor Mapping
  // ==============================

  CursorPosition getLocalCursorFromGlobal() {
    int current = 0;
    for (int i = 0; i < _pages.length; i++) {
      final pageText = _pages[i].map((e) => e.text).join();
      final length = pageText.length;
      if (_globalCursorPosition <= current + length) {
        return CursorPosition(
          pageIndex: i,
          localPosition: _globalCursorPosition - current,
        );
      }
      current += length;
    }
    return CursorPosition(
      pageIndex: _pages.isEmpty ? 0 : _pages.length - 1,
      localPosition: _pages.isEmpty
          ? 0
          : _pages.last.map((e) => e.text).join().length,
    );
  }

  int getGlobalFromLocal(int pageIndex, int localOffset) {
    if (_pages.isEmpty) return 0;
    int global = 0;
    for (int i = 0; i < pageIndex && i < _pages.length; i++) {
      global += _pages[i].map((e) => e.text).join().length;
    }
    return (global + localOffset).clamp(0, _documentText.length);
  }

  // ==============================
  // Height-aware Pagination
  // ==============================

  void _paginateByHeight() {
    _pages.clear();

    if (_documentText.isEmpty) {
      _pages.add([StyledText('')]);
      return;
    }

    final style = TextStyle(
      fontSize: _fontSize,
      fontFamily: _fontFamily,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      height: _lineHeight,
    );

    final maxBodyWidth = _layout.bodyWidth;
    final maxBodyHeight = _layout.bodyHeight;

    // Split text into lines first
    final lines = _documentText.split('\n');
    final List<String> pageTexts = [];
    String currentPageText = '';
    double currentPageHeight = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineWithBreak = i < lines.length - 1 ? '$line\n' : line;

      final lineHeight = _measureTextHeight(
        lineWithBreak,
        style,
        maxBodyWidth,
      );

      if (currentPageHeight + lineHeight > maxBodyHeight &&
          currentPageText.isNotEmpty) {
        // Current page is full — save it and start a new one
        pageTexts.add(currentPageText);
        currentPageText = lineWithBreak;
        currentPageHeight = lineHeight;
      } else {
        currentPageText += lineWithBreak;
        currentPageHeight += lineHeight;
      }
    }

    // Add the last page
    if (currentPageText.isNotEmpty) {
      pageTexts.add(currentPageText);
    }

    if (pageTexts.isEmpty) {
      _pages.add([StyledText('')]);
      return;
    }

    for (final pageText in pageTexts) {
      _pages.add([StyledText(pageText)]);
    }
  }

  double _measureTextHeight(
      String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) {
      // Empty line still has height
      final tp = TextPainter(
        text: TextSpan(text: ' ', style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      tp.layout(maxWidth: maxWidth);
      return tp.height;
    }

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    tp.layout(maxWidth: maxWidth);
    return tp.height;
  }
}