// lib/services/print_view.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'pagination_manager.dart';

export 'pagination_manager.dart' show PaginationManager;

enum PaperSize { a4, short, long }

class PrintView extends StatefulWidget {
  final quill.QuillController controller;
  final PaginationManager paginationManager;
  final PaperSize paperSize;
  final TextAlign alignment;
  final double fontSize;
  final String fontFamily;
  final String headerText;
  final String footerText;
  final bool isLocked;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double bodyTopMargin;
  final List<quill.EmbedBuilder> embedBuilders;
  final double marginCm;
  final bool showHeaderFooter;

  const PrintView({
    super.key,
    required this.controller,
    required this.paginationManager,
    this.paperSize = PaperSize.a4,
    this.alignment = TextAlign.left,
    this.fontSize = 14.0,
    this.fontFamily = 'Arial',
    this.headerText = '',
    this.footerText = '',
    this.isLocked = false,
    this.backgroundImagePath,
    this.backgroundOpacity = 0.9,
    this.bodyTopMargin = 160,
    this.embedBuilders = const [],
    this.marginCm = 2.54,
    this.showHeaderFooter = true,
  });

  @override
  State<PrintView> createState() => _PrintViewState();
}

enum _EditZone { body, headerFooter }

class _PrintViewState extends State<PrintView> with TickerProviderStateMixin {
  // ── Controllers & focus ───────────────────────────────────────────────────
  final TransformationController _transformationController =
      TransformationController();

  late AnimationController _animController;
  Animation<Matrix4>? _anim;

  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late FocusNode _focusNode;
  late FocusNode _headerFocusNode;
  late FocusNode _footerFocusNode;

  // ── Layout state ──────────────────────────────────────────────────────────
  late Size _pageSize;

  List<double> _pageStartOffsets = [0];
  final GlobalKey _measureKey = GlobalKey();

  bool _pendingRecompute = false;

  int _lastSelectionIndex = -1;
  int _lastCursorPage = 0; // tracks which page the cursor is on

  int _editorRebuildKey = 0;

  static const double _pageGap = 24.0;
  static const double _ruleGap = 6.0;

  static const double _documentLineHeight = 1.23;


  // MUST stay in sync with the vertical: value in the InteractiveViewer's Padding
  static const double _canvasTopPad = 16.0;

  double _currentScale = 1.0;
  _EditZone _activeZone = _EditZone.body;

  // ── Unit conversions ──────────────────────────────────────────────────────
  double get _margin => widget.marginCm * (96.0 / 2.54);
  double get _displayFontSize => widget.fontSize * (96.0 / 72.0);

  // ── Layout helpers ────────────────────────────────────────────────────────
  bool get _isBackgroundMode =>
      widget.backgroundImagePath != null &&
      widget.backgroundImagePath!.isNotEmpty;

  bool get _isHeaderFooterActive => _activeZone == _EditZone.headerFooter;

  double get _bodyWidth => _pageSize.width - _margin * 2;

