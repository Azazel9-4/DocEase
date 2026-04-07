// lib/services/mobile_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class MobileView extends StatefulWidget {
  final QuillController controller;
  final List<EmbedBuilder> embedBuilders;

  // ── NEW: accept the same font params as PrintView so sizes stay in sync ──
  final double fontSize;
  final String fontFamily;

  const MobileView({
    super.key,
    required this.controller,
    this.embedBuilders = const [],
    this.fontSize = 14.0,        // ← default 14 pt, same as EditorBloc default
    this.fontFamily = 'Arial',
  });

  @override
  State<MobileView> createState() => _MobileViewState();
}

class _MobileViewState extends State<MobileView> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ── pt → Flutter logical pixels (96 DPI, same formula as PrintView) ───────
  // 14 pt × (96/72) ≈ 18.67 px  — matches how Word renders 14 pt on screen.
  double get _displayFontSize => widget.fontSize * (96.0 / 72.0);

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: QuillEditor(
        controller: widget.controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          autoFocus: false,
          expands: true,
          scrollable: true,
          embedBuilders: widget.embedBuilders,

          // ── Inline size attributes: scale pt → px so they stay proportional
          // to the default paragraph size.
          //
          // Without this, setting size=14 stores 14.0 as a literal px value.
          // Because the default paragraph is now ~18.67 px (14 pt scaled),
          // 14 px would look smaller than "default" — which is the exact bug
          // the user reported. This builder applies the same ×(96/72) factor
          // to every inline size, making all picks feel like real pt values.
          customStyleBuilder: (attribute) {
            if (attribute.key == 'size') {
              final dynamic val = attribute.value;
              double pt = widget.fontSize; // fallback to current default
              if (val is num) {
                pt = val.toDouble();
              } else if (val is String) {
                switch (val) {
                  case 'small': pt = widget.fontSize * 0.75; break;
                  case 'large': pt = widget.fontSize * 1.17; break;
                  case 'huge':  pt = widget.fontSize * 1.5;  break;
                }
              }
              return TextStyle(fontSize: pt * (96.0 / 72.0));
            }
            return const TextStyle();
          },

          // ── Default paragraph style uses scaled pt → px ───────────────────
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              TextStyle(
                color: Colors.black,
                fontSize: _displayFontSize,   // ← was hardcoded 16; now 14pt scaled
                fontFamily: widget.fontFamily,
                height: 1.5,
              ),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(0, 0),
              const VerticalSpacing(0, 0),
              null,
            ),
          ),
        ),
      ),
    );
  }
}