  double get _dynamicHeaderHeight {
    if (_isBackgroundMode) return widget.bodyTopMargin;
    if (!widget.showHeaderFooter) return _margin;

    final tp = TextPainter(
      text: TextSpan(
        text:
            _headerController.text.isEmpty ? 'Header' : _headerController.text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _bodyWidth - 8);

    return math.max(_margin, tp.height + 30 + (_margin / 2));
  }

  double get _dynamicFooterHeight {
    if (_isBackgroundMode || !widget.showHeaderFooter) return _margin;

    final tp = TextPainter(
      text: TextSpan(
        text:
            _footerController.text.isEmpty ? 'Footer' : _footerController.text,
        style: const TextStyle(fontSize: 12, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _bodyWidth);

    return math.max(_margin, tp.height + 40 + (_margin / 2));
  }

  double get _bodyTopOffset => _dynamicHeaderHeight;

  double get _pageBodyHeight {
    final raw = _isBackgroundMode
        ? _pageSize.height - widget.bodyTopMargin - _margin
        : _pageSize.height - _dynamicHeaderHeight - _dynamicFooterHeight;
    final lh = _displayFontSize * 1.15;
    if (lh <= 0) return raw;
    final lines = (raw / lh).floor();
    return lines.clamp(1, 99999) * lh;
  }

  int get _numPages => _pageStartOffsets.length;

    // Gets the exact pixel height Flutter is using to draw the lines
  double _getExactLineHeight() {
    final style = TextStyle(
      fontSize: _displayFontSize,
      fontFamily: widget.fontFamily,
      height: _documentLineHeight, 
    );
    final tp = TextPainter(
      text: TextSpan(text: 'Tg', style: style), // Use tall and low letters
      textDirection: TextDirection.ltr,
    )..layout();
    
    final metrics = tp.computeLineMetrics();
    if (metrics.isNotEmpty) {
      return metrics.first.height;
    }
    return _displayFontSize * _documentLineHeight;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pageSize = _getPaperSize(widget.paperSize);
    _headerController = TextEditingController(text: widget.headerText);
    _footerController = TextEditingController(text: widget.footerText);
    _headerController.addListener(_onHeaderFooterChanged);
    _footerController.addListener(_onHeaderFooterChanged);
    _focusNode = FocusNode();
    _headerFocusNode = FocusNode();
    _footerFocusNode = FocusNode();

    _focusNode.addListener(_onFocusChanged);

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _animController.addListener(() {
      if (_anim != null) {
        _transformationController.value = _anim!.value;
      }
    });

    widget.controller.addListener(_onDocumentChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _recomputeFromRender());
  }

  @override
  void didUpdateWidget(PrintView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onDocumentChanged);
      widget.controller.addListener(_onDocumentChanged);
    }
    if (old.paperSize != widget.paperSize ||
        old.fontSize != widget.fontSize ||
        old.fontFamily != widget.fontFamily ||
        old.marginCm != widget.marginCm ||
        old.backgroundImagePath != widget.backgroundImagePath ||
        old.bodyTopMargin != widget.bodyTopMargin) {
      _pageSize = _getPaperSize(widget.paperSize);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeFromRender());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocumentChanged);
    _focusNode.removeListener(_onFocusChanged);
    _headerController.removeListener(_onHeaderFooterChanged);
    _footerController.removeListener(_onHeaderFooterChanged);
    _headerController.dispose();
    _footerController.dispose();
    _focusNode.dispose();
    _headerFocusNode.dispose();
    _footerFocusNode.dispose();
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onHeaderFooterChanged() {
    if (!mounted) return;
    setState(() {});

    if (_pendingRecompute) return;
    _pendingRecompute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingRecompute = false;
      _recomputeFromRender();
    });
  }

  // ── Auto Zoom Feature (Word Mobile UX) ───────────────────────────────────
  void _onFocusChanged() {
    if (_focusNode.hasFocus && _activeZone == _EditZone.body) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _focusNode.hasFocus) {
          _scrollToCursor(centerVertically: true, forceZoom: true);
        }
      });
    }
  }

  // ── Document change handler ───────────────────────────────────────────────
  void _onDocumentChanged() {
    final int currentOffset = widget.controller.selection.baseOffset;
    if (currentOffset != _lastSelectionIndex) {
      _lastSelectionIndex = currentOffset;
      if (_activeZone == _EditZone.body && _focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCursor(centerVertically: false, forceZoom: false);
        });
      }
    }

    if (_pendingRecompute) return;
    _pendingRecompute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingRecompute = false;
      _recomputeFromRender();
    });
  }

  // ── Page Break Computation ────────────────────────────────────────────────
 // ── Page Break Computation ────────────────────────────────────────────────
  void _recomputeFromRender() {
    if (!mounted) return;

    final ctx = _measureKey.currentContext;
    double totalH = 0;
    List<Rect> leafRects = [];

    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        totalH = box.size.height;
        void gatherLeaves(RenderObject node) {
          bool isLeaf = true;
          node.visitChildren((child) {
            isLeaf = false;
            gatherLeaves(child);
          });
          if (isLeaf && node is RenderBox && node.hasSize) {
            final offset = node.localToGlobal(Offset.zero, ancestor: box);
            leafRects.add(offset & node.size);
          }
        }

        gatherLeaves(box);
      }
    }

    // This is the exact height of a single line of text
    final double lh = _getExactLineHeight();

    if (totalH <= 0) {
      final style = TextStyle(
        fontSize: _displayFontSize,
        fontFamily: widget.fontFamily,
        height: 1.15,
      );
      final text = widget.controller.document.toPlainText();
      final tp = TextPainter(
        text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: _bodyWidth);
      totalH = tp.height;

      final metrics = tp.computeLineMetrics();
      double y = 0;
      for (var m in metrics) {
        leafRects.add(Rect.fromLTWH(0, y, _bodyWidth, m.height));
        y += m.height;
      }
    }

    final pageH = _pageBodyHeight;
    List<double> offsets = [0];
    double currentY = 0;

    while (currentY + pageH < totalH) {
      double targetY = currentY + pageH;
      double snappedY = targetY;

      // ── KEY FIX: Snapping Logic ──────────────────────────────────────────
      // If our arbitrary page break cuts directly through a rendered block of 
      // text, we snap the break to the TOP of the line to prevent slicing.
      if (lh > 0) {
        for (var rect in leafRects) {
          // Does the page break slice into this paragraph box?
          if (targetY > rect.top + 1 && targetY < rect.bottom - 1) {
            
            // Find exactly which line we are slicing through
            double localY = targetY - rect.top;
            double lineIndex = (localY / lh).floor().toDouble();
            double lineTop = rect.top + (lineIndex * lh);

            // If snapping puts us at or before the current page start (e.g., huge font), 
            // force it to move forward by at least one line to prevent freezing.
            if (lineTop <= currentY + 1) {
              lineTop += lh;
            }

            snappedY = lineTop; // Push the whole line to the next page!
            break;
          }
        }
      }

      // Safeguard just in case snapping fails
      if (snappedY <= currentY) {
        snappedY = currentY + pageH;
      }

      currentY = snappedY;
      offsets.add(currentY);
    }

    final hadFocus = _focusNode.hasFocus;

    if (offsets != _pageStartOffsets) {
      final bool pageWasDeleted = offsets.length < _pageStartOffsets.length;
      if (pageWasDeleted) {
        _editorRebuildKey++;
      }

      setState(() => _pageStartOffsets = offsets);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hadFocus && _activeZone == _EditZone.body) {
          if (pageWasDeleted || !_focusNode.hasFocus) {
            _focusNode.unfocus();
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) _focusNode.requestFocus();
            });
          }
        }
        _scrollToCursor();
      });
    }
  }

  Size _getPaperSize(PaperSize size) {
    switch (size) {
      case PaperSize.a4:
        return const Size(794, 1123);
      case PaperSize.short:
        return const Size(816, 1056);
      case PaperSize.long:
        return const Size(816, 1344);
    }
  }

  // ── Cursor helpers ────────────────────────────────────────────────────────

  /// Document-space Y of the cursor (raw text height, no page gaps).
  double _cursorDocY() {
    final offset = widget.controller.selection.baseOffset;
    if (offset <= 0) return 0;
    final text = widget.controller.document.toPlainText();
    final safe = offset.clamp(0, text.length);
    final tp = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? ' ' : text.substring(0, safe),
        style: TextStyle(
            fontSize: _displayFontSize,
            fontFamily: widget.fontFamily,
            height: 1.15),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: _bodyWidth);
    final double lh = _getExactLineHeight();
    
    // Tracks the vertical center of the line so it doesn't bounce/tunnel
    return math.max(0.0, tp.height - (lh / 2));
  }

  int _pageIndexForDocY(double docY) {
    for (int i = _pageStartOffsets.length - 1; i >= 0; i--) {
      if (docY >= _pageStartOffsets[i]) return i;
    }
    return 0;
  }

  /// Converts document-space Y → canvas-space Y.
  ///
  /// Canvas layout produced by the Column inside InteractiveViewer's Padding:
  ///
  ///   _canvasTopPad                              (Padding vertical: 16 → top)
  ///   + pageIndex × (_pageSize.height + _pageGap) (pages above this one)
  ///   + _bodyTopOffset                            (header height inside page)
  ///   + (docY − _pageStartOffsets[pageIndex])     (position within body)
  double _docYToCanvasY(double docY) {
    final pageIdx = _pageIndexForDocY(docY);
    final pageCanvasTop =
        _canvasTopPad + pageIdx * (_pageSize.height + _pageGap);
    final yWithinBody = docY - _pageStartOffsets[pageIdx];
    return pageCanvasTop + _bodyTopOffset + yWithinBody;
  }

  // ── Auto scroll ───────────────────────────────────────────────────────────
  void _scrollToCursor({
    bool centerVertically = false,
    bool forceZoom = false,
  }) {
    if (!mounted) return;

    final double docY = _cursorDocY();
    final int cursorPage = _pageIndexForDocY(docY);

    if (cursorPage >= _pageStartOffsets.length) return;

    final matrix = _transformationController.value;
    double scale = matrix.getMaxScaleOnAxis();

    final viewportHeight = context.size?.height ?? 0;
    final viewportWidth = context.size?.width ?? 0;
    if (viewportHeight <= 0 || viewportWidth <= 0) return;

    bool scaleChanged = false;
    if (forceZoom && scale < 0.7) {
      scale = 0.7;
      scaleChanged = true;
    }

    final double cursorCanvasY = _docYToCanvasY(docY);

    final currentVisibleTop = -matrix.getTranslation().y / scale;
    final currentVisibleBottom = currentVisibleTop + (viewportHeight / scale);

    // Detect a page boundary crossing
    final bool crossedPage = cursorPage != _lastCursorPage;
    _lastCursorPage = cursorPage;

    double newVisibleTop = currentVisibleTop;
    double newX = matrix.getTranslation().x;
    bool needsPan = false;

    if (centerVertically || scaleChanged) {
      // Focus tap / zoom-in: centre the cursor vertically
      newVisibleTop = cursorCanvasY - (viewportHeight / scale) / 2;
      newX = (viewportWidth / 2) - ((_pageSize.width / 2) * scale);
      needsPan = true;
    } else if (crossedPage) {
      // ── KEY FIX ──────────────────────────────────────────────────────────
      // The cursor just moved to a different page.  Centre the new page
      // vertically and skip the animation entirely → instant snap, no tunnel.
      newVisibleTop = cursorCanvasY - (viewportHeight / scale) / 2;
      needsPan = true;
    } else {
      // Normal typing within a page: gentle edge-scroll only
      const double topPad = 60.0;
      const double bottomPad = 100.0;

      if (cursorCanvasY < currentVisibleTop + topPad) {
        newVisibleTop = cursorCanvasY - topPad;
        needsPan = true;
      } else if (cursorCanvasY > currentVisibleBottom - bottomPad) {
        newVisibleTop = cursorCanvasY - (viewportHeight / scale) + bottomPad;
        needsPan = true;
      }
    }

    if (!needsPan && !scaleChanged) return;

    // Clamp so we can never pan into the grey void
    final contentHeight =
        _canvasTopPad * 2 + _numPages * (_pageSize.height + _pageGap);
    final maxVisibleTop =
        math.max(0.0, contentHeight - (viewportHeight / scale));
    newVisibleTop = newVisibleTop.clamp(0.0, maxVisibleTop);

    final maxVisibleLeft =
        math.max(0.0, _pageSize.width * scale - viewportWidth);
    if (newX > 0) newX = 0;
    if (newX < -maxVisibleLeft) newX = -maxVisibleLeft;

    final newMatrix = Matrix4.identity()
      ..translate(newX, -newVisibleTop * scale)
      ..scale(scale, scale);

    if (_animController.isAnimating) _animController.stop();

    if (crossedPage && !centerVertically && !scaleChanged) {
      // Instant snap on page cross — no animation = no tunneling
      _transformationController.value = newMatrix;
    } else {
      // Smooth scroll within the same page
      _anim = Matrix4Tween(begin: matrix, end: newMatrix).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.forward(from: 0.0);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bodyOpacity = _isHeaderFooterActive ? 0.35 : 1.0;
    final hfOpacity = _isHeaderFooterActive ? 1.0 : 0.5;
    final numPages = _numPages;

    return LayoutBuilder(builder: (context, constraints) {
      _currentScale = (constraints.maxWidth - 24) / _pageSize.width;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_transformationController.value == Matrix4.identity()) {
          _transformationController.value =
              Matrix4.identity()..scale(_currentScale, _currentScale);
        }
      });

      return Container(
        color: const Color(0xFFD6D6D6),
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.3,
              maxScale: 3.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(80),
              child: Padding(
                // vertical value here MUST equal _canvasTopPad above
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  children: [
                    ...List.generate(numPages, (pageIndex) {
                      final startY = _pageStartOffsets[pageIndex];

                      final endY = pageIndex + 1 < numPages
                          ? _pageStartOffsets[pageIndex + 1]
                          : startY + _pageBodyHeight;

                      final clipHeight =
                          (endY - startY).clamp(0.0, _pageBodyHeight);
                      final pageNumber = pageIndex + 1;

                      return Padding(
                        padding: EdgeInsets.only(bottom: _pageGap),
                        child: SizedBox(
                          width: _pageSize.width,
                          height: _pageSize.height,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                if (_isBackgroundMode)
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: widget.backgroundOpacity,
                                      child: Image.file(
                                          File(widget.backgroundImagePath!),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                if (!_isBackgroundMode && widget.showHeaderFooter)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: _dynamicHeaderHeight,
                                    child: _buildHeader(
                                        pageNumber, numPages, hfOpacity),
                                  ),
                                Positioned(
                                  top: _bodyTopOffset,
                                  left: _margin,
                                  right: _margin,
                                  height: _pageBodyHeight,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    child: AnimatedOpacity(
                                      opacity: bodyOpacity,
                                      duration:
                                          const Duration(milliseconds: 250),
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: SizedBox(
                                          height: clipHeight,
                                          width: _bodyWidth,
                                          child: ClipRect(
                                            child: OverflowBox(
                                              alignment: Alignment.topLeft,
                                              maxHeight: double.infinity,
                                              maxWidth: _bodyWidth,
                                              child: Transform.translate(
                                                offset: Offset(0, -startY),
                                                child: AbsorbPointer(
                                                  absorbing:
                                                      _isHeaderFooterActive,
                                                  child: SizedBox(
                                                      width: _bodyWidth,
                                                      child: _buildQuillEditor(
                                                          pageIndex)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!_isBackgroundMode && widget.showHeaderFooter)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: _dynamicFooterHeight,
                                    child: _buildFooter(hfOpacity),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            Positioned(
              left: -10000,
              top: 0,
              width: _bodyWidth,
              child: _buildMeasureEditor(),
            ),
          ],
        ),
      );
    });
  }

  quill.QuillEditorConfig get _editorConfig => quill.QuillEditorConfig(
        padding: EdgeInsets.zero,
        autoFocus: false,
        expands: false,
        scrollable: false,
        embedBuilders: widget.embedBuilders,
        customStyleBuilder: (attribute) {
          if (attribute.key == 'size') {
            final dynamic val = attribute.value;
            double pt = widget.fontSize;
            if (val is num) {
              pt = val.toDouble();
            } else if (val is String) {
              switch (val) {
                case 'small':
                  pt = widget.fontSize * 0.75;
                  break;
                case 'large':
                  pt = widget.fontSize * 1.17;
                  break;
                case 'huge':
                  pt = widget.fontSize * 1.50;
                  break;
              }
            }
            return TextStyle(fontSize: pt * (96.0 / 72.0));
          }
          return const TextStyle();
        },
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(
            TextStyle(
                fontSize: _displayFontSize,
                fontFamily: widget.fontFamily,
                color: Colors.black,
                height: 1.15),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(0, 0),
            const quill.VerticalSpacing(0, 0),
            null,
          ),
        ),
      );

  Widget _buildQuillEditor(int pageIndex) => quill.QuillEditor(
        key: ValueKey('quill_editor_${pageIndex}_$_editorRebuildKey'),
        controller: widget.controller,
        focusNode: _focusNode,
        scrollController: ScrollController(),
        config: _editorConfig,
      );

  Widget _buildMeasureEditor() => RepaintBoundary(
        child: quill.QuillEditor(
          key: _measureKey,
          controller: widget.controller,
          focusNode: FocusNode(canRequestFocus: false),
          scrollController: ScrollController(),
          config: _editorConfig.copyWith(
              autoFocus: false, scrollable: false, expands: false),
        ),
      );

  Widget _buildHeader(int pageNumber, int numPages, double hfOpacity) {
    return GestureDetector(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: _isHeaderFooterActive && !widget.isLocked
            ? const Color(0xFFF0F4FF)
            : Colors.transparent,
        child: AnimatedOpacity(
          opacity: hfOpacity,
          duration: const Duration(milliseconds: 250),
          child: Padding(
            padding: EdgeInsets.only(
                left: _margin, right: _margin, top: _margin / 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: widget.isLocked || !_isHeaderFooterActive
                          ? Text(
                              _headerController.text.isEmpty
                                  ? 'Header'
                                  : _headerController.text,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: widget.isLocked
                                    ? Colors.grey.shade400
                                    : (_headerController.text.isEmpty
                                        ? Colors.grey.shade400
                                        : const Color(0xFF404040)),
                              ),
                            )
                          : TextField(
                              controller: _headerController,
                              focusNode: _headerFocusNode,
                              maxLines: null,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333)),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Type header...',
                                hintStyle:
                                    TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: _ruleGap),
                _DashedDivider(
                  color: widget.isLocked
                      ? Colors.grey.shade200
                      : (_isHeaderFooterActive
                          ? Colors.blue.shade300
                          : Colors.grey.shade300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(double hfOpacity) {
    return GestureDetector(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: _isHeaderFooterActive && !widget.isLocked
            ? const Color(0xFFF0F4FF)
            : Colors.transparent,
        child: AnimatedOpacity(
          opacity: hfOpacity,
          duration: const Duration(milliseconds: 250),
          child: Padding(
            padding: EdgeInsets.only(
                left: _margin, right: _margin, bottom: _margin / 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DashedDivider(
                  color: widget.isLocked
                      ? Colors.grey.shade200
                      : (_isHeaderFooterActive
                          ? Colors.blue.shade300
                          : Colors.grey.shade300),
                ),
                const SizedBox(height: _ruleGap),
                if (_isHeaderFooterActive && !widget.isLocked) ...[
                  TextField(
                    controller: _footerController,
                    focusNode: _footerFocusNode,
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 9, color: Color(0xFF404040)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Type footer...',
                      hintStyle: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _EditBadge(label: 'Footer'),
                ] else ...[
                  Text(
                    _footerController.text.isEmpty
                        ? 'Footer'
                        : _footerController.text,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 9,
                      color: widget.isLocked
                          ? Colors.grey.shade400
                          : (_footerController.text.isEmpty
                              ? Colors.grey.shade400
                              : const Color(0xFF404040)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  final String label;
  const _EditBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 8,
                color: Colors.blue,
                fontWeight: FontWeight.w600)),
      );
}

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          const dashWidth = 4.0;
          const dashSpace = 3.0;
          final count =
              (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            children: List.generate(
              count,
              (_) => Padding(
                padding: const EdgeInsets.only(right: dashSpace),
                child: Container(width: dashWidth, height: 1, color: color),
              ),
            ),
          );
        }),
      );
}